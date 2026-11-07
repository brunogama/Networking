import SwiftSyntax
import SwiftSyntaxMacros

extension RequestModelMacro {
  static func validate(
    properties: [RequestModelProperty],
    context: some MacroExpansionContext
  ) -> Bool {
    validateHeaders(properties.headers, context: context)
      && validateBodyKeys(properties.body, context: context)
  }

  static func validateHeaders(
    _ headers: [RequestModelProperty],
    context: some MacroExpansionContext
  ) -> Bool {
    var names: Set<String> = []
    for header in headers {
      guard validHeaderName(header.key), names.insert(header.key.lowercased()).inserted else {
        MacroHelpers.emitError(
          "@Header names must be nonempty, contain no CR or LF, and be unique",
          id: .requestModelInvalidHeader,
          node: header.name,
          context: context
        )
        return false
      }
    }
    return true
  }

  static func validHeaderName(_ name: String) -> Bool {
    !name.isEmpty && !name.contains("\r") && !name.contains("\n")
  }

  static func validateBodyKeys(
    _ body: [RequestModelProperty],
    context: some MacroExpansionContext
  ) -> Bool {
    var keys: Set<String> = []
    for field in body where !keys.insert(field.key).inserted {
      MacroHelpers.emitError(
        "@Body keys must be unique within one request model",
        id: .requestModelDuplicateBodyKey,
        node: field.name,
        context: context
      )
      return false
    }
    return true
  }
}
