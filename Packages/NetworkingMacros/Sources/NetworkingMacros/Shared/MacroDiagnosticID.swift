enum MacroDiagnosticID: String, Sendable {
  case apiRequiresProtocol
  case apiRequiresBaseURL
  case emptyBaseURL
  case invalidBaseURL
  case apiRequiresEndpointMethods
  case missingHTTPMethod
  case headersRequiresFunction
  case invalidHeaders
  case invalidHeaderValue
  case unknownHeaderParameter
  case invalidHeaderName
  case missingPath
  case timeoutRequiresProtocol
  case invalidTimeout
  case defaultHeadersRequiresProtocol
  case emptyDefaultHeaders
  case invalidDefaultHeaders
  case missingBodyParameter
  case missingReturnType
  case httpMethodRequiresFunction
  case requestModelDuplicateBodyKey
  case requestModelInvalidHeader
  case requestModelInvalidProperty
  case requestModelRequiresResponse
  case requestModelRequiresRoute
  case requestModelRequiresStruct
}
