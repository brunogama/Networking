import Foundation
import NetworkingCore
import Testing

@Suite("Domain value contracts")
struct BoundaryValueTests {

  @Test("Scalar encoding retains the underlying JSON representation")
  func scalarEncoding() throws {
    try roundTrip(BoundaryString<BoundaryNameDomain>(rawValue: "example"), json: "\"example\"")
    try roundTrip(BoundaryInt<BoundaryCountDomain>(rawValue: 42), json: "42")
    try roundTrip(BoundaryInt64<BoundaryCountDomain>(rawValue: 42), json: "42")
    try roundTrip(BoundaryDouble<BoundaryCountDomain>(rawValue: 1.5), json: "1.5")
    try roundTrip(BoundaryDuration<BoundaryCountDomain>(rawValue: 1.5), json: "1.5")
    try roundTrip(BoundaryBool<BoundaryCountDomain>(rawValue: true), json: "true")
  }

  @Test("Literal and arithmetic operations preserve their domain")
  func literalsAndArithmetic() {
    let name: BoundaryString<BoundaryNameDomain> = "count \(42)"
    let count: BoundaryInt<BoundaryCountDomain> = 2
    let bytes: BoundaryInt64<BoundaryCountDomain> = 4
    let fraction: BoundaryDouble<BoundaryCountDomain> = 0.5
    let duration: BoundaryDuration<BoundaryCountDomain> = 2
    let enabled: BoundaryBool<BoundaryCountDomain> = true

    #expect(name.rawValue == "count 42")
    #expect((count + 3).rawValue == 5)
    #expect((bytes - 1).rawValue == 3)
    #expect((fraction + 0.25).rawValue == 0.75)
    #expect(duration.rawValue == 2)
    #expect(enabled.rawValue)
    #expect(count < BoundaryInt(rawValue: 3))
  }

  @Test("Foundation values preserve data and identity")
  func foundationValues() throws {
    let payload = BoundaryData<BoundaryPayloadDomain>(Data([0, 1, 255]))
    try roundTrip(payload, json: "\"AAH/\"", withoutEscapingSlashes: true)
    #expect(payload.count.rawValue == 3)
    #expect(!payload.isEmpty.rawValue)

    let location = try #require(
      BoundaryURL<BoundaryLocationDomain>(
        BoundaryString<BoundaryNameDomain>(rawValue: "https://example.com/path")
      )
    )
    let decoded = try JSONDecoder().decode(
      BoundaryURL<BoundaryLocationDomain>.self,
      from: JSONEncoder().encode(location)
    )
    #expect(decoded == location)
    #expect(decoded.rawValue.path == "/path")

    let identity = BoundaryUUID<BoundaryNameDomain>()
    #expect(
      try JSONDecoder().decode(
        BoundaryUUID<BoundaryNameDomain>.self,
        from: JSONEncoder().encode(identity)
      ) == identity
    )
  }

  private func roundTrip<Value: Codable & Equatable>(
    _ value: Value,
    json: String,
    withoutEscapingSlashes: Bool = false
  ) throws {
    let encoder = JSONEncoder()
    if withoutEscapingSlashes {
      encoder.outputFormatting = .withoutEscapingSlashes
    }
    let data = try encoder.encode(value)
    #expect(String(data: data, encoding: .utf8) == json)
    #expect(try JSONDecoder().decode(Value.self, from: data) == value)
  }
}
