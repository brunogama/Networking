import Testing
import Foundation
@testable import Networking

@Suite("WebSocket Tests")
struct WebSocketClientTests {

  // MARK: - WebSocketMessage Tests

  @Test("WebSocketMessage text value accessor")
  func testTextValueAccessor() {
    let message = WebSocketMessage.text("hello")
    #expect(message.textValue == "hello")
    #expect(message.dataValue == nil)
  }

  @Test("WebSocketMessage data value accessor")
  func testDataValueAccessor() {
    let data = Data([0x01, 0x02, 0x03])
    let message = WebSocketMessage.data(data)
    #expect(message.dataValue == data)
    #expect(message.textValue == nil)
  }

  @Test("WebSocketMessage equality for text")
  func testTextEquality() {
    #expect(WebSocketMessage.text("a") == WebSocketMessage.text("a"))
    #expect(WebSocketMessage.text("a") != WebSocketMessage.text("b"))
  }

  @Test("WebSocketMessage equality for data")
  func testDataEquality() {
    let data1 = Data([1, 2, 3])
    let data2 = Data([1, 2, 3])
    let data3 = Data([4, 5, 6])
    #expect(WebSocketMessage.data(data1) == WebSocketMessage.data(data2))
    #expect(WebSocketMessage.data(data1) != WebSocketMessage.data(data3))
  }

  @Test("WebSocketMessage text and data are not equal")
  func testTextDataNotEqual() {
    #expect(WebSocketMessage.text("abc") != WebSocketMessage.data("abc".data(using: .utf8)!))
  }

  // MARK: - WebSocketConfiguration Tests

  @Test("Default configuration values")
  func testDefaultConfiguration() {
    let config = WebSocketConfiguration.default
    #expect(config.pingInterval == 30)
    #expect(config.maximumMessageSize == 1_048_576)
    #expect(config.additionalHeaders.isEmpty)
    #expect(config.protocols.isEmpty)
  }

  @Test("Custom configuration")
  func testCustomConfiguration() {
    let config = WebSocketConfiguration(
      pingInterval: 10,
      maximumMessageSize: 512_000,
      additionalHeaders: ["X-API-Key": "123"],
      protocols: ["chat", "superchat"]
    )
    #expect(config.pingInterval == 10)
    #expect(config.maximumMessageSize == 512_000)
    #expect(config.additionalHeaders["X-API-Key"] == "123")
    #expect(config.protocols == ["chat", "superchat"])
  }

  @Test("Nil ping interval disables ping")
  func testNilPingInterval() {
    let config = WebSocketConfiguration(pingInterval: nil)
    #expect(config.pingInterval == nil)
  }

  // MARK: - WebSocketCloseCode Tests

  @Test("Standard close codes")
  func testStandardCloseCodes() {
    #expect(WebSocketCloseCode.normalClosure.rawValue == 1000)
    #expect(WebSocketCloseCode.goingAway.rawValue == 1001)
    #expect(WebSocketCloseCode.protocolError.rawValue == 1002)
    #expect(WebSocketCloseCode.messageTooBig.rawValue == 1009)
    #expect(WebSocketCloseCode.internalServerError.rawValue == 1011)
  }

  @Test("Custom close code")
  func testCustomCloseCode() {
    let code = WebSocketCloseCode(rawValue: 4000)
    #expect(code.rawValue == 4000)
  }

  @Test("Close code equality")
  func testCloseCodeEquality() {
    #expect(WebSocketCloseCode.normalClosure == WebSocketCloseCode(rawValue: 1000))
    #expect(WebSocketCloseCode.normalClosure != WebSocketCloseCode.goingAway)
  }

  // MARK: - WebSocketClient State Tests

  @Test("WebSocketClient initial state is disconnected")
  func testInitialState() async {
    let client = WebSocketClient()
    let state = await client.state
    #expect(state == .disconnected)
  }

  @Test("WebSocketClient with custom configuration")
  func testClientWithCustomConfig() async {
    let config = WebSocketConfiguration(pingInterval: 5)
    let client = WebSocketClient(configuration: config)
    let state = await client.state
    #expect(state == .disconnected)
  }

  @Test("WebSocketClient connect throws on invalid URL")
  func testConnectInvalidURL() async {
    let client = WebSocketClient()
    await #expect(throws: WebSocketError.self) {
      _ = try await client.connect(to: "not a url %%%")
    }
  }
}
