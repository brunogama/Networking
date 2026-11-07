import SwiftSyntax
import SwiftSyntaxBuilder

extension RequestModelMacro {
  static func headersProperty(
    for properties: [RequestModelProperty],
    access: DeclModifierListSyntax
  ) -> VariableDeclSyntax {
    RequestModelSyntaxFactory.computedProperty(
      modifiers: access,
      name: "headers",
      type: RequestModelSyntaxFactory.namedType("HTTPHeaders"),
      expression: ExprSyntax(headerDictionary(for: properties))
    )
  }

  static func headerDictionary(for properties: [RequestModelProperty]) -> DictionaryExprSyntax {
    DictionaryExprSyntax {
      for property in properties {
        DictionaryElementSyntax(key: headerName(property), value: headerValue(property))
      }
    }
  }

  static func headerName(_ property: RequestModelProperty) -> ExprSyntax {
    ExprSyntax(
      RequestModelSyntaxFactory.call(
        ExprSyntax(RequestModelSyntaxFactory.identifier("HTTPHeaderName")),
        arguments: LabeledExprListSyntax {
          LabeledExprSyntax(expression: StringLiteralExprSyntax(content: property.key))
        }
      )
    )
  }

  static func headerValue(_ property: RequestModelProperty) -> ExprSyntax {
    ExprSyntax(
      RequestModelSyntaxFactory.call(
        ExprSyntax(RequestModelSyntaxFactory.identifier("HTTPHeaderValue")),
        arguments: LabeledExprListSyntax {
          LabeledExprSyntax(expression: descriptiveValue(for: property))
        }
      )
    )
  }

  static func descriptiveValue(for property: RequestModelProperty) -> ExprSyntax {
    ExprSyntax(
      RequestModelSyntaxFactory.call(
        ExprSyntax(RequestModelSyntaxFactory.identifier("String")),
        arguments: LabeledExprListSyntax {
          LabeledExprSyntax(
            label: .identifier("describing"),
            colon: .colonToken(),
            expression: RequestModelSyntaxFactory.member(
              RequestModelStorage.headerValues.identifier,
              property.name
            )
          )
        }
      )
    )
  }

  static func bodyFunction(access: DeclModifierListSyntax) -> FunctionDeclSyntax {
    FunctionDeclSyntax(
      modifiers: access,
      name: .identifier("body"),
      signature: bodySignature(),
      body: RequestModelSyntaxFactory.codeBlock(StmtSyntax(bodyReturnStatement()))
    )
  }

  static func bodySignature() -> FunctionSignatureSyntax {
    FunctionSignatureSyntax(
      parameterClause: FunctionParameterClauseSyntax(
        parameters: FunctionParameterListSyntax {
          FunctionParameterSyntax(
            firstName: .identifier("using"),
            secondName: .identifier("codec"),
            colon: .colonToken(),
            type: RequestModelSyntaxFactory.namedType("JSONCodec")
          )
        }
      ),
      effectSpecifiers: FunctionEffectSpecifiersSyntax(
        throwsClause: ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))
      ),
      returnClause: ReturnClauseSyntax(
        type: OptionalTypeSyntax(wrappedType: RequestModelSyntaxFactory.namedType("HTTPBody"))
      )
    )
  }

  static func bodyReturnStatement() -> ReturnStmtSyntax {
    ReturnStmtSyntax(
      expression: TryExprSyntax(
        expression: RequestModelSyntaxFactory.call(
          ExprSyntax(RequestModelSyntaxFactory.identifier("HTTPBody")),
          arguments: LabeledExprListSyntax {
            LabeledExprSyntax(expression: encodedPayload())
          }
        )
      )
    )
  }

  static func encodedPayload() -> ExprSyntax {
    ExprSyntax(
      RequestModelSyntaxFactory.call(
        ExprSyntax(
          RequestModelSyntaxFactory.member(
            ExprSyntax(RequestModelSyntaxFactory.identifier("codec")),
            "encode"
          )
        ),
        arguments: LabeledExprListSyntax {
          LabeledExprSyntax(
            expression: DeclReferenceExprSyntax(baseName: RequestModelStorage.payload.identifier)
          )
        }
      )
    )
  }

  static func initializer(
    for properties: [RequestModelProperty],
    access: DeclModifierListSyntax
  ) -> InitializerDeclSyntax {
    InitializerDeclSyntax(
      modifiers: access,
      signature: initializerSignature(for: properties),
      body: initializerBody(for: properties)
    )
  }

  static func initializerSignature(
    for properties: [RequestModelProperty]
  ) -> FunctionSignatureSyntax {
    FunctionSignatureSyntax(
      parameterClause: FunctionParameterClauseSyntax(
        parameters: FunctionParameterListSyntax {
          for property in properties {
            FunctionParameterSyntax(
              firstName: property.name,
              colon: .colonToken(),
              type: property.type
            )
          }
        }
      )
    )
  }

  static func initializerBody(for properties: [RequestModelProperty]) -> CodeBlockSyntax {
    CodeBlockSyntax(
      statements: CodeBlockItemListSyntax {
        if !properties.headers.isEmpty {
          assignment(storage: .headerValues, properties: properties.headers)
        }
        if !properties.body.isEmpty { assignment(storage: .payload, properties: properties.body) }
      }
    )
  }

  static func assignment(
    storage: RequestModelStorage,
    properties: [RequestModelProperty]
  ) -> CodeBlockItemSyntax {
    CodeBlockItemSyntax(
      item: .expr(
        ExprSyntax(
          SequenceExprSyntax(
            elements: ExprListSyntax {
              RequestModelSyntaxFactory.member(.keyword(.self), storage.identifier)
              AssignmentExprSyntax()
              RequestModelSyntaxFactory.call(
                ExprSyntax(RequestModelSyntaxFactory.identifier(storage.typeName)),
                arguments: LabeledExprListSyntax {
                  for property in properties {
                    LabeledExprSyntax(
                      label: property.name,
                      colon: .colonToken(),
                      expression: DeclReferenceExprSyntax(baseName: property.name)
                    )
                  }
                }
              )
            }
          )
        )
      )
    )
  }
}
