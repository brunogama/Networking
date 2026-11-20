import SwiftSyntax
import SwiftSyntaxBuilder

extension RequestModelMacro {
  static func assignment(
    storage: RequestModelStorage,
    properties: [RequestModelProperty]
  ) -> CodeBlockItemSyntax {
    let expression = assignmentExpression(
      storage: storage,
      properties: properties
    )
    return CodeBlockItemSyntax(item: .expr(ExprSyntax(expression)))
  }

  private static func assignmentExpression(
    storage: RequestModelStorage,
    properties: [RequestModelProperty]
  ) -> SequenceExprSyntax {
    SequenceExprSyntax(
      elements: assignmentElements(storage: storage, properties: properties)
    )
  }

  private static func assignmentElements(
    storage: RequestModelStorage,
    properties: [RequestModelProperty]
  ) -> ExprListSyntax {
    ExprListSyntax {
      RequestModelSyntaxFactory.member(.keyword(.self), storage.identifier)
      AssignmentExprSyntax()
      payloadInitialization(storage: storage, properties: properties)
    }
  }

  private static func payloadInitialization(
    storage: RequestModelStorage,
    properties: [RequestModelProperty]
  ) -> FunctionCallExprSyntax {
    RequestModelSyntaxFactory.call(
      ExprSyntax(
        RequestModelSyntaxFactory.identifier(storage.typeName)
      ),
      arguments: initializationArguments(for: properties)
    )
  }

  private static func initializationArguments(
    for properties: [RequestModelProperty]
  ) -> LabeledExprListSyntax {
    LabeledExprListSyntax {
      for property in properties {
        LabeledExprSyntax(
          label: property.name,
          colon: .colonToken(),
          expression: DeclReferenceExprSyntax(
            baseName: property.name
          )
        )
      }
    }
  }
}
