import SwiftSyntax

enum APIAccessLevel: String {
  case `public`
  case package
  case `internal`
  case `fileprivate`
  case `private`

  init?(modifiers: DeclModifierListSyntax) {
    for modifier in modifiers {
      if let accessLevel = Self(rawValue: modifier.name.text) {
        self = accessLevel
        return
      }
    }
    return nil
  }

  var sourcePrefix: String { "\(rawValue) " }

  var peerAccessLevel: Self {
    self == .private ? .fileprivate : self
  }

  var keyword: Keyword {
    switch self {
    case .fileprivate:
      .fileprivate
    case .internal:
      .internal
    case .package:
      .package
    case .private:
      .private
    case .public:
      .public
    }
  }
}
