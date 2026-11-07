import Foundation
import NetworkingCore
import NetworkingObservabilityOTLP
import NetworkingTesting
import Testing

final class OTLPTestFixture: Sendable {
  let contextID = MockContextIdentifier()
  let configuration: OTLPConfiguration
  let session: URLSession

  init() throws {
    configuration = OTLPConfiguration(
      endpoint: HTTPRequestURL(try #require(URL(string: "https://collector.example"))),
      resource: OTLPResource(serviceName: "test-service")
    )
    session = URLSession(
      configuration: MockURLProtocol.createMockConfiguration(contextID: contextID)
    )
  }

  deinit {
    session.invalidateAndCancel()
    MockURLProtocol.clearAll(contextID: contextID)
  }

  func stub(signal: String, status: Int, body: Data = Data()) {
    let url = configuration.endpoint.rawValue.appendingPathComponent("v1/\(signal)")
    MockURLProtocol.stub(
      matching: .url(HTTPRequestURL(url)),
      response: .success(statusCode: HTTPStatusCode(status), data: HTTPBody(body)),
      contextID: contextID
    )
  }

  func requests() async -> [URLRequest] {
    await MockURLProtocol.getCapturedRequests(contextID: contextID)
  }
}
