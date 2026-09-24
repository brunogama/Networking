import NetworkingCore
import Testing

@Suite("HTTP header semantics")
struct HTTPHeadersBehaviorTests {
  @Test("Header names are case insensitive for lookup and replacement")
  func caseInsensitiveNames() {
    var headers: HTTPHeaders = ["Content-Type": "application/json"]

    #expect(headers["content-type"] == "application/json")
    headers["CONTENT-TYPE"] = "text/plain"
    #expect(headers["Content-Type"] == "text/plain")
    #expect(headers.count == 1)
    #expect(headers == ["content-type": "text/plain"])
  }
}
