import Foundation
import NetworkingCore
import NetworkingDSL
import Testing

@Suite("HTTPRequest composition")
struct HTTPRequestCompositionBehaviorTests {
  @Test("The right request overrides method and URL")
  func rightRequestOverrides() throws {
    let left = HTTPRequest(
      method: .get,
      url: HTTPRequestURL(try #require(URL(string: "https://example.com/left")))
    )
    let right = HTTPRequest(
      method: .post,
      url: HTTPRequestURL(try #require(URL(string: "https://example.com/right")))
    )

    let merged = left + right

    #expect(merged.method == .post)
    #expect(merged.url == right.url)
  }
}
