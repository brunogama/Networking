import SwiftSyntax
import SwiftSyntaxBuilder

extension RequestModelMacro {
  static func declarations(
    for input: RequestModelInput,
    properties: [RequestModelProperty],
    structure: StructDeclSyntax
  ) -> [DeclSyntax] {
    let access = accessModifiers(for: structure)
    var declarations = endpointDeclarations(for: input, access: access)
    declarations += headerDeclarations(for: properties.headers, access: access)
    declarations += bodyDeclarations(for: properties.body, access: access)
    if !properties.isEmpty {
      declarations.append(DeclSyntax(initializer(for: properties, access: access)))
    }
    return declarations
  }

  static func endpointDeclarations(
    for input: RequestModelInput,
    access: DeclModifierListSyntax
  ) -> [DeclSyntax] {
    [
      DeclSyntax(
        RequestModelSyntaxFactory.computedProperty(
          modifiers: access,
          name: "method",
          type: RequestModelSyntaxFactory.namedType("HTTPMethod"),
          expression: input.method
        )
      ),
      DeclSyntax(
        RequestModelSyntaxFactory.computedProperty(
          modifiers: access,
          name: "path",
          type: RequestModelSyntaxFactory.qualifiedType(
            module: "NetworkingCore",
            name: "EndpointPath"
          ),
          expression: endpointPath(input.path)
        )
      ),
    ]
  }

  static func endpointPath(_ path: String) -> ExprSyntax {
    ExprSyntax(
      RequestModelSyntaxFactory.call(
        ExprSyntax(
          RequestModelSyntaxFactory.member(
            ExprSyntax(RequestModelSyntaxFactory.identifier("NetworkingCore")),
            "EndpointPath"
          )
        ),
        arguments: LabeledExprListSyntax {
          LabeledExprSyntax(expression: StringLiteralExprSyntax(content: path))
        }
      )
    )
  }

  static func headerDeclarations(
    for headers: [RequestModelProperty],
    access: DeclModifierListSyntax
  ) -> [DeclSyntax] {
    guard !headers.isEmpty else { return [] }
    return [
      DeclSyntax(headerValuesType(for: headers)),
      DeclSyntax(
        RequestModelSyntaxFactory.privateStoredProperty(
          storage: .headerValues,
          type: RequestModelSyntaxFactory.namedType("RequestModelHeaderValues")
        )
      ),
      DeclSyntax(headersProperty(for: headers, access: access)),
    ]
  }

  static func bodyDeclarations(
    for body: [RequestModelProperty],
    access: DeclModifierListSyntax
  ) -> [DeclSyntax] {
    guard !body.isEmpty else { return [] }
    return [
      DeclSyntax(payloadType(for: body)),
      DeclSyntax(
        RequestModelSyntaxFactory.privateStoredProperty(
          storage: .payload,
          type: RequestModelSyntaxFactory.namedType("RequestModelPayload")
        )
      ),
      DeclSyntax(bodyFunction(access: access)),
    ]
  }

  static func accessModifiers(for structure: StructDeclSyntax) -> DeclModifierListSyntax {
    guard let access = APIAccessLevel(modifiers: structure.modifiers) else { return [] }
    return DeclModifierListSyntax {
      DeclModifierSyntax(name: .keyword(access.keyword))
    }
  }
}
