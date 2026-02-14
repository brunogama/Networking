# AI Coding Agent Rules (Project-Agnostic, Lint-First)

**Purpose**: Ensure any AI agent changes compile cleanly, pass tests, and comply with repo lint/format rules *by design* (not by cleanup at the end).

---

## 0) Minimal-diff mandate (scale-safe)

This codebase is large. Your default behavior must be **surgical**.

### 0.1 Change policy (hard rules)
- **Touch the fewest files possible**. If a change can be contained to 1 file, do not spread it to 2.
- **No opportunistic refactors**: do not rename, reformat, reorder, “clean up”, or “modernize” unrelated code.
- **No mass formatting**: never run format/lint across the whole repo. Only target files you changed or files required to compile.
- **No file moves** (renames, path changes) unless explicitly required.
- **No signature churn**: keep public APIs stable unless the task requires it.
- **No behavior drift**: if you cannot articulate the behavior change in one sentence, you likely changed too much.

### 0.2 Diff budget (guardrails)
- Prefer changes that are **≤ 50 lines net** unless the request explicitly requires more.
- Prefer **localized edits** over wide-reaching abstractions.
- If you need to exceed the budget, first try:
  1) extracting a tiny helper inside the same file,
  2) adding a small collaborator type,
  3) adding a small parameter object.
  Only then consider larger restructuring.

### 0.3 Working set discipline
- Determine the *minimum* set of impacted symbols/types/modules.
- Restrict searches to the smallest scope (module folder first, then repo).
- Validate impact using **reverse references** (e.g., `rg`/`swift package describe`/compiler errors) before broad edits.

---

## 0.4 Regression-zero mindset
“Zero regressions” means you must prove safety, not assume it.

- If behavior changes: add/adjust tests that fail before and pass after.
- If behavior must not change: add regression tests or assertions around the affected seam if tests are missing.
- Prefer **narrow unit tests** and **golden snapshots** (where applicable) over broad integration rewrites.


## 1) Non‑negotiables (Definition of Done)

Work is **not done** unless all items below are true:

1. **Formatting applied** using the repo formatter (Swift: `swift-format` with the repo `.swift-format`).
2. **Lint clean**: run SwiftLint in *fix* mode, then in *strict* mode, on the changed files.
3. **Zero warnings / zero errors** when building with warnings treated as errors (Swift: `swift build -Xswiftc -warnings-as-errors`).
4. **Tests pass** (Swift packages: `swift test`).
5. **Coverage gate passes** when the repo enforces it (do not lower thresholds or bypass checks).
6. **No bypasses**: never use `--no-verify`, never disable hooks, never “temporarily” commit broken code.

These checks are enforced by pre-commit hooks in many repos (format, lint strict, tests, coverage, warnings-as-errors). If your output would fail them, refactor before finishing.

---

## 2) Treat lint rules as design constraints (budget-based coding)

### 2.1 Hard budgets (lint/format)

**Source of truth**: the repo’s lint/format config files (e.g., `.swiftlint.yml`, `.swift-format`, ESLint, etc.).
If you don’t know the exact thresholds, assume conservative defaults and refactor early.

**Typical safe defaults (adjust to your repo):**
- **Line length**: 100
- **Parameters per function**: warning at 4, hard limit at 6
- **Function body length**: warning at 60, hard limit at 120
- **Type body length**: warning at 300, hard limit at 800
- **File length**: warning at 400, hard limit at 1000
- **Cyclomatic complexity**: warning at 10, hard limit at 15
- **Nesting**: type ≤ 2, function ≤ 3

Also respect repo-specific rules such as “no debug prints”, “prefer value types”, naming conventions, and forbidden APIs.

### 2.2 “Refactor triggers” (act early)
Refactor **before** adding more code when any of these are true:

- A function is likely to exceed ~50 lines (you are approaching the 60-line warning).
- Complexity is increasing (multiple `if`/`switch` branches, nested loops, deep guards).
- A file is trending past ~350 lines (you are approaching the 400-line warning).
- A type becomes a “god type” (multiple responsibilities, many private helpers, many stored properties).

---

## 3) Mandatory tactics to stay under budgets

### 3.1 Keep functions small and flat
Preferred shape:

- Early exits (`guard`) instead of deep nesting.
- Extract private helpers when:
  - A block is >10–15 lines,
  - A branch has >1 responsibility,
  - A loop does more than one conceptual thing.
