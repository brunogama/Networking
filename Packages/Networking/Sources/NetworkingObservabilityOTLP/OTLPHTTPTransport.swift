import Foundation
import NetworkingCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct OTLPHTTPTransport: Sendable {
  let configuration: OTLPConfiguration
  let session: URLSession

  func send(_ body: Data, signal: Signal) async throws(OTLPExportError) -> Data {
    let request = makeRequest(body, signal: signal)
    do {
      try Task.checkCancellation()
      let (data, response) = try await session.data(for: request)
      try Task.checkCancellation()
      try validate(response)
      return data
    } catch let error as OTLPExportError {
      throw error
    } catch let error as URLError where error.code == .cancelled {
      throw .cancelled
    } catch {
      throw Task.isCancelled ? .cancelled : .transport
    }
  }

  private func validate(_ response: URLResponse) throws(OTLPExportError) {
    guard let response = response as? HTTPURLResponse else { throw .transport }
    guard (200..<300).contains(response.statusCode) else {
      throw .rejectedStatus(HTTPStatusCode(response.statusCode))
    }
  }

  func makeRequest(_ body: Data, signal: Signal) -> URLRequest {
    let endpoint = configuration.endpoint.rawValue.appendingPathComponent("v1/\(signal.rawValue)")
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"
    request.httpBody = body
    request.timeoutInterval = configuration.timeout.rawValue
    for (name, value) in configuration.headers {
      request.setValue(value.rawValue, forHTTPHeaderField: name.rawValue)
    }
    request.setValue("application/x-protobuf", forHTTPHeaderField: "Content-Type")
    request.setValue("application/x-protobuf", forHTTPHeaderField: "Accept")
    return request
  }
}
