# Technical Research: Automated Documentation.docc Update System

## Strategic Summary

Three viable approaches exist for automatically detecting new public APIs and updating Documentation.docc: (1) Symbol Graph-based detection using `swift-symbolgraph-extract` with a Claude Code post-commit hook, (2) AST-based detection using swift-syntax with a dedicated agent, and (3) Hybrid CI pipeline combining both. **Recommendation: Symbol Graph + Claude Code Hook** provides the best balance of accuracy, maintainability, and integration with your existing hook infrastructure.

---

## Requirements

Based on user input:

- **Triggers**: Git post-commit hook, CI/CD pipeline, manual invocation
- **Documentation depth**: Full DocC catalog (articles, tutorials, code samples, cross-refs)
- **Detection method**: Symbol graph dump (`swift-symbolgraph-extract`)
- **Integration**: Must leverage Claude Code hooks to invoke specialized agents
- **Constraints**: Swift 6+, macOS 13+, existing .claude/hooks infrastructure

---

## Approach 1: Symbol Graph + Claude Code Hook (Recommended)

### How it works

1. **Post-commit hook** triggers after Swift file commits
2. **Symbol graph extraction** runs `swift build --emit-symbol-graph` to generate JSON symbol graphs
3. **Diff analysis** compares current symbol graph against cached baseline to find new public APIs
4. **Agent invocation** uses Claude Code's `type: "agent"` hook to spawn a specialized docs-sync agent
5. **Agent generates** DocC articles, tutorials, and Extension files for new symbols
6. **Commit** staged changes with automated commit message

### Technical Implementation

```json
// .claude/settings.json addition
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/detect-api-changes.sh",
            "timeout": 60000,
            "statusMessage": "Checking for new public APIs..."
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "docs-sync-agent",
        "hooks": [
          {
            "type": "command",
            "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/post-docs-update.sh",
            "timeout": 30000
          }
        ]
      }
    ]
  }
}
```

**detect-api-changes.sh:**
```bash
#!/bin/bash
set -e

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only trigger on git commit
if ! echo "$COMMAND" | grep -qE 'git commit'; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SYMBOL_DIR="$PROJECT_DIR/.build/symbol-graphs"
CACHE_FILE="$PROJECT_DIR/.cache/api-baseline.json"

# Generate symbol graphs
mkdir -p "$SYMBOL_DIR"
swift build --target Networking \
  -Xswiftc -emit-symbol-graph \
  -Xswiftc -emit-symbol-graph-dir -Xswiftc "$SYMBOL_DIR" 2>/dev/null

# Extract public symbols
NEW_SYMBOLS=$(jq -r '.symbols[]? | select(.accessLevel == "public") | .identifier.precise' \
  "$SYMBOL_DIR"/Networking.symbols.json 2>/dev/null | sort)

if [ -f "$CACHE_FILE" ]; then
  OLD_SYMBOLS=$(jq -r '.symbols[]' "$CACHE_FILE" | sort)
  DIFF=$(comm -23 <(echo "$NEW_SYMBOLS") <(echo "$OLD_SYMBOLS"))

  if [ -n "$DIFF" ]; then
    # Output JSON to trigger agent spawn
    echo "{\"additionalContext\": \"NEW_PUBLIC_APIS_DETECTED: $DIFF\"}"
  fi
fi

# Update baseline
mkdir -p "$(dirname "$CACHE_FILE")"
echo "{\"symbols\": $(echo "$NEW_SYMBOLS" | jq -R . | jq -s .)}" > "$CACHE_FILE"

exit 0
```

**Specialized Agent Configuration** (`.claude/agents/docs-sync-agent.yml`):
```yaml
name: docs-sync-agent
description: Generates DocC documentation for new public APIs
tools:
  - Read
  - Write
  - Edit
  - Glob
  - Grep
prompt: |
  You are a documentation specialist for Swift frameworks.

  Given new public API symbols detected: $ARGUMENTS

  Tasks:
  1. Read the source files containing these symbols
  2. Extract documentation comments (/// and /** */)
  3. Generate appropriate DocC content:
     - For new types: Create Extensions/<TypeName>.md
     - For major features: Create Articles/<FeatureName>.md
     - For complex APIs: Create tutorial steps in Tutorials/
  4. Update Documentation.docc/Networking.md topic groups
  5. Ensure all links resolve correctly

  Follow existing DocC patterns in Documentation.docc/

  Output only the files you created/modified.
```

### Libraries/Tools

