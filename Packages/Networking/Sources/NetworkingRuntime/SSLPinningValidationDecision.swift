#if canImport(Security)
enum SSLPinningValidationDecision: Equatable {
  case useCredential
  case performDefaultHandling
  case rejectProtectionSpace
}
#endif
