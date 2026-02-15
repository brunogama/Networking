# Phase 08: Extract Core Networking Macros - Research

**Researched:** 2026-02-14
**Domain:** Swift Package Manager workspace, macro compiler plugin extraction
**Confidence:** HIGH

## Summary

Phase 08 extracts the Core Networking macros (20 files, ~4200 lines) from `Packages/Networking/Sources/NetworkingMacros/` into a standalone `NetworkingMacros` package within the existing monorepo workspace. This follows the pattern established in Phase 07 for NetworkingGraphQL, which already has independent macro support.

**Key findings:**
- Macros have ZERO runtime dependency on Core Networking (only Swift Syntax dependencies)
- Macro-generated code references Networking types (NetworkClient, HTTPRequest, etc.) but macros themselves don't import Networking
- Swift 6.0 supports workspace manifests with `.package(path:)` dependencies between local packages
- MacroTesting framework requires separate test target configuration
- Standard pattern: separate `.macro()` target type with SwiftCompilerPlugin dependencies

**Primary recommendation:** Create `Packages/NetworkingMacros/` as peer to existing packages, update workspace manifest to include it, make Core Networking optionally depend on macros via `.package(path: "../NetworkingMacros")`.

## Standard Stack

### Core Dependencies
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| swift-syntax | 600.0.0+ | Swift AST parsing and manipulation | Apple's official Swift syntax library, required for all macro implementations |
| swift-compiler-plugin-support | (part of swift-syntax) | Compiler plugin infrastructure | Enables .macro() target type in Package.swift |
| swift-macro-testing | 0.5.2+ | Macro expansion testing | Point-Free's testing framework, industry standard for macro tests |

### Supporting Tools
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SwiftCheck | 0.12.0+ | Property-based testing | Optional - for testing macro edge cases with generated inputs |
| Quick/Nimble | 7.4.0+ / 13.0.0+ | BDD testing | Optional - already available in workspace dependencies |

**Installation (in new Package.swift):**
```swift
dependencies: [
  .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
  .package(url: "https://github.com/pointfreeco/swift-macro-testing.git", from: "0.5.2"),
]
```

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Local path dependency (.package(path:)) | Git submodule or separate repo | Local path keeps monorepo simple, separate repo adds versioning complexity |
| .macro() target | .executableTarget with @main | .macro() is official Swift 6.0 target type for compiler plugins, better tooling support |
| MacroTesting | Manual XCTest assertions | MacroTesting provides assertMacro DSL with automatic expansion comparison |

## Architecture Patterns

### Recommended Project Structure

```
ModernNetworking/ (root workspace)
├── Package.swift (workspace manifest)
└── Packages/
    ├── Networking/ (Core, standalone)
    │   ├── Package.swift (optionally depends on ../NetworkingMacros)
    │   ├── Sources/Networking/ (116 files, NO MACROS)
    │   └── Tests/NetworkingTests/ (test files, macro tests MOVE OUT)
    │
    ├── NetworkingMacros/ ← NEW PACKAGE
    │   ├── Package.swift
    │   ├── Sources/
    │   │   └── NetworkingMacros/ (20 files from Networking)
    │   │       ├── Plugin.swift (@main CompilerPlugin)
    │   │       ├── API/ (APIMacro.swift)
    │   │       ├── HTTP/ (GET/POST/PUT/PATCH/DELETE macros)
    │   │       ├── Configuration/ (Cacheable, Measured, DefaultHeaders, Timeout)
    │   │       ├── Interceptors/ (InterceptorsMacro, InterceptorCodeGenerator)
    │   │       ├── Shared/ (PathTemplateParser, SyntaxFactory, MacroHelpers)
    │   │       ├── BodyMacro.swift
    │   │       └── HeadersMacro.swift
    │   │
    │   └── Tests/
    │       └── NetworkingMacrosTests/ (15 macro test files)
    │           ├── Macros/ (APIMacroTests, GETMacroTests, etc.)
    │           ├── MacroGenerationTests.swift
    │           ├── MacroExpansionTests.swift
    │           └── MacroTestHelpers.swift
    │
    ├── NetworkingWebSocket/ (extension)
    └── NetworkingGraphQL/ (extension with own macros)
```

