# Context Workspace

Purpose: persist recoverable repo context for `ModernNetworking` on disk so future sessions can
reload state without replaying large command outputs or re-reading the whole worktree.

Current branch: `epic/mvp-core`
Last refreshed: `2026-03-10`

## What This Workspace Tracks

- the active refactor plan for `Packages/Networking`
- the current package graph and validation expectations
- recently created, modified, or deleted repo artifacts
- durable repo facts that should survive session boundaries
- long outputs that should live on disk instead of in chat

## Layout

- `current-plan.yaml`: active plan, focus, and next action
- `session-summary.md`: rolling summary of current repo state
- `artifact-index.md`: important files and path groups touched by recent work
- `tool-outputs/`: large command outputs, test logs, and research dumps
- `plans/`: task-specific plans distilled from source-of-truth docs
- `memory/`: stable repo facts that are safe to reuse later
- `agents/`: sub-agent findings and handoff files when parallel work is running

## Usage Rules

- Write large outputs to `tool-outputs/` and keep only a short summary in chat.
- Update `current-plan.yaml` whenever objective, status, or next action changes.
- Keep `session-summary.md` concise and current enough for a new session to re-orient quickly.
- Record meaningful file creation, movement, and deletion in `artifact-index.md`.
- Store only validated, durable knowledge in `memory/`; do not promote guesses or transient logs.
- Mirror the repo rules: root `swift test` is not a meaningful gate here; package validation must use
  `--package-path`.
