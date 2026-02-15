import MacroTemplateKit
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

/// Generates a timing wrapper function for performance measurement.
///
/// Example:
/// ```swift
/// @Measured
/// func fetchUsers() async throws -> [User] {
///   return try await api.getUsers()
/// }
/// ```
///
/// Expands to:
/// ```swift
/// func fetchUsers_measured() async throws -> [User] {
///   let startTime = Date()
///   defer {
///     let duration = Date().timeIntervalSince(startTime)
///     Metrics.shared.record(duration: duration, operation: "fetchUsers")
///   }
///   return try await fetchUsers()
/// }
/// ```
public struct MeasuredMacro: PeerMacro {
  public static func expansion(
    of node: AttributeSyntax,
    providingPeersOf declaration: some DeclSyntaxProtocol,
    in context: some MacroExpansionContext
  ) throws -> [DeclSyntax] {
    // Verify applied to function
    guard let funcDecl = declaration.as(FunctionDeclSyntax.self) else {
      let diagnostic = Diagnostic(
        node: Syntax(node),
        message: ConfigurationMacroDiagnostic.measuredRequiresFunction
      )
      context.diagnose(diagnostic)
      return []
    }

    let funcName = funcDecl.name.text
    let metricName =
      MacroHelpers.extractStringValue(labeled: "name", from: node) ?? funcName
    let signature = funcDecl.signature

    // Extract parameters for FunctionSignature
    let parameters = signature.parameterClause.parameters.map { param in
      ParameterSignature(
        label: param.firstName.text == "_" ? "_" : param.firstName.text,
        name: param.secondName?.text ?? param.firstName.text,
        type: param.type.description.trimmingCharacters(in: .whitespaces),
        isInout: false
      )
    }

    // Extract function signature details
    let isAsync = signature.effectSpecifiers?.asyncSpecifier != nil
    let canThrow = signature.effectSpecifiers?.throwsClause != nil
    let returnType = signature.returnClause?.type.description.trimmingCharacters(in: .whitespaces)

    // Build function call arguments
    let callArguments: [(label: String?, value: Template<Void>)] = parameters.map { param in
      let label = param.label == "_" ? nil : param.label
      return (label: label, value: .variable(param.name, payload: ()))
    }

    // Create function body statements using Statement ADT
    let bodyStatements: [Statement<Void>] = [
      // let startTime = Date()
      .letBinding(
        name: "startTime",
        type: nil,
        initializer: .functionCall(function: "Date", arguments: [])
      ),
      // defer { ... }
      .deferStatement([
        // let duration = Date().timeIntervalSince(startTime)
        .letBinding(
          name: "duration",
          type: nil,
          initializer: .methodCall(
            base: .functionCall(function: "Date", arguments: []),
            method: "timeIntervalSince",
            arguments: [(label: nil, value: .variable("startTime", payload: ()))]
          )
        ),
        // Metrics.shared.record(duration: duration, operation: metricName)
        .expression(
          .methodCall(
            base: .propertyAccess(
              base: .variable("Metrics", payload: ()),
              property: "shared"
            ),
            method: "record",
            arguments: [
              (label: "duration", value: .variable("duration", payload: ())),
              (label: "operation", value: .literal(.string(metricName))),
            ]
          )
        ),
      ]),
      // return try await funcName(...)
      .returnStatement(
        .functionCall(
          function: funcName,
          arguments: callArguments
        )
      ),
    ]

    // Create wrapper function declaration
    let wrapperDeclaration = Declaration<Void>.function(
      FunctionSignature<Void>(
        name: "\(funcName)_measured",
        parameters: parameters,
        isAsync: isAsync,
        canThrow: canThrow,
        returnType: returnType,
        body: bodyStatements
      )
    )

    // Render to DeclSyntax
    let wrapperCode = Renderer.render(wrapperDeclaration)

    return [wrapperCode]
  }
}