| Tool | Version | Purpose |
|------|---------|---------|
| `swift-symbolgraph-extract` | Built into Swift 6+ | Generate JSON symbol graphs |
| `jq` | 1.6+ | JSON parsing in shell |
| Claude Code hooks | Current | Event-driven automation |
| Claude Code agents | Current | Documentation generation |

### Pros

- **Accurate detection**: Symbol graphs are the source of truth for public APIs
- **Leverages existing infrastructure**: Uses your `.claude/hooks` setup
- **Incremental**: Only processes changed symbols
- **Official tooling**: `swift-symbolgraph-extract` is Apple's tool
- **Multi-trigger**: Works for post-commit, CI, and manual runs

### Cons

- **Build dependency**: Requires successful `swift build` to generate symbol graphs
- **Large JSON files**: Symbol graphs can be 10MB+ for large packages
- **Shell complexity**: Hook scripts require robust error handling
- **Agent quality**: Generated docs depend on Claude's understanding of context

### Best when

- You want tight integration with git workflow
- Public API surface changes frequently
- You need CI/CD compatibility
- Documentation must match actual public APIs exactly

### Complexity: M (Medium)

---

## Approach 2: AST-Based Detection with swift-syntax

### How it works

1. **Swift executable** uses swift-syntax to parse source files
2. **Visitor pattern** extracts public declarations (structs, classes, funcs, etc.)
3. **Diffing** compares against previous parse results
4. **Template generation** creates DocC markdown from AST nodes
5. **Direct file write** outputs to Documentation.docc/

### Technical Implementation

```swift
// Sources/DocCGenerator/main.swift
import SwiftSyntax
import SwiftParser
import Foundation

@main
struct DocCGenerator {
    static func main() async throws {
        let sourcesURL = URL(fileURLWithPath: "Sources/Networking")
        let docsURL = URL(fileURLWithPath: "Documentation.docc")

        let extractor = PublicAPIExtractor()
        let symbols = try await extractor.extract(from: sourcesURL)

        let baseline = try? Baseline.load()
        let newSymbols = symbols.filter { !baseline?.contains($0) ?? true }

        if !newSymbols.isEmpty {
            let generator = DocCTemplateGenerator()
            for symbol in newSymbols {
                let template = generator.generate(for: symbol)
                try template.write(to: docsURL)
            }

            // Update main catalog
            try generator.updateCatalog(at: docsURL, adding: newSymbols)
        }

        try Baseline.save(symbols)
    }
}

class PublicAPIExtractor: SyntaxVisitor {
    var symbols: [APISymbol] = []

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        if hasPublicModifier(node.modifiers) {
            symbols.append(APISymbol(
                kind: .struct,
                name: node.name.text,
                documentation: extractDocComment(node),
                members: extractPublicMembers(node.memberBlock)
            ))
        }
        return .visitChildren
    }

    // Similar for ClassDeclSyntax, EnumDeclSyntax, FunctionDeclSyntax, etc.
}
```

**Hook Integration:**
```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "if echo \"$CLAUDE_TOOL_INPUT\" | grep -qE 'git commit'; then swift run DocCGenerator 2>/dev/null; fi",
            "timeout": 120000
          }
        ]
      }
    ]
  }
}
```

### Libraries/Tools

| Tool | Version | Purpose |
|------|---------|---------|
| `swift-syntax` | 600.0.0+ | AST parsing |
| `swift-argument-parser` | 1.3.0+ | CLI interface |
| `Stencil` or `Mustache` | Optional | Template rendering |

### Pros

- **Fine-grained control**: Full access to AST for doc comment extraction
- **No build required**: Parses source directly, faster than symbol graph
- **Template customization**: Generate any DocC format you want
- **Pure Swift**: Type-safe, testable, maintainable

### Cons

- **Maintenance burden**: Must keep visitor up-to-date with Swift syntax changes
- **Missing context**: AST doesn't have type resolution (can't infer conformances)
- **Duplicate effort**: Reimplements what `swift-symbolgraph-extract` already does
- **Build time**: Adds executable target to your package

### Best when

- You need highly customized documentation templates
- Build times are critical (AST parsing is faster)
- You want pure Swift solution without shell scripts
- Documentation needs info not available in symbol graphs

### Complexity: L (Large)

---

## Approach 3: CI Pipeline with GitHub Actions

### How it works

1. **GitHub Action** triggers on push/PR to main
2. **Symbol graph generation** in CI environment
3. **Comparison job** diffs against previous workflow artifact
4. **Claude API call** invokes Claude to generate documentation
5. **PR creation** opens automated PR with doc changes

