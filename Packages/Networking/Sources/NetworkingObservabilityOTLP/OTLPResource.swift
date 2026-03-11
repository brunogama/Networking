import NetworkingCore
import NetworkingObservability
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Semantic convention attribute keys for OTLP resources.
///
/// These keys follow the OpenTelemetry semantic conventions for resource attributes.
/// See: https://opentelemetry.io/docs/specs/semconv/resource/
public enum ResourceAttributes {
  /// Service name identifier
  public static let serviceName = ResourceAttributeName(rawValue: "service.name")

  /// Service version (e.g., "1.2.3")
  public static let serviceVersion = ResourceAttributeName(rawValue: "service.version")

  /// Unique service instance identifier
  public static let serviceInstanceId = ResourceAttributeName(rawValue: "service.instance.id")

  /// Deployment environment (e.g., "production", "staging")
  public static let deploymentEnvironment = ResourceAttributeName(
    rawValue: "deployment.environment"
  )

  /// Telemetry SDK name
  public static let telemetrySdkName = ResourceAttributeName(rawValue: "telemetry.sdk.name")

  /// Telemetry SDK version
  public static let telemetrySdkVersion = ResourceAttributeName(
    rawValue: "telemetry.sdk.version"
  )

  /// Telemetry SDK language (e.g., "swift")
  public static let telemetrySdkLanguage = ResourceAttributeName(
    rawValue: "telemetry.sdk.language"
  )

  /// Operating system type (e.g., "ios", "macos")
  public static let osType = ResourceAttributeName(rawValue: "os.type")

  /// Operating system version
  public static let osVersion = ResourceAttributeName(rawValue: "os.version")

  /// Device identifier
  public static let deviceId = ResourceAttributeName(rawValue: "device.id")

  /// Device model identifier (e.g., "iPhone14,2")
  public static let deviceModelIdentifier = ResourceAttributeName(
    rawValue: "device.model.identifier"
  )
}

/// Service resource attributes attached to all exported spans and metrics.
///
/// Resources identify the source of telemetry data (service name, version, environment).
///
/// ## Example
///
/// ```swift
/// let resource = OTLPResource(
///   serviceName: "my-ios-app",
///   serviceVersion: "1.2.3",
///   deploymentEnvironment: "production"
/// )
/// ```
///
/// ## Auto-Detection
///
/// You can also auto-detect resource attributes from the app bundle:
///
/// ```swift
/// let resource = OTLPResource.autoDetect()
/// // Extracts service name from bundle ID, version from Info.plist
/// ```
public struct OTLPResource: Sendable, Equatable {
  /// Service name (required for meaningful traces)
  public let serviceName: ServiceName

  /// Service version (e.g., from Bundle.main)
  public let serviceVersion: ServiceVersion?

  /// Unique instance identifier (e.g., device UUID)
  public let serviceInstanceId: ServiceInstanceIdentifier?

  /// Deployment environment (production, staging, development)
  public let deploymentEnvironment: DeploymentEnvironmentName?

  /// Additional custom attributes
  public let customAttributes: [ResourceAttributeName: ResourceAttributeValue]

  /// Creates a new OTLP resource with the specified attributes.
  ///
  /// - Parameters:
  ///   - serviceName: Service name (default: "unknown")
  ///   - serviceVersion: Service version (default: nil)
  ///   - serviceInstanceId: Unique instance identifier (default: nil)
  ///   - deploymentEnvironment: Deployment environment (default: nil)
  ///   - customAttributes: Additional custom attributes (default: empty)
  public init(
    serviceName: ServiceName = ServiceName(rawValue: "unknown"),
    serviceVersion: ServiceVersion? = nil,
    serviceInstanceId: ServiceInstanceIdentifier? = nil,
    deploymentEnvironment: DeploymentEnvironmentName? = nil,
    customAttributes: [ResourceAttributeName: ResourceAttributeValue] = [:]
  ) {
    self.serviceName = serviceName
    self.serviceVersion = serviceVersion
    self.serviceInstanceId = serviceInstanceId
    self.deploymentEnvironment = deploymentEnvironment
    self.customAttributes = customAttributes
  }
}

