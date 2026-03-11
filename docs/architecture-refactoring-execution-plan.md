# Architecture Refactoring Execution Plan

This document turns the target architecture in `docs/architecture-migration-plan.md` into an
execution plan. It adds the missing policy for public protocols, testability, package extraction,
and rollout sequencing.

## Goals

- Split the current `Networking` target into smaller, coherent packages.
- Keep downstream adoption simple by preserving `Networking` as a compatibility umbrella.
- Improve testability by introducing dedicated testing targets and narrow dependency seams.
- Avoid blanket protocolization of the public API.
- Remove optional subsystem dependencies from the base runtime.

## Non-Goals

- Rewriting the DSL or macro model from scratch.
- Removing the `Networking` umbrella in the first migration.
- Protocolizing every public type to satisfy mocking.
- Coupling `AgentOrchestration` into the networking runtime graph.

## Guiding Rules

1. Middleware is the canonical runtime extension model.
2. Interceptors become compatibility-only and stop receiving new feature work.
3. Protocols exist only for true substitution seams or compile-time marker semantics.
4. Concrete types remain concrete when the framework owns their lifecycle, behavior, or value
   semantics.
5. Testability comes from small injected seams plus a dedicated `NetworkingTesting` target, not
   from turning the entire public API into protocols.

## Public API Protocol Policy

Use the following decision rule for every public protocol:

1. Can an external consumer realistically provide their own implementation?
2. Are there at least two meaningful implementations now or in the near-term design?
3. Does the protocol express a true behavioral boundary rather than just shape?
4. Would a fake in `NetworkingTesting` solve the testing need without widening the public API?

If the answer to the first three questions is not clearly "yes", the surface should stay concrete
or become `internal`/package-scoped.

### Keep As Public Protocols

- `HTTPClient`
- `HTTPRequestMiddleware`
- `HTTPResponseMiddleware`
- `HTTPErrorMiddleware`
- `BearerTokenProvider`
- `CustomAuthProvider`
- `OrchestratedAgent` in the standalone orchestration package
- DSL marker protocols that encode compile-time constraints:
  - `HTTPMethodType`
  - `HTTPEnvironmentType`
  - `BodyAllowedMethod`

### Review For Possible Downgrade To Internal Or Package-Scoped

These should be audited before package extraction because they may be widening the public API
without providing a strong consumer-facing extension point:

- `RequestComponent`
- `ResponseComponent`
- `ConfigurationComponent`
- `AuthenticationComponent`
- `RetryComponent`
- `CachingComponent`
- `SessionComponent`
- `ResponseProcessor`
- `ResponseValidator`
- BDD step protocols that are currently living under the main package surface

### Keep Concrete

These should remain concrete unless a real product requirement appears:

- `NetworkClient`
- `HTTPRequest`
- `HTTPResponse`
- `HTTPError`
- request/response builder types
- configuration value types
- cache metadata and metrics value types
- test DSL value types

## Target Package Graph

The target graph remains the same as the migration design:

- `Networking`: compatibility umbrella
- `NetworkingCore`: HTTP primitives and foundational contracts
- `NetworkingRuntime`: concrete client runtime and middleware
- `NetworkingDSL`: request/response composition surface
- `NetworkingRuntimeDSL`: bridge extensions from runtime to DSL
- `NetworkingMacros`: public macro declarations and plugin implementation
- `NetworkingObservability`: generic observability interfaces and runtime middleware
- `NetworkingObservabilityOTLP`: OTLP-specific exporter integration
- `NetworkingTesting`: mocks, fakes, and testing helpers
- `NetworkingBDD`: BDD core, parser, reporting, and step abstractions
- `NetworkingBDDQuickSupport`: Quick/Nimble integration only

`AgentOrchestration` stays outside this graph. It can be included as a workspace package, but it
must not become a dependency of `NetworkingCore`, `NetworkingRuntime`, or `NetworkingDSL`.

## Workstream Plan

### Workstream 1: Inventory And Freeze

Objective: stop the architecture from drifting while the refactor is underway.

Tasks:

