import Foundation

/// Reuses a configured encoder and decoder for a client or persistence owner.
///
/// Configuration is applied before publication. The private Foundation coders support concurrent
/// operations on the supported platforms; callers cannot mutate their settings after initialization.
public final class JSONCodec: Sendable {
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  /// Creates reusable coders with a snapshot of the supplied settings.
  public init(configuration: Configuration = Configuration()) {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = configuration.dateEncoding
    encoder.dataEncodingStrategy = configuration.dataEncoding
    encoder.keyEncodingStrategy = configuration.keyEncoding
    encoder.nonConformingFloatEncodingStrategy = configuration.floatEncoding
    encoder.outputFormatting = configuration.outputFormatting
    encoder.userInfo = configuration.userInfo
    self.encoder = encoder

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = configuration.dateDecoding
    decoder.dataDecodingStrategy = configuration.dataDecoding
    decoder.keyDecodingStrategy = configuration.keyDecoding
    decoder.nonConformingFloatDecodingStrategy = configuration.floatDecoding
    decoder.userInfo = configuration.userInfo
    self.decoder = decoder
  }

  /// Encodes a value, preserving errors from its encoding implementation.
  public func encode<Value: Encodable>(_ value: Value) throws -> Data {
    try encoder.encode(value)
  }

  /// Decodes a value, preserving errors from its decoding implementation.
  public func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
    try decoder.decode(type, from: data)
  }
}
