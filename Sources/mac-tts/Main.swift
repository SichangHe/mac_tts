import Foundation
@preconcurrency import MLX
@preconcurrency import MLXAudioCore
import MLXAudioTTS

let usage = """
    usage: mac-tts [-o FILE.wav] [TEXT...]   speak TEXT (or stdin) aloud, or write it to FILE.wav
           mac-tts --lines DIR               keep the model loaded; each stdin line becomes DIR/N.wav, whose path is printed
    Kokoro-82M on the GPU through MLX/Metal; English voice `af_heart`, Mandarin runs voice `zf_xiaobei`.
    """

/// Text cut into `(isChinese, run)` pieces in order, matching `split_chinese` in the server's `audio-service.py`:
/// a Chinese run starts and ends with a Han character and keeps CJK punctuation, digits, and spaces inside it.
func splitChinese(_ text: String) -> [(Bool, String)] {
    let han = "\\p{Script=Han}"
    let inner = "\\x{3000}-\\x{303f}\\x{ff00}-\\x{ffef}"
    let run = try! Regex("[\(han)](?:[\(han)\(inner)0-9\\s]*[\(han)\(inner)])?")
    var pieces: [(Bool, String)] = []
    var at = text.startIndex
    for m in text.matches(of: run) {
        let gap = String(text[at..<m.range.lowerBound])
        if !gap.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { pieces.append((false, gap)) }
        pieces.append((true, String(text[m.range])))
        at = m.range.upperBound
    }
    let tail = String(text[at...])
    if !tail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { pieces.append((false, tail)) }
    return pieces
}

/// `text` cut at sentence ends (then commas, then spaces) into pieces of at most `limit` characters:
/// Kokoro takes at most 510 phoneme tokens per call, and the server's pipeline splits long text the same way.
func sentences(_ text: String, limit: Int = 200) -> [String] {
    var out: [String] = [], cur = ""
    func flush() { let t = cur.trimmingCharacters(in: .whitespacesAndNewlines); if !t.isEmpty { out.append(t) }; cur = "" }
    for ch in text {
        cur.append(ch)
        if ".!?;。！？；\n".contains(ch) { flush() }
        else if cur.count >= limit, ",，、 ".contains(ch) { flush() }
        else if cur.count >= limit * 2 { flush() }
    }
    flush()
    return out
}

// 🧑 "use pretty much the same thing as the server currently uses"
/// Speak `text` into one 24 kHz mono waveform, like the server's `speak`.
func synthesize(_ model: SpeechGenerationModel, _ text: String) async throws -> [Float] {
    var samples: [Float] = []
    for (isChinese, run) in splitChinese(text) {
        for piece in sentences(run, limit: isChinese ? 80 : 200) {
            let audio = try await model.generate(
                text: piece, voice: isChinese ? "zf_xiaobei" : "af_heart",
                refAudio: nil, refText: nil, language: nil)
            samples += audio.asArray(Float.self)
        }
    }
    return samples
}

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(Data("mac-tts: \(msg)\n".utf8))
    exit(2)
}

@main
struct MacTTS {
    static func main() async {
        var args = Array(CommandLine.arguments.dropFirst())
        if args.first == "-h" || args.first == "--help" { print(usage); exit(0) }
        do {
            let model = try await TTS.loadModel(modelRepo: "mlx-community/Kokoro-82M-bf16")
            if args.first == "--lines" {
                guard args.count == 2 else { fail("--lines takes one DIR") }
                let dir = URL(fileURLWithPath: args[1])
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                print("ready"); fflush(stdout)
                var n = 0
                while let line = readLine() {
                    let out = dir.appendingPathComponent("\(n).wav")
                    n += 1
                    try AudioUtils.writeWavFile(samples: try await synthesize(model, line), sampleRate: model.sampleRate, fileURL: out)
                    print(out.path); fflush(stdout)
                }
            } else {
                var out: URL?
                if args.first == "-o" {
                    guard args.count >= 2 else { fail("-o takes FILE.wav") }
                    out = URL(fileURLWithPath: args[1])
                    args.removeFirst(2)
                }
                let text = args.isEmpty ? String(decoding: FileHandle.standardInput.readDataToEndOfFile(), as: UTF8.self) : args.joined(separator: " ")
                let samples = try await synthesize(model, text)
                guard !samples.isEmpty else { fail("no speech produced for this text") }
                let file = out ?? FileManager.default.temporaryDirectory.appendingPathComponent("mac-tts-\(getpid()).wav")
                try AudioUtils.writeWavFile(samples: samples, sampleRate: model.sampleRate, fileURL: file)
                if out == nil {
                    let player = try Process.run(URL(fileURLWithPath: "/usr/bin/afplay"), arguments: [file.path])
                    player.waitUntilExit()
                    try? FileManager.default.removeItem(at: file)
                }
            }
            // Skip C++ static destructors: mac_stt saw MLX's Metal teardown segfault at exit on macOS 15.
            fflush(stdout)
            _exit(0)
        } catch {
            fail(error.localizedDescription)
        }
    }
}