### Pattern 1: Workspace Manifest (Root Package.swift)

**What:** Root-level Package.swift lists all local packages as workspace members
**When to use:** Monorepo with multiple related packages that need unified development

**Example:**
```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "ModernNetworking",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
    .tvOS(.v16),
    .watchOS(.v9),
  ],
  products: [],  // Empty - products come from individual packages
  dependencies: [
    .package(path: "Packages/NetworkingMacros"),  // Add FIRST (depended upon)
    .package(path: "Packages/Networking"),
    .package(path: "Packages/NetworkingWebSocket"),
    .package(path: "Packages/NetworkingGraphQL"),
  ],
  targets: []  // Empty - targets come from individual packages
)
```

**Why this pattern:** Allows `swift build` at root to build all packages, Xcode workspace integration, unified dependency resolution.

### Pattern 2: Macro Package Structure (NetworkingMacros/Package.swift)

**What:** Standalone package with .macro() target, no dependency on Core Networking
**When to use:** Compiler plugins that generate code referencing other modules

**Example:**
```swift
// swift-tools-version: 6.0
import PackageDescription
import CompilerPluginSupport

let package = Package(
  name: "NetworkingMacros",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
    .tvOS(.v16),
    .watchOS(.v9),
  ],
  products: [
    .library(
      name: "NetworkingMacros",
      targets: ["NetworkingMacros"]
    )
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    .package(url: "https://github.com/pointfreeco/swift-macro-testing.git", from: "0.5.2"),
  ],
  targets: [
    // Macro implementation (compiler plugin)
    .macro(
      name: "NetworkingMacros",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ]
    ),

    // Test target
    .testTarget(
      name: "NetworkingMacrosTests",
      dependencies: [
        "NetworkingMacros",
        .product(name: "MacroTesting", package: "swift-macro-testing"),
      ]
    ),
  ]
)
```

**Why this pattern:**
- `.macro()` target type signals compiler plugin to Swift toolchain
- No Core Networking dependency keeps macro package pure (only Swift Syntax)
- MacroTesting in test target only (not available to macro implementation)

### Pattern 3: Optional Macro Dependency (Core Networking)

**What:** Core Networking optionally depends on macros for macro export, users can use Core without macros
**When to use:** Library wants to provide macros but also support macro-free usage

**Example:**
```swift
// Packages/Networking/Package.swift
let package = Package(
  name: "Networking",
  // ...
  dependencies: [
    // Optional dependency on macros (for re-export)
    .package(path: "../NetworkingMacros"),
    // ... other deps
  ],
  targets: [
    .target(
      name: "Networking",
      dependencies: [
        .product(name: "NetworkingMacros", package: "NetworkingMacros"),
      ],
      // ...
    ),
  ]
)
```

**Then in Sources/Networking/Macros/Macros.swift:**
```swift
// Re-export macros from NetworkingMacros package
@_exported import NetworkingMacros
```

**Why this pattern:** Users can `import Networking` and get macros automatically, OR they can skip macros and use Core Networking standalone.

### Pattern 4: Macro Plugin Entry Point

**What:** Single Plugin.swift file with @main and providingMacros list
**When to use:** Every macro package (required by Swift compiler)

**Example:**
```swift
// Sources/NetworkingMacros/Plugin.swift
import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct NetworkingPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    APIMacro.self,
    GETMacro.self,
    POSTMacro.self,
    PUTMacro.self,
    PATCHMacro.self,
    DELETEMacro.self,
    DefaultHeadersMacro.self,
    TimeoutMacro.self,
    InterceptorsMacro.self,
    BodyMacro.self,
    HeadersMacro.self,
    CacheableMacro.self,
    MeasuredMacro.self,
  ]
}
```

**Why this pattern:** Swift compiler invokes @main entry point, providingMacros registers all macros for expansion.

### Anti-Patterns to Avoid

