# Phase 9 Research: Update CI and Pre-commit Hooks for SPM Workspace Layout

**Research Date**: 2026-02-15
**Researcher**: AI Research Agent
**Objective**: Determine requirements for modernizing CI/CD pipeline and pre-commit hooks for the new monorepo workspace structure with automated changelog generation, LLMs.txt generation, and Documentation.docc catalog updates.

---

## Executive Summary

This research covers five key areas required for Phase 9:

1. **Multi-package CI/CD workflows** - Build/test matrix strategies for 5 packages
2. **Pre-commit hook updates** - Workspace-aware validation patterns
3. **Automated changelog generation** - git-cliff integration for version tags/releases
4. **LLMs.txt generation** - AI-discoverable API documentation from public symbols
5. **Documentation.docc automation** - Auto-update catalog on source changes

**Key Finding**: The current CI setup (`docs-sync.yml`) only builds the main Networking package. We need to extend it to support all 5 workspace packages with parallel execution, shared caching, and consolidated reporting.

---

## 1. Current State Analysis

### 1.1 Workspace Structure

The project has been refactored into a monorepo workspace with 5 packages:

```
/Users/bruno/Developer/Inbox/ModernNetworking/
├── Package.swift (workspace manifest)
├── Packages/
│   ├── MacroTemplateKit/Package.swift       (0 dependencies)
│   ├── NetworkingMacros/Package.swift       (depends: MacroTemplateKit)
│   ├── Networking/Package.swift             (depends: NetworkingMacros)
│   ├── NetworkingWebSocket/Package.swift    (depends: Networking)
│   └── NetworkingGraphQL/Package.swift      (depends: Networking)
├── .github/workflows/
│   └── docs-sync.yml (only builds Networking)
└── .pre-commit-config.yaml (only validates root Package.swift)
```

**Dependency Order** (critical for CI):
1. MacroTemplateKit (leaf node)
2. NetworkingMacros (depends on 1)
3. Networking (depends on 2)
4. NetworkingWebSocket + NetworkingGraphQL (both depend on 3)

### 1.2 Existing CI Workflow Analysis

**File**: `.github/workflows/docs-sync.yml`

**Current Capabilities**:
- ✅ Detects API changes via symbol-graph extraction
- ✅ Creates documentation issues for new public APIs
- ✅ Uses artifact storage for baseline tracking (90-day retention)
- ✅ Comments on PRs when documentation is needed

**Limitations**:
- ❌ Only builds `Networking` target
- ❌ No multi-package support
- ❌ No test execution
- ❌ No build matrix for platforms/Swift versions
- ❌ No consolidated reporting across packages

**Lines 66-69** (single-package build):
```yaml
swift build --target Networking \
  -Xswiftc -emit-symbol-graph \
  -Xswiftc -emit-symbol-graph-dir -Xswiftc .build/symbol-graphs
```

### 1.3 Existing Pre-commit Hooks Analysis

**File**: `.pre-commit-config.yaml`

**Current Capabilities**:
- ✅ Swift formatting (swift-format)
- ✅ Swift linting (swiftlint --fix and --strict)
- ✅ Swift tests (conditional on Swift file changes)
- ✅ Swift warnings-as-errors check
- ✅ Branch protection (blocks direct commits to main/dev)
- ✅ LICENSE year updater
- ✅ CHANGELOG enforcer (fails if code changed but CHANGELOG not updated)

**Limitations**:
- ❌ Only runs on root `Package.swift` (line 28: `if [ -f "Package.swift" ]`)
- ❌ Doesn't validate workspace packages individually
- ❌ No package-specific test execution
- ❌ CHANGELOG enforcer is global (not per-package)

**Lines 26-33** (single-package test detection):
```yaml
entry: bash -c 'if [ -f "Package.swift" ] && git diff --cached --name-only | grep -q "\.swift$"; then echo "🔍 Swift files detected, running tests..."; swift test; else echo "ℹ️ No Swift package or Swift files changed, skipping tests"; fi'
```

