---
phase: 07-extract-websocket-graphql
plan: 03
subsystem: architecture
tags: [graphql, modularization, swift-package-manager, macro-extraction]

# Dependency graph
requires:
  - phase: 07-extract-websocket-graphql
    plan: 01
    provides: Monorepo workspace structure at Packages/
provides:
  - Standalone NetworkingGraphQL package with local dependency on Core Networking
  - GraphQL client implementation independent from Core
  - GraphQL macro implementations (@Query, @Mutation) in separate macro target
  - Independent build and test capability for GraphQL package
affects: [07-04-workspace-manifest]

# Tech tracking
tech-stack:
  added: [NetworkingGraphQL package, NetworkingGraphQLMacros macro target]
  patterns: [Package-level GraphQL implementation, Local package dependency]

key-files:
  created:
    - Packages/NetworkingGraphQL/Package.swift
    - Packages/NetworkingGraphQL/Sources/NetworkingGraphQLMacros/Plugin.swift
  modified:
    - Packages/NetworkingGraphQL/Sources/NetworkingGraphQL/GraphQLClient.swift (added import Networking)
    - Packages/NetworkingGraphQL/Sources/NetworkingGraphQL/GraphQLMacros.swift (updated module references)
  moved:
    - GraphQLClient.swift → NetworkingGraphQL package
    - GraphQLTypes.swift → NetworkingGraphQL package
    - GraphQLMacros.swift → NetworkingGraphQL package
    - QueryMacro.swift → NetworkingGraphQLMacros target
    - MutationMacro.swift → NetworkingGraphQLMacros target
    - GraphQLClientTests.swift → NetworkingGraphQL tests
    - QueryMacroTests.swift → NetworkingGraphQL tests
    - MutationMacroTests.swift → NetworkingGraphQL tests

key-decisions:
  - "NetworkingGraphQL has its own macro target (not depending on Core NetworkingMacros)"
  - "GraphQL macros (@Query, @Mutation) completely independent from Core macros"
  - "Local package dependency via .package(path: \"../Networking\")"
  - "GraphQLClient imports Networking for HTTPClient, HTTPRequest, HTTPResponse, HTTPError types"

patterns-established:
  - "Extension packages have their own Package.swift with local Core dependency"
  - "Extension macro implementations in separate macro target"
  - "Module references updated to match new package structure"

# Metrics
duration: 3min 51s
completed: 2026-02-15
---

# Phase 07 Plan 03: NetworkingGraphQL Package Summary

**Standalone GraphQL package with local dependency on Core Networking, independent macro target, builds and tests separately**

## Performance

- **Duration:** 3 minutes 51 seconds (231 seconds)
- **Started:** 2026-02-15T01:52:19Z
- **Completed:** 2026-02-15T01:56:10Z
- **Tasks:** 4 (all committed atomically)
- **Files modified:** 11 files (8 moved, 2 modified, 1 created)

## Accomplishments

- Created NetworkingGraphQL package with complete standalone Package.swift
- Moved all GraphQL source files from Core Networking to NetworkingGraphQL
- Moved all GraphQL macro implementations to NetworkingGraphQLMacros target
- Created macro plugin entry point for NetworkingGraphQLMacros
- Moved all GraphQL test files to NetworkingGraphQL test target
- Updated all imports and module references for new package structure
- Core Networking builds without GraphQL code (3.54s, warnings-as-errors)
- NetworkingGraphQL builds independently (11.34s, warnings-as-errors)
- Verified local package dependency structure

## Task Commits

Each task was committed atomically:

1. **Task 1: Create NetworkingGraphQL package structure** - `00ecb68` (feat)
   - Created Packages/NetworkingGraphQL/ directory
   - Created Package.swift with NetworkingGraphQL, NetworkingGraphQLMacros, and test targets
   - Local dependency on ../Networking via .package(path:)
   - Swift Syntax dependencies for macro implementation

2. **Task 2: Move GraphQL source files and update macro declarations** - `fd6a520` (feat)
   - Moved GraphQLClient.swift to NetworkingGraphQL/Sources/NetworkingGraphQL/
   - Moved GraphQLTypes.swift to NetworkingGraphQL/Sources/NetworkingGraphQL/
   - Moved GraphQLMacros.swift to NetworkingGraphQL/Sources/NetworkingGraphQL/
   - Added `import Networking` to GraphQLClient.swift for HTTPClient types
   - Updated #externalMacro references from "NetworkingMacros" to "NetworkingGraphQLMacros"
   - Removed GraphQL files from Core Networking

3. **Task 3: Move GraphQL macro implementations and create plugin** - `c179e75` (feat)
   - Moved QueryMacro.swift to NetworkingGraphQLMacros target
   - Moved MutationMacro.swift to NetworkingGraphQLMacros target
   - Created Plugin.swift entry point for NetworkingGraphQLMacros
   - Removed empty GraphQL/ directory from Core NetworkingMacros
   - GraphQL macros now completely independent from Core

4. **Task 4: Move GraphQL tests and verify independent builds** - `1880848` (feat)
   - Moved GraphQLClientTests.swift to NetworkingGraphQL/Tests/
   - Moved QueryMacroTests.swift to NetworkingGraphQL/Tests/
   - Moved MutationMacroTests.swift to NetworkingGraphQL/Tests/
   - Updated test imports: @testable import NetworkingGraphQL
   - Updated macro test imports: NetworkingGraphQLMacros
   - Verified Core Networking builds without GraphQL (0 GraphQL references)
   - Verified NetworkingGraphQL builds independently with local dependency

## Files Created/Modified

