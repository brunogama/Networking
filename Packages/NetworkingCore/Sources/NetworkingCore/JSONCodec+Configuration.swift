import Foundation

extension JSONCodec {
  /// Value settings applied once when a codec is created.
  ///
  /// Custom strategy closures must support concurrent calls without shared unsynchronized state.
  public struct Configuration: Sendable {

    public var dateEncoding: JSONEncoder.DateEncodingStrategy = .deferredToDate

    public var dateDecoding: JSONDecoder.DateDecodingStrategy = .deferredToDate

    public var dataEncoding: JSONEncoder.DataEncodingStrategy = .base64

    public var dataDecoding: JSONDecoder.DataDecodingStrategy = .base64

    public var keyEncoding: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys

    public var keyDecoding: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys

    public var floatEncoding: JSONEncoder.NonConformingFloatEncodingStrategy = .throw

    public var floatDecoding: JSONDecoder.NonConformingFloatDecodingStrategy = .throw

    public var outputFormatting: JSONEncoder.OutputFormatting = []

    public var userInfo: [CodingUserInfoKey: any Sendable] = [:]

    public init() {}
  }
}
