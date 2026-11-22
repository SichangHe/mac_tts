#!/bin/sh
# Installs mac-tts from the latest release and downloads the voice model.
#   curl -fsSL https://raw.githubusercontent.com/SichangHe/mac_tts/main/install.sh | sh
# Environment: MAC_TTS_VERSION (tag, default latest), MAC_TTS_PREFIX (default ~/.local),
#              MAC_TTS_SKIP_SETUP=1 to skip the model download.
set -eu

repo=SichangHe/mac_tts
prefix=${MAC_TTS_PREFIX:-$HOME/.local}
asset=mac-tts-macos-arm64.tar.gz

[ "$(uname -s)" = Darwin ] || { echo "mac-tts runs on macOS only" >&2; exit 1; }
[ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ] || { echo "mac-tts needs an Apple Silicon Mac" >&2; exit 1; }
[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 14 ] || { echo "mac-tts needs macOS 14 or newer" >&2; exit 1; }

if [ -n "${MAC_TTS_VERSION:-}" ]; then base=https://github.com/$repo/releases/download/$MAC_TTS_VERSION
else base=https://github.com/$repo/releases/latest/download; fi

work=$(mktemp -d "${TMPDIR:-/tmp}/mac-tts-install.XXXXXX")
trap 'rm -rf "$work"' EXIT
echo "downloading $base/$asset"
curl -fSL --retry 3 -o "$work/$asset" "$base/$asset"
curl -fsSL --retry 3 -o "$work/$asset.sha256" "$base/$asset.sha256"
(cd "$work" && shasum -a 256 -c "$asset.sha256")
tar -xzf "$work/$asset" -C "$work"

# The binary and its mlx.metallib live in their own directory: mac-stt keeps a different
# mlx.metallib next to itself in $prefix/bin, and MLX loads the one beside the executable.
lib=$prefix/lib/mac-tts
mkdir -p "$lib" "$prefix/bin"
install -m 755 "$work/mac-tts" "$lib/mac-tts"
install -m 644 "$work/mlx.metallib" "$lib/mlx.metallib"
printf '#!/bin/sh\nexec "%s/mac-tts" "$@"\n' "$lib" > "$prefix/bin/mac-tts"
chmod 755 "$prefix/bin/mac-tts"
echo "installed $prefix/bin/mac-tts"

if [ "${MAC_TTS_SKIP_SETUP:-}" != 1 ]; then
    echo "downloading the voice model and speaking a test sentence"
    "$prefix/bin/mac-tts" "mac text to speech is ready."
fi

case ":$PATH:" in
    *":$prefix/bin:"*) ;;
    *) echo "add to your shell profile: export PATH=\"$prefix/bin:\$PATH\"" ;;
esac
