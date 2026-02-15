---
phase: 09-ci-hooks-workspace-automation
plan: 03
subsystem: ci-automation
tags: [changelog, git-cliff, github-actions, conventional-commits]
dependency_graph:
  requires: ["09-01"]
  provides: ["automated-changelog", "release-notes"]
  affects: ["ci-workflows", "release-process"]
tech_stack:
  added: ["git-cliff", "Keep a Changelog format"]
  patterns: ["conventional-commits", "semantic-versioning"]
key_files:
  created:
    - cliff.toml
    - .github/workflows/changelog.yml
  modified: []
decisions:
  - "Use git-cliff for changelog generation over manual maintenance"
  - "Map conventional commits to Keep a Changelog categories (Added, Fixed, Changed, etc.)"
  - "Trigger on version tags (v*.*.*) plus manual workflow dispatch"
  - "Auto-commit changelog to default branch after generation"
  - "Generate GitHub Release notes from latest tag"
metrics:
  duration_seconds: 129
  tasks_completed: 3
  commits: 2
  files_created: 2
  completed_date: 2026-02-15
---

# Phase 09 Plan 03: Automated Changelog Generation Summary

**One-liner**: Automated changelog generation using git-cliff with conventional commits parsing, Keep a Changelog format, and GitHub Release notes integration.

## Tasks Completed

### Task 1: Create git-cliff configuration
**Status**: ✅ Complete
**Commit**: ae6ea1a

Created `cliff.toml` with:
- Keep a Changelog format template (header/body/footer)
- Conventional commits parsing enabled
- 13 commit parsers mapping to changelog categories:
  - `feat` → Added
  - `fix` → Fixed
  - `doc` → Documentation
  - `perf` → Performance
  - `refactor/style` → Changed
  - `test` → Testing
  - `build` → Build
  - `ci` → CI/CD
  - `chore(deps)` → Dependencies
- GitHub integration (brunogama/Networking repository)
- Link parsers for issue/PR references and RFC documentation
- Tag pattern: `v[0-9].*`

**Files created**:
- `cliff.toml` (87 lines)

### Task 2: Create changelog workflow
**Status**: ✅ Complete
**Commit**: 6e20937

Created `.github/workflows/changelog.yml` with:
- **Triggers**:
  - Push to version tags (`v*.*.*`)
  - Manual workflow dispatch with optional tag and dry-run mode
- **Two jobs**:
  1. `generate-changelog`: Install git-cliff, generate CHANGELOG.md, commit to default branch
  2. `update-release-notes`: Generate release notes from latest tag, update GitHub Release
- **Features**:
  - Full git history fetch (`fetch-depth: 0`)
  - git-cliff v2.4.0 installation from GitHub releases
  - Preview output in GitHub step summary
  - Conditional commit based on dry-run flag
  - Artifact upload with 30-day retention
  - Concurrency control to prevent parallel runs

**Files created**:
- `.github/workflows/changelog.yml` (109 lines)

### Task 3: Validate and commit
**Status**: ✅ Complete

**Validation results**:
- ✅ YAML syntax valid (changelog.yml)
- ✅ TOML syntax valid (cliff.toml)
- ✅ `conventional_commits = true` present
- ✅ `commit_parsers` array defined (13 parsers)
- ✅ Git commits successful (2 commits)
- ✅ Git log shows plan 01, 02, and 03 commits

**Verification commands executed**:
```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/changelog.yml'))"  # OK
python3 -c "import tomllib; tomllib.load(open('cliff.toml', 'rb'))"                # OK
grep "conventional_commits = true" cliff.toml                                        # Found
grep "commit_parsers" cliff.toml                                                    # Found
```

## Deviations from Plan

None - plan executed exactly as written.

## Success Criteria Verification

| Criterion | Status | Evidence |
|-----------|--------|----------|
| cliff.toml exists with Conventional Commits parsing | ✅ PASS | `conventional_commits = true` in config |
| changelog.yml workflow triggers on v*.*.* tags | ✅ PASS | `on.push.tags: ['v*.*.*']` defined |
| Workflow installs git-cliff and generates changelog | ✅ PASS | Install step + `git-cliff --config cliff.toml` command |
| Release notes automatically updated on GitHub Release | ✅ PASS | `update-release-notes` job with softprops/action-gh-release |
| Changes committed locally | ✅ PASS | 2 commits (ae6ea1a, 6e20937) |

**All 5 success criteria PASS**.

## Integration Points

### Dependencies
- **Requires**: Phase 09 Plan 01 (multi-package CI workflow) for GitHub Actions infrastructure
- **Builds on**: Conventional Commits standard (existing in project)