// MARK: - Auto-Detection

extension OTLPResource {
  /// Creates a resource by auto-detecting values from Bundle and system info.
  ///
  /// This factory method extracts resource attributes from:
  /// - Bundle ID → service name
  /// - CFBundleShortVersionString → service version
  /// - CFBundleVersion → build number (appended to version)
  /// - System platform → OS type
  /// - Random UUID → service instance ID
  ///
  /// - Parameter serviceName: Override for service name (defaults to bundle name)
  /// - Returns: Resource with auto-detected attributes
  ///
  /// ## Example
  ///
  /// ```swift
  /// let resource = OTLPResource.autoDetect()
  /// // serviceName: "com.example.MyApp"
  /// // serviceVersion: "1.2.3+456"
  /// // customAttributes: ["os.type": "ios", "telemetry.sdk.language": "swift"]
  /// ```
  public static func autoDetect(serviceName: ServiceName? = nil) -> OTLPResource {
    let bundle = Bundle.main
    let name = serviceName ?? ServiceName(bundle.bundleIdentifier ?? "unknown")
    let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String
    let buildNumber = bundle.infoDictionary?["CFBundleVersion"] as? String
    let fullVersion = [version, buildNumber].compactMap { $0 }.joined(separator: "+")

    var customAttrs: [ResourceAttributeName: ResourceAttributeValue] = [
      ResourceAttributes.telemetrySdkName: "Networking",
      ResourceAttributes.telemetrySdkLanguage: "swift",
    ]

    #if os(iOS)
    customAttrs[ResourceAttributes.osType] = "ios"
    #elseif os(macOS)
    customAttrs[ResourceAttributes.osType] = "macos"
    #elseif os(tvOS)
    customAttrs[ResourceAttributes.osType] = "tvos"
    #elseif os(watchOS)
    customAttrs[ResourceAttributes.osType] = "watchos"
    #endif

    return OTLPResource(
      serviceName: name,
      serviceVersion: fullVersion.isEmpty ? nil : ServiceVersion(fullVersion),
      serviceInstanceId: ServiceInstanceIdentifier(UUID().uuidString),
      customAttributes: customAttrs
    )
  }
}

// MARK: - Attribute Conversion

extension OTLPResource {
  /// Converts resource to attribute dictionary for OTLP export.
  ///
  /// This method produces a flat dictionary of string key-value pairs
  /// suitable for OTLP resource attribute encoding.
  ///
  /// - Returns: Dictionary of resource attributes
  ///
  /// ## Example
  ///
  /// ```swift
  /// let resource = OTLPResource(
  ///   serviceName: "my-app",
  ///   serviceVersion: "1.0.0"
  /// )
  /// let attrs = resource.toAttributes()
  /// // ["service.name": "my-app", "service.version": "1.0.0"]
  /// ```
  public func toAttributes() -> [ResourceAttributeName: ResourceAttributeValue] {
    var attrs: [ResourceAttributeName: ResourceAttributeValue] = [
      ResourceAttributes.serviceName: ResourceAttributeValue(serviceName.rawValue)
    ]

    if let version = serviceVersion {
      attrs[ResourceAttributes.serviceVersion] = ResourceAttributeValue(version.rawValue)
    }
    if let instanceId = serviceInstanceId {
      attrs[ResourceAttributes.serviceInstanceId] = ResourceAttributeValue(instanceId.rawValue)
    }
    if let env = deploymentEnvironment {
      attrs[ResourceAttributes.deploymentEnvironment] = ResourceAttributeValue(env.rawValue)
    }

    for (key, value) in customAttributes {
      attrs[key] = value
    }

    return attrs
  }
}
