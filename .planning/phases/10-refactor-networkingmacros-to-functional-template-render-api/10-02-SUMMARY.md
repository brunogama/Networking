---
phase: 10-refactor-networkingmacros-to-functional-template-render-api
plan: 02
subsystem: SPM-Dependency-Wiring
tags: [spm, workspace, dependency-management, monorepo]
dependency-graph:
  requires: [10-01-MacroTemplateKit-package]
  provides: [NetworkingMacros-MacroTemplateKit-dependency, workspace-dependency-order]
  affects: [Packages/NetworkingMacros, root-workspace]
tech-stack:
  added: []
  patterns: [local-path-dependencies, workspace-dependency-ordering]
key-files:
  created: []
  modified:
    - Packages/NetworkingMacros/Package.swift
    - Package.swift
decisions:
  - decision: "List MacroTemplateKit FIRST in workspace dependencies"
    rationale: "SPM resolves dependencies in order; leaf nodes (no dependencies) must come before consumers"
  - decision: "MacroTemplateKit is regular .target, importable by .macro targets"
    rationale: "Unlike other macros, MacroTemplateKit is a standard library that can be used by macro implementations"
metrics:
  duration: 92
  completed: "2026-02-15T04:01:09Z"
  tasks: 3
  commits: 2
  files-modified: 2
---

# Phase 10 Plan 02: MacroTemplateKit Dependency Wiring

**One-liner**: Wire MacroTemplateKit as local path dependency of NetworkingMacros and establish correct SPM workspace dependency order

## Objective

Establish correct SPM dependency graph for monorepo workspace by adding MacroTemplateKit as a dependency of NetworkingMacros and updating the root workspace manifest to list packages in dependency order (leaf nodes first).

## Execution Summary

Successfully wired MacroTemplateKit into the NetworkingMacros package and updated the workspace dependency order. All packages now resolve and build successfully with correct dependency chain:

MacroTemplateKit → NetworkingMacros → Networking → (NetworkingWebSocket, NetworkingGraphQL)

## Tasks Completed

### Task 1: Add MacroTemplateKit dependency to NetworkingMacros Package.swift
**Commit**: `4cf9ae4`
**Files**: `Packages/NetworkingMacros/Package.swift`

- Added `.package(path: "../MacroTemplateKit")` to dependencies array (listed FIRST before swift-syntax)
- Added `.product(name: "MacroTemplateKit", package: "MacroTemplateKit")` to macro target dependencies (listed FIRST)
- MacroTemplateKit is a regular `.target` (not `.macro`), so it CAN be imported by macro targets
- Dependencies resolve successfully with swift-syntax 600.0.1, swift-macro-testing 0.6.4

**Verification**:
```bash
cd Packages/NetworkingMacros && swift package resolve
# All dependencies resolved successfully (2.62s)
```

### Task 2: Update root workspace Package.swift with correct dependency order
**Commit**: `1cb1c23`
**Files**: `Package.swift`

- Added MacroTemplateKit as FIRST package in workspace dependencies array
- Reordered dependencies to match dependency graph (leaf nodes → consumers):
  1. MacroTemplateKit (no local dependencies)
  2. NetworkingMacros (depends on MacroTemplateKit)
  3. Networking (depends on NetworkingMacros)
  4. NetworkingWebSocket, NetworkingGraphQL (depend on Networking)

- Updated comments to reflect new 5-package structure

**Verification**:
```bash
swift package resolve
# All 5 packages resolved successfully
```

### Task 3: Verify NetworkingMacros builds with MacroTemplateKit dependency
**No commit** (verification task)
**Files**: None

- Built NetworkingMacros independently: `swift build -Xswiftc -warnings-as-errors` (2.59s) ✅
- Built from workspace root: `swift build -Xswiftc -warnings-as-errors` (0.84s) ✅
- Confirmed MacroTemplateKit is compiled and available for import
- Verified dependency wiring: both `.package(path:)` and `.product(name:)` declarations present
- Verified workspace order: MacroTemplateKit appears before NetworkingMacros
- Confirmed 5 total packages in workspace

**Verification Results**:
- NetworkingMacros build: Build complete! (2.59s)
- Workspace build: Build complete! (0.84s)
- MacroTemplateKit dependency found in NetworkingMacros/Package.swift (2 lines)
- Dependency order correct in Package.swift (MacroTemplateKit before NetworkingMacros)
- Total packages: 5 (MacroTemplateKit, NetworkingMacros, Networking, NetworkingWebSocket, NetworkingGraphQL)

## Deviations from Plan

None - plan executed exactly as written.

## Verification Results

