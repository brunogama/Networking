import NetworkingCore

/// Semantic convention attribute keys for OTLP resources.
///
/// These keys follow the OpenTelemetry semantic conventions for resource attributes.
/// See: https://opentelemetry.io/docs/specs/semconv/resource/
public enum ResourceAttributes {
  /// Service name identifier.
  public static let serviceName = ResourceAttributeName(rawValue: "service.name")

  /// Service version (e.g., "1.2.3").
  public static let serviceVersion = ResourceAttributeName(rawValue: "service.version")

  /// Unique service instance identifier.
  public static let serviceInstanceId = ResourceAttributeName(rawValue: "service.instance.id")

  /// Deployment environment (e.g., "production", "staging").
  public static let deploymentEnvironment = ResourceAttributeName(
    rawValue: "deployment.environment"
  )

  /// Telemetry SDK name.
  public static let telemetrySdkName = ResourceAttributeName(rawValue: "telemetry.sdk.name")

  /// Telemetry SDK version.
  public static let telemetrySdkVersion = ResourceAttributeName(
    rawValue: "telemetry.sdk.version"
  )

  /// Telemetry SDK language (e.g., "swift").
  public static let telemetrySdkLanguage = ResourceAttributeName(
    rawValue: "telemetry.sdk.language"
  )

  /// Operating system type (e.g., "ios", "macos").
  public static let osType = ResourceAttributeName(rawValue: "os.type")

  /// Operating system version.
  public static let osVersion = ResourceAttributeName(rawValue: "os.version")

  /// Device identifier.
  public static let deviceId = ResourceAttributeName(rawValue: "device.id")

  /// Device model identifier (e.g., "iPhone14,2").
  public static let deviceModelIdentifier = ResourceAttributeName(
    rawValue: "device.model.identifier"
  )
}
