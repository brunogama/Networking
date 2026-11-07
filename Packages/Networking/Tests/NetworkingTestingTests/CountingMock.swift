import NetworkingCore
import NetworkingTesting

actor CountingMock: MockVerifiable {
  private var count = 0
  var callCount: MockVerificationCount { MockVerificationCount(count) }
  func recordCall() { count += 1 }
}