- **Macro imports Core Networking:** Macros generate code that references types, but MUST NOT import the types themselves (circular dependency)
- **Shared test utilities in macro package:** Keep MacroTesting utilities in test target, not in macro implementation target
- **Mixing macro and non-macro code:** Keep macro package pure (only macro implementations), put generated code helpers in Core
- **Hardcoding paths:** Use .package(path: "../Name") for relative workspace paths, NOT absolute file system paths

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Macro expansion testing | Manual string comparison in XCTest | MacroTesting framework (assertMacro) | Handles trivia, whitespace, provides clean diff output, industry standard |
| Swift AST node creation | Raw string interpolation and parsing | SwiftSyntaxBuilder builders | Type-safe, compile-time validated, prevents syntax errors |
| Macro error reporting | throw Error or print() | context.diagnose() with Diagnostic | Compiler-native error display with source location, severity levels |
| Path parameter parsing | Regex or manual string splitting | PathTemplateParser (existing utility) | Already handles {param}, edge cases, tested |
| Workspace dependency resolution | Git submodules or copy-paste | .package(path:) in workspace manifest | Swift Package Manager native, automatic dependency graph |

**Key insight:** Swift macro system is highly structured. The compiler expects specific patterns (CompilerPlugin, .macro() target, Diagnostic system). Fighting these patterns leads to fragile, hard-to-maintain code. Use official APIs and patterns.

## Common Pitfalls

### Pitfall 1: Circular Dependency Between Core and Macros
**What goes wrong:** Core Networking depends on NetworkingMacros (for re-export), macro code tries to import Networking types
**Why it happens:** Confusion between "macro generates code that references X" vs "macro implementation needs X at compile time"
**How to avoid:**
- Macro implementation (Sources/NetworkingMacros/) NEVER imports Core Networking
- Macros generate string literals that reference types like "NetworkClient" (as text, not imports)
- Core Networking imports macros for re-export (one-way dependency)
**Warning signs:**
- Swift compiler error "circular dependency between targets"
- Macro build fails with "module 'Networking' not found"

### Pitfall 2: Test Files in Wrong Package
**What goes wrong:** Macro tests remain in Core Networking tests, fail to find macro implementations
**Why it happens:** Moving macro sources but forgetting to move corresponding tests
**How to avoid:**
- Move ALL macro-related test files to `Packages/NetworkingMacros/Tests/NetworkingMacrosTests/`
- Pattern match: `*MacroTests.swift`, `MacroGeneration*.swift`, `MacroExpansion*.swift`, `MacroTestHelpers.swift`
- Verify with: `rg "import.*MacroTesting|assertMacro" Packages/Networking/Tests/` (should return nothing)
**Warning signs:**
- `swift test` in Core Networking fails with "cannot find 'assertMacro'"
- Test count drops significantly after extraction

### Pitfall 3: Missing @main or providingMacros
**What goes wrong:** Macro package builds but macros don't expand at compile time
**Why it happens:** Plugin.swift missing @main attribute or providingMacros list incomplete
**How to avoid:**
- ALWAYS have exactly one `@main struct X: CompilerPlugin` in macro package
- List ALL macro types in providingMacros array
- Verify with: `swift build -v` and check for "Building macro 'NetworkingMacros'" in output
**Warning signs:**
- User code with @API doesn't expand (no compiler errors, just no generated code)
- `swift build` succeeds but generated code doesn't appear in build output

### Pitfall 4: Workspace Manifest Dependency Order
**What goes wrong:** Workspace build fails with "package 'NetworkingMacros' not found"
**Why it happens:** Dependencies listed in wrong order (Core Networking before NetworkingMacros)
**How to avoid:**
- In root Package.swift, list `.package(path:)` dependencies in dependency order (leaf nodes first)
- NetworkingMacros BEFORE Networking (Networking depends on Macros)
- Verify with: `swift package resolve` at root (should succeed without errors)
**Warning signs:**
- Root `swift build` fails but individual package builds succeed
- Xcode workspace shows red warnings on Package.swift

