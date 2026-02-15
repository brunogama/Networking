#!/bin/bash
# Generate llms.txt from Swift symbol graphs
# Usage: ./scripts/generate-llms-txt.sh

set -e

OUTPUT_FILE="${1:-llms.txt}"
BUILD_DIR=".build/symbol-graphs"

# Define packages in dependency order
packages=(
  "MacroTemplateKit"
  "NetworkingMacros"
  "Networking"
  "NetworkingWebSocket"
  "NetworkingGraphQL"
)

echo "Generating symbol graphs for all packages..."
mkdir -p "$BUILD_DIR"

for pkg in "${packages[@]}"; do
  echo "  Building $pkg..."
  swift build --package-path "Packages/$pkg" \
    -Xswiftc -emit-symbol-graph \
    -Xswiftc -emit-symbol-graph-dir -Xswiftc "$BUILD_DIR/$pkg" 2>/dev/null || true
done

# Start llms.txt output
cat > "$OUTPUT_FILE" << 'HEADER'
# ModernNetworking - Swift HTTP Client Framework

A production-grade Swift networking library featuring async/await, interceptors, macros, and multi-transport support.

## Overview

ModernNetworking is a monorepo containing 5 Swift packages:

| Package | Purpose |
|---------|---------|
| MacroTemplateKit | SwiftSyntax template DSL for macro code generation |
| NetworkingMacros | Swift compiler plugin for HTTP client macros |
| Networking | Core async/await HTTP client with middleware |
| NetworkingWebSocket | Actor-based WebSocket client |
| NetworkingGraphQL | Type-safe GraphQL client |

## Quick Start

```swift
import Networking

// Simple GET request
let client = NetworkClient()
let response = try await client.execute(HTTPRequest(url: URL(string: "https://api.example.com/users")!))

// Using @API macro
@API
protocol UsersAPI {
    @GET("/users")
    func getUsers() async throws -> [User]

    @POST("/users")
    func createUser(@Body user: User) async throws -> User
}
```

## Public API

HEADER

# Extract symbols for each package
for pkg in "${packages[@]}"; do
  SYMBOL_FILE="$BUILD_DIR/$pkg/$pkg.symbols.json"

  if [ ! -f "$SYMBOL_FILE" ]; then
    echo "  Warning: No symbol graph for $pkg"
    continue
  fi

  echo "" >> "$OUTPUT_FILE"
  echo "### $pkg" >> "$OUTPUT_FILE"
  echo "" >> "$OUTPUT_FILE"

  # Extract structs
  structs=$(jq -r '[.symbols[]? | select(.accessLevel == "public" or .accessLevel == "open") | select(.kind.identifier == "swift.struct") | .names.title] | unique | .[]' "$SYMBOL_FILE" 2>/dev/null || true)
  if [ -n "$structs" ]; then
    echo "**Structs:**" >> "$OUTPUT_FILE"
    echo "$structs" | while read -r name; do
      [ -n "$name" ] && echo "- \`$name\`" >> "$OUTPUT_FILE"
    done
    echo "" >> "$OUTPUT_FILE"
  fi

  # Extract protocols
  protocols=$(jq -r '[.symbols[]? | select(.accessLevel == "public" or .accessLevel == "open") | select(.kind.identifier == "swift.protocol") | .names.title] | unique | .[]' "$SYMBOL_FILE" 2>/dev/null || true)
  if [ -n "$protocols" ]; then
    echo "**Protocols:**" >> "$OUTPUT_FILE"
    echo "$protocols" | while read -r name; do
      [ -n "$name" ] && echo "- \`$name\`" >> "$OUTPUT_FILE"
    done
    echo "" >> "$OUTPUT_FILE"
  fi

  # Extract enums
  enums=$(jq -r '[.symbols[]? | select(.accessLevel == "public" or .accessLevel == "open") | select(.kind.identifier == "swift.enum") | .names.title] | unique | .[]' "$SYMBOL_FILE" 2>/dev/null || true)
  if [ -n "$enums" ]; then
    echo "**Enums:**" >> "$OUTPUT_FILE"
    echo "$enums" | while read -r name; do
      [ -n "$name" ] && echo "- \`$name\`" >> "$OUTPUT_FILE"
    done
    echo "" >> "$OUTPUT_FILE"
  fi

  # Extract classes
  classes=$(jq -r '[.symbols[]? | select(.accessLevel == "public" or .accessLevel == "open") | select(.kind.identifier == "swift.class") | .names.title] | unique | .[]' "$SYMBOL_FILE" 2>/dev/null || true)
  if [ -n "$classes" ]; then
    echo "**Classes:**" >> "$OUTPUT_FILE"
    echo "$classes" | while read -r name; do
      [ -n "$name" ] && echo "- \`$name\`" >> "$OUTPUT_FILE"
    done
    echo "" >> "$OUTPUT_FILE"
  fi

  # Extract type aliases
  typealiases=$(jq -r '[.symbols[]? | select(.accessLevel == "public" or .accessLevel == "open") | select(.kind.identifier == "swift.typealias") | .names.title] | unique | .[]' "$SYMBOL_FILE" 2>/dev/null || true)
  if [ -n "$typealiases" ]; then
    echo "**Type Aliases:**" >> "$OUTPUT_FILE"
    echo "$typealiases" | while read -r name; do
      [ -n "$name" ] && echo "- \`$name\`" >> "$OUTPUT_FILE"
    done
    echo "" >> "$OUTPUT_FILE"
  fi
done

# Add footer
cat >> "$OUTPUT_FILE" << 'FOOTER'

## Documentation

- GitHub: https://github.com/brunogama/Networking
- API Reference: https://brunogama.github.io/Networking/documentation/networking

## Requirements

- Swift 6.0+
- iOS 16+, macOS 13+, tvOS 16+, watchOS 9+

## License

MIT License - see LICENSE file for details.

---
*Auto-generated from Swift symbol graphs*
FOOTER

# Count symbols
total=$(grep -c "^- \`" "$OUTPUT_FILE" || echo "0")
echo ""
echo "Generated $OUTPUT_FILE with $total public symbols"
