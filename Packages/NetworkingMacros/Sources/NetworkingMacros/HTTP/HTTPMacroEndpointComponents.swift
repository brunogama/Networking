struct HTTPMacroEndpointComponents {
  let bodyParameter: String?
  let queryParameters: [String]
  let headers: [ParsedHeader]
  let returnType: String
}
