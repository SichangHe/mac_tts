// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "mac-tts",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "mac-tts", targets: ["mac-tts"])],
    dependencies: [
        .package(url: "https://github.com/Blaizzy/mlx-audio-swift.git", revision: "e0de9e79d69c24a1277982bb3d8fafc4da5ce035"),
    ],
    targets: [
        .executableTarget(
            name: "mac-tts",
            dependencies: [
                .product(name: "MLXAudioTTS", package: "mlx-audio-swift"),
                .product(name: "MLXAudioCore", package: "mlx-audio-swift"),
            ]
        ),
    ]
)
