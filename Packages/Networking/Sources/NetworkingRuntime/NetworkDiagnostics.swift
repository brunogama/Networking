import Foundation
import NetworkingCore
import os

/// Records bounded HTTP traces and emits structured logs without changing request behavior.
///
/// Every mutable field is protected by the same lock. No lock spans an await or subscriber callback.
public final class NetworkDiagnostics: Sendable {

  private let storage = OSAllocatedUnfairLock(initialState: Storage())
  private let capacity: Int
  private let privacy: HTTPTracePrivacy
  private let logger: Logger?
  private let codec: JSONCodec
  private let logs: Logs
  private let logFormat: LogFormat

  public init(
    capacity: Int = 100,
    privacy: HTTPTracePrivacy = .init(),
    logs: Logs = [.success, .error],
    logFormat: LogFormat = .trace
  ) {
    self.capacity = max(0, capacity)
    self.privacy = privacy
    self.logs = logs
    self.logFormat = logFormat
    logger = logs.isEmpty ? nil : Logger(subsystem: "Networking", category: "HTTP")
    var encoding = JSONCodec.Configuration()
    encoding.outputFormatting = [.prettyPrinted, .sortedKeys]
    encoding.dateEncoding = .iso8601
    codec = JSONCodec(configuration: encoding)
  }

  public var traces: [HTTPTrace] { storage.withLock { $0.traces } }

  public func changes() -> AsyncStream<Void> {
    let identity = UUID()
    let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    continuation.onTermination = { [weak self] _ in
      _ = self?.storage.withLock { $0.observers.removeValue(forKey: identity) }
    }
    storage.withLock { $0.observers[identity] = continuation }
    continuation.yield(())
    return stream
  }

  public func clear() {
    storage.withLock { $0.traces.removeAll(keepingCapacity: true) }
    notifyObservers()
  }

  public func export() throws -> Data {
    try codec.encode(traces)
  }

  func start(_ request: HTTPRequest) -> HTTPTraceID {
    let trace = HTTPTrace(id: HTTPTraceID(), request: privacy.request(request), startedAt: Date())
    storage.withLock { state in
      state.active[trace.id] = trace
      guard capacity > 0 else { return }
      state.traces.append(trace)
      state.traces.removeFirst(max(0, state.traces.count - capacity))
    }
    notifyObservers()
    return trace.id
  }

  func finish(_ id: HTTPTraceID, response: HTTPResponse) {
    let message = privacy.response(response)
    let trace = complete(id) {
      $0.response = message
      $0.endedAt = Date()
    }
    let outcome: Logs =
      response.status.isClientError.rawValue || response.status.isServerError.rawValue
      ? .error
      : .success
    log(trace, for: outcome)
  }

  func fail(_ id: HTTPTraceID, error: any Error) {
    let failure = error as NSError
    let trace = complete(id) {
      $0.failure = "\(failure.domain):\(failure.code)"
      $0.endedAt = Date()
    }
    log(trace, for: .error)
  }

  func record(_ id: HTTPTraceID, metrics: URLSessionTaskMetrics) {
    let connections = metrics.transactionMetrics.map(HTTPTrace.Connection.init)
    update(id) { $0.connections = connections }
  }

  private func update(_ id: HTTPTraceID, _ change: @Sendable (inout HTTPTrace) -> Void) {
    let changed = storage.withLock { state -> Bool in
      guard var trace = state.active[id] else { return false }
      change(&trace)
      state.active[id] = trace
      guard let index = state.traces.firstIndex(where: { $0.id == id }) else { return true }
      state.traces[index] = trace
      return true
    }
    if changed { notifyObservers() }
  }

  private func complete(
    _ id: HTTPTraceID,
    _ change: @Sendable (inout HTTPTrace) -> Void
  ) -> HTTPTrace? {
    let trace = storage.withLock { state -> HTTPTrace? in
      guard var trace = state.active.removeValue(forKey: id) else { return nil }
      change(&trace)
      guard let index = state.traces.firstIndex(where: { $0.id == id }) else { return trace }
      state.traces[index] = trace
      return trace
    }
    if trace != nil { notifyObservers() }
    return trace
  }

  private func log(_ trace: HTTPTrace?, for outcome: Logs) {
    guard logs.contains(outcome), let trace else { return }
    let output = HTTPTraceLogRenderer.render(trace, format: logFormat, codec: codec)
    switch outcome {
    case .success:
      logger?.notice("\(output, privacy: .public)")
    case .error:
      logger?.error("\(output, privacy: .public)")
    default:
      return
    }
  }

  private func notifyObservers() {
    let observers = storage.withLock { Array($0.observers.values) }
    for observer in observers { observer.yield(()) }
  }

  deinit {
    let observers = storage.withLock { Array($0.observers.values) }
    for observer in observers { observer.finish() }
  }
}

extension HTTPTrace.Connection {
  init(_ metrics: URLSessionTaskTransactionMetrics) {
    protocolName = metrics.networkProtocolName
    reused = metrics.isReusedConnection
    dns = Self.interval(metrics.domainLookupStartDate, metrics.domainLookupEndDate)
    connect = Self.interval(metrics.connectStartDate, metrics.connectEndDate)
    tls = Self.interval(metrics.secureConnectionStartDate, metrics.secureConnectionEndDate)
    timeToFirstByte = Self.interval(metrics.requestStartDate, metrics.responseStartDate)
  }

  private static func interval(_ start: Date?, _ end: Date?) -> TimeInterval? {
    guard let start, let end else { return nil }
    return max(0, end.timeIntervalSince(start))
  }
}
