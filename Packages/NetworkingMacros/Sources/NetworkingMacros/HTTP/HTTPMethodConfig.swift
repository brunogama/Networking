enum HTTPMethodConfig: String, Sendable {
  case get = "GET"
  case post = "POST"
  case put = "PUT"
  case patch = "PATCH"
  case delete = "DELETE"

  var method: String { rawValue }
  var requiresBody: Bool { self == .post || self == .put || self == .patch }
  var allowsVoidReturn: Bool { self == .delete }
}
