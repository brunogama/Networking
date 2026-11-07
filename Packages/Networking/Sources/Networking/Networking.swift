@_exported import Foundation
@_exported import NetworkingCore
@_exported import NetworkingObservability
@_exported import NetworkingRuntime
@_exported import NetworkingSSE

/// The result of a completed HTTP operation.
public typealias HTTPResult = Result<HTTPResponse, HTTPError>
