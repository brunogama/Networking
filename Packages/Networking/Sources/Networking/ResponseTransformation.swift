import Foundation

// MARK: - Response Transformation Pipelines

/// Protocol for response transformation pipelines
public protocol ResponseTransformationPipeline: Sendable {
  associatedtype Input: Sendable
  associatedtype Output: Sendable

  func transform(_ input: Input) async throws -> Output
}

/// A transformation pipeline that chains multiple transformers
public struct ChainedTransformationPipeline<Input: Sendable, Output: Sendable>:
  ResponseTransformationPipeline, Sendable
{
  private let transformations: [@Sendable (any Sendable) async throws -> any Sendable]

  internal init(transformations: [@Sendable (any Sendable) async throws -> any Sendable]) {
    self.transformations = transformations
  }

  public func transform(_ input: Input) async throws -> Output {
    var current: any Sendable = input

    for transformation in transformations {
      current = try await transformation(current)
    }

    guard let result = current as? Output else {
      throw HTTPError(
        category: .configuration("Transformation pipeline produced wrong output type")
      )
    }

    return result
  }
}

// MARK: - Data Conversion Protocols

/// Protocol for asynchronous response transformers
public protocol AsyncResponseTransformer<Input, Output>: Sendable {
  associatedtype Input: Sendable
  associatedtype Output: Sendable

  func transform(_ input: Input) async throws -> Output
}

/// Protocol for synchronous response transformers (extends existing)
public protocol SyncResponseTransformer<Input, Output>: ResponseTransformer, Sendable {
  // Inherits from existing ResponseTransformer protocol
}

/// Adapter to make sync transformers work with async pipelines
public struct AsyncTransformerAdapter<T: ResponseTransformer>: AsyncResponseTransformer
where T.Input: Sendable, T.Output: Sendable {
  public typealias Input = T.Input
  public typealias Output = T.Output

  private let syncTransformer: T

  public init(_ syncTransformer: T) {
    self.syncTransformer = syncTransformer
  }

  public func transform(_ input: Input) async throws -> Output {
    try syncTransformer.transform(input)
  }
}

// MARK: - Async Transformation Chains

/// A transformation chain that supports async operations
public struct AsyncTransformationChain<T: Sendable>: Sendable {
  public let response: HTTPResponse
  public let value: T
}

extension AsyncTransformationChain {
  /// Applies an async transformation to the current value
  public func transform<U>(
    _ transformer: some AsyncResponseTransformer<T, U>
  ) async throws -> AsyncTransformationChain<U> {
    let transformedValue = try await transformer.transform(value)
    return AsyncTransformationChain<U>(response: response, value: transformedValue)
  }

  /// Applies a sync transformation to the current value
  public func transform<U>(
    _ transformer: some ResponseTransformer<T, U>
  ) async throws -> AsyncTransformationChain<U> {
    let transformedValue = try transformer.transform(value)
    return AsyncTransformationChain<U>(response: response, value: transformedValue)
  }

  /// Applies a custom async transformation using a closure
  public func map<U>(_ transform: (T) async throws -> U) async throws -> AsyncTransformationChain<U>
  {
    let transformedValue = try await transform(value)
    return AsyncTransformationChain<U>(response: response, value: transformedValue)
  }

  /// Extracts the final value from the chain
  public func extractValue() -> T {
    value
  }

  /// Extracts both the response and the transformed value
  public func result() -> (response: HTTPResponse, value: T) {
    (response: response, value: value)
  }
}

// MARK: - Built-in Async Transformers

/// Async JSON decoder transformer
public struct AsyncJSONDecoderTransformer<T: Decodable & Sendable>: AsyncResponseTransformer {
  public typealias Input = Data
  public typealias Output = T

  private let decoder: JSONDecoder
  private let type: T.Type

  public init(_ type: T.Type, decoder: JSONDecoder = JSONDecoder()) {
    self.type = type
    self.decoder = decoder
  }

  public func transform(_ input: Data) async throws -> T {
    // We're already async - no need for continuation + Task nesting
    // Just do the work directly
    do {
      return try decoder.decode(type, from: input)
    } catch {
      throw HTTPError(
        category: .decoding("Failed to decode \(type): \(error.localizedDescription)"),
        underlyingError: error
      )
    }
  }
}

/// Async image decoder transformer
public struct AsyncImageDecoderTransformer: AsyncResponseTransformer {
  public typealias Input = Data
  public typealias Output = ImageData

  public struct ImageData: Sendable {
    public let data: Data
    public let format: ImageFormat
    public let size: CGSize?

