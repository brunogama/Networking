import NetworkingCore
import Testing

@Suite("HTTP error descriptions")
struct HTTPErrorMessageTests {
  @Test("A supplied message is visible to LocalizedError consumers")
  func customMessage() {
    let error = HTTPError(
      category: .timeout,
      message: "The server did not respond in time"
    )

    #expect(error.errorDescription == "The server did not respond in time")
  }
}
