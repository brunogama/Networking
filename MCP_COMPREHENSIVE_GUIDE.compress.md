# MCP Compact Reference Guide

## MCP Server Overview

| Server | Purpose | Key Functions |
|--------|---------|---------------|
| `mcp__archon` | Project Management & RAG | Projects, tasks, docs, knowledge search |
| `mcp__MCP_DOCKER` | Multi-Platform Integration | GitHub, Heroku, Docker, web search, PostgreSQL |
| `mcp__Crawl4AI_1` | Web Scraping | Page scraping, website crawling |
| `mcp__ide` | Development Environment | Code execution, diagnostics |
| `mcp__Ref` | Documentation Search | Tech docs search, URL reading |

---

## MCP_Archon - Project Management & RAG

### Core Functions

**Knowledge Base**
```python
# Search knowledge base
perform_rag_query(query, source_domain=None, match_count=5)
search_code_examples(query, source_domain=None, match_count=5)
get_available_sources()
```

**Projects**
```python
create_project(title, description="", github_repo=None)
list_projects() / get_project(project_id) / update_project(project_id, **kwargs)
delete_project(project_id)
```

**Tasks**
```python
create_task(project_id, title, description="", assignee="User", 
           task_order=0, feature=None, sources=None, code_examples=None)
list_tasks(filter_by=None, filter_value=None, project_id=None)
update_task(task_id, status=None, **kwargs)  # status: "todo"|"doing"|"review"|"done"
```

**Documents & Versions**
```python
create_document(project_id, title, document_type, content=None, tags=None)
create_version(project_id, field_name, content, change_summary=None)
restore_version(project_id, field_name, version_number)
```

### Example Usage
```python
# Research-driven task creation
knowledge = mcp__archon__perform_rag_query(
    query="Swift URLSession async await patterns",
    source_domain="developer.apple.com"
)

project = mcp__archon__create_project(
    title="Swift Networking Library",
    description="Modern async/await networking"
)

task = mcp__archon__create_task(
    project_id=project["project_id"],
    title="Implement URLSession wrapper",
    sources=[{"url": "https://developer.apple.com/documentation/foundation/urlsession", 
              "type": "documentation", "relevance": "Official URLSession docs"}]
)
```

---

## MCP_DOCKER - Multi-Platform Integration

### GitHub Operations

**Repository Management**
| Function | Required | Optional | Purpose |
|----------|----------|----------|---------|
| `create_repository` | name | description, private, autoInit | Create repo |
| `get_file_contents` | owner, repo | path, ref | Get files |
| `push_files` | owner, repo, branch, files, message | - | Batch file upload |
| `create_branch` | owner, repo, branch | from_branch | Create branch |

**Issues & PRs**
| Function | Required | Optional | Purpose |
|----------|----------|----------|---------|
| `create_issue` | owner, repo, title | body, labels, assignees | Create issue |
| `create_pull_request` | owner, repo, title, head, base | body, draft | Create PR |
| `search_code` | query | sort, order, page | Search GitHub code |

### Web Search & Content
| Function | Required | Optional | Purpose |
|----------|----------|----------|---------|
| `brave_web_search` | query | count, country | General search |
| `tavily_search` | query | max_results, search_depth | AI-powered search |
| `tavily_extract` | urls | extract_depth, format | Content extraction |
| `tavily_crawl` | url | max_depth, limit | Site crawling |

### Heroku & PostgreSQL
| Function | Required | Optional | Purpose |
|----------|----------|----------|---------|
| `create_app` | - | app, region | Create Heroku app |
| `deploy_to_heroku` | name, rootUri, appJson | env | Deploy app |
| `pg_psql` | app | command, database | Execute SQL |

