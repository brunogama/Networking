# Module Migration

Use this guide when you want to adopt the split package graph directly instead of relying only on
the `Networking` umbrella.

## Default Recommendation

Most downstream targets should continue to:

```swift
import Networking
```

The umbrella target re-exports the core runtime modules so existing consumer code can keep a single
import while the package graph is modernized underneath it.

## Package Map

Choose the smallest module set that matches the behavior you need:

- `NetworkingCore`: HTTP primitives, error types, and foundational contracts
- `NetworkingRuntime`: `NetworkClient`, auth, retry, caching, transfer, security, and middleware
- `NetworkingDSL`: request builders, typed requests, response pipelines, and transformations
- `NetworkingRuntimeDSL`: convenience bridges from `NetworkClient` into the DSL
- `NetworkingObservability`: generic metrics, tracing, and observability middleware
- `NetworkingObservabilityOTLP`: OTLP exporters and related OpenTelemetry integration
- `NetworkingTesting`: mocks, fakes, `MockURLProtocol`, and test helpers
- `NetworkingInterceptorsCompat`: compatibility-only interceptor APIs

## Common Import Sets

Typical feature target:

```swift
import NetworkingRuntime
import NetworkingDSL
import NetworkingRuntimeDSL
```

Observability-enabled target:

```swift
import NetworkingRuntime
import NetworkingDSL
import NetworkingRuntimeDSL
import NetworkingObservability
```

Testing target:

```swift
import Networking
import NetworkingTesting
```

## Compatibility Rules

- Keep `import Networking` as the default consumer-facing import during the migration.
- Prefer middleware for new runtime extension work.
- Treat `NetworkingInterceptorsCompat` as a legacy compatibility surface.
- Use `NetworkingTesting` for test doubles instead of expanding the public protocol surface.
- Add `NetworkingObservabilityOTLP` only when you actually need OTLP exporters.

## Public Protocol Notes

The refactor reviewed the previously broad protocol surface and kept only the protocols that still
act as real consumer extension seams:

- `RequestComponent` and `ResponseComponent` remain public because downstream modules can add custom
  request and response builder elements.
- `ConfigurationComponent` plus its auth/retry/caching/session specializations remain public
  because `NetworkClientBuilder` is designed to accept external configuration plugins.
- `ResponseProcessor` and `ResponseValidator` remain public because response pipelines can still be
  extended with consumer-defined processors and validators.
- `ScenarioStep`, `GivenStep`, `WhenStep`, and `ThenStep` remain public in `NetworkingBDD`
  because custom steps are a first-class BDD extension point.
- New testability work should prefer `NetworkingTesting` fakes and helpers over adding new public
  protocols to production modules.

## Migration Notes

If a target previously depended on the monolithic package for just request building and execution,
the smallest equivalent direct dependency is usually:

```swift
import NetworkingRuntime
import NetworkingDSL
import NetworkingRuntimeDSL
```

If the target only needs shared HTTP models and contracts, `NetworkingCore` is enough.