### Created
- `Packages/NetworkingGraphQL/Package.swift` - Standalone package manifest with local Networking dependency
- `Packages/NetworkingGraphQL/Sources/NetworkingGraphQLMacros/Plugin.swift` - Macro plugin entry point

### Modified
- `Packages/NetworkingGraphQL/Sources/NetworkingGraphQL/GraphQLClient.swift` - Added `import Networking`
- `Packages/NetworkingGraphQL/Sources/NetworkingGraphQL/GraphQLMacros.swift` - Updated module references to NetworkingGraphQLMacros

### Moved (8 files)
- `GraphQLClient.swift` → Packages/NetworkingGraphQL/Sources/NetworkingGraphQL/
- `GraphQLTypes.swift` → Packages/NetworkingGraphQL/Sources/NetworkingGraphQL/
- `GraphQLMacros.swift` → Packages/NetworkingGraphQL/Sources/NetworkingGraphQL/
- `QueryMacro.swift` → Packages/NetworkingGraphQL/Sources/NetworkingGraphQLMacros/
- `MutationMacro.swift` → Packages/NetworkingGraphQL/Sources/NetworkingGraphQLMacros/
- `GraphQLClientTests.swift` → Packages/NetworkingGraphQL/Tests/NetworkingGraphQLTests/
- `QueryMacroTests.swift` → Packages/NetworkingGraphQL/Tests/NetworkingGraphQLTests/
- `MutationMacroTests.swift` → Packages/NetworkingGraphQL/Tests/NetworkingGraphQLTests/

### Removed
- `Packages/Networking/Sources/Networking/GraphQLClient.swift` (moved)
- `Packages/Networking/Sources/Networking/GraphQLTypes.swift` (moved)
- `Packages/Networking/Sources/Networking/Macros/GraphQLMacros.swift` (moved)
- `Packages/Networking/Sources/NetworkingMacros/GraphQL/` directory (empty, removed)
- GraphQL test files from Core Networking tests

## Decisions Made

1. **Independent macro target for GraphQL**
   - NetworkingGraphQLMacros does not depend on Core NetworkingMacros
   - @Query and @Mutation macros owned by NetworkingGraphQL package
   - Rationale: Clean separation, no coupling between Core and extension macros

2. **Local package dependency**
   - Used `.package(path: "../Networking")` in NetworkingGraphQL/Package.swift
   - Enables monorepo structure while maintaining package independence
   - Rationale: Allows independent versioning and distribution in the future

3. **Import Networking for HTTPClient types**
   - GraphQLClient imports Networking to access HTTPClient, HTTPRequest, HTTPResponse, HTTPError
   - One-way dependency: GraphQL depends on Core, Core doesn't know about GraphQL
   - Rationale: GraphQL is built on top of Core HTTP client functionality

4. **Updated macro module references**
   - Changed #externalMacro(module: "NetworkingMacros") to "NetworkingGraphQLMacros"
   - Critical for macro expansion to find correct plugin
   - Rationale: Macro declarations must reference the correct module name

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None - all tasks completed successfully on first attempt.

## Build Verification Results

### Core Networking (without GraphQL)
```
swift build -Xswiftc -warnings-as-errors
Build complete! (3.54s)
```
- ✅ 0 GraphQL references in Sources/Networking/
- ✅ 0 GraphQL references in Sources/NetworkingMacros/
- ✅ All tests pass (GraphQL tests removed)

### NetworkingGraphQL (independent build)
```
swift build -Xswiftc -warnings-as-errors
Build complete! (11.34s)
```
- ✅ NetworkingGraphQL library target builds
- ✅ NetworkingGraphQLMacros macro target builds
- ✅ Local dependency on Networking resolved
- ✅ Dependencies: Networking (local), swift-syntax, swift-macro-testing

### Dependency Structure
```
NetworkingGraphQL
├── Networking (local path: ../Networking)
│   └── swift-syntax
├── swift-syntax
└── swift-macro-testing
```

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

**Ready for Plan 07-04: Create workspace Package.swift manifest**
- Core Networking builds independently ✅
- NetworkingGraphQL builds independently ✅
- No GraphQL code remains in Core Networking ✅
- All GraphQL macros moved to NetworkingGraphQLMacros ✅
- Local package dependencies working correctly ✅

**No blockers** - all prerequisites met for workspace manifest creation.

---

*Phase: 07-extract-websocket-graphql*
*Plan: 03*
*Completed: 2026-02-15*

## Self-Check: PASSED ✅

All deliverables verified:

- ✅ Packages/NetworkingGraphQL/Package.swift exists
- ✅ Packages/NetworkingGraphQL/Sources/NetworkingGraphQL/ directory exists
- ✅ GraphQLClient.swift file exists in new location
- ✅ GraphQLTypes.swift file exists in new location
- ✅ GraphQLMacros.swift file exists in new location with updated module references
- ✅ QueryMacro.swift file exists in NetworkingGraphQLMacros target
- ✅ MutationMacro.swift file exists in NetworkingGraphQLMacros target
- ✅ Plugin.swift entry point exists in NetworkingGraphQLMacros
- ✅ GraphQL test files moved to NetworkingGraphQL/Tests/
- ✅ Commit 00ecb68 exists (Task 1: package structure)
- ✅ Commit fd6a520 exists (Task 2: source file move)
- ✅ Commit c179e75 exists (Task 3: macro implementations)
- ✅ Commit 1880848 exists (Task 4: tests and verification)
- ✅ Core Networking builds without GraphQL (3.54s)
- ✅ NetworkingGraphQL builds independently (11.34s)
- ✅ 0 GraphQL references in Core Networking sources

All files and commits verified present. Build verification successful.
