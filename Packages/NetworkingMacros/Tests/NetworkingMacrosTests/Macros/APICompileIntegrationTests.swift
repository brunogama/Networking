import Networking
import NetworkingTesting
import Testing

@Test("Generated paths preserve literal quotes and backslashes around interpolation")
func escapedEndpointPathCompilesAndExecutes() async throws {
  let expected = MacroCompileUser(id: 42, name: "Literal path")
  let codec = JSONCodec()
  let client = MockNetworkClient(codec: codec)
  await client.expect(
    matching: .method(.get),
    response: .success(statusCode: 200, data: HTTPBody(try codec.encode(expected))),
    calls: .exactly(1)
  )

  let api = MacroCompileUsersAPIFactory.make(client: client, codec: codec)
  #expect(try await api.escapedPath(id: 42) == expected)
  let request = try #require(await client.getRequestHistory().first)
  #expect(request.url.description == "https://api.example.com/files/a%22b%5Cc/42")
  try await client.verifyExpectations()
}

@Test("@API and all HTTP methods compile and execute against Networking")
func apiAndHTTPMethodsCompileAndExecute() async throws {
  let expected = MacroCompileUser(id: 42, name: "Blob")
  let created = MacroCompileUser(id: 43, name: "Glob")
  let replaced = MacroCompileUser(id: 43, name: "Globby")
  let updated = MacroCompileUser(id: 43, name: "Globster")
  let codec = JSONCodec()
  let client = MockNetworkClient(codec: codec)
  try await client.stubGET(path: "/users/42", json: expected)
  try await stubWriteResponses(
    [(.post, created), (.put, replaced), (.patch, updated)],
    client: client,
    codec: codec
  )
  await client.expect(
    matching: .method(.delete),
    .path("/users/42"),
    response: .success(statusCode: 204, data: HTTPBody(Data())),
    calls: .exactly(1)
  )

  let api = MacroCompileUsersAPIFactory.make(client: client)
  let actual = try await api.user(id: 42)
  let createResult = try await api.create(user: expected, notify: true)
  let replaceResult = try await api.replace(id: 43, with: created)
  let updateResult = try await api.update(id: 43, with: replaced)
  try await api.delete(id: 42)

  #expect(actual == expected)
  #expect(createResult == created)
  #expect(replaceResult == replaced)
  #expect(updateResult == updated)
  try await client.verifyExpectations()

  try verifyCompiledRequests(await client.getRequestHistory(), expected: expected)
}

private func stubWriteResponses(
  _ replies: [(HTTPMethod, MacroCompileUser)],
  client: MockNetworkClient,
  codec: JSONCodec
) async throws {
  for (method, user) in replies {
    let path: MockRequestPath = method == .post ? "/users" : "/users/43"
    let status: HTTPStatusCode = method == .post ? 201 : 200
    await client.expect(
      matching: .method(method),
      .path(path),
      response: .success(statusCode: status, data: HTTPBody(try codec.encode(user))),
      calls: .exactly(1)
    )
  }
}

private func verifyCompiledRequests(
  _ requests: [HTTPRequest],
  expected: MacroCompileUser
) throws {
  #expect(requests.map(\.method) == [.get, .post, .put, .patch, .delete])
  #expect(
    requests.map(\.url.description) == [
      "https://api.example.com/users/42",
      "https://api.example.com/users?notify=true",
      "https://api.example.com/users/43",
      "https://api.example.com/users/43",
      "https://api.example.com/users/42",
    ]
  )

  let createRequest = try #require(requests.dropFirst().first)
  let body = try #require(createRequest.body)
  #expect(try JSONDecoder().decode(MacroCompileUser.self, from: body.rawValue) == expected)
}
