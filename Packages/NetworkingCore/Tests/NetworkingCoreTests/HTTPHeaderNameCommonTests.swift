import NetworkingCore
import Testing

@Test("Common header names retain their canonical spelling")
func commonHeaderNamesRetainCanonicalSpelling() {
  #expect(HTTPHeaderName.authorization.rawValue == "Authorization")
  #expect(HTTPHeaderName.contentType.rawValue == "Content-Type")
  #expect(HTTPHeaderName.ifNoneMatch.rawValue == "If-None-Match")
  #expect(HTTPHeaderName.userAgent.rawValue == "User-Agent")
}
