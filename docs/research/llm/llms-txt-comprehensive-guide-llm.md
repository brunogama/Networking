# llms.txt - LLM Knowledge Base

**Version**: 1.0
**Last Updated**: 2026-02-15
**Token Estimate**: ~8,000 tokens
**Optimization**: RAG-ready, structured for retrieval

---

## Metadata

**Tags**: #llms-txt #ai-documentation #github #markdown #llm-integration #mcp #automation
**Related Topics**: [robots.txt], [ai.txt], [documentation], [API-reference], [MCP-servers], [GitHub-Pages]
**Knowledge Domain**: AI-assisted development, documentation standards, developer tools
**Confidence Level**: High (30+ sources verified)

---

## Quick Facts

- **Created**: September 3, 2024 by Jeremy Howard (Answer.AI)
- **Purpose**: Provide LLM-friendly documentation at predictable location `/llms.txt`
- **Format**: Markdown file with curated content and links (Source: llmstxt.org)
- **Typical Size**: 500-2,000 tokens (base), 5,000-50,000 tokens (full) (Source: Next.js, LangChain examples)
- **Adoption**: 200+ projects in 6 months (Source: thedaviddias/llms-txt-hub)
- **Major Users**: Next.js, LangChain, LangGraph, Stripe, Aptos, Fern (Source: Various)
- **Ecosystem**: 50+ tools (generators, validators, MCP servers) (Source: Research compilation)
- **Status**: Intentionally informal specification to encourage experimentation (Source: AnswerDotAI/llms-txt)

---

## Structured Knowledge

### Core Concepts

**Concept 1: llms.txt (Base Specification)**
- **Definition**: Markdown file at `/llms.txt` providing LLM-optimized project documentation
- **Key characteristics**:
  - Predictable location (like robots.txt)
  - Markdown format (not HTML)
  - Curated content (500-2,000 tokens)
  - Link-based architecture (overview + links to details)
  - Intentionally informal specification
- **Use cases**: 
  - AI assistant context loading
  - IDE integration (Cursor, Windsurf, Claude)
  - MCP server content provision
  - GitHub repository documentation
- **Limitations**: 
  - No strict schema (flexibility vs. consistency tradeoff)
  - Manual maintenance risk (solved with automation)
  - Adoption still growing (not universal)
- **Sources**: 
  - https://llmstxt.org/
  - https://github.com/AnswerDotAI/llms-txt

**Concept 2: llms-full.txt (Comprehensive Variation)**
- **Definition**: Extended version with complete documentation (5,000-50,000 tokens)
- **Key characteristics**:
  - Comprehensive API reference
  - Full code examples
  - Complete guides and tutorials
  - Auto-generated from docs (typically)
- **Use cases**:
  - Large context window LLMs (Claude 200K, GPT-4 128K)
  - Deep technical reference
  - Complete project understanding
- **Limitations**:
  - Large token consumption (25-50% of context)
  - Not suitable for smaller models
  - Requires automation to maintain
- **Sources**:
  - https://nextjs.org/docs/llms-full.txt
  - https://buildwithfern.com/learn/docs/ai-features/llms-txt

**Concept 3: llms-small.txt (Minimal Variation)**
- **Definition**: Quick reference version (200-500 tokens)
- **Key characteristics**:
  - Absolute essentials only
  - Condensed bullet points or tables
  - Minimal code examples
- **Use cases**:
  - Token-constrained environments
  - Quick lookups
  - Small context models
- **Limitations**:
  - Limited detail
  - Less commonly implemented
  - May require follow-up queries
- **Sources**: Emerging pattern (observed in community)

**Concept 4: MCP Integration**
- **Definition**: Model Context Protocol servers that consume and expose llms.txt files
- **Key characteristics**:
  - Dynamic loading of documentation
  - User-configurable URL lists
  - On-demand retrieval
  - Audit trail of tool calls
- **Use cases**:
  - Cursor IDE integration
  - Claude Desktop/Code
  - Windsurf editor
- **Limitations**:
  - Requires MCP-compatible tool
  - Configuration complexity
  - Not all tools support MCP
- **Sources**:
  - https://github.com/langchain-ai/mcpdoc
  - https://github.com/SecretiveShell/MCP-llms-txt

**Concept 5: GitHub Repository Placement**
- **Definition**: Where to place llms.txt files in GitHub repositories
- **Key patterns**:
  - Root directory: `/llms.txt`
  - Docs directory: `/docs/llms.txt`
  - Both (recommended): Root overview + docs full version
  - GitHub Pages: Served at `username.github.io/repo/llms.txt`