- Freeze new public protocols unless they satisfy the policy above.
- Freeze new interceptor-only features.
- Inventory all public declarations under `Packages/Networking/Sources/Networking`.
- Classify each declaration as one of:
  - foundational primitive
  - runtime implementation
  - DSL surface
  - macro declaration
  - observability
  - testing helper
  - BDD
  - compatibility-only
- Mark each public protocol as `keep`, `review`, or `internalize`.

Exit criteria:

- Every public type has a home in the target package graph.
- Every public protocol has an explicit rationale.
- No new feature work is landing on the old ambiguous seams.

### Workstream 2: Canonicalize The Runtime Extension Model

Objective: remove the dual-model ambiguity between middleware and interceptors.

Tasks:

- Update docs to name middleware as the recommended runtime extension path.
- Move concrete interceptor implementations into `NetworkingInterceptorsCompat`.
- Stop expanding interceptor-specific APIs.
- Add deprecation messaging where the API already implies parity with middleware.
- Ensure new runtime capabilities are implemented only once, in middleware.

Exit criteria:

- Middleware is the only path for new runtime behavior.
- Interceptors compile and remain available for compatibility, but they are visibly legacy.

### Workstream 3: Clean Up The Public Surface Before File Moves

Objective: simplify extraction by removing accidental API commitments first.

Tasks:

- Audit builder-related protocols and downgrade those that are not real extension seams.
- Split protocols that currently mix consumer extension points with internal assembly details.
- Move test-only abstractions out of the production package surface where possible.
- Preserve source compatibility with typealiases or deprecated shims when necessary.
- Separate DSL marker protocols from mocking-oriented abstractions in documentation.

Exit criteria:

- Public protocols are intentional and minimal.
- Package boundaries will reflect real ownership, not legacy exposure.

### Workstream 4: Extract Stable Foundation Modules

Objective: create the smallest stable base that other packages can depend on.

Tasks:

- Create `NetworkingCore`.
- Move HTTP primitives, error types, request/response models, status types, and foundational
  protocols into `NetworkingCore`.
- Create `NetworkingRuntime`.
- Move `NetworkClient`, auth, retry, caching, transfer, security, and runtime helpers into
  `NetworkingRuntime`.
- Create `NetworkingDSL`.
- Move request builders, typed request APIs, response chaining, and transformation code into
  `NetworkingDSL`.
- Create `NetworkingRuntimeDSL`.
- Split `RequestBuilderExtensions.swift` so runtime-specific `NetworkClient` conveniences land in
  `NetworkingRuntimeDSL`.
- Convert `Networking` into an umbrella target that re-exports the split modules.

Exit criteria:

- `NetworkingCore` builds independently.
- `NetworkingRuntime` builds on top of `NetworkingCore`.
- `NetworkingDSL` builds on top of `NetworkingCore`.
- `Networking` builds as a compatibility umbrella with a small target surface.

### Workstream 5: Extract Optional Subsystems

Objective: stop optional features from inflating the base runtime.

Tasks:

- Move public macro declarations out of the runtime target and into `NetworkingMacros`.
- Keep macro implementation code in the plugin target.
- Create `NetworkingObservability` for generic observability APIs and middleware.
- Create `NetworkingObservabilityOTLP` for OpenTelemetry-specific exporters.
- Create `NetworkingTesting` for mocks, fakes, `MockURLProtocol`, and related helpers.
- Create `NetworkingBDD` for parser, reporting, steps, and type-safe scenario support.
- Create `NetworkingBDDQuickSupport` for Quick/Nimble integrations only.

Exit criteria:

- The base runtime no longer depends on OpenTelemetry, Quick, or Nimble.
- Macro declarations are no longer owned by the runtime package.
- Testing helpers are available without polluting the main production surface.

### Workstream 6: Re-Home Tests By Package Ownership

Objective: make test layout reinforce the new architecture.

Tasks:

