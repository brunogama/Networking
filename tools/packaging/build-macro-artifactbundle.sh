#!/usr/bin/env bash
# build-macro-artifactbundle.sh -- Build NetworkingMacros artifact bundle
#
# Usage:
#   Local build (macOS arm64 + x86_64 from source):
#     ./build-macro-artifactbundle.sh <version>
#
#   CI assembly (pre-built binaries):
#     ./build-macro-artifactbundle.sh <version> --ci \
#       --macos-arm64 <path> --macos-x86_64 <path> --linux-x86_64 <path>

set -euo pipefail

PRODUCT="NetworkingMacros"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
OUTPUT_DIR="$REPO_ROOT/.build/artifact-bundle"

usage() {
    echo "Usage: $0 <version> [--ci --macos-arm64 <path> --macos-x86_64 <path> --linux-x86_64 <path>]"
    exit 1
}

if [[ $# -lt 1 ]]; then
    usage
fi

VERSION="$1"
shift

CI_MODE=false
MACOS_ARM64=""
MACOS_X86_64=""
LINUX_X86_64=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ci) CI_MODE=true; shift ;;
        --macos-arm64) MACOS_ARM64="$2"; shift 2 ;;
        --macos-x86_64) MACOS_X86_64="$2"; shift 2 ;;
        --linux-x86_64) LINUX_X86_64="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
done

BUNDLE_DIR="$OUTPUT_DIR/$PRODUCT.artifactbundle"
rm -rf "$BUNDLE_DIR"

mkdir -p "$BUNDLE_DIR/$PRODUCT-macos-arm64/bin"
mkdir -p "$BUNDLE_DIR/$PRODUCT-macos-x86_64/bin"
mkdir -p "$BUNDLE_DIR/$PRODUCT-linux-x86_64/bin"

if [[ "$CI_MODE" == true ]]; then
    echo "==> CI assembly mode"
    [[ -n "$MACOS_ARM64" ]] && cp "$MACOS_ARM64" "$BUNDLE_DIR/$PRODUCT-macos-arm64/bin/$PRODUCT"
    [[ -n "$MACOS_X86_64" ]] && cp "$MACOS_X86_64" "$BUNDLE_DIR/$PRODUCT-macos-x86_64/bin/$PRODUCT"
    [[ -n "$LINUX_X86_64" ]] && cp "$LINUX_X86_64" "$BUNDLE_DIR/$PRODUCT-linux-x86_64/bin/$PRODUCT"
else
    echo "==> Building $PRODUCT from source (macOS arm64)"
    cd "$REPO_ROOT"
    swift build -c release --product "$PRODUCT" --triple arm64-apple-macosx
    cp ".build/arm64-apple-macosx/release/$PRODUCT" "$BUNDLE_DIR/$PRODUCT-macos-arm64/bin/$PRODUCT"

    echo "==> Building $PRODUCT from source (macOS x86_64)"
    swift build -c release --product "$PRODUCT" --triple x86_64-apple-macosx
    cp ".build/x86_64-apple-macosx/release/$PRODUCT" "$BUNDLE_DIR/$PRODUCT-macos-x86_64/bin/$PRODUCT"

    echo "==> Code signing macOS binaries"
    codesign --sign - --force "$BUNDLE_DIR/$PRODUCT-macos-arm64/bin/$PRODUCT"
    codesign --sign - --force "$BUNDLE_DIR/$PRODUCT-macos-x86_64/bin/$PRODUCT"
fi

cat > "$BUNDLE_DIR/info.json" <<INFOJSON
{
  "schemaVersion": "1.0",
  "artifacts": {
    "$PRODUCT": {
      "version": "$VERSION",
      "type": "executable",
      "variants": [
        {
          "path": "$PRODUCT-macos-arm64/bin/$PRODUCT",
          "supportedTriples": ["arm64-apple-macosx"]
        },
        {
          "path": "$PRODUCT-macos-x86_64/bin/$PRODUCT",
          "supportedTriples": ["x86_64-apple-macosx"]
        },
        {
          "path": "$PRODUCT-linux-x86_64/bin/$PRODUCT",
          "supportedTriples": ["x86_64-unknown-linux-gnu"]
        }
      ]
    }
  }
}
INFOJSON

cd "$OUTPUT_DIR"
ZIP_NAME="$PRODUCT.artifactbundle.zip"
rm -f "$ZIP_NAME"
zip -r -y "$ZIP_NAME" "$PRODUCT.artifactbundle"

echo ""
echo "==> Artifact bundle: $OUTPUT_DIR/$ZIP_NAME"

if command -v swift >/dev/null 2>&1; then
    CHECKSUM=$(swift package compute-checksum "$OUTPUT_DIR/$ZIP_NAME")
    echo "==> Checksum: $CHECKSUM"
else
    CHECKSUM=$(shasum -a 256 "$OUTPUT_DIR/$ZIP_NAME" | cut -d' ' -f1)
    echo "==> SHA-256: $CHECKSUM"
fi
