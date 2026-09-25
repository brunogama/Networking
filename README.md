# Networking

Networking is a Swift 6 HTTP client built on `URLSession`. The `Networking` library
reexports the core, runtime, request builder, observability, server-sent event,
and compatibility interceptor modules. You can import those modules separately
when a target needs fewer dependencies.

The repository has two Swift packages. `Packages/Networking` contains the runtime
libraries. `Packages/NetworkingMacros` contains the optional API client macros.

---

## Add the package

Add the repository in Xcode's package dependency editor, or use Swift Package
Manager. This repository has no version tag yet, so use the `main` branch until
a release is published.

```swift
.package(url: "https://github.com/brunogama/Networking.git", branch: "main")
```

Add the `Networking` product to your app target. If you use the macros, add the
`NetworkingMacros` product as well.

---

## Make a request

```swift
import Foundation
import Networking

func fetchUsers() async throws -> HTTPResponse {
    guard let url = URL(string: "https://api.example.com/users") else {
        throw URLError(.badURL)
    }

    let request = HTTPRequest(method: .get, url: url)
    return try await NetworkClient().execute(request)
}
```

`NetworkClient` runs request middleware before the `URLSession` call, then runs
response middleware. It also passes failures to error middleware. The client
throws `HTTPError` for transport failures and HTTP error statuses.

The runtime package also includes authentication, retries, caching, file
transfers, progress reporting, and server-sent events. See the
[Networking documentation](Packages/Networking/Sources/Networking/Networking.docc/Networking.md)
for the available modules and guides.

---

## Build and test

Run development checks against each package directory. The root `Package.swift`
also declares products and targets for consumers, but package-specific checks
make it clear which package passed.

```bash
swift build --package-path Packages/Networking -Xswiftc -warnings-as-errors
swift test --package-path Packages/Networking
swift build --package-path Packages/NetworkingMacros -Xswiftc -warnings-as-errors
swift test --package-path Packages/NetworkingMacros
```

[Quick start](QUICKSTART.md) covers local setup. [Onboarding](ONBOARDING.md)
covers the repository layout and contribution checks.

---

## License

This project is available under the MIT license.
