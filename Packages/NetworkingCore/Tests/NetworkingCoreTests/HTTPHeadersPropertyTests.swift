import NetworkingCore
import PremiseCore
import PremiseStrategies
import PremiseTesting
import Testing

@Suite("HTTP header merge properties")
struct HTTPHeadersPropertyTests {
  @Test("Associative combiners preserve merge grouping")
  func associativeMergeGrouping() async throws {
    try await forAll(
      Self.headerName,
      Self.headerValue,
      Self.headerValue,
      config: Self.config
    ) { name, firstValue, secondValue in
      let first = HTTPHeaders([HTTPHeaderName(name.lowercased()): HTTPHeaderValue(firstValue)])
      let second = HTTPHeaders([HTTPHeaderName(name.uppercased()): HTTPHeaderValue(secondValue)])
      let third = HTTPHeaders([HTTPHeaderName(name): "tail"])
      let left =
        first
        .merging(second, uniquingKeysWith: Self.concatenate)
        .merging(third, uniquingKeysWith: Self.concatenate)
      let right = first.merging(
        second.merging(third, uniquingKeysWith: Self.concatenate),
        uniquingKeysWith: Self.concatenate
      )

      #expect(left == right)
    }
  }

  private static let config = PropertyConfig.bounded(runs: 40, shrinks: 160)
  private static let headerName = Strategy<String>.strings(
    from: Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"),
    length: 1...20
  )
  private static let headerValue = Strategy<String>.ascii(length: 0...30)

  private static func concatenate(
    _ left: HTTPHeaderValue,
    _ right: HTTPHeaderValue
  ) -> HTTPHeaderValue {
    HTTPHeaderValue(left.rawValue + "," + right.rawValue)
  }
}
