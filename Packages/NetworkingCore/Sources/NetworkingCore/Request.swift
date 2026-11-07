/// A declarative, typed HTTP operation.
///
/// A request describes endpoint-specific transport semantics. The executing client resolves its
/// configured base URL, default headers, and reusable codec when materializing the request.
public protocol Request: Sendable {
  /// The decoded value returned by this request.
  associatedtype Response: Decodable & Sendable

  /// The HTTP method for the operation.
  var method: HTTPMethod { get }

  /// The endpoint path, resolved relative to the client's configured base URL.
  var path: EndpointPath { get }

  /// Query items appended to the endpoint path.
  var query: [HTTPQueryItem] { get }

  /// Headers specific to this request. They override matching client defaults.
  var headers: HTTPHeaders { get }

  /// An optional request-specific timeout.
  var timeout: RequestTimeout? { get }

  /// Encodes the request body using the client's reusable codec.
  func body(using codec: JSONCodec) throws -> HTTPBody?

  /// Decodes a successful response using the client's reusable codec.
  func decode(_ response: HTTPResponse, using codec: JSONCodec) throws -> Response
}

public extension Request {
  /// The default request has no query items.
  var query: [HTTPQueryItem] { [] }

  /// The default request has no request-specific headers.
  var headers: HTTPHeaders { [:] }

  /// The default request inherits the client's configured timeout.
  var timeout: RequestTimeout? { nil }

  /// The default request has no body.
  func body(using _: JSONCodec) throws -> HTTPBody? { nil }

  /// Decodes the response body as this request's associated response type.
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
