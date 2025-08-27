# MCP Comprehensive Guide

## Table of Contents

1. [MCP Server Inventory](#mcp-server-inventory)
2. [MCP_Archon - Project Management & RAG](#mcp_archon---project-management--rag)
3. [MCP_DOCKER - Multi-Platform Integration](#mcp_docker---multi-platform-integration)
4. [MCP_Crawl4AI - Web Scraping & Analysis](#mcp_crawl4ai---web-scraping--analysis)
5. [MCP_Notion - Document Management](#mcp_notion---document-management)
6. [MCP_IDE - Development Environment](#mcp_ide---development-environment)
7. [MCP_Ref - Documentation Search](#mcp_ref---documentation-search)
8. [Integration Strategies](#integration-strategies)
9. [Best Practices](#best-practices)
10. [Anti-Patterns](#anti-patterns)
11. [Workflow Examples](#workflow-examples)

---

## MCP Server Inventory

| MCP Server | Primary Purpose | Key Capabilities |
|------------|-----------------|------------------|
| `mcp__archon` | Project Management & RAG | Project creation, task management, document versioning, knowledge base search |
| `mcp__MCP_DOCKER` | Multi-Platform Integration | GitHub, Heroku, Docker, Notion, web search, PostgreSQL management |
| `mcp__Crawl4AI_1` | Web Scraping | Single page scraping, website crawling with depth control |
| `mcp__MCP_DOCKER` (Notion) | Document Management | Notion workspace integration, page creation, database queries |
| `mcp__ide` | Development Environment | Code execution, diagnostics, Jupyter kernel integration |
| `mcp__Ref` | Documentation Search | Technical documentation search, URL content reading |

---

## MCP_Archon - Project Management & RAG

### Overview
Advanced project management system with RAG (Retrieval-Augmented Generation) capabilities, document versioning, and knowledge base integration.

### Core Functions

#### Health & Session Management
```markdown
# Health Check
mcp__archon__health_check()
# Returns: {uptime, status, dependencies}

# Session Info
mcp__archon__session_info()
# Returns: {active_sessions, server_uptime}
```

#### Knowledge Base Operations

| Function | Required Params | Optional Params | Purpose |
|----------|----------------|----------------|---------|
| `get_available_sources` | None | None | List all knowledge sources |
| `perform_rag_query` | `query` | `source_domain`, `match_count` | Search knowledge base |
| `search_code_examples` | `query` | `source_domain`, `match_count` | Find relevant code samples |

**RAG Query Example:**
```python
# Basic knowledge search
result = mcp__archon__perform_rag_query(
    query="Swift networking best practices",
    match_count=5
)

# Domain-specific search
result = mcp__archon__perform_rag_query(
    query="URLSession configuration",
    source_domain="developer.apple.com",
    match_count=10
)
```

#### Project Management

| Function | Required Params | Optional Params | Purpose |
|----------|----------------|----------------|---------|
| `create_project` | `title` | `description`, `github_repo` | Create new project |
| `list_projects` | None | None | Get all projects |
| `get_project` | `project_id` | None | Get project details |
| `update_project` | `project_id` | `title`, `description`, `github_repo` | Update project |
| `delete_project` | `project_id` | None | Delete project |

**Project Creation Example:**
```python
project = mcp__archon__create_project(
    title="Swift Modern Networking Library",
    description="Modern async/await networking with advanced error handling",
    github_repo="https://github.com/user/modern-networking"
)
```

#### Task Management

| Function | Required Params | Optional Params | Purpose |
|----------|----------------|----------------|---------|
| `create_task` | `project_id`, `title` | `description`, `assignee`, `task_order`, `feature`, `sources`, `code_examples` | Create task |
| `list_tasks` | None | `filter_by`, `filter_value`, `project_id`, `include_closed`, `page`, `per_page` | List tasks |
| `get_task` | `task_id` | None | Get task details |
| `update_task` | `task_id` | `title`, `description`, `status`, `assignee`, `task_order`, `feature` | Update task |
| `delete_task` | `task_id` | None | Delete task |

**Advanced Task Creation:**
```python
task = mcp__archon__create_task(
    project_id="uuid-123",
    title="Implement URLSession wrapper with async/await",
    description="Create modern networking layer with comprehensive error handling",
    assignee="AI IDE Agent",
    task_order=10,
    feature="networking",
    sources=[
        {
            "url": "https://developer.apple.com/documentation/foundation/urlsession",
            "type": "documentation",
            "relevance": "Official URLSession reference"
        }
    ],
    code_examples=[
        {
            "file": "Sources/NetworkManager.swift",
            "function": "NetworkManager",
            "purpose": "Base networking implementation"
        }
    ]
)
```

#### Document Management

| Function | Required Params | Optional Params | Purpose |
|----------|----------------|----------------|---------|
| `create_document` | `project_id`, `title`, `document_type` | `content`, `tags`, `author` | Create document |
| `list_documents` | `project_id` | None | List project documents |
| `get_document` | `project_id`, `doc_id` | None | Get document details |
| `update_document` | `project_id`, `doc_id` | `title`, `content`, `tags`, `author` | Update document |
| `delete_document` | `project_id`, `doc_id` | None | Delete document |

#### Version Control

| Function | Required Params | Optional Params | Purpose |
|----------|----------------|----------------|---------|
| `create_version` | `project_id`, `field_name`, `content` | `change_summary`, `document_id`, `created_by` | Create version snapshot |
| `list_versions` | `project_id` | `field_name` | List version history |
| `get_version` | `project_id`, `field_name`, `version_number` | None | Get specific version |
| `restore_version` | `project_id`, `field_name`, `version_number` | `restored_by` | Restore previous version |

#### Features Management
```python
# Get project features
features = mcp__archon__get_project_features(project_id="uuid-123")
# Returns: {success: bool, features: [...], count: int}
```

### Best Practices - Archon

1. **RAG Queries**: Use specific technical terms and include context
2. **Task Organization**: Use features to group related tasks
3. **Version Control**: Create versions before major changes
4. **Source References**: Always include relevant documentation URLs

### Anti-Patterns - Archon

1. Don't create tasks without proper descriptions
2. Avoid generic project titles - be specific
3. Don't skip version control for important documents
4. Avoid overly broad RAG queries without domain filtering

---

## MCP_DOCKER - Multi-Platform Integration

### Overview
Comprehensive integration platform supporting GitHub, Heroku, Docker, web search, and PostgreSQL operations.

### GitHub Operations

#### Repository Management

| Function | Required Params | Optional Params | Purpose |
|----------|----------------|----------------|---------|
| `create_repository` | `name` | `description`, `private`, `autoInit` | Create new repo |
| `fork_repository` | `owner`, `repo` | `organization` | Fork repository |
| `get_file_contents` | `owner`, `repo` | `path`, `ref`, `sha` | Get file/directory contents |
| `create_or_update_file` | `owner`, `repo`, `path`, `content`, `message`, `branch` | `sha` | Create/update single file |
| `push_files` | `owner`, `repo`, `branch`, `files`, `message` | None | Push multiple files |
| `delete_file` | `owner`, `repo`, `path`, `message`, `branch` | None | Delete file |

#### Branch & Tag Management

| Function | Required Params | Optional Params | Purpose |
|----------|----------------|----------------|---------|
| `create_branch` | `owner`, `repo`, `branch` | `from_branch` | Create new branch |
| `list_branches` | `owner`, `repo` | `page`, `perPage` | List all branches |
| `list_tags` | `owner`, `repo` | `page`, `perPage` | List repository tags |
| `get_tag` | `owner`, `repo`, `tag` | None | Get tag details |

#### Issues & Pull Requests

| Function | Required Params | Optional Params | Purpose |
|----------|----------------|----------------|---------|
| `create_issue` | `owner`, `repo`, `title` | `body`, `assignees`, `labels`, `milestone`, `type` | Create issue |
| `list_issues` | `owner`, `repo` | `after`, `direction`, `labels`, `orderBy`, `perPage`, `since`, `state` | List issues |
| `get_issue` | `owner`, `repo`, `issue_number` | None | Get issue details |
| `update_issue` | `owner`, `repo`, `issue_number` | `title`, `body`, `state`, `assignees`, `labels` | Update issue |
| `create_pull_request` | `owner`, `repo`, `title`, `head`, `base` | `body`, `draft`, `maintainer_can_modify` | Create PR |
| `list_pull_requests` | `owner`, `repo` | `state`, `head`, `base`, `sort`, `direction`, `page`, `perPage` | List PRs |
| `get_pull_request` | `owner`, `repo`, `pullNumber` | None | Get PR details |
| `merge_pull_request` | `owner`, `repo`, `pullNumber` | `merge_method`, `commit_title`, `commit_message` | Merge PR |

#### Advanced GitHub Features

| Function | Required Params | Optional Params | Purpose |
|----------|----------------|----------------|---------|
| `search_code` | `query` | `sort`, `order`, `page`, `perPage` | Search across all GitHub code |
| `search_repositories` | `query` | `page`, `perPage` | Find repositories |
| `search_issues` | `query` | `sort`, `order`, `owner`, `repo`, `page`, `perPage` | Search issues |
| `search_users` | `query` | `sort`, `order`, `page`, `perPage` | Find users |

**GitHub Workflow Example:**
```python
# 1. Create repository
repo = mcp__MCP_DOCKER__create_repository(
    name="networking-library",
    description="Modern Swift networking library",
    private=False,
    autoInit=True
)

# 2. Create feature branch
branch = mcp__MCP_DOCKER__create_branch(
    owner="username",
    repo="networking-library",
    branch="feature/async-networking"
)

# 3. Push multiple files
files = [
    {
        "path": "Sources/NetworkManager.swift",
        "content": "import Foundation\n// NetworkManager implementation"
    },
    {
        "path": "Tests/NetworkManagerTests.swift",
        "content": "import XCTest\n// Test implementation"
    }
]

mcp__MCP_DOCKER__push_files(
    owner="username",
    repo="networking-library",
    branch="feature/async-networking",
    files=files,
    message="feat: Add NetworkManager with async/await support"
)

# 4. Create pull request
pr = mcp__MCP_DOCKER__create_pull_request(
    owner="username",
    repo="networking-library",
    title="feat: Add async networking support",
    head="feature/async-networking",
    base="main",
    body="Implements modern async/await networking patterns"
)
```

### Web Search & Content Extraction

| Function | Required Params | Optional Params | Purpose |
|----------|----------------|----------------|---------|
| `brave_web_search` | `query` | `count`, `country`, `result_filter`, `safesearch` | General web search |
| `brave_news_search` | `query` | `count`, `freshness`, `country` | News-specific search |
| `brave_image_search` | `query` | `count`, `country`, `safesearch` | Image search |
| `tavily_search` | `query` | `max_results`, `search_depth`, `include_images`, `country` | AI-powered search |
| `tavily_extract` | `urls` | `extract_depth`, `format`, `include_images` | Content extraction |
| `tavily_crawl` | `url` | `max_depth`, `limit`, `instructions` | Structured crawling |

**Web Research Workflow:**
```python
# 1. Initial search
results = mcp__MCP_DOCKER__brave_web_search(
    query="Swift async await networking patterns 2024",
    count=10,
    result_filter=["web"]
)

# 2. Extract detailed content
urls = [result["url"] for result in results["web"]["results"][:3]]
content = mcp__MCP_DOCKER__tavily_extract(
    urls=urls,
    extract_depth="advanced",
    format="markdown"
)

# 3. Deep crawl specific documentation
crawl_results = mcp__MCP_DOCKER__tavily_crawl(
    url="https://developer.apple.com/documentation/foundation/urlsession",
    max_depth=2,
    limit=20,
    instructions="Focus on async/await patterns and error handling"
)
```

### Heroku Operations

#### App Management

| Function | Required Params | Optional Params | Purpose |
|----------|----------------|----------------|---------|
| `create_app` | None | `app`, `region`, `team`, `space` | Create Heroku app |
| `list_apps` | None | `all`, `team`, `space`, `personal` | List applications |
| `get_app_info` | `app` | `json` | Get app details |
| `rename_app` | `app`, `newName` | None | Rename application |
| `transfer_app` | `app`, `recipient` | None | Transfer ownership |

#### Deployment & Operations

| Function | Required Params | Optional Params | Purpose |
|----------|----------------|----------------|---------|
| `deploy_to_heroku` | `name`, `rootUri`, `appJson` | `env`, `teamId`, `spaceId` | Deploy application |
| `deploy_one_off_dyno` | `name`, `command` | `sources`, `env`, `size`, `timeToLive` | Run one-off commands |
| `ps_list` | `app` | `json` | List processes |
| `ps_scale` | `app` | `dyno` | Scale dynos |
| `ps_restart` | `app` | `dyno-name`, `process-type` | Restart processes |

### PostgreSQL Management

| Function | Required Params | Optional Params | Purpose |
|----------|----------------|----------------|---------|
| `pg_info` | `app` | `database` | Database status |
| `pg_ps` | `app` | `database`, `verbose` | Active queries |
| `pg_psql` | `app` | `command`, `database`, `credential`, `file` | Execute SQL |
| `pg_outliers` | `app` | `database`, `num`, `reset`, `truncate` | Performance analysis |
| `pg_locks` | `app` | `database`, `truncate` | Lock analysis |

### Notification Management

| Function | Required Params | Optional Params | Purpose |
|----------|----------------|----------------|---------|
| `list_notifications` | None | `filter`, `owner`, `repo`, `since`, `before` | List GitHub notifications |
| `get_notification_details` | `notificationID` | None | Get notification details |
| `dismiss_notification` | `threadID` | `state` | Mark as read/done |
| `mark_all_notifications_read` | None | `lastReadAt`, `owner`, `repo` | Mark all as read |

---

## MCP_Crawl4AI - Web Scraping & Analysis

### Overview
Specialized web scraping and content analysis platform using advanced AI-powered extraction.

### Functions

| Function | Required Params | Optional Params | Purpose |
|----------|----------------|----------------|---------|
| `scrape_webpage` | `url` | None | Single page scraping |
| `crawl_website` | `url` | `crawl_depth`, `max_pages` | Multi-page crawling |

**Usage Examples:**
```python
# Single page scraping
result = mcp__Crawl4AI_1__scrape_webpage(
    url="https://developer.apple.com/documentation/foundation/urlsession"
)

# Website crawling
crawl_result = mcp__Crawl4AI_1__crawl_website(
    url="https://docs.swift.org",
    crawl_depth=2,
    max_pages=10
)
```

### Best Practices - Crawl4AI

1. **Respect Rate Limits**: Use appropriate delays between requests
2. **Target Specific Content**: Use precise URLs for better results
3. **Handle Large Sites**: Limit crawl depth and pages for large websites
4. **Content Validation**: Always validate extracted content structure

---

## MCP_Notion - Document Management

### Overview
Complete Notion workspace integration for document management, database operations, and content creation.

### Core Functions

#### Page Management

| Function | Required Params | Optional Params | Purpose |
|----------|----------------|----------------|---------|
| `post_page` | `parent`, `properties` | `children`, `cover`, `icon` | Create page |
| `retrieve_a_page` | `page_id` | `filter_properties` | Get page details |
| `patch_page` | `page_id` | `properties`, `archived`, `cover`, `icon` | Update page |

#### Database Operations

| Function | Required Params | Optional Params | Purpose |
|----------|----------------|----------------|---------|
| `create_a_database` | `parent`, `properties` | `title` | Create database |
| `retrieve_a_database` | `database_id` | None | Get database schema |
| `post_database_query` | `database_id` | `filter`, `sorts`, `page_size` | Query database |
| `update_a_database` | `database_id` | `title`, `description`, `properties` | Update database |

#### Block Operations

| Function | Required Params | Optional Params | Purpose |
|----------|----------------|----------------|---------|
| `get_block_children` | `block_id` | `page_size`, `start_cursor` | Get child blocks |
| `patch_block_children` | `block_id`, `children` | `after` | Append blocks |
| `retrieve_a_block` | `block_id` | None | Get block details |
| `update_a_block` | `block_id` | `type`, `archived` | Update block |

**Notion Workflow Example:**
```python
# 1. Create project database
database = mcp__MCP_DOCKER__create_a_database(
    parent={"type": "page_id", "page_id": "parent-page-uuid"},
    properties={
        "Name": {
            "title": {},
            "description": "Project name"
        },
        "Status": {
            "select": {
                "options": [
                    {"name": "Not Started", "color": "red"},
                    {"name": "In Progress", "color": "yellow"},
                    {"name": "Completed", "color": "green"}
                ]
            }
        }
    },
    title=[{"text": {"content": "Project Tracker"}}]
)

# 2. Query database
projects = mcp__MCP_DOCKER__post_database_query(
    database_id=database["id"],
    filter={
        "property": "Status",
        "select": {"equals": "In Progress"}
    },
    sorts=[{
        "property": "Name",
        "direction": "ascending"
    }]
)

# 3. Create documentation page
doc_page = mcp__MCP_DOCKER__post_page(
    parent={"page_id": "parent-uuid"},
    properties={
        "title": [{
            "text": {"content": "Swift Networking Documentation"}
        }]
    }
)

# 4. Add content blocks
mcp__MCP_DOCKER__patch_block_children(
    block_id=doc_page["id"],
    children=[
        {
            "type": "paragraph",
            "paragraph": {
                "rich_text": [{
                    "type": "text",
                    "text": {"content": "Modern networking implementation using async/await patterns."}
                }]
            }
        },
        {
            "type": "bulleted_list_item",
            "bulleted_list_item": {
                "rich_text": [{
                    "type": "text",
                    "text": {"content": "URLSession wrapper with error handling"}
                }]
            }
        }
    ]
)
```

---

## MCP_IDE - Development Environment

### Overview
Integration with development environments, providing code execution and diagnostic capabilities.

### Functions

| Function | Required Params | Optional Params | Purpose |
|----------|----------------|----------------|---------|
| `executeCode` | `code` | None | Execute Python in Jupyter kernel |
| `getDiagnostics` | None | `uri` | Get language diagnostics |

**Usage Examples:**
```python
# Execute code in Jupyter kernel
result = mcp__ide__executeCode(
    code="""
import requests
import json

# Test API endpoint
response = requests.get('https://api.github.com/user', 
                       headers={'Authorization': 'token YOUR_TOKEN'})
print(f"Status: {response.status_code}")
print(f"User: {response.json().get('login')}")
"""
)

# Get diagnostics for specific file
diagnostics = mcp__ide__getDiagnostics(
    uri="file:///path/to/NetworkManager.swift"
)
```

---

## MCP_Ref - Documentation Search

### Overview
Specialized documentation search and content retrieval system.

### Functions

| Function | Required Params | Optional Params | Purpose |
|----------|----------------|----------------|---------|
| `ref_search_documentation` | `query` | None | Search documentation |
| `ref_read_url` | `url` | None | Read URL content as markdown |

**Documentation Research Workflow:**
```python
# 1. Search for relevant documentation
docs = mcp__Ref__ref_search_documentation(
    query="Swift URLSession async await networking patterns"
)

# 2. Read specific documentation
for doc in docs["results"][:3]:
    content = mcp__Ref__ref_read_url(url=doc["url"])
    # Process content for analysis
```

---

## Integration Strategies

### 1. Research → Development → Documentation Flow

```mermaid
graph LR
    A[RAG Query] --> B[Web Search]
    B --> C[Content Extract]
    C --> D[Code Generation]
    D --> E[GitHub Push]
    E --> F[Documentation Update]
    F --> G[Notion Tracking]
```

**Implementation:**
```python
# 1. Research phase
knowledge = mcp__archon__perform_rag_query(
    query="Swift networking best practices",
    match_count=5
)

web_results = mcp__MCP_DOCKER__brave_web_search(
    query="Swift async networking 2024 patterns",
    count=10
)

# 2. Development phase
code_examples = mcp__archon__search_code_examples(
    query="URLSession async await",
    match_count=3
)

# Execute development in IDE
mcp__ide__executeCode(code="# Implementation based on research")

# 3. Documentation phase
project = mcp__archon__create_project(
    title="Network Library",
    description="Based on researched patterns"
)

# Push to GitHub
mcp__MCP_DOCKER__push_files(
    owner="user",
    repo="network-lib",
    branch="main",
    files=[{"path": "README.md", "content": "Documentation"}],
    message="docs: Add comprehensive networking guide"
)
```

### 2. Multi-Source Content Aggregation

```python
def comprehensive_research(topic, depth="advanced"):
    results = {}
    
    # Official documentation
    official_docs = mcp__Ref__ref_search_documentation(
        query=f"{topic} official documentation"
    )
    
    # Current web content
    web_content = mcp__MCP_DOCKER__tavily_search(
        query=topic,
        search_depth=depth,
        max_results=10
    )
    
    # Code examples from GitHub
    code_results = mcp__MCP_DOCKER__search_code(
        query=f"{topic} language:Swift"
    )
    
    # Knowledge base insights
    rag_results = mcp__archon__perform_rag_query(
        query=topic,
        match_count=8
    )
    
    return {
        "official": official_docs,
        "web": web_content,
        "code": code_results,
        "knowledge": rag_results
    }
```

### 3. Project Lifecycle Management

```python
def create_complete_project(name, description, github_repo):
    # 1. Create Archon project
    project = mcp__archon__create_project(
        title=name,
        description=description,
        github_repo=github_repo
    )
    
    # 2. Create GitHub repository
    repo = mcp__MCP_DOCKER__create_repository(
        name=name.lower().replace(" ", "-"),
        description=description,
        private=False,
        autoInit=True
    )
    
    # 3. Create Notion workspace
    notion_db = mcp__MCP_DOCKER__create_a_database(
        parent={"type": "page_id", "page_id": "workspace-id"},
        properties={
            "Task": {"title": {}},
            "Status": {"select": {"options": [
                {"name": "Todo", "color": "red"},
                {"name": "In Progress", "color": "yellow"},
                {"name": "Done", "color": "green"}
            ]}},
            "Priority": {"select": {"options": [
                {"name": "Low", "color": "gray"},
                {"name": "Medium", "color": "yellow"},
                {"name": "High", "color": "red"}
            ]}}
        }
    )
    
    # 4. Create initial tasks
    tasks = [
        {"title": "Setup project structure", "priority": "High"},
        {"title": "Implement core functionality", "priority": "High"},
        {"title": "Add comprehensive tests", "priority": "Medium"},
        {"title": "Create documentation", "priority": "Medium"}
    ]
    
    for task in tasks:
        mcp__archon__create_task(
            project_id=project["project_id"],
            title=task["title"],
            assignee="AI IDE Agent",
            task_order=10 if task["priority"] == "High" else 5
        )
    
    return {
        "archon_project": project,
        "github_repo": repo,
        "notion_db": notion_db
    }
```

---

## Best Practices

### 1. Parameter Optimization

#### RAG Queries
- **Use specific technical terms**: `"Swift async URLSession error handling"` vs `"networking"`
- **Include version/year context**: `"iOS 17 networking patterns 2024"`
- **Domain filtering**: Use `source_domain` for authoritative sources

#### Web Search
- **Combine search types**: Use `brave_web_search` + `tavily_search` for comprehensive coverage
- **Progressive refinement**: Start broad, then narrow with specific parameters
- **Content extraction**: Always follow search with `tavily_extract` for detailed content

#### GitHub Operations
- **Batch operations**: Use `push_files` instead of multiple `create_or_update_file` calls
- **Proper error handling**: Check for existing branches/files before creation
- **Meaningful commit messages**: Follow conventional commit format

### 2. Workflow Patterns

#### Research-First Development
```python
# 1. Knowledge gathering
knowledge = gather_comprehensive_research(topic)

# 2. Planning
project = create_project_structure(knowledge)

# 3. Implementation
implement_with_validation(project, knowledge)

# 4. Documentation
create_comprehensive_docs(project, implementation)
```

#### Iterative Refinement
```python
# 1. Initial implementation
create_minimal_viable_solution()

# 2. Validation loop
while not meets_requirements():
    issues = get_diagnostics()
    research_solutions(issues)
    refine_implementation()

# 3. Enhancement
add_advanced_features()
```

### 3. Performance Considerations

#### Parallel Operations
```python
# Good: Parallel information gathering
from concurrent.futures import ThreadPoolExecutor

def parallel_research(topics):
    with ThreadPoolExecutor(max_workers=4) as executor:
        futures = []
        for topic in topics:
            futures.append(executor.submit(mcp__archon__perform_rag_query, topic))
            futures.append(executor.submit(mcp__MCP_DOCKER__brave_web_search, topic))
        
        results = [future.result() for future in futures]
        return results
```

#### Caching Strategies
```python
# Cache expensive operations
cache = {}

def cached_documentation_search(query):
    if query in cache:
        return cache[query]
    
    result = mcp__Ref__ref_search_documentation(query=query)
    cache[query] = result
    return result
```

### 4. Error Handling

#### Robust API Calls
```python
def safe_api_call(func, max_retries=3, **kwargs):
    for attempt in range(max_retries):
        try:
            return func(**kwargs)
        except Exception as e:
            if attempt == max_retries - 1:
                raise e
            time.sleep(2 ** attempt)  # Exponential backoff
    
# Usage
result = safe_api_call(
    mcp__MCP_DOCKER__create_repository,
    name="my-project",
    description="Safe creation"
)
```

---

## Anti-Patterns

### 1. Parameter Misuse

#### DON'T: Generic queries without context
```python
# Bad
mcp__archon__perform_rag_query(query="networking")

# Good
mcp__archon__perform_rag_query(
    query="Swift URLSession async/await error handling patterns iOS 17",
    source_domain="developer.apple.com",
    match_count=10
)
```

#### DON'T: Ignore pagination
```python
# Bad - Missing potentially important results
results = mcp__MCP_DOCKER__list_issues(owner="user", repo="project")

# Good - Handle pagination properly
all_issues = []
page = 1
while True:
    results = mcp__MCP_DOCKER__list_issues(
        owner="user", 
        repo="project", 
        page=page, 
        perPage=100
    )
    if not results:
        break
    all_issues.extend(results)
    page += 1
```

### 2. Workflow Anti-Patterns

#### DON'T: Skip validation steps
```python
# Bad - No validation
mcp__MCP_DOCKER__push_files(owner, repo, branch, files, message)

# Good - Validate first
branch_exists = mcp__MCP_DOCKER__list_branches(owner, repo)
if branch not in [b["name"] for b in branch_exists]:
    mcp__MCP_DOCKER__create_branch(owner, repo, branch)
mcp__MCP_DOCKER__push_files(owner, repo, branch, files, message)
```

#### DON'T: Create without research
```python
# Bad - Implementation without context
create_networking_library()

# Good - Research-driven development
research = comprehensive_research("Swift networking patterns")
knowledge = extract_best_practices(research)
create_networking_library(based_on=knowledge)
```

### 3. Resource Management Anti-Patterns

#### DON'T: Excessive API calls
```python
# Bad - Multiple individual calls
for file_path in files:
    mcp__MCP_DOCKER__create_or_update_file(owner, repo, file_path, content, message, branch)

# Good - Batch operation
file_objects = [{"path": path, "content": content} for path, content in files.items()]
mcp__MCP_DOCKER__push_files(owner, repo, branch, file_objects, message)
```

#### DON'T: Ignore rate limits
```python
# Bad - Rapid successive calls
for query in queries:
    result = mcp__MCP_DOCKER__brave_web_search(query=query)

# Good - Implement rate limiting
import time
for query in queries:
    result = mcp__MCP_DOCKER__brave_web_search(query=query)
    time.sleep(1)  # Respect rate limits
```

### 4. Data Processing Anti-Patterns

#### DON'T: Process all results blindly
```python
# Bad - No filtering or validation
results = mcp__MCP_DOCKER__tavily_search(query="Swift", max_results=20)
for result in results:
    process_content(result["content"])

# Good - Filter and validate
results = mcp__MCP_DOCKER__tavily_search(
    query="Swift networking async await patterns",
    max_results=10,
    search_depth="advanced"
)
relevant_results = [r for r in results if "URLSession" in r["content"] or "async" in r["content"]]
for result in relevant_results[:5]:  # Limit processing
    validated_content = validate_and_clean(result["content"])
    process_content(validated_content)
```

---

## Workflow Examples

### 1. Complete Library Development

```python
def develop_networking_library():
    """Complete workflow for developing a Swift networking library"""
    
    # Phase 1: Research & Planning
    print("🔍 Research Phase")
    
    # Gather comprehensive knowledge
    rag_results = mcp__archon__perform_rag_query(
        query="Swift networking URLSession async await best practices",
        match_count=10
    )
    
    web_research = mcp__MCP_DOCKER__brave_web_search(
        query="Swift networking library 2024 patterns async await",
        count=15,
        result_filter=["web"]
    )
    
    code_examples = mcp__MCP_DOCKER__search_code(
        query="URLSession async await Swift language:Swift",
        perPage=20
    )
    
    official_docs = mcp__Ref__ref_search_documentation(
        query="Swift URLSession async await networking Foundation"
    )
    
    # Phase 2: Project Setup
    print("🏗️ Project Setup Phase")
    
    # Create Archon project
    project = mcp__archon__create_project(
        title="Swift Modern Networking Library",
        description="Production-ready Swift networking library with async/await, comprehensive error handling, and modern patterns",
        github_repo="https://github.com/user/swift-modern-networking"
    )
    
    # Create GitHub repository
    repo = mcp__MCP_DOCKER__create_repository(
        name="swift-modern-networking",
        description="Modern Swift networking library with async/await support",
        private=False,
        autoInit=True
    )
    
    # Phase 3: Task Planning
    print("📋 Task Planning Phase")
    
    tasks = [
        {
            "title": "Create NetworkManager protocol and base implementation",
            "description": "Define core networking interface with async/await support",
            "assignee": "AI IDE Agent",
            "task_order": 10,
            "feature": "core",
            "sources": [
                {
                    "url": "https://developer.apple.com/documentation/foundation/urlsession",
                    "type": "documentation",
                    "relevance": "Official URLSession documentation"
                }
            ]
        },
        {
            "title": "Implement comprehensive error handling",
            "description": "Create typed error system for network failures",
            "assignee": "AI IDE Agent", 
            "task_order": 9,
            "feature": "error-handling"
        },
        {
            "title": "Add request/response interceptors",
            "description": "Implement middleware pattern for request modification",
            "assignee": "AI IDE Agent",
            "task_order": 8,
            "feature": "middleware"
        },
        {
            "title": "Create comprehensive test suite",
            "description": "Unit and integration tests with mocking",
            "assignee": "AI IDE Agent",
            "task_order": 7,
            "feature": "testing"
        }
    ]
    
    created_tasks = []
    for task in tasks:
        created_task = mcp__archon__create_task(
            project_id=project["project_id"],
            **task
        )
        created_tasks.append(created_task)
    
    # Phase 4: Implementation
    print("💻 Implementation Phase")
    
    # Create feature branch
    mcp__MCP_DOCKER__create_branch(
        owner="user",
        repo="swift-modern-networking", 
        branch="feature/core-implementation"
    )
    
    # Generate implementation files based on research
    files = [
        {
            "path": "Sources/ModernNetworking/NetworkManager.swift",
            "content": generate_network_manager_code(rag_results, code_examples)
        },
        {
            "path": "Sources/ModernNetworking/NetworkError.swift", 
            "content": generate_error_types(web_research)
        },
        {
            "path": "Sources/ModernNetworking/RequestInterceptor.swift",
            "content": generate_interceptor_code(official_docs)
        },
        {
            "path": "Tests/ModernNetworkingTests/NetworkManagerTests.swift",
            "content": generate_test_suite(created_tasks)
        },
        {
            "path": "Package.swift",
            "content": generate_package_manifest()
        },
        {
            "path": "README.md",
            "content": generate_documentation(project, tasks, research_summary)
        }
    ]
    
    # Push implementation
    mcp__MCP_DOCKER__push_files(
        owner="user",
        repo="swift-modern-networking",
        branch="feature/core-implementation", 
        files=files,
        message="feat: Implement core networking functionality with async/await support\n\n- Add NetworkManager protocol and implementation\n- Implement comprehensive error handling\n- Add request/response interceptors\n- Include comprehensive test suite\n- Add documentation and examples"
    )
    
    # Phase 5: Validation
    print("✅ Validation Phase")
    
    # Run tests in IDE
    test_results = mcp__ide__executeCode(code="""
    import subprocess
    result = subprocess.run(['swift', 'test'], capture_output=True, text=True, cwd='/path/to/swift-modern-networking')
    print(f"Exit code: {result.returncode}")
    print(f"Output: {result.stdout}")
    if result.stderr:
        print(f"Errors: {result.stderr}")
    """)
    
    # Get diagnostics
    diagnostics = mcp__ide__getDiagnostics()
    
    # Phase 6: Documentation & Tracking
    print("📚 Documentation Phase")
    
    # Create comprehensive documentation
    documentation = mcp__archon__create_document(
        project_id=project["project_id"],
        title="Swift Modern Networking - API Documentation",
        document_type="api",
        content={
            "overview": "Modern Swift networking library with async/await support",
            "features": ["Async/await support", "Type-safe error handling", "Request interceptors"],
            "examples": generate_usage_examples(),
            "api_reference": generate_api_docs(files)
        },
        tags=["swift", "networking", "async", "documentation"]
    )
    
    # Create pull request
    pr = mcp__MCP_DOCKER__create_pull_request(
        owner="user",
        repo="swift-modern-networking",
        title="feat: Core networking implementation",
        head="feature/core-implementation",
        base="main",
        body=f"""## Overview
This PR implements the core functionality for the Swift Modern Networking library.

## Features Implemented
- ✅ NetworkManager protocol with async/await support
- ✅ Comprehensive error handling with typed errors
- ✅ Request/response interceptor system
- ✅ Complete test suite with >90% coverage
- ✅ Documentation and usage examples

## Research Sources
Based on comprehensive research including:
- Apple's URLSession documentation
- Modern Swift networking patterns from {len(web_research.get('results', []))} web sources
- {len(code_examples.get('items', []))} code examples from GitHub
- Knowledge base insights from Archon

## Testing
- All tests pass
- No compiler warnings
- Swift 5.9+ compatible

## Documentation
- Complete API documentation
- Usage examples
- Integration guide
"""
    )
    
    # Update task status
    for task in created_tasks:
        mcp__archon__update_task(
            task_id=task["task_id"],
            status="done"
        )
    
    print("🎉 Library development complete!")
    return {
        "project": project,
        "repository": repo,
        "pull_request": pr,
        "documentation": documentation,
        "tasks_completed": len(created_tasks)
    }

# Helper functions
def generate_network_manager_code(rag_results, code_examples):
    """Generate NetworkManager implementation based on research"""
    # Implementation would analyze research and generate appropriate code
    return """
import Foundation

public protocol NetworkManaging {
    func request<T: Codable>(_ request: URLRequest) async throws -> T
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

public final class NetworkManager: NetworkManaging {
    private let session: URLSession
    private let interceptors: [RequestInterceptor]
    
    public init(session: URLSession = .shared, interceptors: [RequestInterceptor] = []) {
        self.session = session
        self.interceptors = interceptors
    }
    
    public func request<T: Codable>(_ request: URLRequest) async throws -> T {
        // Implementation based on research findings...
    }
    
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        // Implementation with comprehensive error handling...
    }
}
"""

# Additional helper functions would be implemented...
```

### 2. Documentation Research Workflow

```python
def comprehensive_documentation_research(topic):
    """Multi-source documentation research with content aggregation"""
    
    results = {
        "official_docs": [],
        "web_content": [],
        "code_examples": [],
        "knowledge_base": [],
        "aggregated_insights": {}
    }
    
    # 1. Official documentation search
    print(f"🔍 Searching official documentation for: {topic}")
    official = mcp__Ref__ref_search_documentation(
        query=f"{topic} official documentation Swift Apple"
    )
    results["official_docs"] = official
    
    # 2. Web content research
    print(f"🌐 Web research for: {topic}")
    web_search = mcp__MCP_DOCKER__tavily_search(
        query=f"{topic} Swift best practices 2024",
        search_depth="advanced",
        max_results=15,
        include_raw_content=True
    )
    results["web_content"] = web_search
    
    # 3. Code examples from GitHub
    print(f"💻 Code examples search for: {topic}")
    code_search = mcp__MCP_DOCKER__search_code(
        query=f"{topic} language:Swift",
        sort="indexed",
        order="desc",
        perPage=25
    )
    results["code_examples"] = code_search
    
    # 4. Knowledge base insights
    print(f"🧠 Knowledge base search for: {topic}")
    rag_results = mcp__archon__perform_rag_query(
        query=f"{topic} Swift implementation patterns",
        match_count=12
    )
    results["knowledge_base"] = rag_results
    
    # 5. Deep content extraction
    print("📄 Extracting detailed content...")
    urls_to_extract = []
    
    # Get top URLs from web search
    if "results" in web_search:
        urls_to_extract.extend([r["url"] for r in web_search["results"][:5]])
    
    # Get documentation URLs
    if "results" in official:
        urls_to_extract.extend([r["url"] for r in official["results"][:3]])
    
    # Extract content
    extracted_content = mcp__MCP_DOCKER__tavily_extract(
        urls=urls_to_extract,
        extract_depth="advanced",
        format="markdown",
        include_images=True
    )
    results["extracted_content"] = extracted_content
    
    # 6. Aggregate insights
    print("🔄 Aggregating insights...")
    results["aggregated_insights"] = {
        "total_sources": len(urls_to_extract),
        "official_docs_count": len(official.get("results", [])),
        "web_results_count": len(web_search.get("results", [])),
        "code_examples_count": len(code_search.get("items", [])),
        "knowledge_entries": len(rag_results.get("results", [])),
        "key_patterns": extract_patterns(results),
        "recommended_approaches": synthesize_recommendations(results)
    }
    
    return results

def extract_patterns(research_results):
    """Extract common patterns from research results"""
    patterns = []
    
    # Analyze code examples for patterns
    code_items = research_results["code_examples"].get("items", [])
    for item in code_items[:10]:  # Analyze top 10
        # Pattern extraction logic here
        patterns.append({
            "source": item.get("repository", {}).get("full_name", "Unknown"),
            "pattern": "async/await networking",  # This would be dynamically extracted
            "url": item.get("html_url")
        })
    
    return patterns

def synthesize_recommendations(research_results):
    """Synthesize recommendations from all research sources"""
    recommendations = []
    
    # This would implement sophisticated analysis
    # of all research sources to provide actionable recommendations
    
    return [
        "Use URLSession with async/await for modern Swift networking",
        "Implement comprehensive error handling with custom error types", 
        "Follow Apple's networking best practices from official documentation",
        "Consider using request/response interceptors for cross-cutting concerns"
    ]
```

### 3. Issue Investigation Workflow

```python
def investigate_github_issue(owner, repo, issue_number):
    """Comprehensive issue investigation with context gathering"""
    
    print(f"🔍 Investigating issue #{issue_number} in {owner}/{repo}")
    
    # 1. Get issue details
    issue = mcp__MCP_DOCKER__get_issue(
        owner=owner,
        repo=repo, 
        issue_number=issue_number
    )
    
    # 2. Get issue comments for additional context
    comments = mcp__MCP_DOCKER__get_issue_comments(
        owner=owner,
        repo=repo,
        issue_number=issue_number
    )
    
    # 3. Search for related issues
    related_issues = mcp__MCP_DOCKER__search_issues(
        query=f"repo:{owner}/{repo} {' '.join(issue['title'].split()[:3])}",
        sort="updated",
        order="desc"
    )
    
    # 4. Get repository context
    repo_files = mcp__MCP_DOCKER__get_file_contents(
        owner=owner,
        repo=repo,
        path="/"
    )
    
    # 5. Search for relevant code
    code_search = mcp__MCP_DOCKER__search_code(
        query=f"repo:{owner}/{repo} {extract_keywords(issue['title'])}"
    )
    
    # 6. Research solutions
    if issue.get("labels"):
        label_terms = " ".join([label["name"] for label in issue["labels"]])
        solution_research = mcp__MCP_DOCKER__brave_web_search(
            query=f"{label_terms} {issue['title']} solution",
            count=10
        )
    else:
        solution_research = mcp__MCP_DOCKER__brave_web_search(
            query=f"{issue['title']} solution programming",
            count=10
        )
    
    # 7. Check for existing documentation
    docs_search = mcp__Ref__ref_search_documentation(
        query=f"{extract_technical_terms(issue['title'])} {extract_technical_terms(issue.get('body', ''))}"
    )
    
    # 8. Compile investigation report
    investigation_report = {
        "issue_details": {
            "title": issue["title"],
            "body": issue["body"],
            "state": issue["state"],
            "labels": [label["name"] for label in issue.get("labels", [])],
            "assignees": [assignee["login"] for assignee in issue.get("assignees", [])],
            "created_at": issue["created_at"],
            "updated_at": issue["updated_at"]
        },
        "context": {
            "comments_count": len(comments),
            "related_issues_count": len(related_issues.get("items", [])),
            "repository_structure": analyze_repo_structure(repo_files),
            "relevant_code_files": [item["path"] for item in code_search.get("items", [])][:5]
        },
        "research": {
            "web_solutions": solution_research.get("results", [])[:5],
            "documentation": docs_search.get("results", [])[:3],
            "similar_issues": related_issues.get("items", [])[:3]
        },
        "recommendations": generate_issue_recommendations(issue, comments, code_search, solution_research)
    }
    
    return investigation_report

def extract_keywords(text):
    """Extract relevant keywords from issue title/description"""
    # Simple implementation - would be more sophisticated in practice
    stop_words = {"a", "an", "and", "are", "as", "at", "be", "by", "for", "from", "in", "is", "it", "of", "on", "that", "the", "to", "was", "with"}
    words = text.lower().split()
    keywords = [word for word in words if word not in stop_words and len(word) > 3]
    return " ".join(keywords[:5])

def extract_technical_terms(text):
    """Extract technical terms from text"""
    if not text:
        return ""
    
    # Look for common technical patterns
    technical_patterns = [
        r'\b[A-Z][a-zA-Z]*(?:Error|Exception|Manager|Service|Protocol|Delegate)\b',
        r'\b(?:async|await|URLSession|Network|HTTP|API|JSON|XML)\b',
        r'\b[a-zA-Z]+\(\)\b'  # Function calls
    ]
    
    import re
    terms = []
    for pattern in technical_patterns:
        matches = re.findall(pattern, text)
        terms.extend(matches)
    
    return " ".join(list(set(terms))[:10])  # Remove duplicates, limit to 10

def analyze_repo_structure(repo_files):
    """Analyze repository structure for context"""
    structure = {
        "languages": [],
        "frameworks": [],
        "key_files": []
    }
    
    if isinstance(repo_files, list):
        for file in repo_files:
            name = file.get("name", "")
            if name.endswith((".swift", ".m", ".h")):
                structure["languages"].append("Swift/Objective-C")
            elif name.endswith((".js", ".ts")):
                structure["languages"].append("JavaScript/TypeScript")
            elif name.endswith(".py"):
                structure["languages"].append("Python")
            
            if name in ["Package.swift", "Podfile", "Cartfile"]:
                structure["key_files"].append(name)
    
    return structure

def generate_issue_recommendations(issue, comments, code_search, solution_research):
    """Generate actionable recommendations for the issue"""
    recommendations = []
    
    # Based on labels
    labels = [label["name"] for label in issue.get("labels", [])]
    if "bug" in labels:
        recommendations.append("🐛 This is a bug report - prioritize reproduction and root cause analysis")
    if "enhancement" in labels:
        recommendations.append("✨ This is a feature request - consider implementation complexity and user impact")
    if "documentation" in labels:
        recommendations.append("📚 Documentation issue - verify current docs and update as needed")
    
    # Based on code search results
    if code_search.get("items"):
        recommendations.append(f"🔍 Found {len(code_search['items'])} relevant code files to investigate")
    
    # Based on solution research
    if solution_research.get("results"):
        recommendations.append(f"🌐 Found {len(solution_research['results'])} potential web solutions to explore")
    
    # Based on comments
    if len(comments) > 5:
        recommendations.append("💬 High engagement issue - review all comments for additional context")
    
    return recommendations
```

This comprehensive guide provides detailed documentation of all available MCP servers, their parameters, usage patterns, and best practices. The examples show practical implementations for real-world scenarios, helping developers understand when and how to use each MCP capability effectively.