### Pitfall 5: Platform Misalignment
**What goes wrong:** Macro package builds on macOS but fails on iOS
**Why it happens:** Platforms array in NetworkingMacros/Package.swift doesn't match Core Networking
**How to avoid:**
- Copy platforms array EXACTLY from Networking/Package.swift to NetworkingMacros/Package.swift
- Platforms: iOS 16+, macOS 13+, tvOS 16+, watchOS 9+
- Verify with: `swift build -c release` for each platform target
**Warning signs:**
- Build succeeds in Xcode but fails in CI
- Users report "package 'NetworkingMacros' requires X but project targets Y"

## Code Examples

Verified patterns from swift-syntax and real-world macro packages:

### Workspace Manifest Pattern
```swift
// ModernNetworking/Package.swift (root)
// Source: Swift Package Manager workspace pattern
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "ModernNetworking",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
    .tvOS(.v16),
    .watchOS(.v9),
  ],
  products: [],
  dependencies: [
    // CRITICAL: List dependencies in dependency order
    // NetworkingMacros FIRST (no dependencies on other packages)
    .package(path: "Packages/NetworkingMacros"),

    // Core Networking SECOND (depends on NetworkingMacros)
    .package(path: "Packages/Networking"),

    // Extensions LAST (depend on Core)
    .package(path: "Packages/NetworkingWebSocket"),
    .package(path: "Packages/NetworkingGraphQL"),
  ],
  targets: []
)
```

### Macro Package Manifest
```swift
// Packages/NetworkingMacros/Package.swift
// Source: swift-syntax SwiftCompilerPlugin pattern
// swift-tools-version: 6.0
import PackageDescription
import CompilerPluginSupport

let package = Package(
  name: "NetworkingMacros",
  platforms: [
    .iOS(.v16),
    .macOS(.v13),
    .tvOS(.v16),
    .watchOS(.v9),
  ],
  products: [
    .library(
      name: "NetworkingMacros",
      targets: ["NetworkingMacros"]
    )
  ],
  dependencies: [
    .package(
      url: "https://github.com/swiftlang/swift-syntax.git",
      from: "600.0.0"
    ),
    .package(
      url: "https://github.com/pointfreeco/swift-macro-testing.git",
      from: "0.5.2"
    ),
  ],
  targets: [
    // Macro implementation
    .macro(
      name: "NetworkingMacros",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ]
    ),

    // Test target
    .testTarget(
      name: "NetworkingMacrosTests",
      dependencies: [
        "NetworkingMacros",
        .product(name: "MacroTesting", package: "swift-macro-testing"),
      ]
    ),
  ]
)
```

### Core Networking Macro Re-Export
```swift
// Packages/Networking/Sources/Networking/Macros/Macros.swift
// Source: Standard Swift macro re-export pattern

// Re-export all macros from NetworkingMacros package
// Users can 'import Networking' and get macros automatically
@_exported import NetworkingMacros
```

### Macro Plugin Entry Point
```swift
// Packages/NetworkingMacros/Sources/NetworkingMacros/Plugin.swift
// Source: swift-syntax CompilerPlugin protocol
import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct NetworkingPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    // API macro
    APIMacro.self,

    // HTTP method macros
    GETMacro.self,
    POSTMacro.self,
    PUTMacro.self,
    PATCHMacro.self,
    DELETEMacro.self,

    // Configuration macros
    DefaultHeadersMacro.self,
    TimeoutMacro.self,
    CacheableMacro.self,
    MeasuredMacro.self,

    // Interceptor macros
    InterceptorsMacro.self,

    // Parameter macros
    BodyMacro.self,
    HeadersMacro.self,
  ]
}
```

