# Phase 7: Extract WebSocket and GraphQL to Separate Extension Packages - Research

**Researched:** 2026-02-14
**Domain:** Swift Package Manager multi-product architecture, package extraction, modular library design
**Confidence:** HIGH

## Summary

Phase 7 extracts WebSocket and GraphQL functionality into separate extension packages (`NetworkingWebSocket` and `NetworkingGraphQL`) while maintaining the core `Networking` package as a lightweight, standalone library. This follows established Swift ecosystem patterns (Combine/Foundation, Vapor modular design) where specialized protocols extend a minimal core.

The current codebase has clean separation: WebSocket requires only 2 files (WebSocketClient.swift, WebSocketMessage.swift), GraphQL requires 3 files (GraphQLClient.swift, GraphQLTypes.swift, Macros/GraphQLMacros.swift). Both depend on core types (`HTTPClient` protocol, `HTTPRequest`, `HTTPResponse`) but have zero reverse dependencies—making extraction low-risk.

**Primary recommendation:** Use Swift Package Manager's multi-product `.library()` structure in a single repository. Define three products: `Networking` (core), `NetworkingWebSocket`, `NetworkingGraphQL`. Extension packages import core with `import Networking` and depend on it via `.product(name: "Networking", package: "Networking")`. Tests split into three targets: `NetworkingTests`, `NetworkingWebSocketTests`, `NetworkingGraphQLTests`. This is the standard SPM pattern for modular libraries (used by Apple, Vapor, GraphQLSwift).

## Standard Stack

### Core (Swift Package Manager Multi-Product)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Swift Package Manager | tools-version: 6.0 | Multi-product package manifest | Native iOS/macOS solution, zero external dependencies |
| .library() products | SPM native | Define separate library products in one repo | Apple's recommended approach for modular packages |
| URLSession | iOS 16+ | WebSocket transport (`URLSessionWebSocketTask`) | Built-in WebSocket support since iOS 13, no third-party libs needed |
| URLSessionWebSocketTask | iOS 13+ | WebSocket protocol implementation | Standard Apple API for WebSocket RFC 6455 compliance |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| swift-syntax | 600.0.0+ | GraphQL macro code generation | Already a dependency for `@Query`, `@Mutation` macros |
| NetworkingMacros | internal | Shared macro implementations | GraphQL macros live here, referenced by both core and GraphQL package |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Multi-product single repo | Separate git repos (NetworkingWebSocket.git, NetworkingGraphQL.git) | Separate repos complicate versioning and synchronization; multi-product is standard for Apple frameworks (e.g., Swift Crypto has CryptoKit + _CryptoExtras) |
| Static linking (default) | Dynamic linking (`.dynamic` library type) | Dynamic reduces binary size for multi-target apps but adds runtime overhead; static is default and safer for libraries |
| URLSessionWebSocketTask | Third-party libs (Starscream, SocketRocket) | URLSession native is lighter, better integrated with URLSession middleware, no version conflicts |

**Installation (end users):**
```swift
// Package.swift
dependencies: [
  .package(url: "https://github.com/brunogama/Networking", from: "1.0.0")
],
targets: [
  .target(
    name: "MyApp",
    dependencies: [
      .product(name: "Networking", package: "Networking"),              // Core only
      .product(name: "NetworkingWebSocket", package: "Networking"),     // + WebSocket
      .product(name: "NetworkingGraphQL", package: "Networking"),       // + GraphQL
    ]
  )
]
```

## Architecture Patterns

### Recommended Package Structure

