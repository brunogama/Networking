import SwiftSyntax
import SwiftSyntaxMacros

extension RequestModelMacro {
  static func emitRequiresStruct(
    node: AttributeSyntax,
    context: some MacroExpansionContext
  ) -> [DeclSyntax] {
    MacroHelpers.emitError(
      "@RequestModel can only be applied to a struct",
      id: .requestModelRequiresStruct,
      node: node,
      context: context
    )
    return []
  }

  static func hasResponseAlias(
    in structure: StructDeclSyntax,
    context: some MacroExpansionContext
  ) -> Bool {
    let hasAlias = structure.memberBlock.members.contains {
      $0.decl.as(TypeAliasDeclSyntax.self)?.name.text == "Response"
    }
    guard !hasAlias else { return true }
    MacroHelpers.emitError(
      "@RequestModel requires 'typealias Response = YourResponse'",
      id: .requestModelRequiresResponse,
      node: structure,
      context: context
    )
    return false
  }

  static func properties(
    in structure: StructDeclSyntax,
    context: some MacroExpansionContext
  ) -> [RequestModelProperty] {
    structure.memberBlock.members.flatMap { member -> [RequestModelProperty] in
      guard let variable = member.decl.as(VariableDeclSyntax.self) else { return [] }
      return properties(in: variable, context: context)
    }
  }

  static func properties(
    in variable: VariableDeclSyntax,
    context: some MacroExpansionContext
  ) -> [RequestModelProperty] {
    RequestModelProperty.Kind.allCases.compactMap {
      property(kind: $0, variable: variable, context: context)
    }
  }

  static func property(
    kind: RequestModelProperty.Kind,
    variable: VariableDeclSyntax,
    context: some MacroExpansionContext
  ) -> RequestModelProperty? {
    guard let attribute = attribute(named: kind.attributeName, in: variable) else { return nil }
    guard let binding = validBinding(in: variable) else {
      emitInvalidProperty(attribute: attribute, variable: variable, context: context)
      return nil
    }
    let key = key(from: attribute) ?? binding.name.text
    return RequestModelProperty(kind: kind, name: binding.name, type: binding.type, key: key)
  }

  static func validBinding(
    in variable: VariableDeclSyntax
  ) -> (name: TokenSyntax, type: TypeSyntax)? {
    guard variable.bindingSpecifier.text == "var", variable.bindings.count == 1,
      let binding = variable.bindings.first, binding.initializer == nil,
      let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier,
      let type = binding.typeAnnotation?.type
    else { return nil }
    return (name, type)
  }

  static func emitInvalidProperty(
    attribute: AttributeSyntax,
    variable: VariableDeclSyntax,
    context: some MacroExpansionContext
  ) {
    let name = attribute.attributeName.trimmedDescription
    MacroHelpers.emitError(
      "@\(name) requires one uninitialized 'var' property with an explicit type",
      id: .requestModelInvalidProperty,
      node: variable,
      context: context
    )
  }

  static func attribute(named name: String, in variable: VariableDeclSyntax) -> AttributeSyntax? {
    variable.attributes.compactMap { $0.as(AttributeSyntax.self) }.first {
      $0.attributeName.as(IdentifierTypeSyntax.self)?.name.text == name
    }
  }

  static func key(from attribute: AttributeSyntax) -> String? {
    guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
      let expression = arguments.first?.expression
    else { return nil }
    return BoundaryExpressionParser.string(from: expression)
  }
}
