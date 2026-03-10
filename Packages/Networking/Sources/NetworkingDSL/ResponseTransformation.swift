import Foundation
import NetworkingCore

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
        category: .configuration(
          HTTPErrorDetail(rawValue: "Transformation pipeline produced wrong output type")
        )
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
  public typealias Input = HTTPBody
  public typealias Output = T

  private let decoder: JSONDecoder
  private let type: T.Type

  public init(_ type: T.Type, decoder: JSONDecoder = JSONDecoder()) {
    self.type = type
    self.decoder = decoder
  }

  public func transform(_ input: HTTPBody) async throws -> T {
    // We're already async - no need for continuation + Task nesting
    // Just do the work directly
    do {
      return try decoder.decode(type, from: input)
    } catch {
      throw HTTPError(
        category: .decoding(
          HTTPErrorDetail(rawValue: "Failed to decode \(type): \(error.localizedDescription)")
        ),
        underlyingError: error
      )
    }
  }
}

/// Async image decoder transformer
public struct AsyncImageDecoderTransformer: AsyncResponseTransformer {
  public typealias Input = HTTPBody
  public typealias Output = ImageData

  public struct ImageData: Sendable {
    public let data: HTTPBody
    public let format: ImageFormat
    public let size: CGSize?

    public enum ImageFormat: Sendable, CaseIterable {
      case jpeg
      case png
      case gif
      case webp
      case unknown

      public var mediaType: HTTPMediaType {
        switch self {
        case .jpeg: return HTTPMediaType(rawValue: "image/jpeg")
        case .png: return HTTPMediaType(rawValue: "image/png")
        case .gif: return HTTPMediaType(rawValue: "image/gif")
        case .webp: return HTTPMediaType(rawValue: "image/webp")
        case .unknown: return HTTPMediaType(rawValue: "unknown")
        }
      }
    }
  }

  public init() {}

  public func transform(_ input: HTTPBody) async throws -> ImageData {
    // We're already async - no need for continuation + Task nesting
    // Just do the work directly
    let format = detectImageFormat(from: input)
    let size = extractImageSize(from: input, format: format)

    return ImageData(data: input, format: format, size: size)
  }

  // swiftlint:disable:next cyclomatic_complexity
  private func detectImageFormat(from data: HTTPBody) -> ImageData.ImageFormat {
    guard data.count >= 4 else { return .unknown }

    let bytes = data.rawValue.prefix(4)
    let signature = Array(bytes)

    if isJPEGSignature(signature) {
      return .jpeg
    }

    if isPNGSignature(signature) {
      return .png
    }

    if isGIFSignature(signature) {
      return .gif
    }

    if hasWebPSignature(data) {
      return .webp
    }

    return .unknown
  }

  private func extractImageSize(from data: HTTPBody, format: ImageData.ImageFormat) -> CGSize? {
    // Simplified size extraction - in a real implementation, you'd parse the image headers
    nil
  }

  private func isJPEGSignature(_ signature: [UInt8]) -> Bool {
    signature[0] == 0xFF && signature[1] == 0xD8 && signature[2] == 0xFF
  }

  private func isPNGSignature(_ signature: [UInt8]) -> Bool {
    signature[0] == 0x89 && signature[1] == 0x50 && signature[2] == 0x4E && signature[3] == 0x47
  }

  private func isGIFSignature(_ signature: [UInt8]) -> Bool {
    signature[0] == 0x47 && signature[1] == 0x49 && signature[2] == 0x46 && signature[3] == 0x38
  }

  private func hasWebPSignature(_ data: HTTPBody) -> Bool {
    guard data.count >= 12 else {
      return false
    }

    let riffCheck = data.rawValue.prefix(4)
    let webpCheck = data.rawValue.subdata(in: 8..<12)
    return riffCheck.elementsEqual([0x52, 0x49, 0x46, 0x46])
      && webpCheck.elementsEqual([0x57, 0x45, 0x42, 0x50])
  }
}
