import ExtensionConsumerAPI
import Foundation
import Networking
import NetworkingMacros
import Testing

@Test("A consumer executes a generated API from the extension package")
private func extensionConsumer() async throws {
  let api: any ConsumerAPI = ConsumerAPIFactory.make(client: ConsumerClient())
  #expect(try await api.user(id: 42) == ConsumerUser(name: "Blob"))
}

@Test("A generated public factory works across module boundaries")
private func publicFactoryConsumer() async throws {
  let api: any PublicAPI = PublicAPIFactory.make(
    client: ConsumerClient(),
    codec: JSONCodec()
  )
  #expect(try await api.user(id: 42).name == "Blob")
}
