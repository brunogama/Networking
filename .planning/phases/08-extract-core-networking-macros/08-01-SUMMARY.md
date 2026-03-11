---
phase: 08-extract-core-networking-macros
plan: 01
subsystem: package-structure
tags: [macro-extraction, package-manifest, workspace]
dependency_graph:
  requires: [Phase-07-workspace-structure]
  provides: [NetworkingMacros-package-scaffold]
  affects: [monorepo-workspace]
tech_stack:
  added:
    - swift-syntax (600.0.1) - Macro AST parsing and generation
    - swift-macro-testing (0.6.4) - Macro expansion testing framework
  patterns:
    - Compiler plugin support with .macro() target type
    - Standalone package with zero dependencies on Core Networking
    - Directory structure mirroring existing macro organization
key_files:
  created:
    - Packages/NetworkingMacros/Package.swift - Standalone macro package manifest
    - Packages/NetworkingMacros/Sources/NetworkingMacros/Placeholder.swift - Package validation placeholder
  modified: []
decisions:
  - decision: "Use .macro() target type instead of .executableTarget"
    rationale: "Swift 6.0 native macro support provides better compiler integration"
    alternatives: ["Executable target with @main entry point"]
  - decision: "Zero dependency on Packages/Networking"
    rationale: "Macros only manipulate AST, don't need runtime Networking types"
    alternatives: ["Add dependency for type checking", "Share types between packages"]
  - decision: "Mirror existing directory structure (API/, HTTP/, Configuration/, etc.)"
    rationale: "Maintain logical grouping during migration, easier code review"
    alternatives: ["Flatten to single directory", "Reorganize during migration"]
metrics:
  duration_seconds: 70
  tasks_completed: 3
  files_created: 2
  commits: 1
  completed_at: "2026-02-15T04:34:41Z"
---

# Phase 08 Plan 01: NetworkingMacros Package Structure Summary

**One-liner**: Standalone NetworkingMacros package created with .macro() target, swift-syntax dependencies, and zero coupling to Core Networking.

## What Was Built

Created the foundational package structure for extracting macro implementations from `Packages/Networking/Sources/NetworkingMacros/` into a standalone `Packages/NetworkingMacros/` package within the monorepo workspace.

### Package Structure Created

```
Packages/NetworkingMacros/
├── Package.swift (Standalone manifest with .macro() target)
├── Sources/NetworkingMacros/
│   ├── API/ (Will contain APIMacro)
│   ├── HTTP/ (Will contain GET, POST, PUT, PATCH, DELETE macros)
│   ├── Configuration/ (Will contain Cacheable, Measured, DefaultHeaders, Timeout macros)
│   ├── Interceptors/ (Will contain InterceptorsMacro, InterceptorCodeGenerator)
│   ├── Shared/ (Will contain PathTemplateParser, SyntaxFactory, MacroHelpers)
│   └── Placeholder.swift (Temporary file for package validation)
└── Tests/NetworkingMacrosTests/
    └── Macros/ (Will contain macro expansion tests)
```

### Key Architecture Decisions

1. **Swift 6.0 .macro() Target Type**
   - Uses native compiler plugin support (not executable target)
   - Provides better integration with Swift compiler
   - Eliminates need for @main entry point

2. **Zero Dependency on Core Networking**
   - Macros depend only on swift-syntax for AST manipulation
   - Generated code references Networking types, but macro implementations don't need them
   - Enables independent versioning and development

3. **Directory Structure Mirrors Existing Organization**
   - API/ for @API macro
   - HTTP/ for @GET, @POST, @PUT, @PATCH, @DELETE macros
   - Configuration/ for @Cacheable, @Measured, @DefaultHeaders, @Timeout macros
   - Interceptors/ for @Interceptors macro and code generator
   - Shared/ for common helpers (PathTemplateParser, SyntaxFactory, etc.)

### Dependencies Added

| Dependency | Version | Purpose |
|------------|---------|---------|
| swift-syntax | 600.0.1 | AST parsing, syntax tree manipulation, code generation |
| swift-macro-testing | 0.6.4 | Macro expansion testing framework (test target only) |

**CRITICAL**: The macro package has ZERO dependency on `Packages/Networking`. Macros generate code that uses Networking types (like `NetworkClient`, `HTTPRequest`), but the macro implementations only need Swift Syntax APIs.

## Tasks Completed

