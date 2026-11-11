# Refactor validation

Validated locally on 2026-11-07 with Xcode 27.3 beta, Swift 6.4.2,
SwiftLint 0.63.2, and SourceKitten 0.38.0 on macOS arm64.
This report covers the authorized API pruning, actor review, and type extraction.

---

## Changes

Mutable asynchronous mocks now use actor isolation: `MockNetworkClient`,
`MockBearerTokenProvider`, and the three mock middleware implementations.
The file-transfer test client is also an actor. Expectation registration is one
atomic operation; behavior is captured before suspension without stale writes
after an `await`.

Immutable clients, codecs, and providers remain immutable classes. Synchronous
URLSession/URLProtocol callbacks and cancellation handlers retain synchronized
bridges. Replacing those bridges with actors would require asynchronous handoffs
and change callback ordering or cancellation semantics.

SourceKitten inspected 722 Swift files, including consumer fixtures and excluding
manifests, dependencies, and build output. It found 497 nominal declarations:
zero files with multiple nominal declarations, zero owners with more than two
nested nominal declarations, and zero structure-query failures. Nested types
retain their qualified names through extensions in separate files. Aliases name
existing types and are not counted as new nominal declarations. Macro-generated
declarations are verified through expansion and consumer compilation separately.

Unused aliases, phantom markers, internal forwarding helpers, builders, legacy
compatibility layers, and the other authorized excess were removed. Active
domain distinctions remain. See [API migration](api-simplification.md) for the
removed products and their replacements.

| Package Swift sources | Before | After |
| --- | ---: | ---: |
| Production files | 285 | 575 |
| Production physical lines | 44,229 | 14,812 |
| Test files | 114 | 140 |
| Test physical lines | 27,459 | 10,662 |

Production lines decreased 66.5%; tests decreased 61.2%. These counts include
comments and blank lines. The baseline is the saved working-tree snapshot before
this pruning pass, including the user's previously approved work, not Git HEAD.
File counts increase because retained types now have separate files. These are
size measurements, not runtime performance measurements.

Regression fixes include stale token refresh after logout/replacement, cache
isolation and invalidation, URLProtocol cancellation, native download size and
middleware handling, bounded concurrent uploads with joined progress delivery,
SSE event-ID handling, and escaped endpoint paths in generated Swift.

---

## Validation

All Swift builds and tests were serialized. No external paid services or real
application credentials were used by the tests.

| Command or check | Result |
| --- | --- |
| `swift build --build-system native -v -Xswiftc -warnings-as-errors` after `swift package clean` | PASS; zero source diagnostics |
| `swift build --package-path Packages/NetworkingMacros --build-system native -v -Xswiftc -warnings-as-errors` after package clean | PASS; zero source diagnostics |
| `swift test --package-path Packages/Networking --filter "$(cat /tmp/networking-final-focused-filter.txt)" -Xswiftc -warnings-as-errors` | PASS; 137 XCTest cases and 235 Swift Testing tests |
| `swift test --package-path Packages/NetworkingMacros -Xswiftc -warnings-as-errors` | PASS; 27 tests |
| `swift test --package-path Fixtures/NetworkingConsumer -Xswiftc -warnings-as-errors` | PASS; 3 tests |
| `swift test --package-path Fixtures/ExtensionConsumer -Xswiftc -warnings-as-errors` | PASS; 2 tests, including a public generated factory across module boundaries |
| `bash scripts/swift-style check --all` | PASS |
| Explicit-file `swift-style fix` and final `check` | PASS; final check covered 690 edited Swift files |
| `xcrun swift-format lint --strict --configuration .swift-format` with explicit manifest and consumer paths | PASS |
| `sourcekitten structure --file <path>` for each scoped Swift file | PASS; structural counts above |
| `xcrun swiftc -swift-version 6 -warnings-as-errors -I .build/arm64-apple-macosx/debug/Modules -c <fixture>` | PASS; valid ticket usage compiled; duplicate consumption and pending-phase response access failed with the expected diagnostics |
| `bash scripts/swift-style-analyze /tmp/networking-final-compiler.log` | FAIL; 18 retained findings and four internal macro-indexing errors, detailed below |
| `bash scripts/generate-llms-txt.sh` | PASS; 474 library-owned declarations/macros; repeated generation produced byte-identical output |
| `git diff --check` | PASS |

The focused runtime filter covers domain values, codecs, client configuration,
middleware, response limits, mocks, authentication, Keychain, certificate
pinning, request tickets, retries, caches, batching, transfers, tracing, metrics,
OTLP, and SSE. It does not run the entire repository test suite.

The clean compiler log concatenates the actual verbose root and macro build
logs; no compiler commands were fabricated. SwiftPM emits a deprecation notice
for its native build backend. Normal tests also passed using the default backend.

The path-literal regression first failed during compilation, then passed while
asserting the exact encoded URL containing a quote, backslash, and interpolated
identifier. The SSE overflow test now waits for a terminal diagnostics event
before consuming the stream instead of sleeping to guess when buffering ends.

---

## Remaining issues and coverage limits

The analyzer rerun reduced 197 findings to 18 and still exited with status 2:

- Three package helpers have real test callers: `TaggedValue.contains`, tagged
  `<` against a raw value, and tagged `>=` against a raw value. The gate collects
  production files, so those test references are outside its input.
- Native `NetworkClient.upload` and `download` implement `HTTPFileTransferClient`
  requirements and are invoked through that protocol in file-transfer operations.
- Ten public macro declarations are exercised by compiled macro and consumer
  tests. Indexing their four declaration files also reports
  `DecodingError.dataCorrupted` with an unexpected end of JSON input.
- Three conditional `OSLog`/`Network` imports are retained beside their explicit
  `Logger`, `OSLogType`, and `tls_protocol_version_t` uses. Analyzer probes also
  emit unavailable `FoundationNetworking` errors from guarded imports; the
  actual clean compiler builds succeed.

The analyzer is not reported as passing. No suppressions or policy changes were
added to conceal findings, and required APIs were not deleted to satisfy the
scan. Twenty-five preexisting suppression lines remain, down from 180 in the
saved baseline; ordinary style checks honor those existing exceptions.

Validation is local macOS evidence. iOS, tvOS, watchOS, Linux, and hosted CI were
not run. The existing CI configuration still selects Xcode 16.4 while the local
style configuration requires Xcode 27.3; this report does not claim CI passes.
The native inspector's visual presentation was not exercised.

Keychain coordination applies to a shared service actor, not independent
processes. Disk caches must not share a directory between independent actors.
Cache invalidation cannot identify a network operation that entered response
middleware only after invalidation without an operation identity in that
protocol. Native download limits can overshoot by a transport chunk.

Canonical README, migration guidance, and package `Networking.docc` were updated.
Older generated project-overview material and legacy onboarding guides were not
treated as current API references. Generated files are changed only through
their generators. No commits or pushes were made.

Local evidence is in `/tmp/networking-final-*.log`,
`/tmp/networking-sourcekitten-final-summary.json`,
`/tmp/networking-final-size-counts.json`, and
`/tmp/networking-ticket-compile-checks/`.
