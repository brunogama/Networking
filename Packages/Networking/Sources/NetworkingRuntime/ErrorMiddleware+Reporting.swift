import Foundation
import NetworkingCore

extension ErrorMiddleware {
  /// Protocol for error reporting services.
  public protocol ErrorReporter: Sendable {
    func report(_ error: HTTPError, context: ErrorContext) async
  }

  /// Console error reporter for development.
  public struct ConsoleErrorReporter: ErrorReporter {
    public init() {}

    public func report(_ error: HTTPError, context: ErrorContext) async {
      writeToStandardError("🔴 HTTP Error: \(error.debugDescription)")
      writeToStandardError("   Context: \(context)")
    }

    private func writeToStandardError(_ message: String) {
      FileHandle.standardError.write(Data("\(message)\n".utf8))
    }
  }

  /// Error reporting processor.
  public struct ErrorReportingProcessor: ErrorProcessor {
    private let reporter: any ErrorReporter

    public init(reporter: any ErrorReporter) {
      self.reporter = reporter
    }

    public func process(
      error: HTTPError,
      for request: HTTPRequest,
      context: ErrorContext
    ) async -> HTTPError {
      await reporter.report(error, context: context)
      return error
    }
  }
}
