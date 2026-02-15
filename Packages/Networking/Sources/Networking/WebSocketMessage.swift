import Foundation

// MARK: - WebSocket Message

/// A message sent or received through a WebSocket connection.
///
/// WebSocket messages can be either text (UTF-8 encoded) or binary data.
///
/// ```swift
/// let textMessage = WebSocketMessage.text("Hello, server!")
/// let binaryMessage = WebSocketMessage.data(Data([0x01, 0x02, 0x03]))
/// ```
public enum WebSocketMessage: Sendable, Equatable {
  /// A text message.
  case text(String)

  /// A binary data message.
  case data(Data)

  /// Returns the text content if this is a text message.
  public var textValue: String? {
    if case .text(let value) = self { return value }
    return nil
  }

  /// Returns the data content if this is a data message.
  public var dataValue: Data? {
    if case .data(let value) = self { return value }
    return nil
  }
}

// MARK: - WebSocket Configuration

/// Configuration options for a WebSocket connection.
public struct WebSocketConfiguration: Sendable {
  /// Interval between ping messages (in seconds). Set to `nil` to disable.
  public let pingInterval: TimeInterval?

  /// Maximum allowed message size in bytes. Messages exceeding this are rejected.
  public let maximumMessageSize: Int

  /// Additional HTTP headers to include in the WebSocket handshake.
  public let additionalHeaders: [String: String]

  /// Subprotocols to request during the handshake.
  public let protocols: [String]

  /// Creates a WebSocket configuration.
  ///
  /// - Parameters:
  ///   - pingInterval: Ping interval in seconds (default: 30)
  ///   - maximumMessageSize: Max message size in bytes (default: 1MB)
  ///   - additionalHeaders: Extra handshake headers (default: empty)
  ///   - protocols: Subprotocols to request (default: empty)
  public init(
    pingInterval: TimeInterval? = 30,
    maximumMessageSize: Int = 1_048_576,
    additionalHeaders: [String: String] = [:],
    protocols: [String] = []
  ) {
    self.pingInterval = pingInterval
    self.maximumMessageSize = maximumMessageSize
    self.additionalHeaders = additionalHeaders
    self.protocols = protocols
  }

  /// Default configuration with 30s ping and 1MB max message size.
  public static let `default` = Self()
}

// MARK: - WebSocket Close Code

/// WebSocket connection close codes as defined in RFC 6455.
public struct WebSocketCloseCode: Sendable, Equatable, RawRepresentable {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  /// Normal closure.
  public static let normalClosure = Self(rawValue: 1000)

  /// The endpoint is going away.
  public static let goingAway = Self(rawValue: 1001)

  /// A protocol error occurred.
  public static let protocolError = Self(rawValue: 1002)

  /// Unsupported data type.
  public static let unsupportedData = Self(rawValue: 1003)

  /// Invalid frame payload data.
  public static let invalidFramePayloadData = Self(rawValue: 1007)

  /// Policy violation.
  public static let policyViolation = Self(rawValue: 1008)

  /// Message too big.
  public static let messageTooBig = Self(rawValue: 1009)

  /// Server error.
  public static let internalServerError = Self(rawValue: 1011)
}

// MARK: - WebSocket Error

/// Errors that can occur during WebSocket operations.
public enum WebSocketError: Error, Sendable {
  /// The connection was refused by the server.
  case connectionRefused

  /// The connection timed out.
  case connectionTimeout

  /// The connection was closed with a specific close code and optional reason.
  case disconnected(code: WebSocketCloseCode, reason: String?)

  /// The message exceeded the maximum allowed size.
  case messageTooLarge(size: Int, maximum: Int)

  /// An invalid URL was provided.
  case invalidURL(String)

  /// An underlying transport error.
  case transportError(any Error)

  /// The connection is not currently active.
  case notConnected
}
