import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class MetricsTaskDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didFinishCollecting metrics: URLSessionTaskMetrics
  ) {
    lock.lock()
    count += 1
    lock.unlock()
  }

  func metricsCallbackCount() -> Int {
    lock.lock()
    let currentCount = count
    lock.unlock()
    return currentCount
  }
}

final class AuthenticationTaskDelegate: NSObject, URLSessionTaskDelegate,
  @unchecked Sendable
{
  private let lock = NSLock()
  private var count = 0

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler:
      @escaping @Sendable (
        URLSession.AuthChallengeDisposition,
        URLCredential?
      ) -> Void
  ) {
    lock.lock()
    count += 1
    lock.unlock()
    completionHandler(.cancelAuthenticationChallenge, nil)
  }

  func challengeCount() -> Int {
    lock.lock()
    let currentCount = count
    lock.unlock()
    return currentCount
  }
}

final class AuthenticationChallengeSender: NSObject, URLAuthenticationChallengeSender {
  func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}

  func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}

  func cancel(_ challenge: URLAuthenticationChallenge) {}

  func performDefaultHandling(for challenge: URLAuthenticationChallenge) {}

  func rejectProtectionSpaceAndContinue(with challenge: URLAuthenticationChallenge) {}
}
