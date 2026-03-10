import Foundation
import NetworkingCore

// MARK: - Response Builder Components

/// Base protocol for response builder components.
public protocol ResponseComponent: Sendable {
  func apply(to response: HTTPResponse, state: inout HTTPResponseBuilder.ProcessingState) throws
}

/// Result builder for processing HTTP responses with a fluent API.
@resultBuilder
public struct HTTPResponseBuilder {
  /// Internal structure for processing responses.
  public struct ProcessingState: Sendable {
    public var validators: [any ResponseValidator] = []
    public var transformations: [@Sendable (any Sendable) throws -> any Sendable] = []
    public var cacheSettings: ResponseCacheDuration?
    public var errorRecovery: (@Sendable (HTTPError) throws -> any Sendable)?

    public init() {}
  }

  /// Processed response wrapper containing the final result
  public struct ProcessedResponse<T: Sendable>: Sendable {
    public let response: HTTPResponse
    public let value: T
  }

  public static func buildBlock(_ components: any ResponseComponent...) -> [any ResponseComponent] {
    components
  }

  public static func buildOptional(_ component: [any ResponseComponent]?) -> [any ResponseComponent]
  {
    component ?? []
  }

  public static func buildEither(
    first component: [any ResponseComponent]
  ) -> [any ResponseComponent] {
    component
  }

  public static func buildEither(
    second component: [any ResponseComponent]
  ) -> [any ResponseComponent] {
    component
  }

  public static func buildArray(_ components: [[any ResponseComponent]]) -> [any ResponseComponent]
  {
    components.flatMap { $0 }
  }

  public static func buildLimitedAvailability(
    _ component: [any ResponseComponent]
  ) -> [any ResponseComponent] {
    component
  }

  public static func buildPartialBlock(first: any ResponseComponent) -> [any ResponseComponent] {
    [first]
  }

  public static func buildPartialBlock(
    accumulated: [any ResponseComponent],
    next: any ResponseComponent
  ) -> [any ResponseComponent] {
    accumulated + [next]
  }

  /// Processes an HTTPResponse using the built components.
  public static func process<T: Sendable>(
    _ response: HTTPResponse,
    components: [any ResponseComponent]
  ) throws -> ProcessedResponse<T> {
    var state = ProcessingState()

    // Apply all components to build the processing state
    for component in components {
      try component.apply(to: response, state: &state)
    }

    // Execute validation
    for validator in state.validators {
      let result = validator.validate(response)
      switch result {
      case .success:
        continue

      case .failure(let error):
        if let recovery = state.errorRecovery {
          let recoveredValue = try recovery(error)
          guard let typedValue = recoveredValue as? T else {
            throw HTTPError(category: .configuration("Error recovery returned wrong type"))
          }
          return ProcessedResponse(response: response, value: typedValue)
        }
        throw error
      }
    }

    // Execute transformations
    var currentValue: any Sendable = response
    for transformation in state.transformations {
      currentValue = try transformation(currentValue)
    }

    guard let finalValue = currentValue as? T else {
      throw HTTPError(category: .configuration("Final transformation result has wrong type"))
    }

    return ProcessedResponse(response: response, value: finalValue)
  }

  /// Creates a ProcessedResponse from the built components.
  public static func build<T: Sendable>(
    from response: HTTPResponse,
    _ content: () -> [any ResponseComponent]
  ) throws -> ProcessedResponse<T> {
    let components = content()
    return try process(response, components: components)
  }
}

// MARK: - Validation Components

/// Component that adds status code validation
public struct ValidateStatus: ResponseComponent {
  private let validator: StatusValidator

  public init(_ validator: StatusValidator) {
    self.validator = validator
  }

  public init(codes: Set<Int>) {
    self.validator = StatusValidator(validStatuses: codes)
  }

  public static let success = Self(StatusValidator.successStatus)
  public static let any = Self(StatusValidator.anyStatus)

  public func apply(
    to response: HTTPResponse,
    state: inout HTTPResponseBuilder.ProcessingState
  ) throws {
    state.validators.append(validator)
  }
}

/// Component that adds content type validation
public struct ValidateContentType: ResponseComponent {
  private let validator: ContentTypeValidator

  public init(_ validator: ContentTypeValidator) {
    self.validator = validator
  }

  public init(_ contentTypes: String...) {
    self.validator = ContentTypeValidator(Set(contentTypes))
  }

  public static let json = Self(ContentTypeValidator.json())
  public static let xml = Self(ContentTypeValidator.xml())
  public static let plainText = Self(ContentTypeValidator.plainText())

  public func apply(
    to response: HTTPResponse,
    state: inout HTTPResponseBuilder.ProcessingState
  ) throws {
    state.validators.append(validator)
  }
}

/// Component that adds custom validation
public struct ValidateWith: ResponseComponent {
  private let validator: any ResponseValidator

  public init(_ validator: any ResponseValidator) {
    self.validator = validator
  }

  public func apply(
    to response: HTTPResponse,
    state: inout HTTPResponseBuilder.ProcessingState
  ) throws {
    state.validators.append(validator)
  }
}

// MARK: - Transformation Components

/// Component that adds JSON decoding transformation
public struct DecodeJSON<T: Decodable & Sendable>: ResponseComponent {
  private let type: T.Type
  private let decoder: JSONDecoder

  public init(_ type: T.Type, decoder: JSONDecoder = JSONDecoder()) {
    self.type = type
    self.decoder = decoder
  }

