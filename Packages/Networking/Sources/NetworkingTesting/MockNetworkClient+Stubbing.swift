import NetworkingCore

extension MockNetworkClient {

  public func stubGET(path: MockRequestPath, response: HTTPBody, statusCode: HTTPStatusCode = 200) {
    expect(
      matching: .method(.get),
      .path(path),
      response: .success(statusCode: statusCode, data: response)
    )
  }

  public func stubGET<Value: Encodable & Sendable>(
    path: MockRequestPath,
    json: Value,
    statusCode: HTTPStatusCode = 200
  ) throws {
    let response = MockURLProtocol.MockResponse.success(
      statusCode: statusCode,
      data: HTTPBody(try codec.encode(json)),
      headers: ["Content-Type": "application/json"]
    )
    expect(matching: .method(.get), .path(path), response: response)
  }

  public func stubPOST(path: MockRequestPath, response: HTTPBody, statusCode: HTTPStatusCode = 201)
  {
    expect(
      matching: .method(.post),
      .path(path),
      response: .success(statusCode: statusCode, data: response)
    )
  }

}