```
Networking/
├── Package.swift                        # Multi-product manifest
├── Sources/
│   ├── Networking/                      # Core library (unchanged)
│   │   ├── NetworkClient.swift
│   │   ├── HTTPClient.swift             # Protocol that extensions use
│   │   ├── HTTPRequest.swift            # Types that extensions import
│   │   ├── HTTPResponse.swift
│   │   ├── Interceptors/
│   │   ├── Middleware/
│   │   └── [other core files]
│   ├── NetworkingMacros/                # Shared macro target
│   │   ├── Macros.swift
│   │   ├── APIMacros.swift
│   │   ├── GraphQLMacros.swift          # GraphQL macro implementations
│   │   └── [other macros]
│   ├── NetworkingWebSocket/             # NEW: WebSocket extension
│   │   ├── WebSocketClient.swift        # Moved from Sources/Networking/
│   │   ├── WebSocketMessage.swift       # Moved from Sources/Networking/
│   │   └── WebSocket+Extensions.swift   # Optional: HTTPClient extensions
│   └── NetworkingGraphQL/               # NEW: GraphQL extension
│       ├── GraphQLClient.swift          # Moved from Sources/Networking/
│       ├── GraphQLTypes.swift           # Moved from Sources/Networking/
│       └── GraphQLMacros.swift          # Re-export macros from NetworkingMacros
├── Tests/
│   ├── NetworkingTests/                 # Core tests (existing)
│   ├── NetworkingWebSocketTests/        # NEW: WebSocket tests
│   │   └── WebSocketClientTests.swift   # Moved from Tests/NetworkingTests/
│   └── NetworkingGraphQLTests/          # NEW: GraphQL tests
│       └── GraphQLClientTests.swift     # Moved from Tests/NetworkingTests/
└── Documentation.docc/
    ├── Networking.md                    # Core docs
    ├── WebSocket.md                     # NEW: WebSocket guide
    └── GraphQL.md                       # NEW: GraphQL guide
```

### Pattern 1: One-Way Dependency (Extension Depends on Core)

**What:** Extension packages import core, core never imports extensions. This is the "plugin pattern" or "extension point pattern."

**When to use:** Always for modular architectures. Prevents circular dependencies and keeps core lightweight.

**Example:**
```swift
// Sources/NetworkingWebSocket/WebSocketClient.swift
import Foundation
import Networking  // ✅ Extension imports core

public actor WebSocketClient {
  private let httpClient: any HTTPClient  // Uses core protocol

  public init(httpClient: any HTTPClient = NetworkClient()) {
    self.httpClient = httpClient
  }

  // WebSocket-specific async methods
}
```

**Anti-pattern:**
```swift
// Sources/Networking/NetworkClient.swift
import NetworkingWebSocket  // ❌ NEVER: Core importing extension
```

### Pattern 2: Package.swift Multi-Product Declaration

**What:** Define multiple `.library()` products in a single Package.swift, each with its own target.

**When to use:** When splitting a monolithic package into modules that share a common core.

**Example:**
```swift
// Package.swift
let package = Package(
  name: "Networking",
  platforms: [.iOS(.v16), .macOS(.v13), .tvOS(.v16), .watchOS(.v9)],
  products: [
    .library(name: "Networking", targets: ["Networking"]),
    .library(name: "NetworkingWebSocket", targets: ["NetworkingWebSocket"]),
    .library(name: "NetworkingGraphQL", targets: ["NetworkingGraphQL"]),
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    // Other existing dependencies
  ],
  targets: [
    // Core library (no changes to dependencies)
    .target(
      name: "Networking",
      dependencies: ["NetworkingMacros"],
      swiftSettings: [
        .unsafeFlags(["-warn-concurrency", "-enable-actor-data-race-checks"])
      ]
    ),

    // Macro target (shared by core and GraphQL)
    .macro(
      name: "NetworkingMacros",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ]
    ),

    // NEW: WebSocket extension
    .target(
      name: "NetworkingWebSocket",
      dependencies: ["Networking"],  // Depends on core
      swiftSettings: [
        .unsafeFlags(["-warn-concurrency", "-enable-actor-data-race-checks"])
      ]
    ),

    // NEW: GraphQL extension
    .target(
      name: "NetworkingGraphQL",
      dependencies: [
        "Networking",          // Depends on core
        "NetworkingMacros",    // Shares macro target
      ],
      swiftSettings: [
        .unsafeFlags(["-warn-concurrency", "-enable-actor-data-race-checks"])
      ]
    ),

    // Test targets
    .testTarget(
      name: "NetworkingTests",
      dependencies: ["Networking", "NetworkingMacros", /* other test deps */]
    ),
    .testTarget(
      name: "NetworkingWebSocketTests",
      dependencies: ["NetworkingWebSocket", "Networking"]
    ),
    .testTarget(
      name: "NetworkingGraphQLTests",
      dependencies: ["NetworkingGraphQL", "Networking", "NetworkingMacros"]
    ),
  ]
)
```
**Source:** Swift Package Manager official docs (swift.org/package-manager), Apple's multi-product package examples (Swift Crypto, Swift Numerics).

