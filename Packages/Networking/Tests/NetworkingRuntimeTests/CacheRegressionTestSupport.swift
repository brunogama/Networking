import Foundation
import NetworkingCore
@testable import NetworkingRuntime
import NetworkingTesting
import Testing

func cacheRequest(cookie: String = "alice") throws -> HTTPRequest {
  HTTPRequest(
    method: .get,
    url: try #require(URL(string: "https://cache.example/profile")),
    headers: ["Cookie": cookie]
  )
}
