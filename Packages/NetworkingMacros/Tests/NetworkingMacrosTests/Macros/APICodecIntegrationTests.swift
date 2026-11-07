import Foundation
import Networking
import NetworkingMacros
import Testing

@Test("Generated clients reuse a configured codec across concurrent requests")
private func configuredCodecConcurrentRequests() async throws {
  var configuration = JSONCodec.Configuration()
  configuration.dateEncoding = .secondsSince1970
  configuration.dateDecoding = .secondsSince1970
  configuration.keyEncoding = .convertToSnakeCase
  configuration.keyDecoding = .convertFromSnakeCase
  let codec = JSONCodec(configuration: configuration)
  let client = CodecEchoClient()
  let api = CodecAPIFactory.make(client: client, codec: codec)
  let expected = CodecUser(displayName: "Blob", createdAt: Date(timeIntervalSince1970: 0))

  try await withThrowingTaskGroup(of: CodecUser.self) { group in
    for _ in 0..<8 {
      group.addTask { try await api.create(user: expected, token: "Bearer test") }
    }
    for try await user in group {
      #expect(user == expected)
    }
  }
  #expect(try await api.user(page: nil) == expected)
  #expect(try await api.user(page: 2) == expected)
  try await verifyCodecRequests(client.requests)
}

private func verifyCodecRequests(_ requests: [HTTPRequest]) throws {
  #expect(requests.count == 10)
  for request in requests {
    #expect(request.timeout.rawValue == 0.25)
    #expect(request.headers["Accept"] == "application/json")
  }
  let bodyRequests = requests.filter { $0.method == .post }
  for request in bodyRequests {
    #expect(request.headers["Authorization"] == "Bearer test")
    #expect(request.headers["Content-Type"] == "application/json")
    let body = try #require(request.body)
    let object = try #require(JSONSerialization.jsonObject(with: body.rawValue) as? [String: Any])
    #expect(object["display_name"] as? String == "Blob")
    #expect(object["created_at"] as? Double == 0)
  }
  #expect(
    requests.suffix(2).map(\.url.description) == [
      "https://api.example.com/users", "https://api.example.com/users?page=2",
    ]
  )
}