| Task | Description | Files | Commit |
|------|-------------|-------|--------|
| 1 | Create NetworkingMacros package directory structure | 7 directories | f85909c |
| 2 | Create NetworkingMacros Package.swift manifest | Package.swift | f85909c |
| 3 | Create placeholder source file for package validation | Placeholder.swift | f85909c |

### Task 1: Directory Structure

Created the complete directory hierarchy:
- `Packages/NetworkingMacros/Sources/NetworkingMacros/` (main source directory)
- `Packages/NetworkingMacros/Sources/NetworkingMacros/API/` (APIMacro)
- `Packages/NetworkingMacros/Sources/NetworkingMacros/HTTP/` (HTTP method macros)
- `Packages/NetworkingMacros/Sources/NetworkingMacros/Configuration/` (Configuration macros)
- `Packages/NetworkingMacros/Sources/NetworkingMacros/Interceptors/` (Interceptor macros)
- `Packages/NetworkingMacros/Sources/NetworkingMacros/Shared/` (Shared helpers)
- `Packages/NetworkingMacros/Tests/NetworkingMacrosTests/Macros/` (Test directory)

### Task 2: Package.swift Manifest

Created standalone `Package.swift` with:
- Swift tools version 6.0
- Platforms: iOS 16+, macOS 13+, tvOS 16+, watchOS 9+
- `.macro()` target type with swift-syntax dependencies:
  - SwiftSyntax (AST parsing)
  - SwiftSyntaxBuilder (AST construction)
  - SwiftSyntaxMacros (Macro protocols)
  - SwiftCompilerPlugin (Compiler integration)
- `.testTarget()` with MacroTesting dependency

**Verification**:
- `.macro(` declaration present: ✅
- `swift-syntax` dependency present: ✅
- NO `path.*Networking` dependency: ✅ (grep count: 0)

### Task 3: Placeholder Source File

Created `Placeholder.swift` to enable package resolution before macro source migration:
- Intentionally empty (no code)
- Documented as temporary (will be deleted in Plan 08-02)
- Allows `swift package resolve` to succeed

**Verification**:
- `swift package resolve` completed successfully
- Dependencies fetched: swift-syntax (600.0.1), swift-macro-testing (0.6.4)
- Package structure validated

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

### Package Resolution
```bash
cd Packages/NetworkingMacros && swift package resolve
```
**Result**: ✅ All dependencies resolved successfully
- swift-syntax 600.0.1
- swift-macro-testing 0.6.4
- swift-snapshot-testing 1.18.9 (transitive)
- swift-custom-dump 1.4.1 (transitive)
- xctest-dynamic-overlay 1.8.1 (transitive)

### Package Manifest Validation
```bash
grep ".macro(" Packages/NetworkingMacros/Package.swift
grep "swift-syntax" Packages/NetworkingMacros/Package.swift
grep -c "path.*Networking" Packages/NetworkingMacros/Package.swift
```
**Result**: ✅ All checks passed
- `.macro()` target type declared
- swift-syntax dependency present
- NO Networking dependency (count: 0)

### Directory Structure
```bash
ls -la Packages/NetworkingMacros/Sources/NetworkingMacros/
```
**Result**: ✅ All subdirectories created
- API/
- HTTP/
- Configuration/
- Interceptors/
- Shared/

## Next Steps (Plan 08-02)

1. **Move macro source files** from `Packages/Networking/Sources/NetworkingMacros/` to `Packages/NetworkingMacros/Sources/NetworkingMacros/`
2. **Move macro test files** from `Packages/Networking/Tests/NetworkingTests/MacroTests/` to `Packages/NetworkingMacros/Tests/NetworkingMacrosTests/`
3. **Delete Placeholder.swift** after real macro files are in place
4. **Verify package builds independently** with `swift build`
5. **Run macro tests** with `swift test`

## Commits

| Hash | Message |
|------|---------|
| f85909c | feat(08-01): create NetworkingMacros standalone package structure |

**Commit Details**:
- 2 files created
- 62 lines added
- SwiftLint pre-commit hook passed
- No warnings or errors

## Self-Check: PASSED

### Created Files Verification
```bash
[ -f "Packages/NetworkingMacros/Package.swift" ] && echo "FOUND: Package.swift"
[ -f "Packages/NetworkingMacros/Sources/NetworkingMacros/Placeholder.swift" ] && echo "FOUND: Placeholder.swift"
```
**Result**:
- ✅ FOUND: Package.swift
- ✅ FOUND: Placeholder.swift

