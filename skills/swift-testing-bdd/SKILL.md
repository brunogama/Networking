---
name: swift-testing-bdd
description: Write or migrate behavior-driven tests in Swift using the Swift Testing framework instead of Quick and Nimble. Use when a Swift package or Xcode test target needs BDD-style structure, Given/When/Then scenarios, nested contexts, scenario outlines, shared examples, or matcher-heavy Quick/Nimble specs converted to `@Suite`, `@Test`, `#expect`, `#require`, parameterized tests, confirmations, and traits.
---

# Swift Testing BDD

Use this skill to preserve BDD readability while removing Quick and Nimble. Express `describe/context/it` with native Swift Testing constructs instead of rebuilding a matcher DSL.

## Workflow

1. Read the existing test and identify:
   - the feature or subject under test
   - the contexts or scenarios
   - setup and teardown requirements
   - suite-wide lifecycle hooks such as `beforeSuite`, `afterSuite`, or `aroundEach`
   - shared examples or example tables
   - Nimble matchers, async waits, and focus or pending markers
2. Choose the Swift Testing structure that matches the behavior:
   - `describe` and `context` become nested suite types annotated with `@Suite("...")`
   - `it` becomes `@Test("...")`
   - `beforeEach` becomes stored properties, a zero-argument `init()`, or a fixture factory
   - `afterEach` becomes lexical cleanup such as `defer`, or `deinit` in an instance-based `final class` or `actor` suite when teardown is required
   - `beforeSuite` and `afterSuite` have no direct built-in replacement; prefer explicit shared harnesses only when truly unavoidable
   - `aroundEach` becomes a helper that wraps the action under test and performs cleanup with `defer`
   - `sharedExamples` and scenario outlines become helper assertions plus `@Test(arguments: ...)`
3. Replace assertions with native Swift Testing:
   - value and state checks: `#expect(...)`
   - required values and unwrapping: `try #require(...)`
   - error assertions: `#expect(throws: ...)` or `await #expect(throws: ...)`
   - callback or event delivery: prefer `async` and `await`; otherwise use `await confirmation(...)`
   - unconditional failure branches: `Issue.record(...)`
4. Re-check execution semantics before finalizing:
   - tests and parameterized cases run in parallel by default
   - add `.serialized` only when shared mutable state or external resources require it
   - use `.disabled(...)`, `.enabled(if: ...)`, and existing tags when migration needs runtime gating
5. Clean up the result:
   - make the suite and test display strings read like prose
   - keep Given, When, Then in comments or tiny local helpers inside the test body
   - prefer plain Swift expressions and focused helpers over custom matcher wrappers

## Default Patterns

- Annotate suite types with `@Suite` even though Swift Testing can discover test-containing types without it. `@Suite` gives explicit naming and trait inheritance.
- Prefer `struct` suites. Switch to `final class` or `actor` only when teardown in `deinit` or reference semantics are necessary.
- Use instance test methods when you want fresh per-test state. Swift Testing creates a distinct suite instance for each instance test.
- Use nested suites to represent contexts, not nested `if` statements or giant test names.
- Keep each `@Test` focused on one observable behavior.
- Use descriptive strings in `@Suite("...")` and `@Test("...")`; keep function names short and implementation-oriented.
- Use parameterized tests for data variation. Do not hide multiple cases inside a `for` loop unless the loop itself is the behavior under test.
- If you need reusable behavior checks, extract helper functions that assert domain facts. Do not re-create Nimble's matcher syntax.

## Decision Rules

- If the original Quick spec is mostly `describe/context/it`, model that hierarchy with nested suites.
- If the original spec varies mainly by inputs and expected outputs, collapse it into one parameterized test.
- If the original spec uses `sharedExamples`, extract a helper such as `assertBehavesLikeCachedResponse(...)` and call it from multiple tests or parameterized cases.
- If the original spec uses `waitUntil` or `toEventually`, convert the production API to `async` first when feasible. Use confirmations only for pushed events or callback-driven code, and keep the triggering async work inside the `confirmation` scope so the event arrives before that closure returns.
- If the migrated suite touches globals, singletons, temp files, clocks, or network ports, add `.serialized` at the narrowest scope that fixes the hazard.
- If the original Quick suite used focused tests like `fit` or `fdescribe`, do not encode that permanently in the migrated test. Use local runner filtering or temporary tags instead.

## Reference

Read [migration-patterns.md](references/migration-patterns.md) when:

- converting Quick or Nimble constructs
- choosing between nested suites and parameterized tests
- mapping `beforeEach`, `afterEach`, `waitUntil`, or `toEventually`
- replacing matcher-heavy assertions with `#expect` and helper functions
