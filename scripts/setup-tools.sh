#!/bin/bash
# Explicit one-time setup; verify.sh never downloads or installs tools.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
HOMEBREW_NO_AUTO_UPDATE=1 brew bundle install

# Official universal binary avoids a source build on Intel Macs.
version=0.65.1
checksum=c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0
mkdir -p .build/tools/bin
staging="$(mktemp -d "$root/.build/tools/download.XXXXXX")"
archive="$staging/portable_swiftlint.zip"
curl --fail --location --show-error \
    "https://github.com/realm/SwiftLint/releases/download/$version/portable_swiftlint.zip" \
    --output "$archive"
printf '%s  %s\n' "$checksum" "$archive" | shasum --algorithm 256 --check
unzip -p "$archive" swiftlint > "$staging/swiftlint"
chmod +x "$staging/swiftlint"
"$staging/swiftlint" version
mv "$staging/swiftlint" .build/tools/bin/swiftlint
printf 'Installed SwiftLint %s locally. Run bash scripts/verify.sh\n' "$version"
