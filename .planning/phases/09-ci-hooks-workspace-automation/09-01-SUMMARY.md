---
phase: 09-ci-hooks-workspace-automation
plan: 01
subsystem: ci-cd
tags: [ci, workflows, github-actions, multi-package, automation]
requires: [phase-08]
provides: [multi-package-ci, symbol-graph-consolidation]
affects: [.github/workflows]
tech-stack:
  added: [github-actions-matrix, actions/cache@v4]
  patterns: [dependency-caching, parallel-builds, fail-fast]
key-files:
  created: [.github/workflows/ci.yml]
  modified: [.github/workflows/docs-sync.yml]
decisions:
  - Use parallel matrix strategy instead of sequential dependency order (SPM resolves dependencies automatically)
  - Use fail-fast: true to stop all jobs on first failure for faster feedback
  - Consolidate all package symbols into unified baseline with package field for traceability
  - Preserve existing docs-sync issue creation logic (no changes to notification workflow)
metrics:
  duration: 101
  tasks: 3
  commits: 2
  files-changed: 2
  completed: 2026-02-15T08:39:18Z
---

# Phase 09 Plan 01: Multi-Package CI Workflow and Documentation Sync

**One-liner**: GitHub Actions matrix strategy for building/testing 5 workspace packages with SPM caching and consolidated symbol graph extraction for unified API baseline.

## Overview

Created comprehensive CI workflow supporting all 5 workspace packages (MacroTemplateKit, NetworkingMacros, Networking, NetworkingWebSocket, NetworkingGraphQL) with parallel execution, dependency caching, and consolidated documentation symbol tracking.

**Key Achievement**: Replaced single-package CI with multi-package matrix strategy while maintaining existing docs-sync functionality.

## Tasks Completed

### Task 1: Create Multi-Package CI Workflow
**Files**: `.github/workflows/ci.yml` (created)
**Commit**: 13011c0

**Implementation**:
- Added GitHub Actions matrix strategy with all 5 packages
- Implemented SPM dependency caching using `actions/cache@v4`:
  - Cache path: `Packages/${{ matrix.package }}/.build`, `~/.swiftpm`
  - Cache key: `${{ runner.os }}-spm-${{ matrix.package }}-${{ hashFiles('Packages/${{ matrix.package }}/Package.swift') }}`
- Added warnings-as-errors build flag: `swift build --package-path Packages/${{ matrix.package }} -Xswiftc -warnings-as-errors`
- Implemented conditional test execution (detects `Tests/` directory existence)
- Used `fail-fast: true` for early failure detection
- Set `runs-on: macos-14` (required for Swift 6.0 and macros)
- Added concurrency control to cancel in-progress runs on new commits

**Verification**:
- YAML syntax validated with `python -c "import yaml; yaml.safe_load(...)"`
- Matrix strategy confirmed: 1 matrix definition found
- All 5 packages listed in matrix
- Local build test passed: `swift build --package-path Packages/MacroTemplateKit` succeeded

### Task 2: Update docs-sync.yml for Multi-Package Symbol Extraction
**Files**: `.github/workflows/docs-sync.yml` (modified)
**Commit**: 6580a44

**Implementation**:
- Updated "Generate Symbol Graphs" step (lines 64-69) to loop over all packages:
  ```bash
  for pkg in MacroTemplateKit NetworkingMacros Networking NetworkingWebSocket NetworkingGraphQL; do
    swift build --package-path Packages/$pkg \
      -Xswiftc -emit-symbol-graph \
      -Xswiftc -emit-symbol-graph-dir -Xswiftc .build/symbol-graphs/$pkg
  done
  ```
- Updated "Extract and Compare Symbols" step (lines 71-122) to consolidate symbols:
  - Added `package` field to symbol metadata for traceability
  - Used `jq -s 'add'` to merge symbol arrays from all packages
  - Updated output message: "Total public symbols across all packages: $NEW_COUNT"
- Preserved existing comparison logic (baseline diff, issue creation, PR comments)

**Verification**:
- YAML syntax validated
- Loop pattern confirmed: `for pkg in` found in symbol graph generation
- jq consolidation confirmed: `jq -s 'add'` found in extraction step

### Task 3: Verify Workflow Syntax and Commit
**Status**: Completed (validation passed, commits successful)

**Verification Results**:
- ✅ Both YAML files pass `yaml.safe_load()` validation
- ✅ ci.yml has matrix strategy
- ✅ ci.yml has `actions/cache@v4`
- ✅ ci.yml has `warnings-as-errors`
- ✅ docs-sync.yml has `for pkg in` loop
- ✅ Git status clean after commits (no uncommitted changes)
- ✅ `git log -1 --oneline` shows commit messages

## Deviations from Plan

**None** - Plan executed exactly as written. All tasks completed without modifications.

## Technical Decisions

