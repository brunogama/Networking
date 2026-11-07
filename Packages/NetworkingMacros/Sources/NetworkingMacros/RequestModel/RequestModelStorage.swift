import SwiftSyntax

enum RequestModelStorage {
  case headerValues
  case payload

  var identifier: TokenSyntax {
    switch self {
    case .headerValues:
      .identifier("requestModelHeaderValues")
    case .payload:
      .identifier("requestModelPayload")
    }
  }

  var typeName: String {
    switch self {
    case .headerValues:
      "RequestModelHeaderValues"
    case .payload:
      "RequestModelPayload"
    }
  }
}