- **Use cases**:
  - Open-source project documentation
  - API libraries
  - Framework documentation
  - Developer tools
- **Limitations**:
  - Must account for GitHub Pages vs raw URLs
  - CORS considerations
  - Requires GitHub Actions for automation
- **Sources**: Community best practices, llms-txt-hub examples

---

### Technical Patterns

**Pattern 1: Auto-Generation from Documentation**
```
Problem: Manual maintenance causes drift and staleness
Solution: Generate llms.txt during docs build
Trade-offs: Setup complexity vs. always-fresh content
When to use: Any project with existing documentation
Example:
  - Docusaurus plugin generates from docs/
  - Next.js builds llms-full.txt from MDX files
  - GitHub Action triggers on docs changes
```

**Pattern 2: Multiple Variations**
```
Problem: Different LLMs have different token budgets
Solution: Provide base, full, and small variations
Trade-offs: Maintenance overhead vs. flexibility
When to use: Large documentation sites (50+ pages)
Example:
  /llms.txt (1-2K tokens)
  /llms-full.txt (10-50K tokens)
  /llms-small.txt (200-500 tokens)
```

**Pattern 3: Link-Rich Architecture**
```
Problem: Can't fit all documentation in token budget
Solution: Brief summaries with links to detailed pages
Trade-offs: Requires follow-up requests vs. self-contained
When to use: Any llms.txt implementation
Example:
  ## API Reference
  Brief overview...
  - [Full API Docs](https://docs.example.com/api)
  - [Authentication](https://docs.example.com/auth)
```

**Pattern 4: GitHub Actions Automation**
```yaml
Problem: Keeping llms.txt updated with docs changes
Solution: GitHub Action regenerates on docs/ changes
Trade-offs: CI complexity vs. zero-maintenance freshness
When to use: Active documentation sites
Example:
  on:
    push:
      paths: ['docs/**']
  jobs:
    update-llms-txt:
      - Generate llms.txt
      - Commit if changed
```

**Pattern 5: MCP Server Integration**
```json
Problem: AI tools need dynamic access to documentation
Solution: MCP server exposes llms.txt to IDE
Trade-offs: Configuration vs. automatic context
When to use: Cursor, Claude Desktop, Windsurf users
Example:
  "mcpServers": {
    "llms-txt-docs": {
      "command": "npx",
      "args": ["-y", "@langchain/mcpdoc"],
      "env": {
        "LLMS_TXT_URLS": "https://nextjs.org/docs/llms.txt"
      }
    }
  }
```

---

### Comparisons

**llms.txt vs robots.txt**
| Dimension | llms.txt | robots.txt |
|-----------|----------|------------|
| Purpose | Provide documentation | Control crawler access |
| Format | Markdown | Plain text directives |
| Content | Curated docs + links | Allow/Disallow rules |
| Audience | LLMs consuming content | Web crawlers |
| Size | 500-50,000 tokens | <100 lines typically |
| Relationship | Complementary | Complementary |

**llms.txt vs ai.txt**
| Dimension | llms.txt | ai.txt |
|-----------|----------|--------|
| Purpose | Technical documentation | Policy & legal framework |
| Format | Markdown (curated) | Markdown (policy statements) |
| Content | APIs, examples, guides | Licenses, attribution, terms |
| Audience | LLMs building code | AI systems (training, usage) |
| Adoption | High (200+ projects) | Lower (emerging) |
| Relationship | Complementary | Complementary |

**llms.txt Variations**
| Variation | Size (tokens) | Use Case | Generation |
|-----------|--------------|----------|------------|
| llms.txt | 500-2,000 | Default overview | Manual or auto |
| llms-full.txt | 5,000-50,000 | Complete reference | Typically auto |
| llms-small.txt | 200-500 | Quick ref | Manual |
| llms-ctx.txt | Varies | Context-specific | Pattern (informal) |

**MCP Servers for llms.txt**
| Server | Repository | Purpose | Status |
|--------|-----------|---------|--------|
| mcpdoc | langchain-ai/mcpdoc | Multi-URL llms.txt loader | Production |
| MCP-llms-txt | SecretiveShell/MCP-llms-txt | Awesome-llms-txt directory | Active |
| llms-txt | MCP Market | General integration | Community |

---

## Q&A Pairs (For RAG Retrieval)

