import Foundation
import NetworkingCore
import Testing

struct JSONCodecTests {

  @Test func configurationIsRetainedAcrossConcurrentOperations() async throws {
    var configuration = JSONCodec.Configuration()
    configuration.dateEncoding = .secondsSince1970
    configuration.dateDecoding = .secondsSince1970
    configuration.keyEncoding = .convertToSnakeCase
    configuration.keyDecoding = .convertFromSnakeCase
    let codec = JSONCodec(configuration: configuration)
    configuration.dateEncoding = .iso8601

    try await withThrowingTaskGroup(of: Void.self) { group in
      for index in 0..<20 {
        group.addTask {
          let payload = Payload(createdAt: Date(timeIntervalSince1970: 42), requestNumber: index)
          let encoded = try codec.encode(payload)
          let json = try #require(String(data: encoded, encoding: .utf8))
          #expect(json.contains("\"created_at\":42"))
          #expect(try codec.decode(Payload.self, from: encoded) == payload)
        }
      }
      try await group.waitForAll()
    }
  }

  @Test func encodingAndDecodingFailuresRemainVisible() {
    let codec = JSONCodec()
    #expect(throws: EncodingError.self) { try codec.encode(Double.nan) }
    #expect(throws: DecodingError.self) { try codec.decode(Int.self, from: Data("null".utf8)) }
  }
}
