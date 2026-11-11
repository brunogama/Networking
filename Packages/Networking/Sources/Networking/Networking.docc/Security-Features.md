# Security Features

Configure TLS trust, certificate rotation, and credential ownership explicitly.

---

## Certificate rotation

Certificate hashes are alternatives within one pinning policy. Provision the
current and replacement certificate hashes before switching the server, then
remove the retired hash after the intended client rollout.

```swift
import Networking

func pinnedClient(current: CertificateHash, replacement: CertificateHash) -> NetworkClient {
  let pins = CertificatePinningConfiguration(
    pinnedCertificateHashes: [current, replacement],
    domains: ["api.example.com"],
    allowBackupCertificates: false,
    validationFailureAction: .reject
  )
  let security = SecurityConfiguration(certificatePinning: pins)
  let session = SessionConfiguration().createURLSession(securityConfiguration: security)
  return NetworkClient(session: session)
}
```

Certificate hashes are lowercase hexadecimal SHA-256 digests of DER certificate
data. `allowBackupCertificates` controls whether a non-leaf certificate in the
presented chain may satisfy a pin. It does not control whether the configured
set can contain both current and future leaf pins.

Public-key pinning uses SHA-256 hashes of SubjectPublicKeyInfo (SPKI), also in
lowercase hexadecimal form. It can retain the same pin across certificate
renewal when the public key is unchanged. If certificate and public-key policies
both apply, both are evaluated. Domains match configured host names
case-insensitively; these sets are not wildcard-domain rules.

Keep chain and hostname validation enabled. A matching pin is an additional
constraint, not a replacement for those checks. `.warn` and `.allow` fall back
to URLSession's default trust handling when a pin fails, so they do not enforce
pinning. Setting `requirePinnedKey` to false likewise removes that pin requirement.

---

## TLS and headers

`SessionConfiguration.createURLSession(securityConfiguration:)` installs the
validator and applies TLS protocol limits. Constructing a `SecurityConfiguration`
without attaching it to a session does not affect transport. The default TLS
range is 1.2 through 1.3. Custom CA certificates augment the system trust anchors.

`HeaderSecurityMiddleware` validates field names and values and can filter or
sanitize configured headers. It preserves request identity and rejects invalid
field names. It does not encrypt headers, configure TLS, or turn response-oriented
browser policies such as CSP into client transport protection.

TLS protects HTTP headers and bodies in transit. There is no custom header/body
encryption protocol in this library. Application payload encryption requires an
agreed server format, key management, and replay policy; adding an arbitrary
`Content-Encoding` value and encrypting bytes is not a complete protocol.

---

## Reuse Keychain services and providers

```swift
let keychain = KeychainService(service: "com.example.app.auth")
let provider = KeychainTokenProvider(keychainService: keychain)
let transport = NetworkClient()
let authentication = AuthenticationMiddleware(
  configuration: .init(),
  tokenProvider: provider,
  client: transport
)
let client = NetworkClient(
  middleware: HTTPMiddleware(request: [authentication], error: [authentication])
)
```

This example reads existing credentials. Supply `refreshHandler` when creating
the provider if the application supports refresh; the handler implements the
server's exchange and returns the new access token. The provider cannot invent
that protocol. Restrict `shouldAuthenticate` when a client can reach hosts or
endpoints that must not receive its credentials.

Reuse the `KeychainService` and `KeychainTokenProvider` objects. The provider reads
credential values directly from Keychain rather than caching them between reads.
Mutations through the shared service invalidate a suspended credential refresh
before it can persist stale credentials. This protection does not coordinate
independent service actors or other processes as one transaction.

Keychain operations can fail because of access policy, entitlements, or system
state; handle those errors. Provider `clearTokens()` propagates deletion failures
and is not a system-wide atomic transaction. Authentication middleware shares an
in-flight refresh and checks cancellation before retrying the original request.

Keep credential storage separate from response caching. Diagnostics redaction
covers known secret headers and query values, not every application-specific
secret. Review <doc:Requests-and-Cancellation> before enabling body capture.

---

## Related guides

- <doc:Getting-Started>
- <doc:Middleware-Guide>
- <doc:Requests-and-Cancellation>
