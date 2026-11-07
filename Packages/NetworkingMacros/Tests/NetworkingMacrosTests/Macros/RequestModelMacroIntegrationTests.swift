import Foundation
import Networking
import Testing

@Test("RequestModel synthesizes endpoint, headers, body, and initialization")
func requestModelCompilesAndEncodes() throws {
  let expected = RequestModelCompileUser(name: "Blob")
  let request = RequestModelCreateUser(token: "Bearer test", payload: expected)

  #expect(request.method == .post)
  #expect(request.path == "/request-models")
  #expect(request.headers["Authorization"] == "Bearer test")

  let encoded = try request.body(using: JSONCodec())
  let body = try #require(encoded)
  let object = try JSONSerialization.jsonObject(with: body.rawValue)
  let dictionary = try #require(object as? [String: Any])
  let value = try #require(dictionary["data"] as? [String: String])
  #expect(value["name"] == expected.name)
}
