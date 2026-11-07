import NetworkingCore
import Foundation
#if canImport(UIKit)
import UIKit
#endif

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

  public let serviceName: ServiceName

  public let serviceVersion: ServiceVersion?

  public let serviceInstanceId: ServiceInstanceIdentifier?

  public let deploymentEnvironment: DeploymentEnvironmentName?

  public let customAttributes: [ResourceAttributeName: ResourceAttributeValue]

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
