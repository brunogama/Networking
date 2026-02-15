//
//  Observability.swift
//  Networking
//
//  OpenTelemetry Protocol (OTLP) integration for distributed tracing and metrics.
//

// MARK: - Public API Re-exports

// This file provides a clean entry point for the Observability module.
// All OTLP-related types are organized here for convenient import.

// Configuration
// - OTLPConfiguration: Builder for OTLP exporter settings
// - OTLPResource: Service resource attributes (name, version, environment)
// - OTLPProtocol: Transport protocol (HTTP, gRPC)
// - OTLPConfigurationError: Configuration validation errors

// Trace Export
// - OTLPTraceExporter: Exports TraceSpan to OTLP collector (conforms to TraceExporter)
// - OTLPSpanConverter: Converts TraceSpan to OpenTelemetry SpanData
// - HTTPSemanticAttributes: HTTP semantic convention attribute keys

// Metrics Export
// - OTLPMetricsCollector: Exports PerformanceMetrics to OTLP (conforms to MetricsCollector)
// - OTLPMetricConverter: Converts PerformanceMetrics to OTLP format
// - MetricSemanticNames: HTTP client metric semantic names

// MARK: - Usage Example

/// Example: Configure OTLP export for traces and metrics
///
/// ```swift
/// import Networking
///
/// // Create OTLP configuration
/// let config = OTLPConfiguration(
///   endpoint: URL(string: "http://localhost:4318")!,
///   headers: ["Authorization": "Bearer token"],
///   resource: OTLPResource(
///     serviceName: "my-ios-app",
///     serviceVersion: "1.0.0",
///     deploymentEnvironment: "production"
///   )
/// )
///
/// // Create exporters
/// let traceExporter = try OTLPTraceExporter(configuration: config)
/// let metricsCollector = try OTLPMetricsCollector(configuration: config)
///
/// // Use with middleware
/// let tracingMiddleware = TracingMiddleware(exporter: traceExporter)
/// let observabilityMiddleware = NetworkObservabilityMiddleware(
///   metricsCollector: metricsCollector
/// )
///
/// // Configure network client
/// let client = try NetworkClient(components: [
///   BaseURL("https://api.example.com"),
///   AddMiddleware(tracingMiddleware),
///   AddMiddleware(observabilityMiddleware)
/// ])
/// ```
///
/// ## Environment-Based Configuration
///
/// ```swift
/// // Read from OTEL_* environment variables
/// if let config = OTLPConfiguration.fromEnvironment() {
///   let exporter = try OTLPTraceExporter(configuration: config)
///   // ...
/// }
/// ```
///
/// ## Auto-Detecting Service Resource
///
/// ```swift
/// // Auto-detect from Bundle.main
/// let resource = OTLPResource.autoDetect(serviceName: "my-app")
/// let config = OTLPConfiguration(
///   endpoint: URL(string: "http://localhost:4318")!,
///   resource: resource
/// )
/// ```

// MARK: - Module Notes

// The Observability module provides OpenTelemetry Protocol (OTLP) integration
// for the Networking framework. It extends the existing TraceExporter and
// MetricsCollector protocols to support production-grade observability.
//
// Key design decisions:
// 1. Extends existing protocols (no breaking changes)
// 2. Uses HTTP protocol (not gRPC) for simpler dependency tree
// 3. Batches exports for efficiency
// 4. Logs errors but never crashes on export failures
// 5. Applies OpenTelemetry semantic conventions for interoperability
//
// For more information, see:
// - OpenTelemetry Swift: https://github.com/open-telemetry/opentelemetry-swift
// - OTLP Specification: https://opentelemetry.io/docs/specs/otlp/
// - HTTP Semantic Conventions: https://opentelemetry.io/docs/specs/semconv/http/
