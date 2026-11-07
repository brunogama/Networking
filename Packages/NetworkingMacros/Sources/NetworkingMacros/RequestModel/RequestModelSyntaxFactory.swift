import SwiftSyntax
import SwiftSyntaxBuilder

enum RequestModelSyntaxFactory {
  static func getter(
    from storage: RequestModelStorage,
    property: TokenSyntax
  ) -> AccessorDeclSyntax {
    AccessorDeclSyntax(
      accessorSpecifier: .keyword(.get),
      body: codeBlock(ExprSyntax(member(storage.identifier, property)))
    )
  }

  static func storedProperty(
    name: TokenSyntax,
    type: TypeSyntax
  ) -> VariableDeclSyntax {
    VariableDeclSyntax(bindingSpecifier: .keyword(.let)) {
      PatternBindingSyntax(
        pattern: IdentifierPatternSyntax(identifier: name),
        typeAnnotation: TypeAnnotationSyntax(type: type)
      )
    }
  }

  static func privateStoredProperty(
    storage: RequestModelStorage,
    type: TypeSyntax
  ) -> VariableDeclSyntax {
    VariableDeclSyntax(
      modifiers: privateModifiers,
      bindingSpecifier: .keyword(.let)
    ) {
      PatternBindingSyntax(
        pattern: IdentifierPatternSyntax(identifier: storage.identifier),
        typeAnnotation: TypeAnnotationSyntax(type: type)
      )
    }
  }

  static func computedProperty(
    modifiers: DeclModifierListSyntax,
    name: String,
    type: TypeSyntax,
    expression: ExprSyntax
  ) -> VariableDeclSyntax {
    VariableDeclSyntax(modifiers: modifiers, bindingSpecifier: .keyword(.var)) {
      PatternBindingSyntax(
        pattern: IdentifierPatternSyntax(identifier: .identifier(name)),
        typeAnnotation: TypeAnnotationSyntax(type: type),
        accessorBlock: AccessorBlockSyntax(accessors: .getter(getterItems(expression)))
      )
    }
  }

  static func member(_ base: TokenSyntax, _ name: TokenSyntax) -> MemberAccessExprSyntax {
    MemberAccessExprSyntax(
      base: DeclReferenceExprSyntax(baseName: base),
      declName: DeclReferenceExprSyntax(baseName: name)
    )
  }

  static func member(_ base: ExprSyntax, _ name: String) -> MemberAccessExprSyntax {
    MemberAccessExprSyntax(
      base: base,
      declName: DeclReferenceExprSyntax(baseName: .identifier(name))
    )
  }

  static func call(
    _ callee: ExprSyntax,
    arguments: LabeledExprListSyntax = []
  ) -> FunctionCallExprSyntax {
    FunctionCallExprSyntax(
      calledExpression: callee,
      leftParen: .leftParenToken(),
      arguments: arguments,
      rightParen: .rightParenToken()
    )
  }

  static func codeBlock(_ expression: ExprSyntax) -> CodeBlockSyntax {
    CodeBlockSyntax(
      statements: CodeBlockItemListSyntax {
        CodeBlockItemSyntax(item: .expr(expression))
      }
    )
  }

  static func getterItems(_ expression: ExprSyntax) -> CodeBlockItemListSyntax {
    CodeBlockItemListSyntax {
      CodeBlockItemSyntax(item: .expr(expression))
    }
  }

  static func codeBlock(_ statement: StmtSyntax) -> CodeBlockSyntax {
    CodeBlockSyntax(
      statements: CodeBlockItemListSyntax {
        CodeBlockItemSyntax(item: .stmt(statement))
      }
    )
  }

  static func identifier(_ name: String) -> DeclReferenceExprSyntax {
    DeclReferenceExprSyntax(baseName: .identifier(name))
  }

  static func namedType(_ name: String) -> TypeSyntax {
    TypeSyntax(IdentifierTypeSyntax(name: .identifier(name)))
  }

  static func qualifiedType(module: String, name: String) -> TypeSyntax {
    TypeSyntax(
      MemberTypeSyntax(
        baseType: IdentifierTypeSyntax(name: .identifier(module)),
        name: .identifier(name)
      )
    )
  }

  static var privateModifiers: DeclModifierListSyntax {
    DeclModifierListSyntax {
      DeclModifierSyntax(name: .keyword(.private))
    }
  }
}
