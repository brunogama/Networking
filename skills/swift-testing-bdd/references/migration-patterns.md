# Swift Testing BDD Migration Patterns

## Table of contents

- Quick and Nimble to Swift Testing mapping
- Default suite layout
- Given, When, Then structure
- Scenario outlines with parameterized tests
- Shared behaviors without shared examples
- Async and eventual assertions
- Setup and teardown
- Focus, pending, and execution control
- Matcher replacement cheat sheet
- Anti-patterns

## Quick and Nimble to Swift Testing mapping

| Quick or Nimble construct | Swift Testing pattern |
| --- | --- |
| `describe("...")` | `@Suite("...")` |
| `context("...")` | nested `@Suite("...")` |
| `it("...")` | `@Test("...")` |
| `beforeEach` | stored properties, suite `init()`, or a fixture factory |
| `afterEach` | lexical cleanup with `defer`, or `deinit` in an instance-based `final class` or `actor` suite |
| `beforeSuite` | no direct built-in hook; prefer explicit shared harnesses only when truly necessary |
| `afterSuite` | no direct built-in hook; prefer explicit harness shutdown or eliminating shared mutable suite state |
| `aroundEach` | helper function that wraps the action and cleanup around a closure |
| `sharedExamples` | helper assertion functions plus `@Test(arguments: ...)` when data varies |
| `expect(value).to(equal(x))` | `#expect(value == x)` |
| `expect(value).toNot(beNil())` | `let value = try #require(value)` or `#expect(value != nil)` |
| `expect { try f() }.to(throwError())` | `#expect(throws: ...) { try f() }` or `await #expect(throws: ...) { try await f() }` |
| `waitUntil` | prefer `async` and `await`; otherwise `await confirmation(...)` |
| `toEventually(...)` | await the asynchronous state change directly, or use `confirmation(...)` for pushed events |
| `fit`, `fdescribe`, `fcontext` | local runner filtering or temporary tags, not committed syntax |
| `xit`, `xdescribe`, `xcontext` | `.disabled("reason")` on the test or suite |
| shared mutable suite execution assumptions | `.serialized` at suite or test scope |

## Default suite layout

Use nested suites for the BDD narrative and keep the actual assertions inside tests.

```swift
import Testing

@Suite("NetworkClient")
struct NetworkClientBehaviorTests {
  @Suite("when the request succeeds")
  struct RequestSucceeds {
    let client = MockNetworkClient()

    @Test("returns the response with the correct status")
    func returnsResponseStatus() async throws {
      // Given
      let requestURL = try #require(URL(string: "https://api.example.com/users"))
      let request = HTTPRequest(method: .get, url: requestURL)
      client.stubGET(path: "/users", response: Data("success".utf8))

      // When
      let response = try await client.execute(request)

      // Then
      #expect(response.status == .ok)
    }
  }

  @Suite("when the network is unavailable")
  struct NetworkUnavailable {
    @Test("throws a not connected error")
    func throwsNotConnectedError() async throws {
      let client = MockNetworkClient()
      let requestURL = try #require(URL(string: "https://api.example.com/offline"))
      let request = HTTPRequest(method: .get, url: requestURL)

      client.expectGET("/offline")
        .andReturnError(URLError(.notConnectedToInternet))

      await #expect(throws: URLError.self) {
        _ = try await client.execute(request)
      }
    }
  }
}
```

Use this pattern when the hierarchy itself carries meaning. The suite path should read like prose in test output.

## Given, When, Then structure

Do not create a new DSL for Given, When, Then unless the codebase already has one that is clearly established. In most cases, comments or tiny local helpers are enough:

```swift
@Test("adds the Authorization header")
func addsAuthorizationHeader() async throws {
  // Given
  let client = MockNetworkClient()
  let requestURL = try #require(URL(string: "https://api.example.com/protected"))
  var request = HTTPRequest(method: .get, url: requestURL)
  request.headers["Authorization"] = "Bearer test-token"

  client.expectGET("/protected")
    .withHeader("Authorization", value: "Bearer test-token")
    .andReturn(.success(statusCode: 200, data: Data()))

  // When
  let response = try await client.execute(request)

  // Then
  #expect(response.status == .ok)
}
```

