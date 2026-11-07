import Foundation
import NetworkingCore

extension MockURLProtocol {
  /// Stub a request with flexible matching criteria.
  /// - Parameters:
  ///   - matchers: Array of matchers that must all match for the stub to be used
  ///   - response: The mock response to return
  ///   - maxUsageCount: Maximum number of times this stub can be used (nil = unlimited)
  ///   - requestCapture: Optional closure to capture and inspect the request
  ///   - contextID: Isolates stubs to a specific test session.
  public static func stub(
    matching matchers: RequestMatcher...,
    response: MockResponse,
    maxUsageCount: MockVerificationCount? = nil,
    requestCapture: (@Sendable (URLRequest) -> Void)? = nil,
    contextID: MockContextIdentifier? = nil
  ) {
    let stub = MockURLRequestStub(
      matchers: matchers,
      response: response,
      maxUsageCount: maxUsageCount,
      requestCapture: requestCapture,
      contextID: contextID
    )

    mockState.addStub(stub)
  }

  /// Stub a simple URL with success response.
  /// - Parameters:
  ///   - url: The URL to match
  ///   - statusCode: HTTP status code (default: 200)
  ///   - data: Response data
  ///   - headers: Response headers
  ///   - delay: Response delay in seconds
  ///   - contextID: Isolates stubs to a specific test session.
  public static func stubSuccess(
    url: HTTPRequestURL,
    statusCode: HTTPStatusCode = 200,
    data: HTTPBody = HTTPBody(Data()),
    headers: HTTPHeaders = [:],
    delay: MockResponseDelay = 0,
    contextID: MockContextIdentifier? = nil
  ) {
    let response: MockResponse =
      delay.rawValue > 0
      ? .custom(statusCode: statusCode, data: data, headers: headers, delay: delay)
      : .success(statusCode: statusCode, data: data, headers: headers)

    stub(matching: .url(url), response: response, contextID: contextID)
  }

  /// Stub a URL with JSON response.
  /// - Parameters:
  ///   - url: The URL to match
  ///   - json: Encodable object to return as JSON
  ///   - statusCode: HTTP status code (default: 200)
  ///   - delay: Response delay in seconds
  ///   - contextID: Isolates stubs to a specific test session.
  /// - Throws: An encoding error when the supplied value cannot be represented as JSON.
  public static func stubJSON<T: Encodable>(
    url: HTTPRequestURL,
    json: T,
    statusCode: HTTPStatusCode = 200,
    delay: MockResponseDelay = 0,
    contextID: MockContextIdentifier? = nil
  ) throws {
    let data = try codec.encode(json)
    let headers: HTTPHeaders = ["Content-Type": "application/json"]

    let response: MockResponse =
      delay.rawValue > 0
      ? .custom(statusCode: statusCode, data: HTTPBody(data), headers: headers, delay: delay)
      : .success(statusCode: statusCode, data: HTTPBody(data), headers: headers)

    stub(matching: .url(url), response: response, contextID: contextID)
  }

  /// Stub a URL with error response.
  /// - Parameters:
  ///   - url: The URL to match
  ///   - error: The error to throw
  ///   - contextID: Isolates stubs to a specific test session.
  public static func stubError(
    url: HTTPRequestURL,
    error: Error,
    contextID: MockContextIdentifier? = nil
  ) {
    stub(matching: .url(url), response: .failure(error), contextID: contextID)
  }

  /// Stub a URL with timeout.
  /// - Parameters:
  ///   - url: The URL to match.
  ///   - contextID: Isolates stubs to a specific test session.
  public static func stubTimeout(url: HTTPRequestURL, contextID: MockContextIdentifier? = nil) {
    stub(matching: .url(url), response: .timeout, contextID: contextID)
  }

  /// Stub a URL pattern with regex matching.
  /// - Parameters:
  ///   - pattern: Regular expression pattern to match URLs
  ///   - response: The mock response to return
  ///   - contextID: Isolates stubs to a specific test session.
  /// - Throws: A regular-expression parsing error for an invalid pattern.
  public static func stubPattern(
    _ pattern: MockURLPattern,
    response: MockResponse,
    contextID: MockContextIdentifier? = nil
  ) throws {
    let regex = try NSRegularExpression(pattern: pattern.rawValue, options: [])
    stub(matching: .urlPattern(regex), response: response, contextID: contextID)
  }

  /// Stub multiple URLs with the same response.
  /// - Parameters:
  ///   - urls: Array of URLs to stub
  ///   - response: The mock response for all URLs
  ///   - contextID: Isolates stubs to a specific test session.
  public static func stubMultiple(
    urls: [HTTPRequestURL],
    response: MockResponse,
    contextID: MockContextIdentifier? = nil
  ) {
    for url in urls {
      stub(matching: .url(url), response: response, contextID: contextID)
    }
  }

  /// Stub a REST API endpoint with different methods.
  /// - Parameters:
  ///   - baseURL: Base URL for the endpoint
  ///   - path: Path component
  ///   - getResponse: Response for GET requests
  ///   - postResponse: Response for POST requests
  ///   - putResponse: Response for PUT requests
  ///   - deleteResponse: Response for DELETE requests
  ///   - contextID: Isolates stubs to a specific test session.
  public static func stubRESTEndpoint(
    baseURL: HTTPRequestURL,
    path: MockRequestPath,
    getResponse: MockResponse? = nil,
    postResponse: MockResponse? = nil,
    putResponse: MockResponse? = nil,
    deleteResponse: MockResponse? = nil,
    contextID: MockContextIdentifier? = nil
  ) {
    let fullURLString =
      baseURL.rawValue.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      + path.rawValue
    let fullURL = HTTPRequestURL(URL(string: fullURLString)!)

    if let response = getResponse {
      stub(matching: .url(fullURL), .method(.get), response: response, contextID: contextID)
    }
    if let response = postResponse {
      stub(matching: .url(fullURL), .method(.post), response: response, contextID: contextID)
    }
    if let response = putResponse {
      stub(matching: .url(fullURL), .method(.put), response: response, contextID: contextID)
    }
    if let response = deleteResponse {
      stub(matching: .url(fullURL), .method(.delete), response: response, contextID: contextID)
    }
  }

  /// Stub with sequential responses (different response for each call).
  /// - Parameters:
  ///   - url: The URL to match
  ///   - responses: Array of responses to return in sequence
  ///   - contextID: Isolates stubs to a specific test session.
  public static func stubSequential(
    url: HTTPRequestURL,
    responses: [MockResponse],
    contextID: MockContextIdentifier? = nil
  ) {
    for response in responses {
      stub(
        matching: .url(url),
        response: response,
        maxUsageCount: 1,
        contextID: contextID
      )
    }
  }
}