### 1. Parallel Matrix Strategy vs Sequential Dependency Build
**Decision**: Use parallel matrix strategy with SPM automatic dependency resolution.

**Rationale**:
- SPM resolves package dependencies automatically when building each package
- Parallel execution is faster (5 jobs run concurrently instead of sequentially)
- Simpler workflow configuration (single job instead of 5 dependent jobs)
- Cache hits improve performance even more with parallel builds

**Alternative Considered**: Sequential builds respecting dependency order (MacroTemplateKit → NetworkingMacros → Networking → WebSocket/GraphQL).

**Trade-off**: Parallel builds may duplicate some dependency resolution work, but overall faster due to concurrency.

### 2. Fail-Fast Strategy
**Decision**: Use `fail-fast: true` to stop all matrix jobs on first failure.

**Rationale**:
- Faster feedback to developers (don't wait for all 5 packages to build if first one fails)
- Saves CI minutes (GitHub Actions billing)
- Encourages fixing failures immediately instead of accumulating multiple failures

**Alternative Considered**: `fail-fast: false` to see all package failures at once.

**Trade-off**: May need to re-run CI to see failures in later packages after fixing earlier ones.

### 3. Unified Symbol Baseline with Package Field
**Decision**: Consolidate all package symbols into single baseline with `package` metadata field.

**Rationale**:
- Single source of truth for API changes across entire workspace
- Easier to track API evolution across packages
- Consistent with monorepo workspace structure (one repo, one API surface)

**Alternative Considered**: Separate baselines per package with 5 different artifact uploads.

**Trade-off**: Unified baseline means a change in any package triggers docs-sync workflow, but simpler to manage.

### 4. Preserve Existing docs-sync.yml Logic
**Decision**: Only update symbol extraction steps, keep comparison/issue creation unchanged.

**Rationale**:
- Existing workflow is battle-tested and functional
- Issue creation, PR comments, and artifact management work correctly
- Minimal risk approach (change only what's necessary)

**Modified**: Symbol graph generation and extraction steps only.
**Preserved**: Baseline comparison, issue creation, PR notification, artifact upload/download.

## Files Modified

### Created
- `.github/workflows/ci.yml` (76 lines) - Multi-package build/test matrix workflow

### Modified
- `.github/workflows/docs-sync.yml` (+20 lines) - Multi-package symbol graph extraction

## Verification

### Overall Success Criteria (from plan)
- ✅ ci.yml exists with 5-package matrix strategy
- ✅ docs-sync.yml updated for multi-package symbol extraction
- ✅ Both workflows pass YAML validation
- ✅ Changes committed locally (not pushed)
- ✅ Ready for plan 09-02 (pre-commit hooks)

### Additional Verification
- ✅ `ls -la .github/workflows/` shows ci.yml and docs-sync.yml
- ✅ `grep -c "matrix:" .github/workflows/ci.yml` returns 1
- ✅ `grep "MacroTemplateKit" .github/workflows/ci.yml` returns match
- ✅ `grep "for pkg in" .github/workflows/docs-sync.yml` returns match
- ✅ `git status` shows clean working tree after commits
- ✅ Local build test passed: `swift build --package-path Packages/MacroTemplateKit` succeeded

## Self-Check: PASSED

### Created Files Exist
- ✅ `.github/workflows/ci.yml` - FOUND

### Modified Files Exist
- ✅ `.github/workflows/docs-sync.yml` - FOUND

### Commits Exist
- ✅ 13011c0 (Task 1: multi-package CI workflow) - FOUND
- ✅ 6580a44 (Task 2: docs-sync multi-package updates) - FOUND

### Build Validation
- ✅ MacroTemplateKit builds successfully with `--package-path` flag
- ✅ YAML syntax validation passed for both workflows
- ✅ Git log shows 2 commits with proper conventional commit messages

## Next Steps

**Immediate**: Plan 09-02 - Update pre-commit hooks for workspace-aware validation.

**Subsequent Plans**:
- Plan 09-03: Automated changelog generation with git-cliff
- Plan 09-04: LLMs.txt generation from symbol graphs
- Plan 09-05: Documentation.docc automation with swift-docc-plugin

## Performance Metrics

| Metric | Value |
|--------|-------|
| Duration | 101 seconds (~1.7 minutes) |
| Tasks Completed | 3/3 |
| Commits | 2 |
| Files Changed | 2 |
| Lines Added | 96 (76 ci.yml + 20 docs-sync.yml) |
| YAML Files | 2 (both validated) |
| Packages Supported | 5 |

## Commit History

```
6580a44 feat(09-01): update docs-sync for multi-package symbol extraction
13011c0 feat(09-01): add multi-package CI workflow with build/test matrix
```

---

**Status**: COMPLETE ✅
**Phase**: 09-ci-hooks-workspace-automation
**Plan**: 01
**Date**: 2026-02-15
**Duration**: 101 seconds