Follow these rules:

- Keep Given focused on fixture creation and stubbing.
- Keep When to one action when possible.
- Keep Then to observable outcomes.
- If Then becomes repetitive, extract helper assertions such as `assertAuthorized(_:)`.

## Scenario outlines with parameterized tests

Use parameterized tests when the scenario skeleton stays the same and only the data changes.

```swift
import Testing

struct StatusExample: Sendable, Encodable {
  let code: Int
  let expectedCategory: HTTPStatus.Category
}

@Test(
  "maps HTTP status to the correct category",
  arguments: [
    StatusExample(code: 200, expectedCategory: .success),
    StatusExample(code: 404, expectedCategory: .clientError),
    StatusExample(code: 500, expectedCategory: .serverError),
  ]
)
func mapsStatus(_ example: StatusExample) {
  let status = HTTPStatus(rawValue: example.code)
  #expect(status.category == example.expectedCategory)
}
```

Guidelines:

- Prefer an explicit example type when the case has more than one field.
- Make argument types `Encodable`, `RawRepresentable`, or otherwise selectable when you want to re-run individual cases easily.
- Avoid large Cartesian products unless that breadth is intentional.
- If cases share mutable global state, add `.serialized` or redesign the fixture.

## Shared behaviors without shared examples

Quick's shared examples usually combine two concerns: common setup and common assertions. Separate them in Swift Testing.

Use helper assertions for the invariant behavior:

```swift
func assertBehavesLikeSuccessfulUserFetch(
  _ response: HTTPResponse,
  expectedID: Int,
  expectedName: String
) throws {
  #expect(response.status == .ok)
  let body = try #require(response.body)
  let user = try JSONDecoder().decode(User.self, from: body)
  #expect(user.id == expectedID)
  #expect(user.name == expectedName)
}
```

Use fixtures or factories for common setup:

```swift
enum FixtureError: Error {
  case invalidURL(String)
}

struct Fixture {
  let client = MockNetworkClient()

  func makeRequest(path: String) throws -> HTTPRequest {
    guard let url = URL(string: "https://api.example.com\(path)") else {
      throw FixtureError.invalidURL(path)
    }

    return HTTPRequest(method: .get, url: url)
  }
}
```

Then call them from multiple tests or parameterized cases. This keeps the shared logic in normal Swift code instead of a special-purpose test DSL.

## Async and eventual assertions

Prefer direct concurrency over polling or callback wrappers:

```swift
@Test("refreshes the token before retrying")
func refreshesTokenBeforeRetrying() async throws {
  let client = TokenRefreshingClient()
  let result = try await client.executeProtectedRequest()
  #expect(result.status == .ok)
}
```

When the code under test produces pushed events or callbacks that cannot be awaited directly, use confirmations:

```swift
@Test("emits a sold food event")
func emitsSoldFoodEvent() async {
  await confirmation("sold food event received") { soldFood in
    FoodTruck.shared.eventHandler = { event in
      if case .soldFood = event {
        soldFood()
      }
    }

    await Customer().buy(.soup)
  }
}
```

Guidelines:

- Prefer `async` API conversion over `waitUntil`.
- Keep the async work that triggers the event inside the `confirmation` closure. The confirmation must happen before that closure returns.
- Use `confirmation(expectedCount:)` when the event count matters.
- When the old test expressed eventual truth with timeout-based polling, use an explicit retry or polling helper instead of mechanically replacing it with `confirmation(...)`.
- Use `await #expect(throws: ...)` for async error assertions.
- Use `withKnownIssue(...)` only for documented, tracked exceptions to expected behavior.

## Setup and teardown

Use a `struct` suite when setup is enough:

```swift
@Suite("Authenticated requests")
struct AuthenticatedRequestTests {
  let token = "test-token"
  let client: MockNetworkClient

  init() {
    client = MockNetworkClient()
  }

  @Test("include the bearer token")
  func includeBearerToken() async throws {
    // ...
  }
}
```

Swift Testing creates a fresh suite instance for each instance test method. That makes stored properties and `init()` a good replacement for `beforeEach`.