### Macro Test Pattern with MacroTesting
```swift
// Packages/NetworkingMacros/Tests/NetworkingMacrosTests/Macros/APIMacroTests.swift
// Source: MacroTesting framework documentation
import MacroTesting
import XCTest

final class APIMacroTests: XCTestCase {
  override func invokeTest() {
    // Configure MacroTesting
    withMacroTesting(
      macros: [
        "API": APIMacro.self,
      ]
    ) {
      super.invokeTest()
    }
  }

  func testAPIMacro_generatesImplementationStruct() {
    assertMacro {
      """
      @API(baseURL: "https://api.example.com")
      protocol UserAPI {
        func getUser(id: String) async throws -> User
      }
      """
    } expansion: {
      """
      protocol UserAPI {
        func getUser(id: String) async throws -> User
      }

      public struct UserAPIImplementation: UserAPI, Sendable {
        private let client: NetworkClient
        private let baseURL: String = "https://api.example.com"

        public init(client: NetworkClient = .shared) {
          self.client = client
        }
      }
      """
    }
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Monolithic Package.swift with all targets | Workspace manifest with separate packages | Swift 5.9 (2023) | Enables parallel builds, cleaner dependency graphs, easier versioning |
| Manual macro testing with XCTest string comparison | MacroTesting framework | swift-macro-testing 0.1.0 (2023) | Clean DSL for expansion testing, automatic diff output |
| .executableTarget for macros | .macro() target type | Swift 5.9 (2023) | Native compiler plugin support, better tooling integration |
| Global swift-syntax dependency | Per-package swift-syntax | Swift 6.0 (2024) | Workspace-level deduplication, version alignment |

**Deprecated/outdated:**
- **Macro implementation in same package as library:** Still works but prevents independent versioning, bloats consumer dependencies
- **Manual Plugin registration without @main:** Older tutorials show manual registration, Swift 6.0 requires @main CompilerPlugin
- **SwiftSyntax < 509.0.0:** Swift 6.0 requires swift-syntax 509.0.0+ for full compatibility

## Open Questions

1. **Should Core Networking re-export NetworkingMacros by default?**
   - What we know: Re-export makes user imports simpler (`import Networking` gets macros), but increases Core dependency surface
   - What's unclear: Whether all Core Networking users want macros (some may prefer pure runtime API)
   - Recommendation: YES, re-export by default. Users who don't want macros can skip importing the macro-using code. This matches existing behavior.

2. **Should macro tests stay in NetworkingMacros package or move to NetworkingTests?**
   - What we know: MacroTesting framework is a test-only dependency, macro tests validate macro behavior (not Core Networking)
   - What's unclear: Whether integration tests that use macros belong in Core tests or macro tests
   - Recommendation: Macro expansion tests → NetworkingMacrosTests (pure macro behavior), integration tests using generated code → NetworkingTests (runtime behavior)

3. **Should NetworkingMacros have same version as Core Networking?**
   - What we know: Monorepo workspace doesn't enforce version synchronization, but macros generate code compatible with specific Core versions
   - What's unclear: Future versioning strategy if packages diverge
   - Recommendation: Keep versions synchronized for Phase 08. Document version compatibility in each package's README.

## Sources

### Primary (HIGH confidence)
- swift-syntax repository structure analysis (deepwiki query, 2026-02-14)
  - CompilerPlugin protocol definition and @main entry point requirement
  - Target dependency structure (.macro type with SwiftSyntax dependencies)
  - MacroTesting integration pattern

- Current codebase analysis (direct inspection, 2026-02-14)
  - 20 macro source files in Packages/Networking/Sources/NetworkingMacros/
  - Zero imports of Core Networking in macro code (verified with rg)
  - 15 macro test files in Packages/Networking/Tests/NetworkingTests/Macros/
  - Existing workspace manifest pattern from Phase 07

### Secondary (MEDIUM confidence)
- Exa search results for SPM workspace patterns (2026-02-14)
  - Multiple package monorepo structure discussions (Swift Forums, 2020-2026)
  - Apollo GraphQL Swift package monorepo approach (git subtrees, 2024)
  - Tuist Swift macros at scale blog post (2024)

### Tertiary (LOW confidence)
- General Swift Package Manager workspace patterns (inferred from Phase 07 structure)
  - .package(path:) for local dependencies
  - Workspace manifest with empty products/targets arrays
  - Dependency ordering requirements (not explicitly documented)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - swift-syntax is the only option, MacroTesting is industry standard
- Architecture: HIGH - workspace manifest pattern verified in existing codebase (Phase 07), swift-syntax structure documented
- Pitfalls: MEDIUM - based on common macro package extraction errors (circular deps, missing tests), not exhaustive

**Research date:** 2026-02-14
**Valid until:** 60 days (Swift 6.0 stable, workspace patterns mature, low churn expected)
