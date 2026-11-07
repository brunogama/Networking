import Foundation
import NetworkingCore

extension MockURLProtocol {

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

  public static func stubError(
    url: HTTPRequestURL,
    error: Error,
    contextID: MockContextIdentifier? = nil
  ) {
    stub(matching: .url(url), response: .failure(error), contextID: contextID)
  }

  public static func stubTimeout(url: HTTPRequestURL, contextID: MockContextIdentifier? = nil) {
    stub(matching: .url(url), response: .timeout, contextID: contextID)
  }

  public static func stubPattern(
    _ pattern: MockURLPattern,
    response: MockResponse,
    contextID: MockContextIdentifier? = nil
  ) throws {
    let regex = try NSRegularExpression(pattern: pattern.rawValue, options: [])
    stub(matching: .urlPattern(regex), response: response, contextID: contextID)
  }

  public static func stubMultiple(
    urls: [HTTPRequestURL],
    response: MockResponse,
    contextID: MockContextIdentifier? = nil
  ) {
    for url in urls {
      stub(matching: .url(url), response: response, contextID: contextID)
    }
  }

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