    public enum ImageFormat: String, Sendable, CaseIterable {
      case jpeg = "image/jpeg"
      case png = "image/png"
      case gif = "image/gif"
      case webp = "image/webp"
      case unknown = "unknown"
    }
  }

  public init() {}

  public func transform(_ input: Data) async throws -> ImageData {
    // We're already async - no need for continuation + Task nesting
    // Just do the work directly
    let format = detectImageFormat(from: input)
    let size = extractImageSize(from: input, format: format)

    return ImageData(data: input, format: format, size: size)
  }

  private func detectImageFormat(from data: Data) -> ImageData.ImageFormat {
    guard data.count >= 4 else { return .unknown }

    let bytes = data.prefix(4)
    let signature = bytes.map { $0 }

    // JPEG: FF D8 FF
    if signature[0] == 0xFF && signature[1] == 0xD8 && signature[2] == 0xFF {
      return .jpeg
    }

    // PNG: 89 50 4E 47
    if signature[0] == 0x89 && signature[1] == 0x50 && signature[2] == 0x4E && signature[3] == 0x47
    {
      return .png
    }

    // GIF: 47 49 46 38
    if signature[0] == 0x47 && signature[1] == 0x49 && signature[2] == 0x46 && signature[3] == 0x38
    {
      return .gif
    }

    // WebP: Check for RIFF and WEBP
    if data.count >= 12 {
      let riffCheck = data.prefix(4)
      let webpCheck = data.subdata(in: 8..<12)
      if riffCheck.elementsEqual([0x52, 0x49, 0x46, 0x46])
        && webpCheck.elementsEqual([0x57, 0x45, 0x42, 0x50])
      {
        return .webp
      }
    }

    return .unknown
  }

  private func extractImageSize(from data: Data, format: ImageData.ImageFormat) -> CGSize? {
    // Simplified size extraction - in a real implementation, you'd parse the image headers
    nil
  }
}

// MARK: - Pipeline Composition

/// Protocol for composable transformation pipelines
public protocol ComposableTransformationPipeline<Input, Output>: ResponseTransformationPipeline {
  func then<Next: ResponseTransformationPipeline>(
    _ next: Next
  ) -> ComposedTransformationPipeline<Self, Next> where Output == Next.Input
}

extension ComposableTransformationPipeline {
  public func then<Next: ResponseTransformationPipeline>(
    _ next: Next
  ) -> ComposedTransformationPipeline<Self, Next> where Output == Next.Input {
    ComposedTransformationPipeline(first: self, second: next)
  }
}

/// A composed transformation pipeline that chains two pipelines
public struct ComposedTransformationPipeline<
  First: ResponseTransformationPipeline,
  Second: ResponseTransformationPipeline
>: ComposableTransformationPipeline where First.Output == Second.Input {
  public typealias Input = First.Input
  public typealias Output = Second.Output

  private let first: First
  private let second: Second

  internal init(first: First, second: Second) {
    self.first = first
    self.second = second
  }

  public func transform(_ input: Input) async throws -> Output {
    let intermediate = try await first.transform(input)
    return try await second.transform(intermediate)
  }
}

/// Basic pipeline that extracts data from HTTPResponse
public struct HTTPResponseToDataPipeline: ComposableTransformationPipeline {
  public typealias Input = HTTPResponse
  public typealias Output = Data

  public init() {}

  public func transform(_ input: HTTPResponse) async throws -> Data {
    guard let data = input.body else {
      throw HTTPError(
        category: .decoding("Response body is empty"),
        request: input.request,
        response: input
      )
    }
    return data
  }
}

/// Pipeline adapter for async transformers
public struct AsyncTransformerPipeline<T: AsyncResponseTransformer>:
  ComposableTransformationPipeline
{
  public typealias Input = T.Input
  public typealias Output = T.Output

  private let transformer: T

  public init(_ transformer: T) {
    self.transformer = transformer
  }

  public func transform(_ input: Input) async throws -> Output {
    try await transformer.transform(input)
  }
}

// MARK: - Extensions for HTTPResponse

extension HTTPResponse {
  /// Starts an async transformation chain
  public func asyncChain() -> AsyncTransformationChain<HTTPResponse> {
    AsyncTransformationChain(response: self, value: self)
  }

  /// Applies a transformation pipeline to this response
  public func transform<P: ResponseTransformationPipeline, T>(_ pipeline: P) async throws -> T
  where P.Input == HTTPResponse, P.Output == T {
    try await pipeline.transform(self)
  }
}

// MARK: - CGSize Placeholder

/// Placeholder for CGSize - would import CoreGraphics in real implementation
public struct CGSize: Sendable {
  public let width: Double
  public let height: Double

  public init(width: Double, height: Double) {
    self.width = width
    self.height = height
  }
}
