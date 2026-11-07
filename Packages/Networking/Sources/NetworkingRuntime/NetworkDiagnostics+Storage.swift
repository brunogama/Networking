import Foundation

extension NetworkDiagnostics {
  struct Storage {
    var active: [HTTPTraceID: HTTPTrace] = [:]
    var traces: [HTTPTrace] = []
    var observers: [UUID: AsyncStream<Void>.Continuation] = [:]
  }
}