### Technical Implementation

```yaml
# .github/workflows/docs-sync.yml
name: Documentation Sync

on:
  push:
    branches: [main, dev]
    paths:
      - 'Sources/**/*.swift'
      - 'Packages/**/Sources/**/*.swift'
  workflow_dispatch:

jobs:
  detect-api-changes:
    runs-on: macos-14
    outputs:
      has_changes: ${{ steps.diff.outputs.has_changes }}
      new_symbols: ${{ steps.diff.outputs.new_symbols }}
    steps:
      - uses: actions/checkout@v4

      - name: Generate Symbol Graph
        run: |
          mkdir -p .build/symbol-graphs
          swift build --target Networking \
            -Xswiftc -emit-symbol-graph \
            -Xswiftc -emit-symbol-graph-dir -Xswiftc .build/symbol-graphs

      - name: Download Previous Baseline
        uses: actions/download-artifact@v4
        with:
          name: api-baseline
          path: .cache
        continue-on-error: true

      - name: Diff Symbols
        id: diff
        run: |
          NEW=$(jq -r '.symbols[]?.identifier.precise' .build/symbol-graphs/Networking.symbols.json | sort)
          OLD=$(cat .cache/api-baseline.txt 2>/dev/null || echo "")
          DIFF=$(comm -23 <(echo "$NEW") <(echo "$OLD"))

          if [ -n "$DIFF" ]; then
            echo "has_changes=true" >> $GITHUB_OUTPUT
            echo "new_symbols<<EOF" >> $GITHUB_OUTPUT
            echo "$DIFF" >> $GITHUB_OUTPUT
            echo "EOF" >> $GITHUB_OUTPUT
          else
            echo "has_changes=false" >> $GITHUB_OUTPUT
          fi

          echo "$NEW" > .cache/api-baseline.txt

      - name: Upload Baseline
        uses: actions/upload-artifact@v4
        with:
          name: api-baseline
          path: .cache/api-baseline.txt

  generate-docs:
    needs: detect-api-changes
    if: needs.detect-api-changes.outputs.has_changes == 'true'
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Install Claude CLI
        run: npm install -g @anthropic-ai/claude-code

      - name: Generate Documentation
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          claude --message "Generate DocC documentation for these new public APIs: ${{ needs.detect-api-changes.outputs.new_symbols }}" \
            --skill docs-sync-agent \
            --output-format json

      - name: Create PR
        uses: peter-evans/create-pull-request@v6
        with:
          title: "docs: Add documentation for new public APIs"
          body: |
            This PR adds documentation for newly detected public APIs:

            ${{ needs.detect-api-changes.outputs.new_symbols }}
          branch: docs/auto-update-${{ github.sha }}
          commit-message: "docs: Auto-generate documentation for new APIs"
```

### Libraries/Tools

| Tool | Version | Purpose |
|------|---------|---------|
| GitHub Actions | N/A | CI/CD orchestration |
| `actions/upload-artifact` | v4 | Baseline persistence |
| `claude-code` CLI | Latest | Documentation generation |
| `peter-evans/create-pull-request` | v6 | Automated PR creation |

### Pros

- **No local setup**: All automation runs in CI
- **Reviewable**: Changes come as PRs, can be reviewed
- **Baseline persistence**: GitHub artifacts store API snapshots
- **Parallel**: Doesn't block developer workflow
- **Auditable**: Full CI logs for debugging

### Cons

- **Latency**: Changes detected after push, not at commit time
- **Cost**: CI minutes + Claude API costs
- **Complexity**: Multiple moving parts (Actions, artifacts, Claude CLI)
- **Local dev**: Developers don't see doc updates until PR merged
- **Secret management**: API keys in GitHub secrets

### Best when

- You want documentation review before merging
- Team prefers PR-based workflow
- Local hooks are unreliable or inconsistent
- You need audit trail for compliance

### Complexity: M (Medium)

---

## Comparison

| Aspect | Approach 1: Symbol Graph + Hook | Approach 2: AST-based | Approach 3: CI Pipeline |
|--------|--------------------------------|----------------------|-------------------------|
| **Complexity** | M | L | M |
| **Accuracy** | High (official tool) | Medium (no type info) | High |
| **Speed** | Fast (incremental) | Faster (no build) | Slow (CI latency) |
| **Maintenance** | Low (shell scripts) | High (Swift code) | Medium (YAML + secrets) |
| **Local support** | Yes | Yes | No |
| **CI support** | Yes | Yes | Primary |
| **Review workflow** | Optional | Optional | Built-in |
| **Error recovery** | Moderate | Good | Good |

