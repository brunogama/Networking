import Foundation
import NetworkingCore
import OpenTelemetryProtocolExporterCommon

struct OTLPEncoding {
  let configuration: OTLPConfiguration

  func resource() -> Opentelemetry_Proto_Resource_V1_Resource {
    var result = Opentelemetry_Proto_Resource_V1_Resource()
    result.attributes = attributes(
      configuration.resource.toAttributes().map {
        ($0.key.rawValue, $0.value.rawValue)
      }
    )
    return result
  }

  func attributes(_ values: [(String, String)]) -> [Opentelemetry_Proto_Common_V1_KeyValue] {
    let excluded = Set(configuration.redactedAttributes.map { $0.rawValue.lowercased() })
    return values.filter { !excluded.contains($0.0.lowercased()) }.map { name, value in
      var attribute = Opentelemetry_Proto_Common_V1_KeyValue()
      attribute.key = name
      attribute.value.stringValue = value
      return attribute
    }
  }

  func attributes(
    _ values: [TraceAttributeKey: TraceAttributeValue]
  )
    -> [Opentelemetry_Proto_Common_V1_KeyValue]
  {
    attributes(values.map { ($0.key.rawValue, $0.value.rawValue) })
  }

  func timestamp(_ value: Date) throws(OTLPExportError) -> UInt64 {
    let nanos = value.timeIntervalSince1970 * 1_000_000_000
    guard nanos.isFinite, nanos >= 0, nanos < Double(UInt64.max) else {
      throw .invalidTimestamp
    }
    return UInt64(nanos)
  }

  func identifier(_ value: String) -> Data {
    let bytes = Array(value.utf8)
    return Data(
      stride(from: 0, to: bytes.count, by: 2).compactMap { index in
        String(bytes: bytes[index..<index + 2], encoding: .utf8).flatMap { UInt8($0, radix: 16) }
      }
    )
  }
}
