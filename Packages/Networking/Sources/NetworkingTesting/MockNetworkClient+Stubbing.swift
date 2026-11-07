import NetworkingCore

extension MockNetworkClient {
  /// Registers a GET response that must be requested at least once.
  public func stubGET(path: MockRequestPath, response: HTTPBody, statusCode: HTTPStatusCode = 200) {
    expect(
      matching: .method(.get),
      .path(path),
      response: .success(statusCode: statusCode, data: response)
    )
  }

  /// Encodes a GET response using this client's codec and requires at least one request.
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

  /// Registers a POST response that must be requested at least once.
  public func stubPOST(path: MockRequestPath, response: HTTPBody, statusCode: HTTPStatusCode = 201)
  {
    expect(
      matching: .method(.post),
      .path(path),
      response: .success(statusCode: statusCode, data: response)
    )
  }

}
