# Phase 09 Research: CI/Hooks and Xcode 26.3 MCP Integration

## Executive Summary

Xcode 26.3 introduces native Model Context Protocol (MCP) support, enabling third-party AI agents (Claude Agent, OpenAI Codex) to interface directly with Xcode's internal toolset. This represents a significant opportunity to modernize our CI/CD pipeline with AI-assisted automation.

## Xcode 26.3 MCP Native Features

### Architecture: `xcrun mcpbridge`

The architectural centerpiece is `mcpbridge`, a utility bundled with Xcode's command-line tools:

```
External Agent (Claude/Codex)
    ↓ MCP Protocol (stdio)
mcpbridge binary
    ↓ XPC calls
Xcode Kernel (project context)
```

**Key Requirements:**
- Xcode must be running with active project
- Visual indicator shows when external agent is connected
- Manual toggle: Settings > Intelligence > Model Context Protocol

### 20 Native MCP-Enabled Tools

| Category | Tools | Functionality |
|----------|-------|---------------|
| Workspace | `XcodeListWindows` | Discovers active workspace paths, tab identifiers |
| Build & Test | `BuildProject`, `RunAllTests` | Trigger compilations, read logs, verify logic |
| Intelligence | `DocumentationSearch`, `RenderPreview` | Semantic search via "Squirrel MLX", visual verification |
| File System | `XcodeRead`, `XcodeWrite`, `XcodeGlob` | Full CRUD on files and project structure |

### Advanced Capabilities

1. **DocumentationSearch (Squirrel MLX)**: Apple's MLX-accelerated embedding system queries Apple documentation corpus and WWDC transcripts (iOS 15 through iOS 26).

2. **RenderPreview**: Agents can "see" SwiftUI previews by capturing screenshots. Modify view → render preview → verify visual output before committing.

### Known Limitations (RC Version)

- **Sandbox constraints**: Agents require explicit user permissions
- **MCP spec mismatch**: `mcpbridge` returns data in `content` field but fails to populate `structuredContent` (Error -32600 on strict clients like Cursor)

---

## XcodeBuildMCP (Third-Party MCP Server)

**Repository**: https://github.com/cameroncooke/XcodeBuildMCP
**Stars**: 4,132 | **License**: MIT
**Version**: v1.12.8 (latest), v2.0 (beta with CLI)

### Overview

MCP server and CLI providing 59 tools for iOS/macOS development automation:

```bash
npm install -g xcodebuildmcp@latest
xcodebuildmcp tools  # List all 59 tools
```

### Tool Categories

| Workflow | Key Tools | Description |
|----------|-----------|-------------|
| Simulator | `build`, `build-and-run`, `test`, `screenshot` | Build and run on simulators |
| Debugging | `attach`, `breakpoint`, LLDB commands | Full debugger integration |
| UI Automation | `tap`, `swipe`, `screenshot` | Interact with simulator UI |
| Device | Deploy to physical devices over USB/Wi-Fi | Real device testing |

### CI/CD Integration

**CLI Mode (v2.0)**: Every MCP tool available from command line:

```bash
# Build for simulator
xcodebuildmcp simulator build-sim \
  --scheme MyApp \
  --project-path ./MyApp.xcodeproj

# Run tests
xcodebuildmcp simulator test \
  --scheme MyAppTests \
  --project-path ./MyApp.xcodeproj

# Capture screenshot
xcodebuildmcp simulator screenshot \
  --output ./screenshots/
```

### Project Configuration

`.xcodebuildmcp/config.yaml`:
```yaml
schemaVersion: 1
enabledWorkflows:
  - simulator
  - ui-automation
  - debugging
sessionDefaults:
  scheme: Networking
  projectPath: ./Package.swift
  simulatorName: iPhone 16
```

### Agent Skills

Install agent skill for AI priming:
```bash
curl -fsSL https://raw.githubusercontent.com/cameroncooke/XcodeBuildMCP/main/scripts/install-skill.sh | bash
```

### Xcode 26.3 Integration

**Claude Code Agent** (`~/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/.claude.json`):
```json
{
  "mcpServers": {
    "XcodeBuildMCP": {
      "command": "/bin/zsh",
      "args": ["-lc", "npx -y xcodebuildmcp@latest mcp"]
    }
  }
}
```

**Codex Agent** (`.codex/config.toml`):
```toml
[mcp_servers.XcodeBuildMCP]
command = "/bin/zsh"
args = ["-lc", "npx -y xcodebuildmcp@latest mcp"]
enabled = true
```

---

## Integration Strategy for Networking Framework

### 1. CI Pipeline Updates

**GitHub Actions Integration**:
```yaml
- name: Build with XcodeBuildMCP
  run: |
    npm install -g xcodebuildmcp@latest
    xcodebuildmcp simulator build \
      --scheme Networking \
      --project-path ./Packages/Networking/Package.swift
```

**Multi-Package Testing**:
```yaml
strategy:
  matrix:
    package: [Networking, NetworkingMacros, NetworkingWebSocket, NetworkingGraphQL]
steps:
  - run: xcodebuildmcp simulator test --scheme ${{ matrix.package }}
```

