import Foundation

extension JSONCodec {
  /// Value settings applied once when a codec is created.
  ///
  /// Custom strategy closures must support concurrent calls without shared unsynchronized state.
  public struct Configuration: Sendable {
    /// The representation used to encode dates.
    public var dateEncoding: JSONEncoder.DateEncodingStrategy = .deferredToDate
    /// The representation expected when decoding dates.
    public var dateDecoding: JSONDecoder.DateDecodingStrategy = .deferredToDate
    /// The representation used to encode binary data.
    public var dataEncoding: JSONEncoder.DataEncodingStrategy = .base64
    /// The representation expected when decoding binary data.
    public var dataDecoding: JSONDecoder.DataDecodingStrategy = .base64
    /// The conversion applied to encoded property names.
    public var keyEncoding: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys
    /// The conversion applied to decoded property names.
    public var keyDecoding: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys
    /// The handling of nonfinite floating-point values during encoding.
    public var floatEncoding: JSONEncoder.NonConformingFloatEncodingStrategy = .throw
    /// The handling of nonfinite floating-point values during decoding.
    public var floatDecoding: JSONDecoder.NonConformingFloatDecodingStrategy = .throw
    /// Whitespace, key ordering, and escaping preferences for encoded output.
    public var outputFormatting: JSONEncoder.OutputFormatting = []
    /// Context shared with encoding and decoding implementations.
    public var userInfo: [CodingUserInfoKey: any Sendable] = [:]

    /// Creates settings matching Foundation's JSON defaults.
    public init() {}
  }
}
