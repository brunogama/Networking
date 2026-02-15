import Foundation
import OpenTelemetryProtocolExporterCommon
import OpenTelemetryProtocolExporterHttp
import OpenTelemetrySdk

#if canImport(OSLog)
  import OSLog
#endif

/// OTLP trace exporter that conforms to the existing TraceExporter protocol.
///
/// Batches spans and exports them to an OTLP HTTP collector endpoint.
///
/// ## Usage
///
/// ```swift
/// let config = OTLPConfiguration(
///   endpoint: URL(string: "http://localhost:4318")!,
///   resource: OTLPResource(serviceName: "my-app")
/// )
/// let exporter = try OTLPTraceExporter(configuration: config)
///
/// let middleware = TracingMiddleware(exporter: exporter)
/// ```
public actor OTLPTraceExporter: TraceExporter {
  // MARK: - Properties

  private let configuration: OTLPConfiguration
  private let converter: OTLPSpanConverter
  private let httpExporter: OtlpHttpTraceExporter
  private var buffer: [TraceSpan] = []
  private var lastFlush = Date()
  private var flushTask: Task<Void, Never>?

  #if canImport(OSLog)
    private let logger = Logger(subsystem: "Networking", category: "OTLPTraceExporter")
  #endif

  // MARK: - Initialization

  /// Creates an OTLP trace exporter.
  ///
  /// - Parameter configuration: OTLP configuration including endpoint and resource
  /// - Throws: OTLPConfigurationError if configuration is invalid
  public init(configuration: OTLPConfiguration) throws {
    try configuration.validate()

    self.configuration = configuration
    self.converter = OTLPSpanConverter(resource: configuration.resource)

    // Create the OpenTelemetry HTTP exporter
    let otlpConfig = OtlpConfiguration(
      timeout: configuration.timeout,
      headers: configuration.headers.map { ($0.key, $0.value) }
    )
    self.httpExporter = OtlpHttpTraceExporter(
      endpoint: configuration.endpoint,
      config: otlpConfig
    )
  }

  /// Starts the periodic flush background task.
  ///
  /// Must be called after initialization to enable automatic batching.
  public func start() {
    startPeriodicFlush()
  }

  deinit {
    flushTask?.cancel()
  }

  // MARK: - TraceExporter Protocol

  /// Exports a completed span to the OTLP collector.
  ///
  /// Spans are buffered and exported in batches for efficiency.
  ///
  /// - Parameter span: The span to export
  public func export(_ span: TraceSpan) async throws {
    buffer.append(span)

    // Flush if batch size reached
    if buffer.count >= configuration.batchSize {
      await flushBuffer()
    }
  }

  /// Flushes any buffered spans immediately.
  public func flush() async throws {
    await flushBuffer()
  }

  // MARK: - Private Methods

  private func startPeriodicFlush() {
    flushTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(5))
        await self?.flushIfNeeded()
      }
    }
  }

  private func flushIfNeeded() async {
    let elapsed = Date().timeIntervalSince(lastFlush)
    if elapsed >= configuration.flushInterval && !buffer.isEmpty {
      await flushBuffer()
    }
  }

  private func flushBuffer() async {
    guard !buffer.isEmpty else { return }

    let spansToExport = buffer
    buffer.removeAll()
    lastFlush = Date()

    // Convert all spans to OpenTelemetry SpanData
    var spanDataList: [SpanData] = []
    for span in spansToExport {
      let spanData = await converter.convert(span)
      spanDataList.append(spanData)
    }

    // Export via OTLP HTTP
    let result = httpExporter.export(spans: spanDataList)
    switch result {
    case .success:
      #if canImport(OSLog)
        logger.debug("Exported \(spanDataList.count) spans to OTLP")
      #endif
    case .failure:
      #if canImport(OSLog)
        logger.warning("Failed to export \(spanDataList.count) spans")
      #endif
      // Note: Failed spans are dropped to prevent unbounded memory growth
      // In production, consider implementing retry with exponential backoff
    }
  }

  /// Forces immediate shutdown and final flush.
  public func shutdown() async {
    flushTask?.cancel()
    await flushBuffer()
    httpExporter.shutdown()
  }
}