### Pattern 3: Test Target Separation

**What:** Split tests into separate targets that mirror the library product structure.

**When to use:** When extracting code into separate packages. Ensures test isolation and clear boundaries.

**Example:**
```swift
// Current (before extraction):
// Tests/NetworkingTests/
//   - WebSocketClientTests.swift
//   - GraphQLClientTests.swift
//   - NetworkClientTests.swift
//   - [all other tests]

// After extraction:
// Tests/NetworkingTests/          (core tests only)
//   - NetworkClientTests.swift
//   - InterceptorTests.swift
//   - [core tests]
// Tests/NetworkingWebSocketTests/  (WebSocket tests)
//   - WebSocketClientTests.swift
// Tests/NetworkingGraphQLTests/    (GraphQL tests)
//   - GraphQLClientTests.swift
```

**Test target dependencies:**
```swift
.testTarget(
  name: "NetworkingWebSocketTests",
  dependencies: [
    "NetworkingWebSocket",  // Primary dependency
    "Networking",           // May need core test utilities
  ]
)
```

### Pattern 4: Shared Macro Target Strategy

**What:** GraphQL macros (`@Query`, `@Mutation`) remain in `NetworkingMacros` target but are re-exported by `NetworkingGraphQL`.

**When to use:** When macros need to be shared between core and extension packages.

**Example:**
```swift
// Sources/NetworkingMacros/GraphQLMacros.swift (unchanged)
@attached(body)
public macro Query(_ query: String) = #externalMacro(module: "NetworkingMacros", type: "QueryMacro")

// Sources/NetworkingGraphQL/GraphQLMacros.swift (re-export)
@_exported import NetworkingMacros

// Users can now do:
import NetworkingGraphQL  // Gets GraphQL client + macros in one import
```

**Rationale:** Macro targets must be `.macro()` type and cannot be split. Re-exporting keeps the user API clean (one import gets everything).

### Anti-Patterns to Avoid

- **Circular dependencies:** Never let core import extensions (validate with `swift package show-dependencies`)
- **API duplication:** Don't copy `HTTPRequest`/`HTTPResponse` types into extensions—import from core
- **Test coupling:** Don't have `NetworkingTests` import `NetworkingWebSocket` (creates reverse dependency)
- **Breaking public API:** Don't remove types from core that users might import directly (use deprecation warnings first)

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Package dependency validation | Custom dependency checker | `swift package show-dependencies` | Built-in SPM command, acyclic validation, standard tooling |
| API breaking change detection | Manual diff review | `swift package diagnose-api-breaking-changes` | SPM native, catches ABI/API breaks, integrates with CI |
| Multi-product test execution | Custom test runner | `swift test --filter NetworkingWebSocketTests` | SPM native, parallel execution, selective test targeting |
| Module visibility control | Manual access control | `@_exported import`, `internal` access levels | Swift language features, compiler-enforced |

**Key insight:** Swift Package Manager already has robust tools for multi-product package management. Don't build custom scripts for dependency validation or API diffing—use `swift package` commands.

## Common Pitfalls

### Pitfall 1: Accidental Core-to-Extension Dependency

**What goes wrong:** Core package accidentally imports extension package, creating circular dependency or forcing users to import extensions they don't need.

**Why it happens:** Developer adds convenience method in core that references WebSocket/GraphQL types.

**How to avoid:**
1. Run `swift package show-dependencies` after any package structure change—verify graph is acyclic
2. Use protocol abstraction: if core needs to work with WebSocket, define protocol in core that WebSocket conforms to
3. Never `import NetworkingWebSocket` or `import NetworkingGraphQL` in `Sources/Networking/`

**Warning signs:**
- `swift build` errors: "Circular dependency detected"
- Users forced to import `NetworkingWebSocket` even when only using HTTP
- Binary size bloat: core package pulls in WebSocket/GraphQL code