### 1.4 Existing Documentation

**Directory**: `Documentation.docc/`
- Contains: `Networking.md`, `Articles/` subdirectory
- Format: Swift-DocC catalog (`.docc` format)
- Status: Manually maintained

**CHANGELOG.md**:
- Format: Keep a Changelog (https://keepachangelog.com)
- Status: Manually maintained
- Enforced by pre-commit hook

**llms.txt**:
- Status: ❌ Does not exist
- Requirement: Generate from public API surface for AI discoverability

---

## 2. Multi-Package CI/CD Requirements

### 2.1 GitHub Actions Matrix Strategy

**Best Practice** (from research):
Use job matrices to build/test multiple packages in parallel while sharing dependencies.

**Key Techniques**:
1. **Dependency caching**: Cache `.build/` directory per package
2. **Parallel execution**: Run independent packages concurrently
3. **Dependency ordering**: Build in topological order
4. **Shared reporting**: Aggregate results across packages

**Example Matrix Structure** (from research):
```yaml
strategy:
  matrix:
    package:
      - MacroTemplateKit
      - NetworkingMacros
      - Networking
      - NetworkingWebSocket
      - NetworkingGraphQL
    platform:
      - macos-14
      - ubuntu-latest
    swift:
      - '6.0'
```

**References**:
- GitHub Actions matrix docs: https://docs.github.com/actions/writing-workflows/choosing-what-your-workflow-does/running-variations-of-jobs-in-a-workflow
- Swift CI best practices: https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/ContinuousIntegration.md

### 2.2 Build Strategy

**Option A: Sequential Build** (respects dependencies)
```yaml
jobs:
  build-leaf:
    runs-on: macos-14
    steps:
      - run: swift build --package-path Packages/MacroTemplateKit

  build-macros:
    needs: build-leaf
    steps:
      - run: swift build --package-path Packages/NetworkingMacros

  build-core:
    needs: build-macros
    steps:
      - run: swift build --package-path Packages/Networking
```

**Option B: Parallel Build with Shared Cache** (faster, recommended)
```yaml
jobs:
  build-all:
    strategy:
      matrix:
        package: [MacroTemplateKit, NetworkingMacros, Networking, ...]
    steps:
      - uses: actions/cache@v4
        with:
          path: |
            Packages/${{ matrix.package }}/.build
            ~/.swiftpm
          key: ${{ runner.os }}-spm-${{ hashFiles('Packages/${{ matrix.package }}/Package.swift') }}
      - run: swift build --package-path Packages/${{ matrix.package }}
```

**Recommendation**: Use Option B (parallel) for faster CI, relying on SPM's dependency resolution to build dependencies automatically.

### 2.3 Test Strategy

**Requirement**: Run tests for all packages that have test targets.

**Detection Pattern**:
```yaml
- name: Check for tests
  id: check-tests
  run: |
    if [ -d "Packages/${{ matrix.package }}/Tests" ]; then
      echo "has_tests=true" >> $GITHUB_OUTPUT
    else
      echo "has_tests=false" >> $GITHUB_OUTPUT
    fi

- name: Run tests
  if: steps.check-tests.outputs.has_tests == 'true'
  run: swift test --package-path Packages/${{ matrix.package }}
```

**Test Reporting**:
- Use `xcbeautify` for formatted output
- Aggregate results with `actions/upload-artifact` for consolidated view

### 2.4 Symbol Graph Extraction (for Documentation)

**Current Approach** (docs-sync.yml line 64-69):
```yaml
swift build --target Networking \
  -Xswiftc -emit-symbol-graph \
  -Xswiftc -emit-symbol-graph-dir -Xswiftc .build/symbol-graphs
```

**Multi-Package Approach**:
```yaml
- name: Generate symbol graphs
  run: |
    for package in MacroTemplateKit NetworkingMacros Networking NetworkingWebSocket NetworkingGraphQL; do
      swift build --package-path Packages/$package \
        -Xswiftc -emit-symbol-graph \
        -Xswiftc -emit-symbol-graph-dir -Xswiftc .build/symbol-graphs/$package
    done
```

**Consolidation**:
Merge symbol graphs into a unified API baseline for comparison.

---

## 3. Pre-commit Hook Updates

### 3.1 Workspace-Aware Validation

**Current Issue**: Hooks only check root `Package.swift` (line 28).

**Solution**: Iterate over all packages in workspace.

**Pattern**:
```yaml
- id: swift-package-tests
  entry: bash -c '
    if git diff --cached --name-only | grep -q "\.swift$"; then
      for pkg in Packages/*/Package.swift; do
        dir=$(dirname "$pkg")
        echo "🔍 Testing $dir..."
        (cd "$dir" && swift test)
      done
    fi
  '
  pass_filenames: false
```

### 3.2 Package-Specific Validation

**Optimization**: Only run tests for changed packages.

**Detection Logic**:
```bash
# Get changed Swift files
changed_files=$(git diff --cached --name-only | grep "\.swift$")

# Determine affected packages
affected_packages=()
for file in $changed_files; do
  if [[ "$file" =~ ^Packages/([^/]+)/ ]]; then
    pkg="${BASH_REMATCH[1]}"
    if [[ ! " ${affected_packages[*]} " =~ " $pkg " ]]; then
      affected_packages+=("$pkg")
    fi
  fi
done

# Test only affected packages
for pkg in "${affected_packages[@]}"; do
  (cd "Packages/$pkg" && swift test)
done
```

### 3.3 Dependency-Ordered Testing

**Requirement**: Test packages in dependency order to catch breaking changes early.

**Order** (from Package.swift):
1. MacroTemplateKit
2. NetworkingMacros
3. Networking
4. NetworkingWebSocket + NetworkingGraphQL (parallel)

**Implementation**:
```bash
# Define dependency order
packages_ordered=(
  "MacroTemplateKit"
  "NetworkingMacros"
  "Networking"
  "NetworkingWebSocket"
  "NetworkingGraphQL"
)

# Test in order
for pkg in "${packages_ordered[@]}"; do
  if [[ " ${affected_packages[*]} " =~ " $pkg " ]]; then
    echo "🧪 Testing $pkg..."
    (cd "Packages/$pkg" && swift test)
  fi
done
```

### 3.4 CHANGELOG Validation Updates

**Current Hook** (lines 61-68):
Enforces CHANGELOG.md update for any code change.

**Multi-Package Requirement**:
- Option A: Keep global CHANGELOG.md (single source of truth)
- Option B: Add per-package CHANGELOGs (more granular)

**Recommendation**: Keep global CHANGELOG.md (simpler for monorepo, consistent with current structure).

**Updated Hook** (no changes needed, existing hook is sufficient):
```yaml
- id: changelog-enforcer
  name: 📝 Checking CHANGELOG updates...
  entry: bash -c 'if [ -f "CHANGELOG.md" ] && git diff --cached --name-only | grep -v "CHANGELOG.md" | grep -q "\."; then if ! git diff --cached --name-only | grep -q "CHANGELOG.md"; then echo "🛑 Changes detected but CHANGELOG.md was not updated! Please update the changelog."; exit 1; fi; fi'
  # ... existing config
```

---

## 4. Automated Changelog Generation

### 4.1 Tool Selection: git-cliff

**Why git-cliff**:
- Rust-based, fast, highly customizable
- Conventional Commits support (feat:, fix:, docs:, etc.)
- GitHub integration (links issues, PRs)
- Template-based output (can generate Keep a Changelog format)
- NPM/Cargo/Homebrew installation options

**Alternatives Considered**:
- `conventional-changelog` (Node.js) - heavier, requires Node runtime
- `github-changelog-generator` (Ruby) - GitHub API rate limits
- Manual script with `git log` - limited formatting, high maintenance

**References**:
- git-cliff docs: https://git-cliff.org/
- GitHub integration guide: https://git-cliff.org/docs/integration/github

### 4.2 Configuration

**File**: `cliff.toml` (to be created)

**Key Settings**:
```toml
[changelog]
header = """
# Changelog\n
All notable changes to Networking will be documented in this file.\n
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).\n
"""

body = """
{% for group, commits in commits | group_by(attribute="group") %}
    ### {{ group | upper_first }}
    {% for commit in commits %}
        - {{ commit.message | upper_first }} ([{{ commit.id | truncate(length=7, end="") }}]({{ commit.link }}))\
    {% endfor %}
{% endfor %}\n
"""

[git]
conventional_commits = true
filter_unconventional = false
commit_parsers = [
  { message = "^feat", group = "Added" },
  { message = "^fix", group = "Fixed" },
  { message = "^docs", group = "Documentation" },
  { message = "^perf", group = "Performance" },
  { message = "^refactor", group = "Refactored" },
  { message = "^test", group = "Testing" },
  { message = "^chore", skip = true },
]

[remote.github]
owner = "brunogama"
repo = "Networking"
```

### 4.3 GitHub Actions Integration

**Trigger**: On version tags (e.g., `v1.0.0`, `v1.1.0`)

**Workflow**:
```yaml
name: Generate Changelog

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  changelog:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for changelog

      - name: Install git-cliff
        run: |
          curl -L https://github.com/orhun/git-cliff/releases/latest/download/git-cliff-linux-x86_64.tar.gz | tar xz
          chmod +x git-cliff
          sudo mv git-cliff /usr/local/bin/

      - name: Generate CHANGELOG
        run: git-cliff --config cliff.toml --output CHANGELOG.md

      - name: Commit and push
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add CHANGELOG.md
          git commit -m "docs: update CHANGELOG for ${{ github.ref_name }}"
          git push origin HEAD:main
```

**Alternative**: Manual pre-release run via `workflow_dispatch` for review before tagging.

### 4.4 Pre-release Workflow

**Pattern**: Generate changelog preview before tagging.

```yaml
on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to generate changelog for (e.g., 1.2.0)'
        required: true

jobs:
  preview-changelog:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Generate changelog preview
        run: |
          git-cliff --unreleased --tag v${{ inputs.version }} > changelog-preview.md

      - name: Upload preview
        uses: actions/upload-artifact@v4
        with:
          name: changelog-preview
          path: changelog-preview.md
```

---

## 5. LLMs.txt Generation

### 5.1 Purpose and Format

**What is llms.txt**:
AI-discoverable documentation file for LLM/AI tools. Contains:
- Public API surface (types, methods, properties)
- High-level architecture description
- Usage examples
- Links to full documentation

**Format** (from research):
```
# ModernNetworking - Swift HTTP Client Framework

## Public API

### Core Types
- `NetworkClient`: async/await HTTP client
- `HTTPRequest`: request builder
- `HTTPResponse`: response wrapper
- `HTTPError`: error types

### Interceptors
- `AuthenticationInterceptor`: auth header injection
- `RetryInterceptor`: exponential backoff
- `CachingInterceptor`: response caching with LRU

### Macros
- `@API`: protocol-to-client generation
- `@GET`, `@POST`, `@PUT`, `@DELETE`: HTTP method macros

## Architecture
[Description of middleware/interceptor chain, actor isolation, etc.]

## Quick Start
```swift
import Networking

let client = NetworkClient()
let response = try await client.get("https://api.example.com/users")
```

## Documentation
- Full API reference: https://brunogama.github.io/Networking
- Tutorials: https://brunogama.github.io/Networking/tutorials
```

**References**:
- llms.txt standard: https://www.mintlify.com/blog/real-llms-txt-examples
- Aptos example: https://aptos.dev/llms-txt

### 5.2 Generation Strategy

**Approach**: Extract from Swift symbol graphs.

**Steps**:
1. Generate symbol graphs for all packages (already done in docs-sync.yml)
2. Parse symbol graphs to extract public APIs
3. Organize by package/module
4. Generate markdown with sections
5. Include links to full documentation

**Tool Options**:
- **Option A**: Custom script using `swift-symbolgraph-extract` and `jq`
- **Option B**: Swift package plugin (similar to swift-docc-plugin)
- **Option C**: Python script parsing symbol graph JSON

**Recommendation**: Option A (custom script with jq) for simplicity and flexibility.

### 5.3 Symbol Graph Parsing

**Current Approach** (docs-sync.yml lines 74-85):
Already extracts public symbols with `jq`:

```bash
jq -c '[
  .symbols[]? |
  select(.accessLevel == "public" or .accessLevel == "open") |
  select(.identifier.precise | contains("SYNTHESIZED") | not) |
  select(.identifier.precise | test("^s:[0-9]+Networking")) |
  {
    name: .names.title,
    kind: .kind.identifier,
    precise: .identifier.precise
  }
]' .build/symbol-graphs/Networking.symbols.json
```

**Extension for llms.txt**:
```bash
# Extract public types by kind
structs=$(jq -r '.symbols[] | select(.kind.identifier == "swift.struct") | .names.title' symbols.json)
protocols=$(jq -r '.symbols[] | select(.kind.identifier == "swift.protocol") | .names.title' symbols.json)
functions=$(jq -r '.symbols[] | select(.kind.identifier == "swift.func") | .names.title' symbols.json)

# Generate markdown sections
cat > llms.txt <<EOF
# ModernNetworking

## Structs
$(echo "$structs" | sed 's/^/- /')

## Protocols
$(echo "$protocols" | sed 's/^/- /')

## Functions
$(echo "$functions" | sed 's/^/- /')
EOF
```

### 5.4 Multi-Package Consolidation

**Requirement**: Generate unified llms.txt covering all 5 packages.

**Structure**:
```markdown
# ModernNetworking - Multi-Package Swift Framework

## Packages

### MacroTemplateKit
- Purpose: SwiftSyntax template DSL for macro implementations
- Public API: Template<A>, Declaration<A>, Statement<A>, Renderer

### NetworkingMacros
- Purpose: Swift compiler plugin for HTTP client generation
- Public API: @API, @GET, @POST, @PUT, @DELETE

### Networking (Core)
- Purpose: Async/await HTTP client with middleware
- Public API: NetworkClient, HTTPRequest, HTTPResponse, Interceptor protocols

### NetworkingWebSocket
- Purpose: Actor-based WebSocket client
- Public API: WebSocketClient, WebSocketMessage, WebSocketConfiguration

### NetworkingGraphQL
- Purpose: Type-safe GraphQL client
- Public API: GraphQLClient, GraphQLRequest, GraphQLResponse

## Quick Start
[Unified example using multiple packages]

## Documentation
[Links to docc-generated docs]
```

### 5.5 GitHub Actions Integration

**Workflow**:
```yaml
name: Generate LLMs.txt

on:
  push:
    branches: [main, dev]
    paths:
      - 'Packages/**/Sources/**/*.swift'
  workflow_dispatch:

jobs:
  generate-llms-txt:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Generate symbol graphs
        run: |
          for pkg in MacroTemplateKit NetworkingMacros Networking NetworkingWebSocket NetworkingGraphQL; do
            swift build --package-path Packages/$pkg \
              -Xswiftc -emit-symbol-graph \
              -Xswiftc -emit-symbol-graph-dir -Xswiftc .build/symbol-graphs/$pkg
          done

      - name: Generate llms.txt
        run: |
          # Custom script to parse symbol graphs and generate llms.txt
          ./scripts/generate-llms-txt.sh

      - name: Commit and push
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add llms.txt
          git diff --staged --quiet || git commit -m "docs: auto-generate llms.txt"
          git push
```

---

## 6. Documentation.docc Automation

### 6.1 Current State

**Directory**: `Documentation.docc/`
- Contains: `Networking.md` (top-level catalog), `Articles/` subdirectory
- Status: Manually maintained
- CI Integration: docs-sync.yml creates issues for new APIs but doesn't update catalog

### 6.2 Swift-DocC Plugin Integration

**Official Plugin**: `swift-docc-plugin` (from Apple)

**Installation** (Package.swift):
```swift
dependencies: [
  .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.0.0")
]
```

**Usage**:
```bash
# Generate documentation locally
swift package generate-documentation

# Preview documentation
swift package --disable-sandbox preview-documentation --target Networking

# Build for hosting
swift package generate-documentation --target Networking \
  --output-path ./docs \
  --hosting-base-path Networking
```

**GitHub Actions Integration**:
```yaml
- name: Build documentation
  run: swift package generate-documentation --target Networking

- name: Deploy to GitHub Pages
  uses: peaceiris/actions-gh-pages@v3
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    publish_dir: .build/plugins/Swift-DocC/outputs/Networking.doccarchive
```

**References**:
- swift-docc-plugin: https://github.com/swiftlang/swift-docc-plugin
- Tutorial: https://www.kodeco.com/40047657-docc-tutorial-for-swift-automating-publishing-with-github-actions

### 6.3 Auto-Update Strategy

**Trigger**: Source file changes in any package.

**Workflow**:
```yaml
name: Update Documentation

on:
  push:
    branches: [main, dev]
    paths:
      - 'Packages/**/Sources/**/*.swift'
      - 'Documentation.docc/**'

jobs:
  update-docs:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Generate documentation for all packages
        run: |
          for pkg in MacroTemplateKit NetworkingMacros Networking NetworkingWebSocket NetworkingGraphQL; do
            swift package --package-path Packages/$pkg generate-documentation
          done

      - name: Consolidate documentation
        run: |
          # Merge .doccarchive files from all packages
          # Create unified documentation site

      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./docs
```

### 6.4 Multi-Package Documentation

**Challenge**: Each package has its own Package.swift, but we want unified documentation.

**Solutions**:

**Option A**: Build each package separately, merge archives
```bash
for pkg in ...; do
  swift package --package-path Packages/$pkg generate-documentation
done
# Merge .doccarchive files (requires custom tooling)
```

**Option B**: Use workspace manifest to build all at once
```bash
# Add swift-docc-plugin to root Package.swift
swift package generate-documentation --target Networking
swift package generate-documentation --target NetworkingMacros
# etc.
```

**Option C**: Manual consolidation in Documentation.docc/
```
Documentation.docc/
├── Networking.md (root catalog)
├── MacroTemplateKit.md
├── NetworkingMacros.md
├── NetworkingWebSocket.md
└── NetworkingGraphQL.md
```

**Recommendation**: Option C (manual catalog structure) for better control and organization.

### 6.5 Extension File Generation

**Current Workflow** (docs-sync.yml lines 226-236):
Creates checklist for manual documentation:
```
- [ ] Create `TypeName.md` extension file
- [ ] Update `Documentation.docc/Networking.md` topic groups
```

**Automation Opportunity**:
Generate stub extension files automatically.

**Script**:
```bash
# Extract new types from symbol graph
new_types=$(jq -r '.symbols[] | select(.kind.identifier | test("struct|protocol|enum")) | .names.title' new-symbols.json)

# Generate extension files
for type in $new_types; do
  cat > "Documentation.docc/Extensions/$type.md" <<EOF
# ``$type``

@Metadata {
  @DisplayName("$type")
}

## Overview

[Add description of $type here]

## Topics

### Initializers
### Methods
### Properties
EOF
done
```

**Integration**:
Add to docs-sync.yml workflow after API detection.

---

## 7. Implementation Priorities

### Phase 9.1: CI Workflow Updates (High Priority)

**Tasks**:
1. Create `.github/workflows/ci.yml` (multi-package build/test)
2. Add build matrix for all 5 packages
3. Implement dependency caching
4. Add consolidated test reporting
5. Update docs-sync.yml to handle all packages

**Estimated Complexity**: Medium (3-4 hours)

### Phase 9.2: Pre-commit Hook Updates (High Priority)

**Tasks**:
1. Update `.pre-commit-config.yaml` to iterate over workspace packages
2. Add package-specific test execution
3. Implement dependency-ordered validation
4. Keep existing CHANGELOG enforcer (no changes needed)

**Estimated Complexity**: Low (1-2 hours)

### Phase 9.3: Changelog Automation (Medium Priority)

**Tasks**:
1. Install git-cliff (Homebrew/Cargo)
2. Create `cliff.toml` configuration
3. Create `.github/workflows/changelog.yml`
4. Add manual preview workflow
5. Test with version tags

**Estimated Complexity**: Medium (2-3 hours)

### Phase 9.4: LLMs.txt Generation (Medium Priority)

**Tasks**:
1. Create `scripts/generate-llms-txt.sh`
2. Extract symbol graphs from all packages
3. Parse and consolidate into unified llms.txt
4. Create `.github/workflows/llms-txt.yml`
5. Add to pre-commit hook for local validation

**Estimated Complexity**: Medium (2-3 hours)

### Phase 9.5: Documentation.docc Automation (Low Priority)

**Tasks**:
1. Add swift-docc-plugin to Package.swift
2. Create `.github/workflows/docs.yml`
3. Implement multi-package documentation build
4. Generate stub extension files for new APIs
5. Deploy to GitHub Pages

**Estimated Complexity**: High (4-5 hours, includes multi-package complexity)

---

## 8. Risk Assessment

### 8.1 High-Risk Areas

1. **Multi-Package Dependency Resolution**
   - Risk: CI fails if dependency order incorrect
   - Mitigation: Strict topological ordering in workflow

2. **Symbol Graph Merging**
   - Risk: Name collisions across packages
   - Mitigation: Namespace with package name prefix

3. **CHANGELOG Conflicts**
   - Risk: Multiple PRs updating CHANGELOG simultaneously
   - Mitigation: Auto-merge with git-cliff on tag (not on PR)

### 8.2 Medium-Risk Areas

1. **Pre-commit Hook Performance**
   - Risk: Testing all packages on every commit is slow
   - Mitigation: Only test affected packages (detection logic)

2. **Documentation Build Time**
   - Risk: Building docs for 5 packages takes too long
   - Mitigation: Parallel builds, incremental generation

### 8.3 Low-Risk Areas

1. **llms.txt Format**
   - Risk: Non-standard format
   - Mitigation: Follow existing examples (Aptos, Mintlify)

2. **git-cliff Configuration**
   - Risk: Complex template syntax
   - Mitigation: Start with default config, iterate

---

## 9. Open Questions for Planning

1. **CHANGELOG Strategy**: Global vs per-package CHANGELOGs?
   - Recommendation: Global (simpler, current approach)

2. **Documentation Hosting**: GitHub Pages vs other CDN?
   - Recommendation: GitHub Pages (free, integrated)

3. **CI Platform Support**: macOS-only vs Linux support?
   - Recommendation: macOS-14 primary, add Linux for NetworkingMacros (no iOS dependencies)

4. **Pre-commit Strictness**: Fail on any package failure vs warn?
   - Recommendation: Fail fast (fail_fast: true in config)

5. **LLMs.txt Update Frequency**: On every commit vs on release?
   - Recommendation: On every commit to main/dev (keep fresh for AI tools)

---

## 10. Recommended Tooling

### 10.1 GitHub Actions

**Existing**:
- `actions/checkout@v4` ✅
- `actions/upload-artifact@v4` ✅
- `actions/download-artifact@v4` ✅
- `actions/github-script@v7` ✅

**New**:
- `actions/cache@v4` (for SPM dependency caching)
- `peaceiris/actions-gh-pages@v3` (for documentation deployment)
- `swift-actions/setup-swift@v2` (for Swift version matrix)

### 10.2 CLI Tools

**Existing**:
- `swift` (Swift toolchain) ✅
- `swift-format` ✅
- `swiftlint` ✅
- `jq` ✅

**New**:
- `git-cliff` (changelog generation)
- `swift-docc-plugin` (documentation)

### 10.3 Scripts

**To Create**:
- `scripts/generate-llms-txt.sh` (llms.txt generation)
- `scripts/extract-symbol-graphs.sh` (multi-package symbol extraction)
- `scripts/test-affected-packages.sh` (pre-commit optimization)

---

## 11. Success Metrics

### Phase 9 Complete When:

1. ✅ All 5 packages build/test in CI
2. ✅ Pre-commit hooks validate all workspace packages
3. ✅ CHANGELOG auto-generated on version tags
4. ✅ llms.txt auto-updated on source changes
5. ✅ Documentation.docc catalog auto-updated on source changes
6. ✅ Zero manual intervention for routine documentation updates

### Monitoring:

- CI build time < 10 minutes (target)
- Pre-commit hook time < 30 seconds (target)
- Documentation freshness < 1 hour (time from commit to live docs)

---

## 12. Next Steps for PLAN Phase

### Deliverables for 09-PLAN.md:

1. **Detailed workflow YAML specifications**
   - ci.yml (build/test matrix)
   - changelog.yml (git-cliff integration)
   - llms-txt.yml (symbol graph extraction)
   - docs.yml (docc automation)

2. **Pre-commit hook updates**
   - Updated `.pre-commit-config.yaml` with workspace iteration

3. **Configuration files**
   - `cliff.toml` (changelog template)
   - Updated Package.swift with swift-docc-plugin

4. **Scripts**
   - generate-llms-txt.sh
   - test-affected-packages.sh

5. **Documentation updates**
   - CLAUDE.md additions for CI/CD workflow
   - README additions for development workflow

### Questions to Resolve in Planning:

1. Should we keep docs-sync.yml or merge into docs.yml? (Recommendation: merge)
2. Should llms.txt include code examples or just API surface? (Recommendation: include examples)
3. Should we add release workflow (versioning, tagging)? (Recommendation: yes, Phase 9.6)
4. Should we add security scanning (SwiftLint security rules)? (Recommendation: defer to Phase 10)

---

## 13. References

### Documentation

1. **GitHub Actions**:
   - Matrix builds: https://docs.github.com/actions/writing-workflows/choosing-what-your-workflow-does/running-variations-of-jobs-in-a-workflow
   - Swift CI guide: https://github.com/swiftlang/swift-package-manager/blob/main/Documentation/ContinuousIntegration.md

2. **Swift-DocC**:
   - Plugin repo: https://github.com/swiftlang/swift-docc-plugin
   - Tutorial: https://www.kodeco.com/40047657-docc-tutorial-for-swift-automating-publishing-with-github-actions
   - Symbol graphs: https://github.com/swiftlang/swift-docc-symbolkit

3. **git-cliff**:
   - Docs: https://git-cliff.org/
   - GitHub integration: https://git-cliff.org/docs/integration/github
   - Tutorial: https://medium.com/@aspamungkas/automatic-changelog-generation-with-git-cliff-c9a224f4f069

4. **llms.txt**:
   - Examples: https://www.mintlify.com/blog/real-llms-txt-examples
   - Guide: https://www.cherryleaf.com/2026/01/automating-llms-txt-generation-for-multi-version-documentation-sites/
   - Aptos example: https://aptos.dev/llms-txt

5. **Pre-commit**:
   - Swift hooks: https://github.com/csjones/lefthook-plugin
   - SwiftFormat hook: https://github.com/nicklockwood/SwiftFormat/blob/main/.pre-commit-hooks.yaml

### Tools

- swift-build action: https://github.com/BrightDigit/swift-build
- swift-docc-action: https://github.com/fwcd/swift-docc-action
- GitHub workflows (swiftlang): https://github.com/swiftlang/github-workflows

---

**Research Completed**: 2026-02-15
**Status**: Ready for Planning Phase
**Next Document**: `09-PLAN.md`
