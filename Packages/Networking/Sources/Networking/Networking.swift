@_exported import Foundation

#if canImport(FoundationNetworking)
@_exported import FoundationNetworking
#endif

@_exported import NetworkingCore
@_exported import NetworkingDSL
@_exported import NetworkingInterceptorsCompat
@_exported import NetworkingObservability
@_exported import NetworkingRuntime
@_exported import NetworkingRuntimeDSL
@_exported import NetworkingSSE

public typealias HTTPResult = Result<HTTPResponse, HTTPError>

public enum NetworkingVersionTag: Sendable {}
public enum SwiftVersionTag: Sendable {}
public enum TestingSupportTag: Sendable {}

public typealias NetworkingVersion = BoundaryString<NetworkingVersionTag>
public typealias NetworkingSwiftVersion = BoundaryString<SwiftVersionTag>
public typealias NetworkingTestingSupport = BoundaryBool<TestingSupportTag>

public enum Networking {
  public static let version = NetworkingVersion(rawValue: "1.0.0")
  public static let swiftVersion = NetworkingSwiftVersion(rawValue: "6.0")
  public static let supportsTesting = NetworkingTestingSupport(rawValue: true)
}
