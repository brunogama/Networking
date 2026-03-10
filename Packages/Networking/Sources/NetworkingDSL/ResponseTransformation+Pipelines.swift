import Foundation
import NetworkingCore

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

public struct HTTPResponseToDataPipeline: ComposableTransformationPipeline {
  public typealias Input = HTTPResponse
  public typealias Output = HTTPBody

  public init() {}

  public func transform(_ input: HTTPResponse) async throws -> HTTPBody {
    guard let data = input.body else {
      throw HTTPError(
        category: .decoding(HTTPErrorDetail(rawValue: "Response body is empty")),
        request: input.request,
        response: input
      )
    }
    return data
  }
}

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

extension HTTPResponse {
  public func asyncChain() -> AsyncTransformationChain<HTTPResponse> {
    AsyncTransformationChain(response: self, value: self)
  }

  public func transform<P: ResponseTransformationPipeline, T>(_ pipeline: P) async throws -> T
  where P.Input == HTTPResponse, P.Output == T {
    try await pipeline.transform(self)
  }
}

/// Placeholder for CGSize - would import CoreGraphics in real implementation
public struct CGSize: Sendable {
  public let width: ImageDimensionValue
  public let height: ImageDimensionValue

  public init(width: ImageDimensionValue, height: ImageDimensionValue) {
    self.width = width
    self.height = height
  }

  package init(width: Double, height: Double) {
    self.init(width: ImageDimensionValue(width), height: ImageDimensionValue(height))
  }
}