---

## Recommendation

**Approach 1: Symbol Graph + Claude Code Hook** is recommended because:

1. **Best accuracy**: Symbol graphs are the authoritative source for public APIs
2. **Leverages your infrastructure**: You already have `.claude/hooks` with Python scripts
3. **Multi-trigger support**: Works for post-commit, CI, and manual (`swift run`)
4. **Incremental**: Only regenerates docs for changed symbols
5. **Maintainable**: Shell scripts + agent prompts are easier to update than Swift visitors

**Suggested Implementation Order:**
1. Start with manual invocation via a `/docs-sync` skill
2. Add post-commit hook once validated
3. Optionally add CI workflow for PR-based review

---

## Implementation Context

```xml
<claude_context>
<chosen_approach>
- name: Symbol Graph + Claude Code Hook
- libraries:
  - swift-symbolgraph-extract (built into Swift 6+)
  - jq 1.6+
  - Claude Code hooks (existing)
  - Claude Code agents (existing)
- install:
  - brew install jq (if not present)
  - Create .claude/hooks/detect-api-changes.sh
  - Create .claude/agents/docs-sync-agent.yml
  - Update .claude/settings.json with PostToolUse hook
</chosen_approach>
<architecture>
- pattern: Event-driven hook architecture
- components:
  1. detect-api-changes.sh - Shell script for symbol extraction and diffing
  2. docs-sync-agent - Claude Code agent for DocC generation
  3. api-baseline.json - Cache file tracking known symbols
  4. post-docs-update.sh - Cleanup hook after agent completes
- data_flow:
  1. Git commit triggers PostToolUse hook
  2. Hook extracts symbol graph JSON
  3. Hook compares against cached baseline
  4. If new symbols found, outputs additionalContext
  5. Claude spawns docs-sync-agent with symbol list
  6. Agent reads sources, generates DocC files
  7. SubagentStop hook commits staged changes
</architecture>
<files>
- create:
  - .claude/hooks/detect-api-changes.sh
  - .claude/hooks/post-docs-update.sh
  - .claude/agents/docs-sync-agent.yml
  - .cache/.gitkeep (add .cache to .gitignore)
- structure:
  .claude/
    hooks/
      detect-api-changes.sh    # Symbol extraction
      post-docs-update.sh      # Post-agent cleanup
    agents/
      docs-sync-agent.yml      # Agent config
  .cache/
    api-baseline.json          # Symbol cache
  Documentation.docc/
    Extensions/                # Generated type docs
    Articles/                  # Generated guides
    Tutorials/                 # Generated tutorials
- reference:
  - .claude/hooks/post_tool_use.py (existing hook pattern)
  - .claude/settings.json (existing hook config)
  - Documentation.docc/Articles/ (existing doc structure)
</files>
<implementation>
- start_with: Create detect-api-changes.sh and test manually
- order:
  1. Implement detect-api-changes.sh (symbol extraction)
  2. Test: swift build && ./.claude/hooks/detect-api-changes.sh
  3. Create docs-sync-agent.yml with prompts
  4. Update .claude/settings.json with PostToolUse matcher
  5. Test: commit a new public type, verify agent spawns
  6. Add post-docs-update.sh for auto-commit
  7. Add CI workflow (optional)
- gotchas:
  - Symbol graph JSON is large; use jq streaming (-c flag)
  - swift build must succeed before symbol extraction
  - Agent needs Read access to Sources/ to understand context
  - Quote all paths in shell scripts ("$PROJECT_DIR")
  - Baseline file must be ignored in git
  - Test with small changes first (one new function)
- testing:
  - Manual: Run script directly with echo '{}' | ./script.sh
  - Integration: Add a new public struct, commit, verify docs appear
  - CI: Push to branch, check workflow run
  - Regression: Remove a symbol, verify it's not deleted from docs
</implementation>
</claude_context>
```

**Next Action:** Create `detect-api-changes.sh` and test symbol graph extraction manually.

---

## Sources

- Swift DocC Documentation: https://github.com/swiftlang/swift-docc (accessed 2026-02-15)
- Claude Code Hooks Documentation: Internal research (see agent output above)
- swift-symbolgraph-extract: Built into Swift toolchain, `swift symbolgraph-extract --help`
- Symbol Graph JSON Format: https://github.com/apple/swift/blob/main/docs/SymbolGraph.md
