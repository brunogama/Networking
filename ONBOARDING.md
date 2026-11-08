# Contributor onboarding

This repository contains two standalone Swift packages. The root `Package.swift`
also declares their products and targets for consumers. Work in
`Packages/Networking` for the HTTP client and `Packages/NetworkingMacros` for
API client macros.

---

## Find the code

| Area | Location |
| --- | --- |
| Request and response types | `Packages/Networking/Sources/NetworkingCore` |
| `NetworkClient` and middleware | `Packages/Networking/Sources/NetworkingRuntime` |
| Request builder | `Packages/Networking/Sources/NetworkingDSL` |
| Client builder convenience | `Packages/Networking/Sources/NetworkingRuntimeDSL` |
| Metrics and tracing | `Packages/Networking/Sources/NetworkingObservability` |
| Server-sent events | `Packages/Networking/Sources/NetworkingSSE` |
| Public macro declarations | `Packages/NetworkingMacros/Sources/NetworkingMacrosDeclarations` |
| Macro implementations | `Packages/NetworkingMacros/Sources/NetworkingMacros` |

Each package has tests under its own `Tests` directory. The umbrella
`Networking` product reexports runtime modules. The macro product is separate.

---

## Run the required checks

Read [RULES.md](RULES.md) and [AGENTS.md](AGENTS.md) before editing. Run the
commands for each package you change, from the repository root.

```bash
swift build --package-path Packages/Networking -Xswiftc -warnings-as-errors
swift test --package-path Packages/Networking
swift build --package-path Packages/NetworkingMacros -Xswiftc -warnings-as-errors
swift test --package-path Packages/NetworkingMacros
```

When you change a Swift file, pass its path explicitly to `swift-format` and
SwiftLint from the repository root. Replace the example path with each changed
Swift file.

```bash
swift-format -i --configuration .swift-format Packages/Networking/Sources/NetworkingCore/HTTPRequest.swift
swiftlint lint --fix --config .swiftlint.yml -- Packages/Networking/Sources/NetworkingCore/HTTPRequest.swift
swiftlint lint --strict --config .swiftlint.yml -- Packages/Networking/Sources/NetworkingCore/HTTPRequest.swift
```

Shared root configuration and scripts affect both packages. Run both build and
test sets after changing them. Do not edit generated files or `CHANGELOG.md` by
hand.

---

## Follow a request

`HTTPClient` in `NetworkingCore` defines the async execution contract.
`NetworkClient` in `NetworkingRuntime` applies request middleware, checks for a
cached response, calls `URLSession`, applies response middleware, and routes
errors through error middleware. The request builder in `NetworkingDSL` creates
`HTTPRequest` values for that client.

Start with [the client tests](Packages/Networking/Tests/NetworkingTests/NetworkClientTests.swift)
for a small example. For the public API, read the
[Networking documentation](Packages/Networking/Sources/Networking/Networking.docc/Networking.md).