- Create package-local test targets:
  - `NetworkingCoreTests`
  - `NetworkingRuntimeTests`
  - `NetworkingDSLTests`
  - `NetworkingInterceptorsCompatTests`
  - `NetworkingObservabilityTests`
  - `NetworkingTestingTests`
  - `NetworkingBDDTests`
  - `NetworkingMacrosTests`
- Move each existing test to the smallest package that owns the behavior under test.
- Add smoke tests for the `Networking` umbrella to validate re-export compatibility.
- Add tests that prove consumer-level scenarios still work after the split.

Exit criteria:

- Tests can be run package-by-package.
- Test failures localize to the package that owns the broken behavior.
- Downstream compatibility remains covered.

### Workstream 7: Build A Dedicated Testing Architecture

Objective: improve testability without forcing protocol expansion.

Tasks:

- Define the supported fake seams in `NetworkingTesting`.
- Prefer concrete fakes and lightweight adapters over new public protocols.
- Provide test helpers for:
  - fake `HTTPClient`
  - fake auth/token providers
  - mock request/response/error middleware
  - cache storage test doubles
  - tracing and metrics test doubles
  - time/retry helpers if needed
- Document the testing strategy:
  - use real concrete value types first
  - use protocol-based fakes only at the approved seams
  - avoid mocking builders, models, and configuration values

Exit criteria:

- Common test cases no longer require downstream teams to create their own ad hoc mock surface.
- New protocol requests must justify why a test helper target is insufficient.

### Workstream 8: Compatibility, Migration, And Cleanup

Objective: land the refactor without breaking consumers unnecessarily.

Tasks:

- Keep `Networking` as the primary consumer-facing import during the first release.
- Re-export new modules from the umbrella package.
- Add deprecations for compatibility-only interceptor APIs and any downgraded public protocols.
- Write migration docs for advanced users who want to depend on smaller packages directly.
- Remove transitional files once the split stabilizes.
- Decide whether `AgentOrchestration` is:
  - a first-class optional workspace package, or
  - an experimental package that stays out of the main release story

Exit criteria:

- Existing users can continue importing `Networking`.
- Advanced users can adopt narrower dependencies intentionally.
- Compatibility-only APIs have a visible deprecation path.

## Suggested PR Sequence

Keep the rollout in small, reviewable steps:

1. Doc-only PR: protocol policy, package map, and migration rules.
2. Public-surface cleanup PR: downgrade or isolate accidental protocols.
3. Middleware/interceptor PR: canonicalize extension model.
4. `NetworkingCore` + `NetworkingRuntime` extraction PR.
5. `NetworkingDSL` + `NetworkingRuntimeDSL` extraction PR.
6. `NetworkingMacros` declaration move PR.
7. Observability extraction PR.
8. Testing extraction PR.
9. BDD extraction PR.
10. Umbrella cleanup and migration-doc PR.

## Validation Matrix

Every phase should be validated with the smallest meaningful command set:

- `swift build --target NetworkingCore`
- `swift build --target NetworkingRuntime`
- `swift build --target NetworkingDSL`
- `swift build --target Networking`
- package-local `swift test` runs for each extracted package
- umbrella compatibility smoke tests

Before the full migration is considered complete:

- `swift build -Xswiftc -warnings-as-errors`
- `swift test`

## Key Risks

- Overexposing protocols now and being forced to support them forever.
- Letting testing concerns drive the production API instead of using a dedicated testing package.
- Keeping Quick/Nimble or OpenTelemetry dependencies in the base runtime by accident.
- Moving files before the protocol policy is settled, which creates rework across packages.
- Coupling `AgentOrchestration` into the networking stack and muddying ownership boundaries.

## Definition Of Done

The refactor is complete when all of the following are true:

- `Networking` is a thin compatibility umbrella.
- `NetworkingCore`, `NetworkingRuntime`, and `NetworkingDSL` compile independently.
- Optional subsystems are extracted and no longer inflate the base runtime.
- Public protocols are narrow, intentional, and documented.
- Testing uses a dedicated `NetworkingTesting` package instead of protocolizing value surfaces.
- Interceptors are isolated as compatibility-only APIs.
- Downstream users can stay on `import Networking` or adopt narrower modules by choice.