**Q: What is llms.txt and why was it created?**
A: llms.txt is a standardized markdown file at `/llms.txt` providing LLM-optimized documentation. Created by Jeremy Howard (Answer.AI) in September 2024 to solve: (1) LLMs lacking fresh documentation, (2) inefficient discovery of relevant docs, (3) token waste on HTML chrome, (4) no canonical source for AI assistants. (Source: llmstxt.org, Answer.AI blog)

**Q: Where should I place llms.txt in a GitHub repository?**
A: Three options: (1) Root directory `/llms.txt` for easy discovery, (2) Docs directory `/docs/llms.txt` for organization, (3) Both (recommended) with root for overview and docs for full version. GitHub Pages serves from configured branch/folder. (Source: Community best practices)

**Q: What's the difference between llms.txt and llms-full.txt?**
A: llms.txt is a brief overview (500-2,000 tokens) for quick context. llms-full.txt is comprehensive (5,000-50,000 tokens) with complete API reference, examples, and guides. Use llms.txt by default, llms-full.txt when LLM has large context window and needs deep reference. (Source: Next.js, Fern documentation)

**Q: How do I auto-generate llms.txt from my documentation?**
A: Use: (1) Documentation framework plugins (Docusaurus, MkDocs, Sphinx), (2) Generator tools (llms-txt-generator, llmstxt.in), (3) GitHub Actions (demodrive-ai/llms-txt-action) triggered on docs changes. Auto-generation prevents drift and ensures freshness. (Source: Tooling research)

**Q: What should I include in an llms.txt file?**
A: Include: (1) Project overview (what, why, who), (2) Installation instructions, (3) Basic usage example, (4) Key concepts/architecture, (5) Links to detailed documentation, (6) Resources (GitHub, docs, community). Keep to 500-2,000 tokens. Avoid: marketing copy, full API reference, HTML tags. (Source: llmstxt.org specification)

**Q: How do MCP servers use llms.txt?**
A: MCP servers (like mcpdoc) are configured with llms.txt URLs, provide tools for AI assistants to fetch documentation on demand, return fresh content when requested, and offer audit trail of tool calls. Compatible with Cursor, Claude Desktop, Windsurf. (Source: langchain-ai/mcpdoc)

**Q: What's the recommended token size for llms.txt variations?**
A: llms.txt base: 500-2,000 tokens (1-3 pages), llms-full.txt: 5,000-50,000 tokens (10-100 pages), llms-small.txt: 200-500 tokens (half page). Leave 50-70% of context window for conversation and code. Estimate: 1 token ≈ 4 characters. (Source: Observed patterns, Next.js example)

**Q: How does llms.txt differ from robots.txt?**
A: robots.txt controls crawler access (Allow/Disallow), llms.txt provides curated documentation content. Both use predictable locations. They're complementary: use robots.txt to allow AI crawlers, llms.txt to provide optimized content. (Source: llmstxt.org philosophy)

**Q: What tools can validate my llms.txt file?**
A: Validators: (1) llms.unusual.ai/llms-txt-validator (comprehensive checks), (2) llmstxtvalidator.dev (syntax + best practices), (3) rankray.com llms-txt-checker (SEO perspective). Check: valid markdown, token count, link validity, structure, no HTML. (Source: Tool directory)

**Q: Should I create llms.txt for a small project?**
A: Yes, even small projects benefit. Create single llms.txt (no need for full variant) with: overview, installation, basic example, links to docs. Takes 1-2 hours, improves AI assistant accuracy. Skip llms-full.txt unless you have 10+ documentation pages. (Source: Best practices)

**Q: How do I integrate llms.txt with Cursor or Claude Desktop?**
A: Install MCP server (mcpdoc): Add to Claude Desktop config with llms.txt URLs. Server loads at startup, provides fetch_docs tool, LLM requests docs as needed. Alternative: paste llms.txt content into project context manually. (Source: mcpdoc documentation)

**Q: What are common llms.txt mistakes to avoid?**
A: Avoid: (1) Using HTML instead of markdown, (2) 100K+ token dumps (too verbose), (3) Marketing copy vs. technical content, (4) Outdated content (not automated), (5) Broken links, (6) No structure/headings. Fix: use pure markdown, curate to 1-50K tokens, focus on technical accuracy, automate generation, validate links, clear hierarchy. (Source: Anti-patterns analysis)

