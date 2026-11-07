import Testing
@testable import NetworkingMacrosPlugin

struct HTTPMethodMacroTests {
  @Test(arguments: ["GET", "POST", "PUT", "PATCH", "DELETE"])
  func generatesRequestAndCodecCalls(method: String) throws {
    let macro = try #require(httpTestMacros[method])
    let hasBody = ["POST", "PUT", "PATCH"].contains(method)
    let bodyAttribute = hasBody ? "@Body(.parameter(\"payload\"))" : ""
    let expansion = try expandPeer(
      macro,
      source: """
        @\(method)(.path("/projects/{project}/items/{id}"), queryParameters: [.parameter("page")])
        \(bodyAttribute)
        func item(project: String, id: Int, payload: Item, page: Int?) async throws -> Item
        """
    )
    #expect(expansion.messages.isEmpty)
    #expect(expansion.declarations.count == 1)
    #expect(expansion.source.contains("method: .\(method.lowercased())"))
    #expect(expansion.source.contains(#"let path = "/projects/\(project)/items/\(id)""#))
    #expect(expansion.source.contains("if let page"))
    #expect(expansion.source.contains(#"try request.addQueryParameter(name: "page", value: page)"#))
    #expect(expansion.source.contains("try await client.execute(request)"))
    #expect(expansion.source.contains("try codec.decode(Item.self, from: responseBody.rawValue)"))
    #expect(expansion.source.contains("try codec.encode(payload)") == hasBody)
  }

  @Test(arguments: ["GET", "POST", "PUT", "PATCH", "DELETE"], ["async", "throws"])
  func requiresAsyncThrows(method: String, missing: String) throws {
    let macro = try #require(httpTestMacros[method])
    let effects = missing == "async" ? "throws" : "async"
    let expansion = try expandPeer(
      macro,
      source: """
        @\(method)(.path("/items"))
        func item() \(effects) -> Item
        """
    )
    #expect(expansion.messages == ["Function 'item' must be marked '\(missing)'"])
  }

  @Test(arguments: ["GET", "POST", "PUT", "PATCH", "DELETE"])
  func requiresPath(method: String) throws {
    let macro = try #require(httpTestMacros[method])
    let expansion = try expandPeer(macro, source: "@\(method)\nfunc item() async throws -> Item")
    #expect(expansion.messages == ["@\(method) requires a path argument"])
    #expect(expansion.diagnostics.first?.node.positionAfterSkippingLeadingTrivia.utf8Offset == 0)
  }

  @Test(arguments: ["POST", "PUT", "PATCH"])
  func requiresBody(method: String) throws {
    let macro = try #require(httpTestMacros[method])
    let expansion = try expandPeer(
      macro,
      source: """
        @\(method)(.path("/items"))
        func item(payload: Item) async throws -> Item
        """
    )
    #expect(expansion.messages.count == 1)
    #expect(expansion.messages.first?.contains("requires a body parameter") == true)
  }

  @Test(arguments: ["GET", "POST", "PUT", "PATCH", "DELETE"])
  func rejectsUnknownPathParameter(method: String) throws {
    let macro = try #require(httpTestMacros[method])
    let expansion = try expandPeer(
      macro,
      source: """
        @\(method)(.path("/items/{missing}"))
        @Body(.parameter("payload"))
        func item(payload: Item) async throws -> Item
        """
    )
    #expect(expansion.messages.count == 1)
    #expect(expansion.messages.first?.contains("Path parameter mismatch") == true)
  }

  @Test(arguments: ["", " -> Void", " -> ()"])
  func deleteWithoutResponseBody(returnClause: String) throws {
    let expansion = try expandPeer(
      DELETEMacro.self,
      source: """
        @DELETE(.path("/items/{id}"))
        func remove(id: Int) async throws\(returnClause)
        """
    )
    #expect(expansion.messages.isEmpty)
    #expect(expansion.source.contains("_ = try await client.execute(request)"))
    #expect(!expansion.source.contains("codec.decode"))
  }

  @Test func rejectsUnknownQueryParameter() throws {
    let expansion = try expandPeer(
      GETMacro.self,
      source: """
        @GET(.path("/items"), queryParameters: [.parameter("missing")])
        func items() async throws -> [Item]
        """
    )
    #expect(expansion.messages.first?.contains("Query parameter 'missing' not found") == true)
  }

  @Test(arguments: ["/items/{id", "/items/{}"])
  func rejectsMalformedPaths(path: String) throws {
    let expansion = try expandPeer(
      GETMacro.self,
      source: """
        @GET(.path("\(path)"))
        func item(id: Int) async throws -> Item
        """
    )
    #expect(expansion.messages.first?.contains("Invalid path template") == true)
  }
}
