import NetworkingCore

/// Propagates trace context and exports spans without collecting credentials or URL queries.
///
/// Register on request, response, and error middleware chains for terminal cleanup.
/// Export failures do not change the HTTP result; direct exporter calls expose those failures.
public actor TracingMiddleware: HTTPRequestMiddleware, HTTPResponseMiddleware, HTTPErrorMiddleware {
  private let exporter: any TraceExporter
  private var activeSpans: [SpanIdentifier: TraceSpan] = [:]

  /// Creates instrumentation using an explicit export destination.
  public init(exporter: any TraceExporter) { self.exporter = exporter }

  /// Active spans awaiting a response or error callback.
  public var activeSpanCount: Int { activeSpans.count }

  /// Creates a child span and preserves the request's logical identity and transport options.
  public func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    let parent = request.headers[HTTPHeaderName("traceparent")].flatMap {
      TraceContext.parse(traceparent: $0)
    }
    let context = parent?.createChild() ?? TraceContext()
    let attributes: [TraceAttributeKey: TraceAttributeValue] = [
      TraceAttributeKey(HTTPSemanticAttributes.httpMethod):
        TraceAttributeValue(request.method.rawValue.rawValue),
      TraceAttributeKey(HTTPSemanticAttributes.httpHost):
        TraceAttributeValue(request.url.rawValue.host ?? "unknown"),
    ]
    activeSpans[context.spanId] = TraceSpan(
      name: TraceSpanName(request.method.rawValue.rawValue),
      context: context,
      attributes: attributes
    )
    var headers = request.headers
    headers[HTTPHeaderName("traceparent")] = context.traceparent
    return HTTPRequest(
      method: request.method,
      url: request.url,
      headers: headers,
      body: request.body,
      timeout: request.timeoutOverride,
      id: request.id
    )
  }

  /// Records HTTP status and exports exactly once for this transport attempt.
  public func processResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest
  )
    async throws -> HTTPResponse
  {
    guard let span = takeSpan(for: request) else { return response }
    await span.setAttribute(
      TraceAttributeKey(HTTPSemanticAttributes.httpStatusCode),
      TraceAttributeValue(String(response.status.rawValue.rawValue))
    )
    let status: TraceSpan.SpanStatus =
      response.status.rawValue.rawValue >= 400
      ? .error(SpanStatusMessage("HTTP \(response.status.rawValue.rawValue)")) : .ok
    await span.end(status: status)
    try? await exporter.export(span)
    return response
  }

  /// Completes a failed span and preserves the original request failure.
  public func handleError(_ error: HTTPError, for request: HTTPRequest) async throws -> HTTPResponse
  {
    if let span = takeSpan(for: request) {
      await span.end(status: .error("Request failed"))
      try? await exporter.export(span)
    }
    throw error
  }

  private func takeSpan(for request: HTTPRequest) -> TraceSpan? {
    guard let header = request.headers[HTTPHeaderName("traceparent")],
      let context = TraceContext.parse(traceparent: header)
    else { return nil }
    return activeSpans.removeValue(forKey: context.spanId)
  }
}
