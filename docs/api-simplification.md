# API simplification

This is a breaking redesign. Applications should compose ordinary Swift values
and inject reusable dependencies at their composition root.

---

## Removed surface and replacements

| Removed | Replacement |
| --- | --- |
| `NetworkingDSL`, request builders and operators | `HTTPRequest(method:url:headers:body:)` |
| `NetworkingRuntimeDSL`, `NetworkClientBuilder` | `NetworkClient.Configuration` and `HTTPMiddleware` |
| `NetworkingInterceptorsCompat` | Request, response, and error middleware protocols |
| `NetworkingBDD` | Swift Testing with real client or isolated mock transport |
| `BatchRequestBuilder` and `batch {}` | `executeBatch([request1, request2])` |
| Circuit breaker and duplicate retry strategies | One explicit `RetryMiddleware` |
| Error advice, recovery categories, processors and reports | `HTTPError.Category` and application-owned decisions |
| Simulated transfer pause/resume controls | Real transport cancellation and existing file transfer APIs |
| Legacy analytics, timers and synthetic metric events | `NetworkDiagnostics` and completed request metrics |
| OTLP background scheduling and flush configuration | Awaited export with observable delivery errors |
| Mock result builders and sequential mock DSL | Direct mock expectations or URLProtocol stubs |
| `@Interceptors`, `@Cacheable`, `@Measured`, header builders | Explicit middleware and typed header dictionaries |
| Dormant macro generators and MacroTemplateKit dependency | The active SwiftSyntax generators |
| Hard-coded intelligent prefetch and preload patterns | Explicit caller-owned prefetch and bounded cache warming |
| Mutable mock expectation builders | One actor-isolated `expect(matching:response:calls:capture:)` registration |
| Duplicate progress streams, completion-only middleware, and inert chunking descriptors | Await `execute` for completion; use native file-transfer callbacks for byte progress |
| `CachingMiddleware.CacheStorage` | `HTTPResponseCacheStorage` |
| `TraceSpan.Snapshot` | `TraceSpanSnapshot` |
| `HTTPError.SecurityError` | `HeaderSecurityError` |
| TLS version cases `v1_2` and `v1_3` | `tls12` and `tls13` |

The native SwiftUI inspector retains SwiftUI's own view-building syntax.

Each source-declared nominal type has its own file. Nested declarations live in
extensions when their qualified name remains useful, with at most two nested
types per owner. A type alias names an existing type; it does not introduce a
new runtime representation. Unused boundary aliases and their phantom markers
have been removed, while active domain distinctions remain.

---

## Reuse without global mutable configuration

Construct `JSONCodec(configuration:)` once and inject it into generated client
factories. The same codec can encode and decode concurrently under Foundation's
Sendable contract. Custom coding closures must also support concurrent calls.
Disk cache storage and diagnostics own reusable codecs for their own formats.

Construct one `KeychainService` for the relevant service/access group and inject
it into token providers. This shares the service object without retaining secret
values between reads. Sharing an actor does not coordinate independent actors or
other processes writing to Keychain.

Mutable asynchronous test doubles are actors. Configure and inspect them using
`await`; expectation registration is atomic. Immutable clients, codecs, and
providers remain shared values or immutable classes. URLSession/URLProtocol
delegates and cancellation handlers retain synchronous bridges with synchronized
storage because their callbacks cannot suspend.

---

## State and cancellation

Use noncopyable request tickets where consuming the result or cancellation
capability prevents an actual misuse. Do not add phantom states to ordinary data
that cannot make an illegal transition.

Batch execution and cache warming use bounded task groups. Direct prefetch runs
within the caller's task. This checkout does not contain an `AsyncMemoizer` or a
property-wrapper cache. Introducing shared request flights requires a separate
contract for cancellation, freshness, identity, and authorization isolation.

---

## Cache simplification

Straightforward guards describe restoration failures without a custom
`CachePipeline`. Collection operations are useful for querying and accumulating;
ordinary loops remain appropriate for deletion and eviction. Cache storage
reuses coders and batches metadata writes.

Cache partitioning must include representation and authorization inputs. A URL
alone cannot distinguish authenticated responses. Invalidation must also account
for work suspended in another actor or transport operation.

---

## Security boundaries

Multiple certificate hashes are alternatives for certificate rotation. Allowing
non-leaf certificate matches is a separate choice. If certificate and public-key
policies both apply, both policies are evaluated. Pinning settings still need to
be reviewed alongside normal hostname and trust-chain validation.

TLS protects HTTP headers and bodies in transit. Arbitrary header encryption
would break routing and authentication protocols. Application payload encryption
is intentionally not added without a server protocol, key management, and replay
protection requirements.

Primary references consulted using Firecrawl:

- [Apple identity pinning guidance](https://developer.apple.com/news/?id=g9ejcf8y).
- [TLS 1.3](https://www.rfc-editor.org/rfc/rfc8446).
- [HTTP field grammar](https://www.rfc-editor.org/rfc/rfc9110).
- [HTTP caching and Vary](https://www.rfc-editor.org/rfc/rfc9111).
- [JSON Web Encryption](https://www.rfc-editor.org/rfc/rfc7516).