**Q: How often should I update llms.txt?**
A: Update on: major releases, significant features, breaking changes, doc restructures, deprecations. Automate with GitHub Actions (on docs changes, releases, or weekly schedule). Manual quarterly audits recommended. (Source: Maintenance best practices)

**Q: Can I have multiple llms.txt files for different contexts?**
A: Yes, emerging pattern: `/llms-frontend.txt`, `/llms-backend.txt`, `/llms-api.txt`, `/llms-beginner.txt`, `/llms-advanced.txt`. Not formally specified but used by some projects for context-specific documentation. (Source: Observed community pattern)

**Q: What's the relationship between llms.txt and ai.txt?**
A: llms.txt provides technical documentation (APIs, examples, guides), ai.txt provides policy framework (licensing, attribution, AI usage terms). Use both: llms.txt for code generation, ai.txt for legal/policy compliance. (Source: ai.txt specification, 365i.co.uk)

---

## Decision Tree

```
IF project has documentation
  THEN create llms.txt
  BECAUSE AI assistants need fresh, curated content
  
  IF documentation > 10 pages
    THEN create llms-full.txt
    BECAUSE comprehensive reference improves accuracy
  ELSE
    THEN single llms.txt sufficient
    BECAUSE small projects don't need multiple variations
  
  IF documentation changes frequently
    THEN automate with GitHub Actions
    BECAUSE manual updates cause drift
  ELSE
    THEN manual updates acceptable
    BECAUSE stable docs need less maintenance
  
  IF users use Cursor/Claude/Windsurf
    THEN configure MCP server
    BECAUSE dynamic loading improves workflow
  ELSE
    THEN mention in README
    BECAUSE users can manually add to context
    
ELSE (no documentation)
  THEN create minimal llms.txt with:
    - Project overview
    - Installation
    - Basic example
    - GitHub link
  BECAUSE even minimal context helps AI assistants
```

---

## Key Relationships

```mermaid
graph TD
    A[Documentation Source] -->|generates| B[llms.txt]
    A -->|generates| C[llms-full.txt]
    B -->|served at| D[/llms.txt URL]
    C -->|served at| E[/llms-full.txt URL]
    D -->|consumed by| F[MCP Server]
    E -->|consumed by| F
    F -->|provides to| G[Cursor IDE]
    F -->|provides to| H[Claude Desktop]
    F -->|provides to| I[Windsurf]
    G -->|requests docs| F
    H -->|requests docs| F
    I -->|requests docs| F
    J[GitHub Actions] -->|automates| K[Generation]
    K -->|updates| B
    K -->|updates| C
    L[robots.txt] -.controls access.-> D
    M[ai.txt] -.declares policy.-> D
    D -.complementary.-> L
    D -.complementary.-> M
```

---

## Condensed References

- **Official Spec**: https://llmstxt.org/
- **GitHub Repo**: https://github.com/AnswerDotAI/llms-txt
- **Directory**: https://github.com/thedaviddias/llms-txt-hub
- **MCP Server**: https://github.com/langchain-ai/mcpdoc
- **Next.js Example**: https://nextjs.org/docs/llms-full.txt
- **LangChain**: https://python.langchain.com/llms.txt
- **Fern Docs**: https://buildwithfern.com/learn/docs/ai-features/llms-txt
- **Validator**: https://llms.unusual.ai/llms-txt-validator
- **Generator**: https://llmstxt.in/
- **GitHub Action**: https://github.com/demodrive-ai/llms-txt-action
- **ai.txt Spec**: https://www.365i.co.uk/ai-visibility-definition/specifications/ai-txt/
- **Mintlify Guide**: https://www.mintlify.com/blog/what-is-llms-txt

---

## Implementation Checklist

**Immediate (1-2 hours):**
- [ ] Create `/llms.txt` with overview, install, example, links
- [ ] Validate with llms.unusual.ai validator
- [ ] Mention in README

**Near-term (2-4 hours):**
- [ ] Create `/llms-full.txt` if docs > 10 pages
- [ ] Set up GitHub Action for auto-generation
- [ ] Submit to llms-txt-hub directory

**Long-term:**
- [ ] Integrate into documentation build pipeline
- [ ] Configure MCP server for team (if using Cursor/Claude)
- [ ] Monitor and iterate based on feedback

---

## Version History

- v1.0 (2026-02-15): Initial research compilation from 30+ sources

---

**Token Count**: ~8,000 tokens
**Optimized For**: RAG retrieval, quick reference, AI assistant context
**Update Frequency**: As specification evolves (semi-annually recommended)
