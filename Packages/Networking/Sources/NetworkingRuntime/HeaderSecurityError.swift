/// Security failures detected at the request boundary.
public enum HeaderSecurityError: Sendable {
  case headerInjection
  case maliciousContent
  case suspiciousActivity
  case rateLimitExceeded
}
