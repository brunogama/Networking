import NetworkingCore

/// Reports an unmet request expectation.
public struct AssertionError: Error, Sendable, CustomStringConvertible {
  /// The expectations that did not match their observed call counts.
  public let message: UserMessageText

  /// Creates a failure with the supplied expectation description.
  public init(_ message: UserMessageText) { self.message = message }

  /// The expectation failure in readable form.
  public var description: String { message.rawValue }
}
