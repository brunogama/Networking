/// A declarative, typed HTTP operation.
///
/// A request describes endpoint-specific transport semantics. The executing client resolves its
/// configured base URL, default headers, and reusable codec when materializing the request.
public protocol Request: Sendable {

  associatedtype Response: Decodable & Sendable

  var method: HTTPMethod { get }

  var path: EndpointPath { get }

  var query: [HTTPQueryItem] { get }

  var headers: HTTPHeaders { get }

  var timeout: RequestTimeout? { get }

  func body(using codec: JSONCodec) throws -> HTTPBody?

  func decode(_ response: HTTPResponse, using codec: JSONCodec) throws -> Response
}

public extension Request {

  var query: [HTTPQueryItem] { [] }

  var headers: HTTPHeaders { [:] }

  var timeout: RequestTimeout? { nil }

  func body(using _: JSONCodec) throws -> HTTPBody? { nil }

  func decode(_ response: HTTPResponse, using codec: JSONCodec) throws -> Response {
    guard let body = response.body else {
      throw HTTPError(
        category: .decoding(HTTPErrorDetail("Response body is empty")),
        request: response.request,
        response: response
      )
    }

    do {
      return try codec.decode(Response.self, from: body.rawValue)
    } catch {
      throw HTTPError(
        category: .decoding(HTTPErrorDetail(String(describing: error))),
        request: response.request,
        response: response,
        underlyingError: error
      )
    }
  }
}
