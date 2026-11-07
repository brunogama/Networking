import SwiftSyntax

struct RequestModelProperty {
  enum Kind: CaseIterable {
    case body
    case header
  }

  let kind: Kind
  let name: TokenSyntax
  let type: TypeSyntax
  let key: String
}

extension RequestModelProperty.Kind {
  var attributeName: String {
    switch self {
    case .body:
      "Body"
    case .header:
      "Header"
    }
  }
}

extension Array where Element == RequestModelProperty {
  var body: [RequestModelProperty] { filter { $0.kind == .body } }

  var headers: [RequestModelProperty] { filter { $0.kind == .header } }
}
