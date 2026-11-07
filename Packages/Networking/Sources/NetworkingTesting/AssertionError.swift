import NetworkingCore

/// Reports an unmet request expectation.
public struct AssertionError: Error, Sendable, CustomStringConvertible {

  public let message: UserMessageText

  public init(_ message: UserMessageText) { self.message = message }

  public var description: String { message.rawValue }
}
