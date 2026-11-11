import Foundation
import NetworkingCore

extension NetworkClient {

  public func send<Model: Request>(_ request: Model) async throws(HTTPError) -> Model.Response {
    let httpRequest = try materialize(request)
    let response = try await execute(httpRequest)
    do {
      return try request.decode(response, using: codec)
    } catch let error as HTTPError {
      throw error
    } catch {
      throw HTTPError(
        category: .decoding(HTTPErrorDetail(String(describing: error))),
        request: response.request,
        response: response,
        underlyingError: error
      )
    }
  }

  public func send<each Model: Request>(
    _ requests: repeat each Model
  ) async throws(HTTPError) -> (repeat (each Model).Response) {
    do {
      async let responses = (repeat send(each requests))
      return try await responses
    } catch let error as HTTPError {
      throw error
    } catch {
      throw HTTPError(
        category: .custom("Request batch", "An unexpected request failure occurred"),
        underlyingError: error
      )
    }
  }

  private func materialize<Model: Request>(_ request: Model) throws(HTTPError) -> HTTPRequest {
    HTTPRequest(
      method: request.method,
      url: try requestURL(request),
      headers: request.headers,
      body: try encodedBody(request),
      timeout: request.timeout
    )
  }

  private func requestURL<Model: Request>(_ request: Model) throws(HTTPError) -> HTTPRequestURL {
    guard var components = URLComponents(string: request.path.rawValue) else {
      throw HTTPError(category: .configuration("Invalid request path"))
    }
    if !request.query.isEmpty {
      components.queryItems = request.query.map { item in
        URLQueryItem(name: item.name.rawValue, value: item.value)
      }
    }
    guard let url = components.url else {
      throw HTTPError(category: .configuration("Invalid request query"))
    }
    return HTTPRequestURL(url)
  }

  private func encodedBody<Model: Request>(_ request: Model) throws(HTTPError) -> HTTPBody? {
    do {
      return try request.body(using: codec)
    } catch let error as HTTPError {
      throw error
    } catch {
      throw HTTPError(
        category: .encoding(HTTPErrorDetail(String(describing: error))),
        underlyingError: error
      )
    }
  }
}