- Split “do everything” functions into:
  - `parse/validate` (pure), `transform` (pure), `perform` (side effects), `persist` (I/O).

### 3.2 Reduce cyclomatic complexity (target ≤ 8)
Use these patterns:

- Replace long `if/else` chains with:
  - Table-driven mappings (`Dictionary` lookup),
  - Small strategy types (protocol + structs),
  - `switch` with extracted case handlers.
- If a `switch` has many cases, create a per-case private function (or type) so the main function stays small.

### 3.3 Keep files/types small
Default split rules:

- **1 type per file** (exceptions: tiny internal helpers tightly coupled to the type).
- If a file has multiple “sections” (protocols, adapters, mappers), split them.
- If a type needs many helpers: move helpers into:
  - `TypeName+Helpers.swift`,
  - nested types,
  - or separate collaborator types.

### 3.4 Parameter count control
If a function wants >4 parameters:

- Introduce a parameter object (`struct`) or a small domain type.
- Prefer passing cohesive objects (e.g., `Request`, `Context`) over parallel primitives.

---

## 4) Process the agent must follow (every change)

1. **Plan**: state what you will change and where (files/types), and how you will keep within the budgets above.
2. **Implement** with budget-first refactoring (do not “just add code”).
3. **Self-review** (required): verify you did not introduce:
   - large functions,
   - large files,
   - added nesting,
   - increased complexity,
   - unnecessary public API surface.
4. **Run the same checks the repo runs** (locally or logically, if tooling is unavailable):
   - `swift-format -i --configuration .swift-format <changed files>`
   - `swiftlint lint --fix --config .swiftlint.yml <changed files>` and then
     `swiftlint lint --strict --config .swiftlint.yml <changed files>`
   - `swift test` (when `Package.swift` exists and Swift files changed)
   - `swift build -Xswiftc -warnings-as-errors` (same condition)
   - Coverage gate script, if present

If any check fails, **fix the code** (do not weaken rules).

---

## 5) Allowed exceptions (rare, documented, minimal)

- Temporary `swiftlint:disable` is allowed only when:
  - you include a one-line justification,
  - you scope it to the smallest region,
  - you add a TODO with a removal plan.
- Never disable: file length, function length, complexity, nesting, warnings-as-errors, or tests, unless the repo owner explicitly changed policy.

---

## 6) Output requirements for AI agents

When producing changes, you must include **three things**:

### 6.1 Exact scope statement
- **Intent**: one sentence.
- **Touched files**: explicit list.
- **Why each file was necessary**: one short bullet per file.

### 6.2 Minimality report
Before finalizing, answer:
- What is the *smallest* change that solves the problem?
- Did I modify any code unrelated to that change? (must be “no”)
- Did I introduce any formatting-only diff outside touched logic? (must be “no”)
- Did I increase public surface area? (must be “no”, unless required)
- Is there any alternative that touches fewer files? If yes, choose it.

### 6.3 Regression-proofing evidence
Provide:
- Which tests cover the change (or new tests you added).
- If no tests exist, what targeted safety net you added (small tests, assertions, invariants).

---

## 7) Mandatory reflection protocol (meta-prompt)

You must run this reflection **twice**: once before editing, once after editing.

### Pass A — Pre-edit (plan validation)
1. Restate the requirement in one sentence.
2. Identify the *single best seam* to change (type/function).
3. List the *minimum* files to touch.
4. List failure modes / regressions likely to occur.
5. Decide the smallest test(s) that would detect those regressions.

### Pass B — Post-edit (diff review)
1. Review the diff and delete anything not strictly required.
2. Re-check budgets (length/complexity/nesting). If near limits, refactor *locally*.
3. Confirm no stray formatting churn (imports, whitespace, reorder) beyond touched code.
4. Confirm no public API churn unless required.
5. Confirm tests: failing-before/passing-after (or best available safety net).

**Stop condition**: If you cannot honestly answer all items, do not output code; refactor until you can.

## 8) Keep this document reusable

This file is intentionally project-agnostic.

Repository-specific details belong in:
- `.swiftlint.yml`, `.swift-format`, CI, `Makefile`, and per-module READMEs.

When this document conflicts with repo tooling, **repo tooling wins**.
