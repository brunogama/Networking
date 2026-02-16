import Foundation
import OpenTelemetryApi
@preconcurrency import OpenTelemetrySdk

/// HTTP semantic convention attribute keys per OpenTelemetry spec.
///
/// See: https://opentelemetry.io/docs/specs/semconv/http/http-spans/
///
/// These keys are used to annotate spans with standardized HTTP request/response
/// attributes for consistent telemetry across services.
public enum HTTPSemanticAttributes {
  /// The HTTP request method (e.g., "GET", "POST").
  public static let httpMethod = "http.request.method"

  /// The full request URL including scheme, host, path, and query.
  public static let httpUrl = "url.full"

  /// The HTTP response status code (e.g., "200", "404").
  public static let httpStatusCode = "http.response.status_code"

  /// The size of the request body in bytes.
  public static let httpRequestBodySize = "http.request.body.size"

  /// The size of the response body in bytes.
  public static let httpResponseBodySize = "http.response.body.size"

  /// The server address (host) from the request URL.
  public static let httpHost = "server.address"

  /// The server port from the request URL.
  public static let httpPort = "server.port"

  /// The URL path component (e.g., "/users/123").
  public static let httpPath = "url.path"

  /// The URL scheme (e.g., "https", "http").
  public static let httpScheme = "url.scheme"

  /// The original User-Agent header value.
  public static let userAgentOriginal = "user_agent.original"

  /// The network protocol name (e.g., "http").
  public static let networkProtocolName = "network.protocol.name"

  /// The network protocol version (e.g., "1.1", "2.0").
  public static let networkProtocolVersion = "network.protocol.version"
}

/// Converts our TraceSpan to OpenTelemetry SDK SpanData.
///
/// This converter bridges our internal span representation to the OpenTelemetry SDK
/// format for OTLP export. It handles:
///
/// - Trace and span ID conversion from hex strings to OpenTelemetry types
/// - Status mapping (unset, ok, error)
/// - Attribute conversion (String dictionary → AttributeValue)
/// - Event conversion with timestamps
/// - Resource attribute attachment
///
/// ## Architectural Note
///
/// OpenTelemetry SDK doesn't expose a public initializer for SpanData. This converter
/// works around this by creating spans through the SDK's TracerProvider and immediately
/// converting them to SpanData. While not ideal, this is the only public API available.
///
/// ## Usage
///
/// ```swift
/// let resource = OTLPResource(serviceName: "my-app")
/// let converter = OTLPSpanConverter(resource: resource)
///
/// let otlpSpan = await converter.convert(myTraceSpan)
/// // Now ready for OTLP export
/// ```
public struct OTLPSpanConverter: Sendable {
  private let resource: OTLPResource

  /// Creates a span converter with the specified resource attributes.
  ///
  /// - Parameter resource: Resource attributes to attach to all spans
  public init(resource: OTLPResource) {
    self.resource = resource
  }

  /// Converts a completed TraceSpan to OpenTelemetry SpanData.
  ///
  /// - Parameter span: The trace span to convert
  /// - Returns: OpenTelemetry SpanData ready for OTLP export
  ///
  /// ## Implementation Note
  ///
  /// Due to OpenTelemetry SDK design, SpanData doesn't expose a public initializer.
  /// This method creates a minimal span using internal span creation and then
  /// populates it with our data via setter methods.
  public func convert(_ span: TraceSpan) async -> SpanData {
    let otelStatus = await convertStatus(span.status)
    let startTime = span.startTime
    let endTime = await span.endTime ?? Date()
    let attributes = await convertAttributes(span.attributes)

    // Parse trace and span IDs from hex strings
    let traceId = TraceId(fromHexString: span.context.traceId)
    let spanId = SpanId(fromHexString: span.context.spanId)
    let parentSpanId = span.context.parentSpanId.map { SpanId(fromHexString: $0) }

    // Create trace flags from context
    var traceFlags = TraceFlags()
    traceFlags = traceFlags.settingIsSampled(span.context.isSampled)

    // Create SpanData using SDK tracer (no public initializer exists)
    var spanData = createSpanData(
      with: SpanCreationParams(
        traceId: traceId,
        spanId: spanId,
        name: span.name,
        kind: .client
      )
    )

    // Configure span using setter methods
    spanData.settingStartTime(startTime)
    spanData.settingEndTime(endTime)
    spanData.settingTraceFlags(traceFlags)
    spanData.settingAttributes(attributes)
    spanData.settingTotalAttributeCount(attributes.count)
    spanData.settingHasEnded(true)
    spanData.settingStatus(otelStatus)
    spanData.settingResource(convertResource())

    if let parent = parentSpanId {
      spanData.settingParentSpanId(parent)
    }

    return spanData
  }

  /// Parameters for creating SpanData via SDK tracer.
  private struct SpanCreationParams {
    let traceId: TraceId
    let spanId: SpanId
    let name: String
    let kind: SpanKind
  }

  /// Creates a minimal SpanData using the internal span creation pattern.
  ///
  /// This is a workaround for OpenTelemetry SDK not exposing a public SpanData initializer.
  /// We create a span via the SDK's tracer and immediately convert it to SpanData.
  ///
  /// - Parameter params: Span creation parameters
  /// - Returns: SpanData for OTLP export
  private func createSpanData(with params: SpanCreationParams) -> SpanData {
    // Create a minimal tracer provider for span creation
    let tracerProvider = TracerProviderSdk()

    // TracerProviderSdk.get() returns TracerSdk - guaranteed by SDK architecture
    let tracer =
      tracerProvider.get(
        instrumentationName: "Networking",
        instrumentationVersion: nil
          // swiftlint:disable:next force_cast
      ) as! TracerSdk  // swiftlint:disable:this force_cast

    // Create a span and immediately end it
    let otelSpan = tracer.spanBuilder(spanName: params.name)
      .setSpanKind(spanKind: params.kind)
      .startSpan()

    otelSpan.end()

    // TracerSdk creates RecordEventsReadableSpan - guaranteed by SDK
    let readableSpan = otelSpan as! ReadableSpan  // swiftlint:disable:this force_cast

    return readableSpan.toSpanData()
  }

  /// Converts our SpanStatus to OpenTelemetry Status.
  private func convertStatus(_ status: TraceSpan.SpanStatus) -> Status {
    switch status {
    case .unset:
      return .unset
    case .ok:
      return .ok
    case .error(let message):
      return .error(description: message)
    }
  }

  /// Converts attribute dictionary to OpenTelemetry AttributeValue map.
  private func convertAttributes(_ attributes: [String: String]) -> [String: AttributeValue] {
    attributes.mapValues { AttributeValue($0) }
  }

  /// Converts resource attributes to OpenTelemetry Resource.
  private func convertResource() -> Resource {
    let attrs = resource.toAttributes()
    let attributeValues = attrs.mapValues { AttributeValue($0) }
    return Resource(attributes: attributeValues)
  }
}
