#!/bin/bash
# Generate llms.txt from Swift symbol graphs
# Usage: ./scripts/generate-llms-txt.sh

set -euo pipefail

OUTPUT_FILE="${1:-llms.txt}"
mkdir -p "$PWD/.build"
BUILD_DIR=$(mktemp -d "$PWD/.build/llms-symbol-graphs.XXXXXX")
TEMP_OUTPUT=$(mktemp "${OUTPUT_FILE}.tmp.XXXXXX")
trap 'rm -f "$TEMP_OUTPUT"; rm -rf "$BUILD_DIR"' EXIT

# Define packages in dependency order
packages=(
  "NetworkingMacros"
  "Networking"
)

echo "Generating symbol graphs for all packages..."
for pkg in "${packages[@]}"; do
  echo "  Building $pkg..."
  mkdir -p "$BUILD_DIR/$pkg"
  swift build --package-path "Packages/$pkg" \
    -Xswiftc -emit-symbol-graph \
    -Xswiftc -emit-symbol-graph-dir -Xswiftc "$BUILD_DIR/$pkg"
  test -s "$BUILD_DIR/$pkg/$pkg.symbols.json" || {
    echo "Missing symbol graph for $pkg" >&2
    exit 1
  }
done

# Start llms.txt output
cat > "$TEMP_OUTPUT" << 'HEADER'
# Networking - Swift HTTP Client

A Swift 6 URLSession library with request values, actor-owned middleware state,
scoped cancellation, optional caching, diagnostics, and HTTP client macros.

---

## Overview

The repository contains two Swift packages:

| Package | Purpose |
|---------|---------|
| NetworkingMacros | Swift compiler plugin for HTTP client macros |
| Networking | Core async/await HTTP client with middleware |

---

## Quick Start

```swift
import Foundation
import Networking

let client = NetworkClient()
guard let url = URL(string: "https://api.example.com/users") else {
    throw URLError(.badURL)
}
let response = try await client.execute(HTTPRequest(method: .get, url: url))
```

With the optional macro package and an application-defined `User: Decodable`:

```swift
import Networking
import NetworkingMacros

@API(baseURL: .absolute("https://api.example.com"))
protocol UsersAPI {
    @GET(.path("/users"))
    func getUsers() async throws -> [User]
}
```

---

## Public API

HEADER

# Extract every public product, including modules re-exported by Networking.
modules=(NetworkingMacros NetworkingCore NetworkingRuntime NetworkingObservability
  NetworkingObservabilityOTLP NetworkingTesting NetworkingSSE Networking)
for module in "${modules[@]}"; do
  package="Networking"
  if [[ "$module" == "NetworkingMacros" ]]; then package="NetworkingMacros"; fi
  SYMBOL_FILE="$BUILD_DIR/$package/$module.symbols.json"
  test -s "$SYMBOL_FILE" || {
    echo "Missing symbol graph for $module" >&2
    exit 1
  }

  printf '\n### %s\n\n' "$module" >> "$TEMP_OUTPUT"

  source_module="$module"
  if [[ "$module" == "NetworkingMacros" ]]; then
    source_module="NetworkingMacrosDeclarations"
  fi
  source_prefix="file://$PWD/Packages/$package/Sources/$source_module/"

  for kind in struct protocol enum class typealias macro; do
    case "$kind" in
      struct) heading="Structs" ;;
      protocol) heading="Protocols" ;;
      enum) heading="Enums" ;;
      class) heading="Classes and actors" ;;
      typealias) heading="Type aliases" ;;
      macro) heading="Macros" ;;
    esac
    symbols=$(jq -r --arg kind "swift.$kind" --arg prefix "$source_prefix" '
      [.symbols[]?
        | select(.accessLevel == "public" or .accessLevel == "open")
        | select((.location.uri // "") | startswith($prefix))
        | select(.kind.identifier == $kind
          or ($kind == "swift.class" and .kind.identifier == "swift.actor"))
        | .names.title] | unique | .[]' "$SYMBOL_FILE")
    if [[ -n "$symbols" ]]; then
      printf '**%s:**\n\n' "$heading" >> "$TEMP_OUTPUT"
      while IFS= read -r name; do
        printf -- '- `%s`\n' "$name" >> "$TEMP_OUTPUT"
      done <<< "$symbols"
      printf '\n' >> "$TEMP_OUTPUT"
    fi
  done
done

# Add footer
cat >> "$TEMP_OUTPUT" << 'FOOTER'

---

## Documentation

- GitHub: https://github.com/brunogama/Networking
- API Reference: https://brunogama.github.io/Networking/documentation/networking

---

## Requirements

- Swift 6.0+
- iOS 16+, macOS 13+, tvOS 16+, watchOS 9+

---

## License

MIT License - see LICENSE file for details.

---
*Auto-generated from Swift symbol graphs*
FOOTER

# Count symbols
total=$(awk '/^- `/{count++} END {print count+0}' "$TEMP_OUTPUT")
mv "$TEMP_OUTPUT" "$OUTPUT_FILE"
echo ""
echo "Generated $OUTPUT_FILE with $total public symbols"
