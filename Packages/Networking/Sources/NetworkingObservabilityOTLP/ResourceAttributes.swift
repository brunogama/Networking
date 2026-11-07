import NetworkingCore

/// Semantic convention attribute keys for OTLP resources.
///
/// These keys follow the OpenTelemetry semantic conventions for resource attributes.
/// See: https://opentelemetry.io/docs/specs/semconv/resource/
public enum ResourceAttributes {

  public static let serviceName = ResourceAttributeName(rawValue: "service.name")

  public static let serviceVersion = ResourceAttributeName(rawValue: "service.version")

  public static let serviceInstanceId = ResourceAttributeName(rawValue: "service.instance.id")

  public static let deploymentEnvironment = ResourceAttributeName(
    rawValue: "deployment.environment"
  )

  public static let telemetrySdkName = ResourceAttributeName(rawValue: "telemetry.sdk.name")

  public static let telemetrySdkVersion = ResourceAttributeName(
    rawValue: "telemetry.sdk.version"
  )

  public static let telemetrySdkLanguage = ResourceAttributeName(
    rawValue: "telemetry.sdk.language"
  )

  public static let osType = ResourceAttributeName(rawValue: "os.type")

  public static let osVersion = ResourceAttributeName(rawValue: "os.version")

  public static let deviceId = ResourceAttributeName(rawValue: "device.id")

  public static let deviceModelIdentifier = ResourceAttributeName(
    rawValue: "device.model.identifier"
  )
}
