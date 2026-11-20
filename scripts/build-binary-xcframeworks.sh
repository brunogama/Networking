#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo 'Usage: build-binary-xcframeworks.sh TAG OUTPUT_DIR OWNER/REPO' >&2
  exit 2
fi

tag=$1
output_dir=$2
repository=$3
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(cd "$script_dir/.." && pwd)
component='(0|[1-9][0-9]*)'
if ! [[ $tag =~ ^${component}[.]${component}[.]${component}$ ]]; then
  echo 'Expected a stable MAJOR.MINOR.PATCH tag without a v prefix.' >&2
  exit 2
fi
if [[ $output_dir == / || -z $output_dir ]]; then
  echo 'Refusing an unsafe output directory.' >&2
  exit 2
fi

modules=(NetworkingCore NetworkingRuntime NetworkingObservability NetworkingSSE Networking)
platform_names=(macOS iOS iOSSimulator tvOS tvOSSimulator watchOS watchOSSimulator)
platform_destinations=(
  'generic/platform=macOS'
  'generic/platform=iOS'
  'generic/platform=iOS Simulator'
  'generic/platform=tvOS'
  'generic/platform=tvOS Simulator'
  'generic/platform=watchOS'
  'generic/platform=watchOS Simulator'
)

workspace=$(mktemp -d "${TMPDIR:-/tmp}/networking-binary-release.XXXXXXXX")
trap 'rm -rf "$workspace"' EXIT
rm -rf "$output_dir"
mkdir -p "$output_dir" "$workspace/Packages"
ditto "$repository_root/Packages/NetworkingCore" "$workspace/Packages/NetworkingCore"
ditto "$repository_root/Packages/Networking" "$workspace/Packages/Networking"

python3 - "$workspace" <<'PY'
from pathlib import Path
import sys

workspace = Path(sys.argv[1])
core_manifest = workspace / "Packages/NetworkingCore/Package.swift"
networking_manifest = workspace / "Packages/Networking/Package.swift"
core_source = core_manifest.read_text()
networking_source = networking_manifest.read_text()
core_old = '.library(name: "NetworkingCore", targets: ["NetworkingCore"])'
networking_old = '].map { Product.library(name: $0, targets: [$0]) }'
if core_old not in core_source or networking_old not in networking_source:
    raise SystemExit("Unable to prepare dynamic products from the expected package manifests.")
core_manifest.write_text(core_source.replace(
    core_old,
    '.library(name: "NetworkingCore", type: .dynamic, targets: ["NetworkingCore"])',
    1,
))
networking_manifest.write_text(networking_source.replace(
    networking_old,
    '].map { Product.library(name: $0, type: .dynamic, targets: [$0]) }',
    1,
))
PY

package_directory() {
  case $1 in
    NetworkingCore) printf '%s\n' "$workspace/Packages/NetworkingCore" ;;
    *) printf '%s\n' "$workspace/Packages/Networking" ;;
  esac
}

archive_module() {
  local module=$1
  local platform_name=$2
  local destination=$3
  local package_path
  package_path=$(package_directory "$module")
  local archive_path="$workspace/archives/$module-$platform_name.xcarchive"
  local derived_data_path="$workspace/derived/$module-$platform_name"
  local framework
  local source_module
  local module_directory

  (
    cd "$package_path"
    xcodebuild archive -quiet \
      -scheme "$module" \
      -destination "$destination" \
      -archivePath "$archive_path" \
      -derivedDataPath "$derived_data_path" \
      SKIP_INSTALL=NO \
      BUILD_LIBRARY_FOR_DISTRIBUTION=YES \
      MACH_O_TYPE=staticlib \
      CODE_SIGNING_ALLOWED=NO
  )

  framework=$(find "$archive_path/Products" -type d -name "$module.framework" -print -quit)
  source_module=$(find \
    "$derived_data_path/Build/Intermediates.noindex/ArchiveIntermediates/$module/BuildProductsPath" \
    -type d -name "$module.swiftmodule" -print -quit)
  if [[ -z $framework || -z $source_module ]]; then
    echo "Archive for $module on $platform_name lacks a framework or Swift module." >&2
    exit 1
  fi
  if ! find "$source_module" -name '*.swiftinterface' \
    ! -name '*.private.swiftinterface' \
    ! -name '*.package.swiftinterface' -print -quit | grep -q .; then
    echo "Archive for $module on $platform_name lacks a public Swift interface." >&2
    exit 1
  fi

  if [[ -d "$framework/Versions/A" ]]; then
    module_directory="$framework/Versions/A/Modules"
    mkdir -p "$module_directory"
    cp -R "$source_module" "$module_directory/"
    if [[ ! -e "$framework/Modules" ]]; then
      ln -s Versions/Current/Modules "$framework/Modules"
    fi
  else
    module_directory="$framework/Modules"
    mkdir -p "$module_directory"
    cp -R "$source_module" "$module_directory/"
  fi
  printf '%s\n' "$framework"
}

for module in "${modules[@]}"; do
  framework_paths=()
  for index in "${!platform_names[@]}"; do
    framework_paths+=("$(archive_module "$module" "${platform_names[$index]}" "${platform_destinations[$index]}")")
  done

  create_arguments=(-create-xcframework)
  for framework in "${framework_paths[@]}"; do
    create_arguments+=(-framework "$framework")
  done
  create_arguments+=(-output "$output_dir/$module.xcframework")
  xcodebuild "${create_arguments[@]}"

  (
    cd "$output_dir"
    ditto -c -k --sequesterRsrc --keepParent "$module.xcframework" "$module.xcframework.zip"
  )
done

"$script_dir/render-binary-manifest.sh" "$tag" "$output_dir" "$repository"