**Example fix:**
```swift
// ❌ WRONG: Core imports extension
// Sources/Networking/NetworkClient.swift
import NetworkingWebSocket

public struct NetworkClient {
  public func upgradeToWebSocket() -> WebSocketClient { ... }  // Breaks one-way dependency
}

// ✅ CORRECT: Extension extends core
// Sources/NetworkingWebSocket/NetworkClient+WebSocket.swift
import Networking

extension NetworkClient {
  public func upgradeToWebSocket() -> WebSocketClient {
    WebSocketClient(httpClient: self)
  }
}
```

### Pitfall 2: Forgetting to Update Test Targets

**What goes wrong:** Tests remain in `NetworkingTests` but reference moved types, causing import errors or hidden coupling.

**Why it happens:** File moves in `Sources/` are obvious, test moves are easy to forget.

**How to avoid:**
1. Move test files at the same time as source files (atomic commit)
2. Run `swift test` immediately after extraction to catch missing test moves
3. Search for test imports: `rg "import.*Networking" Tests/` and verify no orphaned tests

**Warning signs:**
- `NetworkingTests` importing `NetworkingWebSocket` (creates reverse dependency in test graph)
- Tests passing locally but CI fails (due to different build order)
- Test duplication: same functionality tested in multiple targets

**Example:**
```bash
# ❌ WRONG: Test file not moved
# Tests/NetworkingTests/WebSocketClientTests.swift still exists after extraction

# ✅ CORRECT: Atomic move
git mv Sources/Networking/WebSocketClient.swift Sources/NetworkingWebSocket/
git mv Tests/NetworkingTests/WebSocketClientTests.swift Tests/NetworkingWebSocketTests/
# Commit both moves together
```

### Pitfall 3: Breaking Public API for Existing Users

**What goes wrong:** Extracting types to new package breaks existing code that imports `Networking` and expects `WebSocketClient` to be available.

**Why it happens:** Extraction removes symbols from core package namespace.

**How to avoid:**
1. Add deprecation warnings before extraction (in prior release)
2. Provide migration guide in release notes
3. Consider re-exporting extension types from core with deprecation (transitional phase)
4. Run `swift package diagnose-api-breaking-changes` before release

**Warning signs:**
- User code breaks: `'WebSocketClient' is not a member of 'Networking'`
- GitHub issues: "Upgrade broke my build"
- Semantic versioning violation: extraction is a breaking change (major version bump required)

**Migration strategy (3-phase):**
```swift
// Phase 1 (v1.0.0): Everything in core
import Networking
let ws = WebSocketClient()  // ✅ Works

// Phase 2 (v1.1.0): Add deprecation warning (non-breaking)
@available(*, deprecated, message: "Import NetworkingWebSocket instead")
public typealias WebSocketClient = NetworkingWebSocket.WebSocketClient

// Phase 3 (v2.0.0): Remove from core (breaking change)
// Users must now: import NetworkingWebSocket
```

### Pitfall 4: Macro Target Confusion

**What goes wrong:** GraphQL macros stop working after extraction because macro target setup is incorrect.

**Why it happens:** Macros require special `.macro()` target type and plugin configuration; easy to break during refactor.