### Example Workflows
```python
# Complete project setup
repo = mcp__MCP_DOCKER__create_repository(
    name="my-project", description="Project desc", autoInit=True)

mcp__MCP_DOCKER__create_branch(
    owner="user", repo="my-project", branch="feature/impl")

files = [{"path": "src/main.py", "content": "# Implementation"}]
mcp__MCP_DOCKER__push_files(
    owner="user", repo="my-project", branch="feature/impl", 
    files=files, message="feat: Add implementation")

# Research workflow
results = mcp__MCP_DOCKER__brave_web_search(
    query="Swift networking patterns 2024", count=10)
content = mcp__MCP_DOCKER__tavily_extract(
    urls=[r["url"] for r in results["results"][:3]])
```

---

## Other MCP Servers

### MCP_Crawl4AI - Web Scraping
```python
scrape_webpage(url)                    # Single page
crawl_website(url, crawl_depth=2, max_pages=10)  # Multi-page
```

### MCP_IDE - Development Environment
```python
executeCode(code)                      # Run Python in Jupyter
getDiagnostics(uri=None)              # Get language diagnostics
```

### MCP_Ref - Documentation Search
```python
ref_search_documentation(query)       # Search tech docs
ref_read_url(url)                     # Read URL as markdown
```

---

## Integration Patterns

### Research → Development Flow
```python
def research_and_implement(topic):
    # 1. Multi-source research
    knowledge = mcp__archon__perform_rag_query(query=f"{topic} best practices")
    web_results = mcp__MCP_DOCKER__brave_web_search(query=f"{topic} 2024")
    docs = mcp__Ref__ref_search_documentation(query=topic)
    
    # 2. Create project
    project = mcp__archon__create_project(title=f"{topic} Implementation")
    
    # 3. Generate implementation
    repo = mcp__MCP_DOCKER__create_repository(name=project["title"].lower())
    files = generate_code_from_research(knowledge, web_results, docs)
    mcp__MCP_DOCKER__push_files(owner="user", repo=repo["name"], 
                                branch="main", files=files, message="Initial implementation")
    
    return {"project": project, "repo": repo}
```

### Task-Driven Development
```python
def complete_task_cycle(task_id):
    task = mcp__archon__get_task(task_id)
    mcp__archon__update_task(task_id, status="doing")
    
    # Research for task
    if task.get("sources"):
        research = [mcp__Ref__ref_read_url(s["url"]) for s in task["sources"]]
    
    # Implement
    implementation = implement_task(task, research)
    
    # Update status
    mcp__archon__update_task(task_id, status="review")
    return implementation
```

---

## Best Practices

### Parameter Optimization
- **RAG Queries**: Use specific technical terms + domain filtering
- **Web Search**: Combine `brave_web_search` + `tavily_extract` for depth
- **GitHub**: Use `push_files` for batch operations, not individual calls

### Error Handling
```python
def safe_api_call(func, max_retries=3, **kwargs):
    for attempt in range(max_retries):
        try:
            return func(**kwargs)
        except Exception as e:
            if attempt == max_retries - 1:
                raise e
            time.sleep(2 ** attempt)
```

### Anti-Patterns to Avoid
- Generic queries without context: ❌ `query="networking"` → ✅ `query="Swift URLSession async patterns iOS 17"`
- Ignoring pagination in list operations
- Creating without validation (check if branch exists before creating)
- Excessive individual API calls instead of batch operations

---

## Quick Reference

### Common Workflows
1. **New Project**: `create_project` → `create_repository` → `create_branch` → `create_task`
2. **Research**: `perform_rag_query` → `brave_web_search` → `tavily_extract` → `ref_search_documentation`
3. **Implementation**: `get_task` → `update_task(status="doing")` → implement → `push_files` → `update_task(status="review")`
4. **Documentation**: `create_document` → `create_version` for snapshots

### Key Parameters
- **match_count**: 5-15 for RAG queries
- **search_depth**: "basic"|"advanced" for Tavily
- **extract_depth**: "basic"|"advanced" for content extraction
- **task_order**: 0-100, higher = more priority
- **status**: "todo"|"doing"|"review"|"done"