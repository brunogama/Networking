// swiftlint:disable file_length
import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Base protocol for network client configuration components.
public protocol ConfigurationComponent: Sendable {
  func apply(to configuration: inout NetworkClientBuilder.Configuration)
}

// MARK: - Basic Configuration Components

public struct ClientBaseURL: ConfigurationComponent {
  private let url: HTTPRequestURL

  public init(_ urlString: BaseURLText) throws {
    guard let url = URL(string: urlString.rawValue) else {
      throw HTTPError(category: .configuration("Invalid base URL: \(urlString.rawValue)"))
    }
    self.url = HTTPRequestURL(url)
  }

  public init(_ url: HTTPRequestURL) {
    self.url = url
  }

  public func apply(to configuration: inout NetworkClientBuilder.Configuration) {
    configuration.baseURL = url
  }
}

public struct DefaultTimeout: ConfigurationComponent {
  private let timeout: RequestTimeout

  public init(_ timeout: RequestTimeout) {
    self.timeout = timeout
  }

  public func apply(to configuration: inout NetworkClientBuilder.Configuration) {
    configuration.timeout = timeout
  }
}

public struct DefaultHeader: ConfigurationComponent {
  private let name: HTTPHeaderName
  private let value: HTTPHeaderValue

  public init(_ name: HTTPHeaderName, _ value: HTTPHeaderValue) {
    self.name = name
    self.value = value
  }

  public func apply(to configuration: inout NetworkClientBuilder.Configuration) {
    configuration.defaultHeaders[name] = value
  }
}

// MARK: - Middleware Configuration Components

public struct AddMiddleware: ConfigurationComponent {
  private let requestMiddleware: (any HTTPRequestMiddleware)?
  private let responseMiddleware: (any HTTPResponseMiddleware)?
  private let errorMiddleware: (any HTTPErrorMiddleware)?

  public init(_ middleware: any HTTPRequestMiddleware) {
    self.requestMiddleware = middleware
    self.responseMiddleware = nil
    self.errorMiddleware = nil
  }

  public init(_ middleware: any HTTPResponseMiddleware) {
    self.requestMiddleware = nil
    self.responseMiddleware = middleware
    self.errorMiddleware = nil
  }

  public init(_ middleware: any HTTPErrorMiddleware) {
    self.requestMiddleware = nil
    self.responseMiddleware = nil
    self.errorMiddleware = middleware
  }

  public init<T: HTTPRequestMiddleware & HTTPResponseMiddleware>(_ middleware: T) {
    self.requestMiddleware = middleware
    self.responseMiddleware = middleware
    self.errorMiddleware = nil
  }

  public init<T: HTTPRequestMiddleware & HTTPResponseMiddleware & HTTPErrorMiddleware>(
    _ middleware: T
  ) {
    self.requestMiddleware = middleware
    self.responseMiddleware = middleware
    self.errorMiddleware = middleware
  }

  public func apply(to configuration: inout NetworkClientBuilder.Configuration) {
    if let requestMiddleware = requestMiddleware {
      configuration.requestMiddlewares.append(requestMiddleware)
    }
    if let responseMiddleware = responseMiddleware {
      configuration.responseMiddlewares.append(responseMiddleware)
    }
    if let errorMiddleware = errorMiddleware {
      configuration.errorMiddlewares.append(errorMiddleware)
    }
  }
}

public struct EnableRetry: ConfigurationComponent {
  private let configuration: RetryMiddleware.Configuration

  public init(_ configuration: RetryMiddleware.Configuration = RetryMiddleware.Configuration()) {
    self.configuration = configuration
  }

  public func apply(to configuration: inout NetworkClientBuilder.Configuration) {
    // Note: We need to create a placeholder client for the retry middleware
    // In practice, this would be resolved when the NetworkClient is built
    let retryMiddleware = RetryMiddleware(
      configuration: self.configuration,
      client: NetworkClient()  // This will be replaced with the actual client
    )
    configuration.errorMiddlewares.append(retryMiddleware)
  }
}

#if canImport(OSLog)

public struct EnableLogging: ConfigurationComponent {
  private let configuration: LoggingMiddleware.Configuration

  public init(
    _ configuration: LoggingMiddleware.Configuration = LoggingMiddleware.Configuration()
  ) {
    self.configuration = configuration
  }

  public func apply(to configuration: inout NetworkClientBuilder.Configuration) {
    let loggingMiddleware = LoggingMiddleware(configuration: self.configuration)
    configuration.requestMiddlewares.append(loggingMiddleware)
    configuration.responseMiddlewares.append(loggingMiddleware)
    configuration.errorMiddlewares.append(loggingMiddleware)
  }
}

#endif  // canImport(OSLog)

public struct CustomSession: ConfigurationComponent {
  private let session: URLSession

  public init(_ session: URLSession) {
    self.session = session
  }

  public func apply(to configuration: inout NetworkClientBuilder.Configuration) {
    configuration.session = session
  }
}

public struct EnableSecurity: ConfigurationComponent {
  private let securityConfiguration: SecurityConfiguration

  public init(_ configuration: SecurityConfiguration) {
    self.securityConfiguration = configuration
  }

  public func apply(to configuration: inout NetworkClientBuilder.Configuration) {
    configuration.securityConfiguration = securityConfiguration
  }
}

