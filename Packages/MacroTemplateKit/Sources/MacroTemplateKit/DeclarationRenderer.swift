import SwiftSyntax
import SwiftSyntaxBuilder

/// Declaration-level rendering utilities.
///
/// Provides pure functions to transform `Declaration<A>` templates into SwiftSyntax
/// declaration nodes (`DeclSyntax`). Declaration rendering is the top-level transformation
/// layer for complete Swift declarations (functions, properties, extensions, structs).
extension Renderer {
  // MARK: - Declaration Rendering

  /// Renders a Declaration to SwiftSyntax DeclSyntax.
  ///
  /// Converts declaration-level templates to complete Swift declarations. The rendering process:
  /// - Translates each Declaration case to corresponding SwiftSyntax declaration node
  /// - Handles functions, properties, computed properties, extensions, and structs
  /// - Recursively renders statement bodies and nested declarations
  ///
  /// - Parameter declaration: Declaration to render
  /// - Returns: SwiftSyntax declaration node
  public static func render<A: Sendable>(_ declaration: Declaration<A>) -> DeclSyntax {
    switch declaration {
    case .function(let sig):
      return DeclSyntax(renderFunction(sig))

    case .property(let sig):
      return DeclSyntax(renderProperty(sig))

    case .computedProperty(let sig):
      return DeclSyntax(renderComputedProperty(sig))

    case .extensionDecl(let sig):
      return DeclSyntax(renderExtension(sig))

    case .structDecl(let sig):
      return DeclSyntax(renderStruct(sig))
    }
  }

  // MARK: - Private Declaration Helpers

  private static func renderFunction<A: Sendable>(_ sig: FunctionSignature<A>) -> FunctionDeclSyntax {
    let params = sig.parameters.map { param -> FunctionParameterSyntax in
      let firstName = param.label.map { TokenSyntax.identifier($0) } ?? .identifier(param.name)
      let secondName = param.label != nil ? TokenSyntax.identifier(param.name) : nil

      return FunctionParameterSyntax(
        firstName: firstName,
        secondName: secondName,
        type: TypeSyntax(stringLiteral: param.isInout ? "inout \(param.type)" : param.type)
      )
    }

    let parameterClause = FunctionParameterClauseSyntax(
      parameters: FunctionParameterListSyntax(params)
    )

    var effectSpecifiers: FunctionEffectSpecifiersSyntax?
    if sig.isAsync || sig.canThrow {
      effectSpecifiers = FunctionEffectSpecifiersSyntax(
        asyncSpecifier: sig.isAsync ? .keyword(.async) : nil,
        throwsClause: sig.canThrow ? ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws)) : nil
      )
    }

    let returnClause = sig.returnType.map { type in
      ReturnClauseSyntax(type: TypeSyntax(stringLiteral: type))
    }

    let signature = FunctionSignatureSyntax(
      parameterClause: parameterClause,
      effectSpecifiers: effectSpecifiers,
      returnClause: returnClause
    )

    let body = CodeBlockSyntax(statements: renderStatements(sig.body))

    return FunctionDeclSyntax(
      name: .identifier(sig.name),
      signature: signature,
      body: body
    )
  }

  private static func renderProperty<A: Sendable>(_ sig: PropertySignature<A>) -> VariableDeclSyntax {
    var modifiers = DeclModifierListSyntax([])
    if sig.isStatic {
      modifiers = DeclModifierListSyntax([DeclModifierSyntax(name: .keyword(.static))])
    }

    let pattern = IdentifierPatternSyntax(identifier: .identifier(sig.name))
    let typeAnnotation = sig.type.map { TypeAnnotationSyntax(type: TypeSyntax(stringLiteral: $0)) }
    let initializer = sig.initializer.map { InitializerClauseSyntax(value: render($0)) }

    let binding = PatternBindingSyntax(
      pattern: PatternSyntax(pattern),
      typeAnnotation: typeAnnotation,
      initializer: initializer
    )

    return VariableDeclSyntax(
      modifiers: modifiers,
      bindingSpecifier: sig.isLet ? .keyword(.let) : .keyword(.var),
      bindings: PatternBindingListSyntax([binding])
    )
  }

  private static func renderComputedProperty<A: Sendable>(
    _ sig: ComputedPropertySignature<A>
  ) -> VariableDeclSyntax {
    var modifiers = DeclModifierListSyntax([])
    if sig.isStatic {
      modifiers = DeclModifierListSyntax([DeclModifierSyntax(name: .keyword(.static))])
    }

    let getterBody = CodeBlockSyntax(statements: renderStatements(sig.getter))
    let getter = AccessorDeclSyntax(
      accessorSpecifier: .keyword(.get),
      body: getterBody
    )

    var accessors: AccessorDeclListSyntax
    if let setterSig = sig.setter {
      let setterBody = CodeBlockSyntax(statements: renderStatements(setterSig.body))
      let setter = AccessorDeclSyntax(
        accessorSpecifier: .keyword(.set),
        parameters: AccessorParametersSyntax(
          name: .identifier(setterSig.parameterName)
        ),
        body: setterBody
      )
      accessors = AccessorDeclListSyntax([getter, setter])
    } else {
      accessors = AccessorDeclListSyntax([getter])
    }

    let pattern = IdentifierPatternSyntax(identifier: .identifier(sig.name))
    let typeAnnotation = TypeAnnotationSyntax(type: TypeSyntax(stringLiteral: sig.type))

    let binding = PatternBindingSyntax(
      pattern: PatternSyntax(pattern),
      typeAnnotation: typeAnnotation,
      accessorBlock: AccessorBlockSyntax(accessors: .accessors(accessors))
    )

    return VariableDeclSyntax(
      modifiers: modifiers,
      bindingSpecifier: .keyword(.var),
      bindings: PatternBindingListSyntax([binding])
    )
  }

  private static func renderExtension<A: Sendable>(_ sig: ExtensionSignature<A>) -> ExtensionDeclSyntax {
    let inheritanceClause: InheritanceClauseSyntax? = sig.conformances.isEmpty ? nil : {
      let types = sig.conformances.map { conformance in
        InheritedTypeSyntax(type: TypeSyntax(stringLiteral: conformance))
      }
      return InheritanceClauseSyntax(inheritedTypes: InheritedTypeListSyntax(types))
    }()

    let members = MemberBlockItemListSyntax(
      sig.members.map { member in
        MemberBlockItemSyntax(decl: render(member))
      }
    )

    return ExtensionDeclSyntax(
      extendedType: TypeSyntax(stringLiteral: sig.typeName),
      inheritanceClause: inheritanceClause,
      memberBlock: MemberBlockSyntax(members: members)
    )
  }

  private static func renderStruct<A: Sendable>(_ sig: StructSignature<A>) -> StructDeclSyntax {
    let inheritanceClause: InheritanceClauseSyntax? = sig.conformances.isEmpty ? nil : {
      let types = sig.conformances.map { conformance in
        InheritedTypeSyntax(type: TypeSyntax(stringLiteral: conformance))
      }
      return InheritanceClauseSyntax(inheritedTypes: InheritedTypeListSyntax(types))
    }()

    let members = MemberBlockItemListSyntax(
      sig.members.map { member in
        MemberBlockItemSyntax(decl: render(member))
      }
    )

    return StructDeclSyntax(
      name: .identifier(sig.name),
      inheritanceClause: inheritanceClause,
      memberBlock: MemberBlockSyntax(members: members)
    )
  }
}
