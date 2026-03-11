import NetworkingCore
import NetworkingRuntime

/// Middleware that injects W3C Trace Context headers into outgoing requests
/// and records spans for each request lifecycle.
///
/// ## Usage
///
/// ```swift
/// let tracingMiddleware = TracingMiddleware()
///
/// let client = try NetworkClient(components: [
///     BaseURL("https://api.example.com"),
///     AddMiddleware(tracingMiddleware)
/// ])
/// ```
///
/// This will automatically add `traceparent` and `tracestate` headers to all
/// outgoing requests and record timing information for each request.
public final class TracingMiddleware: HTTPRequestMiddleware, HTTPResponseMiddleware,
  @unchecked Sendable
{
  private let exporter: (any TraceExporter)?
  private let spanStorage = SpanStorage()

  /// Actor-based storage for active spans.
  private actor SpanStorage {
    var activeSpans: [HTTPRequestID: TraceSpan] = [:]

    func store(_ span: TraceSpan, for requestId: HTTPRequestID) {
      activeSpans[requestId] = span
    }

    func retrieve(for requestId: HTTPRequestID) -> TraceSpan? {
      activeSpans.removeValue(forKey: requestId)
    }
  }

  /// Creates a tracing middleware.
  public init(exporter: (any TraceExporter)? = nil) {
    self.exporter = exporter
  }

  public func modifyRequest(_ request: HTTPRequest) async throws -> HTTPRequest {
    let context = TraceContext()
    let span = makeSpan(for: request, context: context)

    await applyRequestAttributes(to: span, request: request)
    await spanStorage.store(span, for: request.id)

    return injectTraceHeaders(into: request, context: context)
  }

  public func processResponse(
    _ response: HTTPResponse,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    guard let span = await spanStorage.retrieve(for: request.id) else {
      return response
    }

    await applyResponseAttributes(to: span, response: response)
    await end(span: span, for: response)

    if let exporter = exporter {
      try? await exporter.export(span)
    }

    return response
  }

  private func makeSpan(for request: HTTPRequest, context: TraceContext) -> TraceSpan {
    TraceSpan(
      name: TraceSpanName("\(request.method.rawValue.rawValue) \(request.url.path)"),
      context: context
    )
  }

  private func applyRequestAttributes(to span: TraceSpan, request: HTTPRequest) async {
    await span.setAttribute(
      TraceAttributeKey(HTTPSemanticAttributes.httpMethod),
      TraceAttributeValue(request.method.rawValue.rawValue)
    )
    await span.setAttribute(
      TraceAttributeKey(HTTPSemanticAttributes.httpUrl),
      TraceAttributeValue(request.url.absoluteString)
    )
    await span.setAttribute(
      TraceAttributeKey(HTTPSemanticAttributes.httpHost),
      TraceAttributeValue(request.url.host ?? "unknown")
    )
    await span.setAttribute(
      TraceAttributeKey(HTTPSemanticAttributes.httpPath),
      TraceAttributeValue(request.url.path)
    )
    await span.setAttribute(
      TraceAttributeKey(HTTPSemanticAttributes.httpScheme),
      TraceAttributeValue(request.url.scheme ?? "https")
    )

    if let port = request.url.port {
      await span.setAttribute(
        TraceAttributeKey(HTTPSemanticAttributes.httpPort),
        TraceAttributeValue(String(port))
      )
    }

    if let bodySize = request.body?.count {
      await span.setAttribute(
        TraceAttributeKey(HTTPSemanticAttributes.httpRequestBodySize),
        TraceAttributeValue(String(describing: bodySize))
      )
    }

    if let userAgent = request.headers[HTTPHeaderName("User-Agent")] {
      await span.setAttribute(
        TraceAttributeKey(HTTPSemanticAttributes.userAgentOriginal),
        TraceAttributeValue(userAgent.rawValue)
      )
    }
  }

  private func injectTraceHeaders(into request: HTTPRequest, context: TraceContext) -> HTTPRequest {
    var headers = request.headers
    headers[HTTPHeaderName("traceparent")] = context.traceparent

    if let tracestate = context.tracestateHeader {
      headers[HTTPHeaderName("tracestate")] = tracestate
    }

    return HTTPRequest(
      method: request.method,
      url: request.url,
      headers: headers,
      body: request.body,
      timeout: request.timeout
    )
  }

  private func applyResponseAttributes(to span: TraceSpan, response: HTTPResponse) async {
    await span.setAttribute(
      TraceAttributeKey(HTTPSemanticAttributes.httpStatusCode),
      TraceAttributeValue(String(response.status.rawValue.rawValue))
    )

    if let bodySize = response.body?.count {
      await span.setAttribute(
        TraceAttributeKey(HTTPSemanticAttributes.httpResponseBodySize),
        TraceAttributeValue(String(describing: bodySize))
      )
    }
  }

  private func end(span: TraceSpan, for response: HTTPResponse) async {
    guard !response.status.isSuccess.rawValue else {
      await span.end(status: TraceSpan.SpanStatus.ok)
      return
    }

    await span.end(
      status: TraceSpan.SpanStatus.error(
        SpanStatusMessage("HTTP \(response.status.rawValue.rawValue)")
      )
    )
  }
}
