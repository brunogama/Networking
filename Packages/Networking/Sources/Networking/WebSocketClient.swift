import Foundation

// MARK: - WebSocket Client

/// An actor-based WebSocket client for bidirectional communication.
///
/// `WebSocketClient` provides a modern async/await interface over
/// `URLSessionWebSocketTask`, with automatic ping/pong handling
/// and structured concurrency.
///
/// ## Usage
///
/// ```swift
/// let ws = WebSocketClient()
///
/// // Connect and receive messages
/// let messages = try await ws.connect(to: "wss://echo.websocket.org")
///
/// // Send a message
/// try await ws.send(.text("Hello, server!"))
///
/// // Iterate over incoming messages
/// for try await message in messages {
///     switch message {
///     case .text(let text):
///         print("Received: \(text)")
///     case .data(let data):
///         print("Received \(data.count) bytes")
///     }
/// }
///
/// // Disconnect when done
/// await ws.disconnect()
/// ```
public actor WebSocketClient {
  /// The current connection state.
  public enum State: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case disconnecting
  }

  // MARK: - Properties

  private let configuration: WebSocketConfiguration
  private let session: URLSession
  private var webSocketTask: URLSessionWebSocketTask?
  private var pingTask: Task<Void, Never>?
  private var receiveTask: Task<Void, Never>?

  /// The current connection state.
  public private(set) var state: State = .disconnected

  // MARK: - Initialization

  /// Creates a WebSocket client.
  ///
  /// - Parameters:
  ///   - configuration: WebSocket configuration (default: `.default`)
  ///   - session: URLSession to use (default: `.shared`)
  public init(
    configuration: WebSocketConfiguration = .default,
    session: URLSession = .shared
  ) {
    self.configuration = configuration
    self.session = session
  }

  // MARK: - Connection

  /// Connects to a WebSocket server and returns an async stream of messages.
  ///
  /// - Parameter urlString: The WebSocket URL (must start with `ws://` or `wss://`)
  /// - Returns: An `AsyncThrowingStream` of incoming ``WebSocketMessage`` values
  /// - Throws: ``WebSocketError`` if the connection fails
  public func connect(
    to urlString: String
  ) throws -> AsyncThrowingStream<WebSocketMessage, Error> {
    guard let url = URL(string: urlString) else {
      throw WebSocketError.invalidURL(urlString)
    }

    return try connect(to: url)
  }

  /// Connects to a WebSocket server and returns an async stream of messages.
  ///
  /// - Parameter url: The WebSocket URL
  /// - Returns: An `AsyncThrowingStream` of incoming ``WebSocketMessage`` values
  /// - Throws: ``WebSocketError`` if the connection fails
  /// - Note: REENTRANCY-SAFE - state guard prevents concurrent connect attempts
  public func connect(
    to url: URL
  ) throws -> AsyncThrowingStream<WebSocketMessage, Error> {
    // Guard prevents concurrent connect - state transition is atomic
    guard state == .disconnected else {
      throw WebSocketError.notConnected
    }

    // Set state BEFORE creating task to prevent reentrancy
    state = .connecting

    var request = URLRequest(url: url)
    for (name, value) in configuration.additionalHeaders {
      request.setValue(value, forHTTPHeaderField: name)
    }

    let task = session.webSocketTask(with: request)
    task.maximumMessageSize = configuration.maximumMessageSize
    self.webSocketTask = task

    task.resume()
    state = .connected

    // Start ping if configured
    if let pingInterval = configuration.pingInterval {
      startPing(interval: pingInterval)
    }

    // Create message stream
    let stream = AsyncThrowingStream<WebSocketMessage, Error> { continuation in
      let receiveTask = Task { [weak self] in
        guard let self = self else {
          continuation.finish()
          return
        }

        do {
          while !Task.isCancelled {
            let wsTask = await self.webSocketTask
            guard let activeTask = wsTask else {
              break
            }
            let message = try await activeTask.receive()
            let webSocketMessage: WebSocketMessage
            switch message {
            case .string(let text):
              webSocketMessage = .text(text)
            case .data(let data):
              webSocketMessage = .data(data)
            @unknown default:
              continue
            }
            continuation.yield(webSocketMessage)
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }

      continuation.onTermination = { @Sendable _ in
        receiveTask.cancel()
      }
    }

    return stream
  }

  // MARK: - Sending

  /// Sends a message through the WebSocket connection.
  ///
  /// - Parameter message: The message to send
  /// - Throws: ``WebSocketError/notConnected`` if not connected
  /// - Note: REENTRANCY-SAFE - atomic state check prevents send during invalid state
  public func send(_ message: WebSocketMessage) async throws {
    // Atomic state check prevents send during disconnect/connecting
    guard let task = webSocketTask, state == .connected else {
      throw WebSocketError.notConnected
    }

    switch message {
    case .text(let text):
      try await task.send(.string(text))
    case .data(let data):
      try await task.send(.data(data))
    }
  }

  /// Sends a text message through the WebSocket connection.
  ///
  /// - Parameter text: The text to send
  /// - Throws: ``WebSocketError/notConnected`` if not connected
  public func send(_ text: String) async throws {
    try await send(.text(text))
  }

  /// Sends binary data through the WebSocket connection.
  ///
  /// - Parameter data: The data to send
  /// - Throws: ``WebSocketError/notConnected`` if not connected
  public func send(_ data: Data) async throws {
    try await send(.data(data))
  }

  // MARK: - Disconnection

  /// Disconnects the WebSocket connection.
  ///
  /// - Parameters:
  ///   - closeCode: The close code to send (default: `.normalClosure`)
  ///   - reason: Optional reason string
  /// - Note: REENTRANCY-SAFE - state guard prevents concurrent disconnect
  public func disconnect(
    closeCode: WebSocketCloseCode = .normalClosure,
    reason: String? = nil
  ) {
    // Guard prevents disconnect when already disconnected/disconnecting
    guard state == .connected || state == .connecting else { return }

    // Set state BEFORE cleanup to prevent reentrancy
    state = .disconnecting
    pingTask?.cancel()
    pingTask = nil
    receiveTask?.cancel()
    receiveTask = nil

    let reasonData = reason?.data(using: .utf8)
    let urlCloseCode =
      URLSessionWebSocketTask.CloseCode(rawValue: closeCode.rawValue) ?? .normalClosure
    webSocketTask?.cancel(with: urlCloseCode, reason: reasonData)
    webSocketTask = nil

    state = .disconnected
  }

  // MARK: - Private

  private func startPing(interval: TimeInterval) {
    pingTask?.cancel()
    pingTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        guard !Task.isCancelled else { break }
        guard let self = self else { break }
        let wsTask = await self.webSocketTask
        wsTask?.sendPing { _ in }
      }
    }
  }
}
