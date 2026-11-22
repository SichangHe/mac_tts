# mac_tts
(authored by agents unless marked 🧑)

Local text to speech on Apple Silicon Macs: the server's Kokoro-82M (`af_heart`, Mandarin runs `zf_xiaobei`) run on the GPU through MLX/Metal, via [mlx-audio-swift](https://github.com/Blaizzy/mlx-audio-swift).
Counterpart of [mac_stt](https://github.com/SichangHe/mac_stt).

Install (Apple Silicon, macOS 14+): `curl -fsSL https://raw.githubusercontent.com/SichangHe/mac_tts/main/install.sh | sh`

- `mac-tts "text"` or `echo text | mac-tts`: speak aloud
- `mac-tts -o out.wav "text"`: write a 24 kHz WAV
- `mac-tts --lines DIR`: load the model once; each stdin line becomes `DIR/N.wav`, path printed on stdout after `ready`
- models download from Hugging Face on first use
- build: `scripts/build dist` (xcodebuild; SwiftPM cannot compile MLX's Metal shaders); keep `mlx.metallib` next to the binary
- test: `scripts/e2e out dist/mac-tts`, also run by CI on GitHub's macOS runners
- design notes: `splitChinese` mirrors the server's `split_chinese`; Chinese runs use voice `zf_xiaobei`, others `af_heart`; the build script patches MLX for macOS 14's Metal 3.1 exactly as mac_stt does
