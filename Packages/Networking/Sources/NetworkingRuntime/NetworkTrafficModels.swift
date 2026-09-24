import Foundation
import NetworkingCore

/// Controls which potentially sensitive values a traffic recorder retains.
public struct NetworkTrafficCapturePolicy: Sendable, Equatable {
  /// Records URL query values when enabled. Query names are retained either way.
  public let includesQueryValues: Bool

  /// Header names whose values may be retained, matched case insensitively.
  public let capturedHeaderNames: Set<String>

  /// Maximum request or response body bytes retained per attempt. Zero disables body capture.
  public let bodyByteLimit: Int

  public init(
    includesQueryValues: Bool = false,
    capturedHeaderNames: Set<String> = [],
    bodyByteLimit: Int = 0
  ) {
    self.includesQueryValues = includesQueryValues
    self.capturedHeaderNames = Set(capturedHeaderNames.map { $0.lowercased() })
    self.bodyByteLimit = max(bodyByteLimit, 0)
  }

  public static let metadataOnly = Self()
}

/// A bounded copy of an HTTP body.
public struct NetworkTrafficBody: Sendable, Equatable {
  public let data: Data
  public let originalByteCount: Int
  public let isTruncated: Bool
}

/// A privacy-filtered request snapshot.
public struct NetworkTrafficRequest: Sendable, Equatable {
  public let method: String
  public let url: URL?
  public let headerNames: [String]
  public let headers: [String: String]
  public let body: NetworkTrafficBody?
}

/// A privacy-filtered response snapshot.
public struct NetworkTrafficResponse: Sendable, Equatable {
  public let statusCode: Int?
  public let url: URL?
  public let headerNames: [String]
  public let headers: [String: String]
  public let body: NetworkTrafficBody?
}

/// A transport failure copied into Sendable values.
public struct NetworkTrafficFailure: Sendable, Equatable {
  public let domain: String
  public let code: Int
}

/// How URL Loading System obtained one transaction's resource.
public enum NetworkTrafficResourceFetchType: String, Sendable, Equatable {
  case unknown
  case networkLoad
  case serverPush
  case localCache
}

/// URLSession timings and connection details for one transaction.
public struct NetworkTrafficTransaction: Sendable, Equatable {
  public let requestURL: URL?
  public let responseURL: URL?
  public let responseStatusCode: Int?

  public let fetchStart: Date?
  public let domainLookupStart: Date?
  public let domainLookupEnd: Date?
  public let connectStart: Date?
  public let secureConnectionStart: Date?
  public let secureConnectionEnd: Date?
  public let connectEnd: Date?
  public let requestStart: Date?
  public let requestEnd: Date?
  public let responseStart: Date?
  public let responseEnd: Date?

  public let networkProtocolName: String?
  public let isProxyConnection: Bool
  public let isReusedConnection: Bool
  public let resourceFetchType: NetworkTrafficResourceFetchType
}

/// One redirect observed during a physical URLSession task.
public struct NetworkTrafficRedirect: Sendable, Equatable {
  public let observedAt: Date
  public let statusCode: Int
  public let fromURL: URL?
  public let toURL: URL?
}

/// A completed physical URLSession attempt.
public struct NetworkTrafficRecord: Sendable, Equatable, Identifiable {
  public let id: UUID
  public let sequence: UInt64
  /// Identifies the request passed to the transport after request middleware runs.
  public let requestID: HTTPRequestID
  public let startedAt: Date
  public let endedAt: Date
  public let request: NetworkTrafficRequest
  public let response: NetworkTrafficResponse?
  public let failure: NetworkTrafficFailure?
  public let redirects: [NetworkTrafficRedirect]
  public let taskInterval: DateInterval?
  public let transactions: [NetworkTrafficTransaction]

  public var duration: TimeInterval {
    max(endedAt.timeIntervalSince(startedAt), 0)
  }
}