  public func apply(
    to response: HTTPResponse,
    state: inout HTTPResponseBuilder.ProcessingState
  ) throws {
    let transformation: @Sendable (any Sendable) throws -> any Sendable = { input in
      guard let httpResponse = input as? HTTPResponse else {
        throw HTTPError(category: .configuration("Expected HTTPResponse for JSON decoding"))
      }

      guard let body = httpResponse.body else {
        throw HTTPError(
          category: .decoding("Response body is empty"),
          request: httpResponse.request,
          response: httpResponse
        )
      }

      do {
        return try self.decoder.decode(self.type, from: body)
      } catch {
        throw HTTPError(
          category: .decoding("Failed to decode \(self.type): \(error.localizedDescription)"),
          request: httpResponse.request,
          response: httpResponse,
          underlyingError: error
        )
      }
    }

    state.transformations.append(transformation)
  }
}

/// Component that adds string transformation
public struct TransformToString: ResponseComponent {
  private let encoding: String.Encoding

  public init(encoding: String.Encoding = .utf8) {
    self.encoding = encoding
  }

  public func apply(
    to response: HTTPResponse,
    state: inout HTTPResponseBuilder.ProcessingState
  ) throws {
    let transformation: @Sendable (any Sendable) throws -> any Sendable = { input in
      guard let httpResponse = input as? HTTPResponse else {
        throw HTTPError(category: .configuration("Expected HTTPResponse for string transformation"))
      }

      guard let body = httpResponse.body else {
        throw HTTPError(
          category: .decoding("Response body is empty"),
          request: httpResponse.request,
          response: httpResponse
        )
      }

      guard let string = String(data: body, encoding: self.encoding) else {
        throw HTTPError(
          category: .decoding("Failed to convert data to string using \(self.encoding) encoding"),
          request: httpResponse.request,
          response: httpResponse
        )
      }

      return string
    }

    state.transformations.append(transformation)
  }
}

/// Component that adds custom transformation
public struct TransformWith<Input: Sendable, Output: Sendable>: ResponseComponent {
  private let transformer: any ResponseTransformer<Input, Output>

  public init(_ transformer: any ResponseTransformer<Input, Output>) {
    self.transformer = transformer
  }

  public func apply(
    to response: HTTPResponse,
    state: inout HTTPResponseBuilder.ProcessingState
  ) throws {
    let transformation: @Sendable (any Sendable) throws -> any Sendable = { input in
      guard let typedInput = input as? Input else {
        throw HTTPError(category: .configuration("Transformer input type mismatch"))
      }
      return try self.transformer.transform(typedInput)
    }

    state.transformations.append(transformation)
  }
}

/// Component that applies a custom transformation closure
public struct MapValue<Input: Sendable, Output: Sendable>: ResponseComponent {
  private let transform: @Sendable (Input) throws -> Output

  public init(_ transform: @escaping @Sendable (Input) throws -> Output) {
    self.transform = transform
  }

  public func apply(
    to response: HTTPResponse,
    state: inout HTTPResponseBuilder.ProcessingState
  ) throws {
    let transformation: @Sendable (any Sendable) throws -> any Sendable = { input in
      guard let typedInput = input as? Input else {
        throw HTTPError(category: .configuration("Map input type mismatch"))
      }
      return try self.transform(typedInput)
    }

    state.transformations.append(transformation)
  }
}

// MARK: - Cache Components

/// Component that adds caching behavior
public struct CacheFor: ResponseComponent {
  private let duration: ResponseCacheDuration

  public init(_ duration: ResponseCacheDuration) {
    self.duration = duration
  }

  public static func seconds(_ value: TimeInterval) -> Self {
    Self(ResponseCacheDuration.seconds(value))
  }

  public static func minutes(_ value: TimeInterval) -> Self {
    Self(ResponseCacheDuration.minutes(value))
  }

  public static func hours(_ value: TimeInterval) -> Self {
    Self(ResponseCacheDuration.hours(value))
  }

  public static func days(_ value: TimeInterval) -> Self {
    Self(ResponseCacheDuration.days(value))
  }

  public func apply(
    to response: HTTPResponse,
    state: inout HTTPResponseBuilder.ProcessingState
  ) throws {
    state.cacheSettings = duration
  }
}

// MARK: - Error Recovery Components

/// Component that adds error recovery behavior
public struct RecoverWith<T: Sendable>: ResponseComponent {
  private let recovery: @Sendable (HTTPError) throws -> T

  public init(_ recovery: @escaping @Sendable (HTTPError) throws -> T) {
    self.recovery = recovery
  }

  public func apply(
    to response: HTTPResponse,
    state: inout HTTPResponseBuilder.ProcessingState
  ) throws {
    state.errorRecovery = { error in
      try self.recovery(error)
    }
  }
}

// MARK: - Convenience Extensions

extension HTTPResponse {
  /// Process the response using a result builder pipeline
  /// - Parameter builder: Response processing components
  /// - Returns: Processed response with typed result
  public func process<T: Sendable>(
    @HTTPResponseBuilder _ builder: () -> [any ResponseComponent]
  ) throws -> HTTPResponseBuilder.ProcessedResponse<T> {
    let components = builder()
    return try HTTPResponseBuilder.process(self, components: components)
  }

  /// Process the response with components array
  /// - Parameter components: Array of response components
  /// - Returns: Processed response with typed result
  public func process<T: Sendable>(
    components: [any ResponseComponent]
  ) throws -> HTTPResponseBuilder.ProcessedResponse<T> {
    try HTTPResponseBuilder.process(self, components: components)
  }
}