**How to avoid:**
1. Keep all macros in `NetworkingMacros` target (don't split macro implementations)
2. Re-export macros from `NetworkingGraphQL` using `@_exported import NetworkingMacros`
3. Test macro expansion: `swift test --filter MacroTests` must pass for GraphQL package

**Warning signs:**
- Macro expansion errors: `external macro implementation type 'QueryMacro' could not be found`
- Users report `@Query` not available when importing `NetworkingGraphQL`
- Build errors: "No macro named 'Query'"

**Example fix:**
```swift
// ❌ WRONG: Moving macro implementation to GraphQL package
// Sources/NetworkingGraphQL/GraphQLMacros.swift
@attached(body)
public macro Query(...) = #externalMacro(module: "NetworkingGraphQL", type: "QueryMacro")
// This breaks because NetworkingGraphQL is not a .macro() target

// ✅ CORRECT: Keep in NetworkingMacros, re-export
// Sources/NetworkingMacros/GraphQLMacros.swift (unchanged)
@attached(body)
public macro Query(...) = #externalMacro(module: "NetworkingMacros", type: "QueryMacro")

// Sources/NetworkingGraphQL/Macros.swift (re-export)
@_exported import NetworkingMacros
```

## Code Examples

Verified patterns from Swift Package Manager ecosystem (Apple's Swift packages, Vapor, GraphQLSwift):

### Example 1: Package.swift Multi-Product Definition

```swift
// Package.swift
// Source: Pattern from Swift Crypto (https://github.com/apple/swift-crypto)
import PackageDescription

let package = Package(
  name: "Networking",
  platforms: [.iOS(.v16), .macOS(.v13), .tvOS(.v16), .watchOS(.v9)],

  // Three separate library products
  products: [
    .library(name: "Networking", targets: ["Networking"]),
    .library(name: "NetworkingWebSocket", targets: ["NetworkingWebSocket"]),
    .library(name: "NetworkingGraphQL", targets: ["NetworkingGraphQL"]),
  ],

  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    // Existing test dependencies
  ],

  targets: [
    // Core: No changes except removing WebSocket/GraphQL files
    .target(
      name: "Networking",
      dependencies: ["NetworkingMacros"],
      exclude: ["BDD"],  // Existing exclusion
      swiftSettings: [
        .unsafeFlags(["-warn-concurrency", "-enable-actor-data-race-checks"])
      ]
    ),

    // Shared macro target
    .macro(
      name: "NetworkingMacros",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
      ]
    ),

    // WebSocket extension
    .target(
      name: "NetworkingWebSocket",
      dependencies: ["Networking"],  // One-way dependency
      swiftSettings: [
        .unsafeFlags(["-warn-concurrency", "-enable-actor-data-race-checks"])
      ]
    ),

    // GraphQL extension
    .target(
      name: "NetworkingGraphQL",
      dependencies: [
        "Networking",
        "NetworkingMacros",  // For @Query, @Mutation macros
      ],
      swiftSettings: [
        .unsafeFlags(["-warn-concurrency", "-enable-actor-data-race-checks"])
      ]
    ),

    // Test targets (split by package)
    .testTarget(
      name: "NetworkingTests",
      dependencies: [
        "Networking",
        "NetworkingMacros",
        .product(name: "MacroTesting", package: "swift-macro-testing"),
        .product(name: "SwiftCheck", package: "SwiftCheck"),
        .product(name: "Quick", package: "Quick"),
        .product(name: "Nimble", package: "Nimble"),
      ]
    ),
    .testTarget(
      name: "NetworkingWebSocketTests",
      dependencies: ["NetworkingWebSocket", "Networking"]
    ),
    .testTarget(
      name: "NetworkingGraphQLTests",
      dependencies: [
        "NetworkingGraphQL",
        "Networking",
        "NetworkingMacros",
        .product(name: "MacroTesting", package: "swift-macro-testing"),
      ]
    ),
  ]
)
```

### Example 2: WebSocket Extension Package Structure

```swift
// Sources/NetworkingWebSocket/WebSocketClient.swift
// Moved from Sources/Networking/WebSocketClient.swift (no code changes)
import Foundation
import Networking  // ✅ Extension imports core

/// An actor-based WebSocket client for bidirectional communication.
public actor WebSocketClient {
  // ... existing implementation unchanged
}

// Sources/NetworkingWebSocket/WebSocketMessage.swift
// Moved from Sources/Networking/WebSocketMessage.swift (no code changes)
import Foundation

public enum WebSocketMessage: Sendable, Equatable {
  case text(String)
  case data(Data)
  // ... existing implementation unchanged
}

// NEW: Sources/NetworkingWebSocket/NetworkClient+WebSocket.swift
// Optional convenience extension (NEW file)
import Foundation
import Networking

extension NetworkClient {
  /// Creates a WebSocket client using this network client's session.
  public func webSocketClient(
    configuration: WebSocketConfiguration = .default
  ) -> WebSocketClient {
    WebSocketClient(configuration: configuration, session: self.session)
  }
}
```

### Example 3: GraphQL Extension Package Structure

```swift
// Sources/NetworkingGraphQL/GraphQLClient.swift
// Moved from Sources/Networking/GraphQLClient.swift
import Foundation
import Networking  // ✅ Uses HTTPClient protocol from core

/// A GraphQL client built on top of ``HTTPClient``.
public struct GraphQLClient: Sendable {
  private let httpClient: any HTTPClient  // Core protocol
  public let endpoint: URL

  public init(httpClient: any HTTPClient, endpoint: URL, ...) {
    // ... existing implementation unchanged
  }

  public func query<T: Decodable & Sendable>(...) async throws -> GraphQLResponse<T> {
    // ... existing implementation unchanged
  }
}

// Sources/NetworkingGraphQL/GraphQLTypes.swift
// Moved from Sources/Networking/GraphQLTypes.swift (no changes)
import Foundation

public struct GraphQLRequest: Sendable, Encodable { ... }
public enum GraphQLValue: Sendable, Encodable { ... }
public struct GraphQLResponse<T: Decodable & Sendable>: Sendable { ... }

// Sources/NetworkingGraphQL/Macros.swift
// NEW: Re-export macros from shared NetworkingMacros target
@_exported import NetworkingMacros

// This makes @Query and @Mutation available when users `import NetworkingGraphQL`
```

### Example 4: Test Migration Pattern

```bash
# Step 1: Create new test directories
mkdir -p Tests/NetworkingWebSocketTests
mkdir -p Tests/NetworkingGraphQLTests

# Step 2: Move test files
git mv Tests/NetworkingTests/WebSocketClientTests.swift Tests/NetworkingWebSocketTests/
git mv Tests/NetworkingTests/GraphQLClientTests.swift Tests/NetworkingGraphQLTests/

# Step 3: Update test imports
# Tests/NetworkingWebSocketTests/WebSocketClientTests.swift
# Before:
import Networking

# After:
import NetworkingWebSocket
import Networking  // May need core types like HTTPRequest

# Step 4: Verify tests still pass
swift test --filter NetworkingWebSocketTests
swift test --filter NetworkingGraphQLTests
```

### Example 5: User Migration Path

```swift
// BEFORE extraction (v1.x - current):
import Networking

let client = NetworkClient()
let ws = WebSocketClient()  // Available from core package
let graphQL = GraphQLClient(httpClient: client, endpoint: url)

// AFTER extraction (v2.0 - after Phase 7):
import Networking
import NetworkingWebSocket  // NEW: Explicit import
import NetworkingGraphQL    // NEW: Explicit import

let client = NetworkClient()
let ws = WebSocketClient()  // Now from NetworkingWebSocket
let graphQL = GraphQLClient(httpClient: client, endpoint: url)  // From NetworkingGraphQL

// OR use convenience extensions:
import Networking
import NetworkingWebSocket

let client = NetworkClient()
let ws = client.webSocketClient()  // Extension method
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Monolithic packages | Multi-product packages | Swift 5.3+ (2020) | Users can import only needed modules, reduces binary size |
| Separate git repos per package | Multi-product single repo | 2023+ (Apple's Swift packages) | Simplified versioning, atomic changes, easier CI |
| Dynamic linking by default | Static linking (mergeable libraries) | Swift 5.9+ (2023) | Better dead code stripping, smaller binaries, Xcode optimizes at build time |
| Manual API diff | `swift package diagnose-api-breaking-changes` | Swift 5.6+ (2022) | Automated breaking change detection, CI integration |

**Deprecated/outdated:**
- **Multi-repo approach**: Maintaining separate repos (NetworkingWebSocket.git, NetworkingGraphQL.git) is outdated. Modern Swift packages use multi-product single repo (see Swift Crypto, Swift Numerics, Apollo iOS after 2024 refactor).
  - **Why deprecated**: Version synchronization nightmare, dependency hell, complicated CI/CD
  - **What replaced it**: Multi-product Package.swift with `.library()` products per module

- **Dynamic framework defaults**: Before Swift 5.9, modular packages often used `.dynamic` library type to reduce binary size. Post-5.9, mergeable libraries (static with smart linking) are preferred.
  - **Why deprecated**: Dynamic frameworks add runtime overhead, slower launch times
  - **What replaced it**: Static linking with mergeable libraries (Xcode 15+, Swift 5.9+)

## Open Questions

1. **Should we add transitional deprecation warnings before removal?**
   - **What we know:** Swift Package Manager supports `@available(*, deprecated)` for types
   - **What's unclear:** Whether to have v1.x deprecation release before v2.0 breaking change
   - **Recommendation:** YES. Add deprecation warnings in v1.x (Phase 6 or earlier) with message directing users to new imports. Extract in v2.0 (Phase 7). This follows Swift Evolution guidelines for library evolution.

2. **Do we need separate README.md files for each extension package?**
   - **What we know:** SPM packages can have per-product documentation in `Documentation.docc/`
   - **What's unclear:** Whether to duplicate setup instructions or centralize in root README
   - **Recommendation:** Single root README with "Usage" sections per product. Use DocC articles (WebSocket.md, GraphQL.md) for detailed guides. Avoid duplication, maintain DRY principle.

3. **Should test utilities (MockNetworkClient, MockURLProtocol) remain in core or move to separate test target?**
   - **What we know:** Currently in `Sources/Networking/Testing/`, available to all test targets
   - **What's unclear:** Whether extension test targets need these mocks or should provide their own
   - **Recommendation:** Keep in core `Networking` package. Extension tests depend on core and can import testing utilities via `@testable import Networking`. If needed, create `NetworkingTestHelpers` product in future phase.

4. **Binary size impact: How much smaller will apps be when importing only core vs. core+WebSocket+GraphQL?**
   - **What we know:** WebSocket = 2 files (~500 LOC), GraphQL = 3 files (~400 LOC), Core = ~40 files (~5000 LOC)
   - **What's unclear:** Actual binary size reduction after dead code stripping (depends on app's usage patterns)
   - **Recommendation:** Measure with test app before/after extraction. Run `xcrun size` on compiled binaries. Expected savings: 10-15% for apps not using WebSocket/GraphQL (rough estimate based on LOC ratios).

## Sources

### Primary (HIGH confidence)
- Swift Package Manager Documentation: https://swift.org/package-manager/ (multi-product structure, target dependencies)
- Swift Forums: "SPM Multi Package Repositories" (2020-12-20) - Community patterns for modularization
- Swift Forums: "Best Practices for Integration Testing and Releasing Multiple Packages" (2021-03-29) - Test organization
- Apple Developer Documentation: `testTarget(name:dependencies:...)` - Test target configuration
- Swift Package Manager manifest API: https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html

### Secondary (MEDIUM confidence)
- "Splitting Up a Monolith: From 1 to 25 Swift Packages" by Ryan Ashcraft (2024-04-08) - Real-world extraction case study
- "Modularizing iOS Applications with SwiftUI and Swift Package Manager" by Nimble (2023-06-07) - Modularization patterns
- "How to Organize Your Swift Packages" by Dashlane (2023-03-14) - Multi-product organization strategies
- "Let iOS Developers Choose Dependencies in Your KMP SDK" by Mohammed Akram Hussain (2025-11-04) - Granular dependency patterns
- Swift Forums: "RFC: Allowing package-level dependency cycles in tools-version >= 6.0" (2024-05-22) - Dependency validation

### Tertiary (Requires Verification)
- GraphQLSwift/Graphiti repository structure (multi-product GraphQL package example)
- Apollo iOS modular architecture (post-2024 SPM refactor)
- Hummingbird WebSocket package (swift-websocket) - Separation pattern example

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Swift Package Manager multi-product is native and well-documented
- Architecture: HIGH - Pattern verified across Apple packages (Swift Crypto, Numerics), Vapor ecosystem
- Pitfalls: HIGH - Common issues documented in Swift Forums, migration guides from Apollo/GraphQLSwift
- Binary size impact: MEDIUM - Theoretical calculation based on LOC, requires empirical testing

**Research date:** 2026-02-14
**Valid until:** 90 days (stable domain, SPM patterns unlikely to change significantly before Swift 7)

**Current codebase facts verified:**
- ✅ WebSocket files identified: 2 files (WebSocketClient.swift, WebSocketMessage.swift)
- ✅ GraphQL files identified: 3 files + 1 macro file
- ✅ Zero reverse dependencies confirmed via `rg` search
- ✅ HTTPClient protocol exists and is public (extension point for GraphQLClient)
- ✅ Package.swift structure supports multi-product (tools-version: 6.0)
- ✅ Test files exist and are locatable (WebSocketClientTests.swift, GraphQLClientTests.swift)