### Provides
- **Automated changelog generation** on version tags
- **GitHub Release notes** from git-cliff output
- **Manual changelog preview** via workflow dispatch

### Affects
- **Release process**: Changelog auto-generated, no manual maintenance
- **CI/CD pipeline**: New workflow triggered on tag push
- **Documentation**: CHANGELOG.md maintained in Keep a Changelog format

## Implementation Details

### git-cliff Configuration
**File**: `cliff.toml`

**Key features**:
1. **Template system**: Jinja2-like templates for header/body/footer
2. **Commit filtering**: Filter unconventional commits, merge commits
3. **Grouping**: Group commits by type into Keep a Changelog sections
4. **Link parsing**: Auto-link GitHub issues (#123) and RFCs (RFC8484)
5. **Sorting**: Newest commits first

**Commit parser logic**:
- Regex patterns match commit message prefixes (`^feat`, `^fix`, etc.)
- Each pattern maps to a changelog group (Added, Fixed, etc.)
- Release commits (`chore(release)`) are skipped
- Dependency updates grouped separately (`chore(deps)`)

### GitHub Actions Workflow
**File**: `.github/workflows/changelog.yml`

**Workflow structure**:
```
Trigger (tag push or manual)
  ↓
generate-changelog job
  ├─ Checkout (full history)
  ├─ Install git-cliff v2.4.0
  ├─ Determine tag (from event or input)
  ├─ Generate CHANGELOG.md
  ├─ Commit and push (unless dry-run)
  └─ Upload artifact
  ↓
update-release-notes job (tag push only)
  ├─ Checkout
  ├─ Install git-cliff
  ├─ Generate release notes (latest tag only)
  └─ Update GitHub Release
```

**Concurrency control**: `group: changelog-${{ github.ref }}` prevents duplicate runs

**Permissions**: `contents: write` for both jobs (commit + release update)

## Testing Strategy

### Manual Testing (Post-Merge)
1. **Dry-run test**:
   ```bash
   # Trigger workflow manually with dry-run
   gh workflow run changelog.yml -f tag=v1.0.0 -f dry_run=true
   ```
   **Expected**: Changelog preview in step summary, no commit

2. **Tag trigger test**:
   ```bash
   # Create and push a test tag
   git tag v0.0.1-test
   git push origin v0.0.1-test
   ```
   **Expected**: Workflow runs, CHANGELOG.md committed, GitHub Release updated

3. **Local cliff test**:
   ```bash
   # Install git-cliff locally (optional)
   brew install git-cliff  # macOS

   # Generate changelog locally
   git-cliff --config cliff.toml --output TEST_CHANGELOG.md
   ```
   **Expected**: Valid CHANGELOG.md generated with Keep a Changelog format

### Validation Performed
- ✅ YAML syntax validation (Python yaml module)
- ✅ TOML syntax validation (Python tomllib module)
- ✅ Configuration keys present (conventional_commits, commit_parsers)
- ✅ Git commits successful

## Future Enhancements

1. **Changelog sections**: Add "Security" and "Deprecated" groups for comprehensive Keep a Changelog coverage
2. **Multi-repo support**: Extend to NetworkingWebSocket, NetworkingGraphQL packages
3. **Changelog validation**: Pre-commit hook to validate commit message format
4. **Release automation**: Integrate with automatic version bumping and tagging
5. **Custom templates**: Package-specific templates for different release types (major, minor, patch)

## Related Documentation

- **git-cliff docs**: https://git-cliff.org/docs/configuration
- **Keep a Changelog**: https://keepachangelog.com/en/1.1.0/
- **Conventional Commits**: https://www.conventionalcommits.org/
- **Semantic Versioning**: https://semver.org/spec/v2.0.0.html

## Commits

| Commit | Message | Files |
|--------|---------|-------|
| ae6ea1a | feat(09-03): add git-cliff configuration for changelog generation | cliff.toml |
| 6e20937 | feat(09-03): add automated changelog generation workflow | .github/workflows/changelog.yml |

## Self-Check: PASSED

### Files Created Verification
```bash
[ -f "cliff.toml" ] && echo "FOUND: cliff.toml"
[ -f ".github/workflows/changelog.yml" ] && echo "FOUND: .github/workflows/changelog.yml"
```
**Result**: Both files exist

### Commits Verification
```bash
git log --oneline --all | grep -q "ae6ea1a" && echo "FOUND: ae6ea1a"
git log --oneline --all | grep -q "6e20937" && echo "FOUND: 6e20937"
```
**Result**: Both commits exist in git history

**All self-check items PASSED**.

---

**Plan 09-03 Complete**: Automated changelog generation with git-cliff configured and ready for version tag releases.
