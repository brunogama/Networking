import Foundation

// A local test server uses a self-signed certificate; never trust non-loopback hosts.
@MainActor
// swiftlint:disable:next prefer_struct
class LoopbackCertificateDelegate: NSObject, URLSessionDelegate {
  nonisolated func urlSession(
    _ session: URLSession,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler:
      @escaping (
        URLSession.AuthChallengeDisposition,
        URLCredential?
      ) -> Void
  ) {
    let host = challenge.protectionSpace.host.lowercased()
    let localHosts: Set<String> = ["localhost", "127.0.0.1"]
    let isLocalHost = localHosts.contains(host)
    let authenticationMethod = challenge.protectionSpace.authenticationMethod
    let isServerTrust =
      authenticationMethod == NSURLAuthenticationMethodServerTrust
    guard isServerTrust, isLocalHost,
      let trust = challenge.protectionSpace.serverTrust
    else {
      completionHandler(.performDefaultHandling, nil)
      return
    }
    let credential = URLCredential(trust: trust)
    completionHandler(.useCredential, credential)
  }
}
