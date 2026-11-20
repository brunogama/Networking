#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo 'Usage: render-binary-manifest.sh TAG ASSET_DIR OWNER/REPO' >&2
  exit 2
fi

tag=$1
asset_dir=$2
repository=$3
component='(0|[1-9][0-9]*)'
if ! [[ $tag =~ ^${component}[.]${component}[.]${component}$ ]]; then
  echo 'Expected a stable MAJOR.MINOR.PATCH tag without a v prefix.' >&2
  exit 2
fi
if ! [[ $repository =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo 'Expected an OWNER/REPO identifier.' >&2
  exit 2
fi

modules=(NetworkingCore NetworkingRuntime NetworkingObservability NetworkingSSE Networking)
checksums=()
for module in "${modules[@]}"; do
  archive="$asset_dir/$module.xcframework.zip"
  if [[ ! -f $archive ]]; then
    echo "Missing XCFramework archive: $archive" >&2
    exit 1
  fi
  unzip -tq "$archive" >/dev/null
  checksum=$(swift package compute-checksum "$archive")
  if ! [[ $checksum =~ ^[a-f0-9]{64}$ ]]; then
    echo "Invalid checksum for $archive" >&2
    exit 1
  fi
  checksums+=("$checksum")
done

manifest="$asset_dir/Package.binary.swift"
temporary=$(mktemp "$asset_dir/.Package.binary.swift.XXXXXXXX")
trap 'rm -f "$temporary"' EXIT
{
  cat <<'SWIFT'
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "NetworkingBinary",
  platforms: [.iOS(.v16), .macOS(.v13), .tvOS(.v16), .watchOS(.v9)],
  products: [
    .library(name: "NetworkingCore", targets: ["NetworkingCore"]),
    .library(name: "NetworkingRuntime", targets: ["NetworkingCore", "NetworkingRuntime"]),
    .library(name: "NetworkingObservability", targets: [
      "NetworkingCore", "NetworkingRuntime", "NetworkingObservability",
    ]),
    .library(name: "NetworkingSSE", targets: [
      "NetworkingCore", "NetworkingRuntime", "NetworkingSSE",
    ]),
    .library(name: "Networking", targets: [
      "NetworkingCore", "NetworkingRuntime", "NetworkingObservability",
      "NetworkingSSE", "Networking",
    ]),
  ],
  targets: [
SWIFT
  for index in "${!modules[@]}"; do
    module=${modules[$index]}
    printf '    .binaryTarget(\n      name: "%s",\n      url: "https://github.com/%s/releases/download/%s/%s.xcframework.zip",\n      checksum: "%s"\n    ),\n' \
      "$module" "$repository" "$tag" "$module" "${checksums[$index]}"
  done
  printf '  ]\n)\n'
} > "$temporary"
mv "$temporary" "$manifest"
printf '%s\n' "$manifest"