### Commit Verification
```bash
git log --oneline --all | grep -q "f85909c" && echo "FOUND: f85909c"
```
**Result**:
- ✅ FOUND: f85909c

### Directory Structure Verification
```bash
ls -d Packages/NetworkingMacros/Sources/NetworkingMacros/API/
ls -d Packages/NetworkingMacros/Sources/NetworkingMacros/HTTP/
ls -d Packages/NetworkingMacros/Sources/NetworkingMacros/Configuration/
ls -d Packages/NetworkingMacros/Tests/NetworkingMacrosTests/
```
**Result**:
- ✅ All directories exist

## Success Criteria Met

| Criterion | Status |
|-----------|--------|
| 1. Packages/NetworkingMacros/ directory exists | ✅ |
| 2. Sources/NetworkingMacros/ directory exists | ✅ |
| 3. Tests/NetworkingMacrosTests/ directory exists | ✅ |
| 4. Subdirectories (API/, HTTP/, Configuration/, Interceptors/, Shared/) exist | ✅ |
| 5. Package.swift declares `.macro()` target type | ✅ |
| 6. Package.swift has swift-syntax dependency (from: "600.0.0") | ✅ (resolved to 600.0.1) |
| 7. Package.swift has swift-macro-testing dependency | ✅ (resolved to 0.6.4) |
| 8. Package.swift has NO dependency on Packages/Networking | ✅ (grep count: 0) |
| 9. `swift package resolve` succeeds in Packages/NetworkingMacros/ | ✅ |

**Overall**: ✅ ALL SUCCESS CRITERIA MET

## Performance Metrics

- **Duration**: 70 seconds (~1.2 minutes)
- **Tasks Completed**: 3/3 (100%)
- **Files Created**: 2
- **Commits**: 1
- **Build Status**: Package resolves successfully (build will succeed after source migration)
- **Test Status**: N/A (tests will be migrated in Plan 08-02)

## Technical Notes

### Why .macro() Target Type?

Swift 6.0 introduces native macro support via the `.macro()` target type in Package.swift. This provides:
- Better compiler integration (macros run in-process)
- Improved error messages (source locations preserved)
- Faster compilation (no IPC overhead)
- Simplified setup (no @main entry point required)

### Why Zero Dependency on Networking?

Macro implementations operate on Swift Syntax AST (abstract syntax tree) and generate source code. They don't need runtime types from the Networking package. The generated code references Networking types (like `NetworkClient.execute(_:)`), but the macro implementation itself only calls Swift Syntax APIs.

Example:
```swift
// Macro implementation (in NetworkingMacros package)
func expansion(of node: ...) -> ExprSyntax {
  return """
    NetworkClient.shared.execute(request)  // This is generated CODE
    """
}

// NO import of Networking needed - we're just generating text!
```

This design enables:
- Independent versioning (macros can evolve separately)
- Reduced compilation times (no cross-package dependencies)
- Clear separation of concerns (AST manipulation vs. runtime behavior)

### Directory Structure Rationale

The subdirectory structure mirrors the existing organization in `Packages/Networking/Sources/NetworkingMacros/`:
- **API/**: Contains APIMacro (main entry point)
- **HTTP/**: Contains HTTP method macros (GET, POST, PUT, PATCH, DELETE)
- **Configuration/**: Contains configuration macros (Cacheable, Measured, DefaultHeaders, Timeout)
- **Interceptors/**: Contains InterceptorsMacro and InterceptorCodeGenerator
- **Shared/**: Contains shared utilities (PathTemplateParser, SyntaxFactory, MacroHelpers)

This structure maintains logical grouping during migration, making code review easier and preserving the existing mental model.

## Blockers

None.

## Risks Mitigated

| Risk | Mitigation |
|------|------------|
| Package doesn't resolve | Verified with `swift package resolve` - dependencies fetched successfully |
| Circular dependency with Networking | Verified NO dependency on Packages/Networking (grep count: 0) |
| Wrong target type (.executableTarget) | Used `.macro()` target type (Swift 6.0 native support) |
| Missing swift-syntax products | Added all 4 required products (SwiftSyntax, SwiftSyntaxBuilder, SwiftSyntaxMacros, SwiftCompilerPlugin) |

---

**Plan Status**: ✅ COMPLETE
**Next Plan**: 08-02 (Move macro source files from Packages/Networking to Packages/NetworkingMacros)
**Phase Status**: In Progress (1/3 plans complete)