### NetworkingMacros Package Dependency ✅
```bash
rg "MacroTemplateKit" Packages/NetworkingMacros/Package.swift
# Found: .package(path: "../MacroTemplateKit") in dependencies
# Found: .product(name: "MacroTemplateKit", package: "MacroTemplateKit") in macro target
```

### Workspace Dependency Order ✅
```bash
rg 'Packages/(MacroTemplateKit|NetworkingMacros)' Package.swift
# Result: MacroTemplateKit appears BEFORE NetworkingMacros (correct order)
```

### Package Resolution ✅
```bash
swift package resolve
# All dependencies resolved without errors
```

### NetworkingMacros Build ✅
```bash
cd Packages/NetworkingMacros && swift build -Xswiftc -warnings-as-errors
# Build complete! (2.59s)
# 43 files compiled including MacroTemplateKit sources
```

### Workspace Build ✅
```bash
swift build -Xswiftc -warnings-as-errors
# Build complete! (0.84s)
# Warnings about unused dependencies expected (workspace has no targets)
```

### Total Package Count ✅
```bash
rg '\.package\(path:' Package.swift | wc -l
# Result: 5 (MacroTemplateKit, NetworkingMacros, Networking, NetworkingWebSocket, NetworkingGraphQL)
```

## Success Criteria Status

| Criterion | Status | Evidence |
|-----------|--------|----------|
| NetworkingMacros has `.package(path: "../MacroTemplateKit")` | ✅ | Line 22-23 of NetworkingMacros/Package.swift |
| Macro target has `.product(name: "MacroTemplateKit")` | ✅ | Line 39 of NetworkingMacros/Package.swift |
| Root Package.swift lists MacroTemplateKit BEFORE NetworkingMacros | ✅ | Lines 19-22 of Package.swift |
| `swift package resolve` succeeds at workspace root | ✅ | All dependencies resolved without errors |
| NetworkingMacros builds with warnings-as-errors | ✅ | Build complete! (2.59s) |
| Workspace builds with warnings-as-errors | ✅ | Build complete! (0.84s) |

## Files Modified

1. **Packages/NetworkingMacros/Package.swift** (2 additions)
   - Added MacroTemplateKit local path dependency
   - Added MacroTemplateKit product to macro target dependencies
   - Enables macro implementations to import Template algebra

2. **Package.swift** (3 additions, 2 deletions)
   - Added MacroTemplateKit as first package in workspace
   - Reordered dependency comments to reflect 5-package structure
   - Updated "FIRST/SECOND/THIRD/LAST" annotations for clarity

## Dependency Graph

```
MacroTemplateKit (leaf)
    ↓
NetworkingMacros (imports MacroTemplateKit)
    ↓
Networking (imports NetworkingMacros via @_exported)
    ↓
    ├─→ NetworkingWebSocket (imports Networking)
    └─→ NetworkingGraphQL (imports Networking)
```

## Next Steps

1. **Import MacroTemplateKit in macro implementations**: Add `import MacroTemplateKit` to macro source files that will use the Template algebra
2. **Refactor first macro to use Template**: Start with simple macro (e.g., GETMacro) to demonstrate Template → ExprSyntax transformation
3. **Add regression tests**: Verify macro expansion still produces identical output after refactoring

## Performance Metrics

- **Duration**: 92 seconds (~1.5 minutes)
- **Tasks**: 3/3 completed
- **Commits**: 2
- **Files Modified**: 2
- **NetworkingMacros Build Time**: 2.59s (with MacroTemplateKit)
- **Workspace Build Time**: 0.84s (all packages)
- **Dependency Resolution Time**: ~2.6s (NetworkingMacros), ~1.2s (workspace)

## Self-Check: PASSED ✅

### Files Modified
- ✅ Packages/NetworkingMacros/Package.swift modified (MacroTemplateKit dependency added)
- ✅ Package.swift modified (MacroTemplateKit listed first)

### Commits
- ✅ `4cf9ae4` - feat(10-02): add MacroTemplateKit dependency to NetworkingMacros
- ✅ `1cb1c23` - feat(10-02): update workspace with MacroTemplateKit first

### Build Verification
- ✅ NetworkingMacros builds independently (2.59s)
- ✅ Workspace builds successfully (0.84s)
- ✅ MacroTemplateKit dependency present in NetworkingMacros manifest
- ✅ Workspace dependency order correct (MacroTemplateKit before NetworkingMacros)
- ✅ Total package count: 5

**Conclusion**: All plan objectives achieved. MacroTemplateKit is now properly wired as a dependency of NetworkingMacros, and the workspace dependency order ensures correct SPM resolution.
