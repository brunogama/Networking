import Foundation
@testable import NetworkingTesting
import NetworkingRuntime
import Testing

func mockURL(_ value: String) -> HTTPRequestURL {
  HTTPRequestURL(URL(string: value)!)
}

func mockBody(_ value: String) -> HTTPBody {
  HTTPBody(Data(value.utf8))
}

func makeMockNetworkClient(
  contextID: MockContextIdentifier
) -> (client: NetworkClient, session: URLSession) {
  let session = URLSession(
    configuration: MockURLProtocol.createMockConfiguration(contextID: contextID)
  )
  return (NetworkClient(session: session), session)
}


@Suite("Mocking Framework Tests")
struct MockingTests {}
