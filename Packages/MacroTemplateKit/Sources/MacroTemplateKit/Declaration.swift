// MARK: - Supporting Types

/// Function parameter representation for declaration templates.
public struct FunctionParameter: Equatable, Hashable, Sendable {
  /// External parameter label (nil for unlabeled parameters)
  public let label: String?
  /// Internal parameter name
  public let name: String
  /// Parameter type annotation
  public let type: String

  public init(label: String? = nil, name: String, type: String) {
    self.label = label
    self.name = name
    self.type = type
  }
}

// MARK: - Declaration

/// Declaration-level code generation templates.
///
/// `Declaration<A>` enables generating full function declarations, extensions,
/// and properties using type-safe template composition without string interpolation.
///
/// The type parameter `A` represents metadata attached to nested templates,
/// allowing compile-time tracking of variable usage.
public indirect enum Declaration<A> {
  // MARK: - Function Declaration

  /// Function declaration with parameters, async/throws modifiers, return type, and body.
  ///
  /// Represents: `func name(params) async throws -> ReturnType { body }`
  ///
  /// SwiftSyntax equivalent: `FunctionDeclSyntax`
  case function(
    name: String,
    parameters: [FunctionParameter],
    isAsync: Bool,
    `throws`: Bool,
    returnType: String?,
    body: [Template<A>]
  )

  // MARK: - Property Declaration

  /// Stored property declaration with optional type annotation and initializer.
  ///
  /// Represents: `static? let/var name: Type = initializer`
  ///
  /// SwiftSyntax equivalent: `VariableDeclSyntax` with `PatternBindingSyntax`
  case property(
    name: String,
    type: String?,
    isStatic: Bool,
    isLet: Bool,
    initializer: Template<A>?
  )

  // MARK: - Computed Property

  /// Computed property with getter and optional setter.
  ///
  /// Represents: `static? var name: Type { get { } set { } }`
  ///
  /// SwiftSyntax equivalent: `VariableDeclSyntax` with `AccessorDeclSyntax`
  case computedProperty(
    name: String,
    type: String,
    isStatic: Bool,
    getter: [Template<A>],
    setter: [Template<A>]?
  )

  // MARK: - Extension

  /// Extension declaration containing member declarations.
  ///
  /// Represents: `extension TypeName { members }`
  ///
  /// SwiftSyntax equivalent: `ExtensionDeclSyntax` with `MemberBlockSyntax`
  case extensionDecl(
    typeName: String,
    members: [Declaration<A>]
  )
}

// MARK: - Functor

extension Declaration {
  /// Maps a transformation function over all template payloads, preserving structure.
  ///
  /// This operation satisfies functor laws:
  /// - Identity: `declaration.map { $0 } == declaration`
  /// - Composition: `declaration.map(f).map(g) == declaration.map { g(f($0)) }`
  ///
  /// Only nested `Template<A>` payloads are transformed; declaration structure remains unchanged.
  ///
  /// - Parameter transform: Function applied to each template payload
  /// - Returns: New declaration with transformed payloads and identical structure
  public func map<B>(_ transform: (A) -> B) -> Declaration<B> {
    switch self {
    case .function(let name, let params, let isAsync, let throwsFlag, let ret, let body):
      return .function(
        name: name,
        parameters: params,
        isAsync: isAsync,
        throws: throwsFlag,
        returnType: ret,
        body: body.map { $0.map(transform) }
      )
    case .property(let name, let type, let isStatic, let isLet, let initializer):
      return .property(
        name: name,
        type: type,
        isStatic: isStatic,
        isLet: isLet,
        initializer: initializer?.map(transform)
      )
    case .computedProperty(let name, let type, let isStatic, let getter, let setter):
      return .computedProperty(
        name: name,
        type: type,
        isStatic: isStatic,
        getter: getter.map { $0.map(transform) },
        setter: setter?.map { $0.map(transform) }
      )
    case .extensionDecl(let typeName, let members):
      return .extensionDecl(
        typeName: typeName,
        members: members.map { $0.map(transform) }
      )
    }
  }
}

// MARK: - Equatable

extension Declaration: Equatable where A: Equatable {}

// MARK: - Hashable

extension Declaration: Hashable where A: Hashable {}

// MARK: - Sendable

extension Declaration: Sendable where A: Sendable {}