If teardown is necessary, use a `final class` or `actor` suite and implement `deinit`:

```swift
@Suite(.serialized)
final class TemporaryDirectoryTests {
  let temporaryDirectory: URL

  init() throws {
    temporaryDirectory = try FileManager.default.url(
      for: .itemReplacementDirectory,
      in: .userDomainMask,
      appropriateFor: URL(fileURLWithPath: NSTemporaryDirectory()),
      create: true
    )
  }

  deinit {
    try? FileManager.default.removeItem(at: temporaryDirectory)
  }
}
```

Use teardown sparingly. Most migrated BDD tests should keep setup local and rely on scope-based cleanup.

`deinit` is only relevant for instance-based class or actor suites. For free functions, static tests, or one-off resource cleanup, use `defer` inside the test or helper that allocated the resource.

## Lifecycle hooks without a direct replacement

Quick lifecycle hooks do not all map 1:1 to Swift Testing:

- `beforeSuite` and `afterSuite`: Swift Testing does not provide a built-in suite-wide once-before or once-after hook. Prefer removing shared mutable suite state. If expensive shared setup is unavoidable, make it explicit in a harness type and isolate it carefully, usually with `.serialized`.
- `aroundEach`: express it as a helper that wraps setup, action, and cleanup around a closure.

Example:

```swift
func withTemporaryDirectory<T>(
  _ body: (URL) async throws -> T
) async throws -> T {
  let directory = FileManager.default.temporaryDirectory
    .appendingPathComponent(UUID().uuidString)

  try FileManager.default.createDirectory(
    at: directory,
    withIntermediateDirectories: true
  )
  defer { try? FileManager.default.removeItem(at: directory) }

  return try await body(directory)
}
```

Use it from a test like this:

```swift
@Test("writes the export file")
func writesExportFile() async throws {
  try await withTemporaryDirectory { directory in
    let exportURL = directory.appendingPathComponent("export.json")
    // exercise code under test
    #expect(FileManager.default.fileExists(atPath: exportURL.path))
  }
}
```

## Focus, pending, and execution control

Translate execution-control features deliberately:

- Pending or skipped examples: `@Test(.disabled("reason"))`
- Pending or skipped contexts: `@Suite(.disabled("reason"))`
- Conditional execution: `.enabled(if: ...)` or `.disabled(if: ...)`
- Shared-state hazards: `.serialized`

Do not encode permanent focus markers in committed tests. Use test runner selection, IDE filtering, or temporary tags for local work.

## Matcher replacement cheat sheet

Prefer direct expressions over matcher wrappers:

| Nimble style | Swift Testing style |
| --- | --- |
| `expect(value).to(equal(expected))` | `#expect(value == expected)` |
| `expect(value).toNot(equal(unexpected))` | `#expect(value != unexpected)` |
| `expect(value).to(beNil())` | `#expect(value == nil)` |
| `expect(value).toNot(beNil())` | `let value = try #require(value)` |
| `expect(collection).to(contain(item))` | `#expect(collection.contains(item))` |
| `expect(flag).to(beTrue())` | `#expect(flag)` |
| `expect(flag).to(beFalse())` | `#expect(!flag)` |
| `expect(error).to(matchError(expected))` | `#expect(error == expected)` when equatable, otherwise inspect specific fields |
| `fail("message")` | `Issue.record("message")` |

When a matcher expresses domain language more clearly than a raw boolean, write a helper assertion function:

```swift
func assertSuccessful(_ response: HTTPResponse) {
  #expect(response.status.isSuccess)
  #expect(response.error == nil)
}
```

That keeps the language meaningful without rebuilding Nimble.

## Anti-patterns

Avoid these migration mistakes:

- Recreating `expect(...).to(...)` as a custom wrapper around `#expect`.
- Converting every `describe` and `context` into huge test names instead of nested suites.
- Keeping mutable suite-wide state without accounting for parallel execution.
- Hiding parameterized cases inside loops where failures cannot identify the input clearly.
- Using `Issue.record(...)` where `#expect` or `#require` would express the requirement directly.
- Porting `waitUntil` mechanically when the code can be made `async`.
- Using `.serialized` on every suite instead of only where ordering or isolation is required.