### 2. Pre-Commit Hooks

```bash
# .husky/pre-commit
xcodebuildmcp simulator build --scheme Networking --warnings-as-errors
xcodebuildmcp simulator test --scheme NetworkingTests
```

### 3. Auto-Documentation with MCP

**LLMs.txt Generation**: Use `DocumentationSearch` to extract public API surface and generate AI-consumable documentation.

**Documentation.docc Integration**: Trigger `RenderPreview` for SwiftUI documentation previews.

### 4. Agentic CI Workflows

Enable AI agents to:
1. Detect build failures
2. Propose fixes
3. Verify fixes via automated test runs
4. Capture SwiftUI preview screenshots for visual regression

---

## Success Criteria Updates

Based on research, Phase 9 should include:

1. **CI-01**: GitHub Actions updated for 4-package workspace build/test
2. **CI-02**: XcodeBuildMCP CLI integrated for automated testing
3. **CI-03**: Pre-commit hooks validate all packages
4. **CI-04**: Auto-changelog on version tags (git-cliff or similar)
5. **CI-05**: Auto LLMs.txt from public API surface
6. **CI-06**: Auto Documentation.docc catalog sync
7. **CI-07**: Xcode 26.3 MCP configuration files (`.codex/config.toml`, Claude agent config)
8. **CI-08**: XcodeBuildMCP project configuration (`.xcodebuildmcp/config.yaml`)

---

## References

- [Ars Technica: Xcode 26.3 MCP Support](https://arstechnica.com/apple/2026/02/xcode-26-3-adds-support-for-claude-codex-and-other-agentic-tools-via-mcp/)
- [Cosmo Edge: Xcode 26.3 MCP Guide](https://cosmo-edge.com/xcode-26-3-mcp-ai-agentic-coding/)
- [XcodeBuildMCP Documentation](https://www.xcodebuildmcp.com/)
- [XcodeBuildMCP GitHub](https://github.com/cameroncooke/XcodeBuildMCP)
- [TechCrunch: Xcode Agentic Coding](https://techcrunch.com/2026/02/03/xcode-moves-into-agentic-coding-with-deeper-openai-and-anthropic-integrations/)

---

## Project Configuration (Applied)

### Files Updated

1. **`.codex/config.toml`** - OpenAI Codex agent configuration
   - XcodeBuildMCP @beta (v2.0 with CLI)
   - Native Xcode MCP bridge via `xcrun mcpbridge`

2. **`.xcodebuildmcp/config.yaml`** - XcodeBuildMCP project config
   - Enabled workflows: simulator, debugging, ui-automation
   - Proxy Xcode native MCP tools enabled
   - Package-specific schemes for monorepo

3. **`.claude.json`** - Claude Code agent configuration
   - XcodeBuildMCP @beta server
   - Xcode 26.3 native tools documented
   - Build/test/lint commands

### Xcode 26.3 Agent Configuration Paths

| Agent | Configuration Path |
|-------|-------------------|
| Claude Code (global) | `~/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/.claude.json` |
| Claude Code (project) | `.claude.json` in project root |
| Codex (project) | `.codex/config.toml` in project root |
| Skills | `~/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/skills/` |
| Commands | `~/Library/Developer/Xcode/CodingAssistant/ClaudeAgentConfig/commands/` |

### Environment Notes

- Xcode agents run in restricted PATH environment
- Must use absolute paths for MCP commands
- Configure `PATH` explicitly in shell wrapper args
- Check MCP status with `/context` command in Agent panel

### Adaptive CLAUDE.md Strategy

For projects using both Xcode Agent and CLI Claude Code:
- Detect environment via `CLAUDE_CONFIG_DIR` variable
- Contains `Xcode/CodingAssistant` → Xcode environment
- Otherwise → CLI environment
- Use separate `CLAUDE-XCODE.md` and `CLAUDE-PURE.md` for environment-specific rules

---

## References

- [Apple Newsroom: Xcode 26.3 Agentic Coding](https://www.apple.com/newsroom/2026/02/xcode-26-point-3-unlocks-the-power-of-agentic-coding/)
- [Ars Technica: Xcode 26.3 MCP Support](https://arstechnica.com/apple/2026/02/xcode-26-3-adds-support-for-claude-codex-and-other-agentic-tools-via-mcp/)
- [Cosmo Edge: Xcode 26.3 MCP Guide](https://cosmo-edge.com/xcode-26-3-mcp-ai-agentic-coding/)
- [Fatbobman: Xcode 26.3 + Claude Agent](https://fatbobman.com/en/posts/xcode-263-claude/)
- [Swift with Majid: Agentic Coding in Xcode](https://swiftwithmajid.com/2026/02/10/agentic-coding-in-xcode/)
- [XcodeBuildMCP Documentation](https://www.xcodebuildmcp.com/)
- [XcodeBuildMCP GitHub](https://github.com/cameroncooke/XcodeBuildMCP)

---

*Research completed: 2026-02-14*
*Updated: 2026-02-14 (Xcode 26.3 RC, XcodeBuildMCP v2.0-beta)*
