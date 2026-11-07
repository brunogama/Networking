/// Distinguishes the static strings accepted by networking macro arguments.
public struct MacroBoundaryString<Tag>: Sendable, Hashable {
  private let value: String

  private init(_ value: StaticString) {
    self.value = String(describing: value)
  }
}

extension MacroBoundaryString where Tag == HeaderNameTag {
  /// Names a header in a macro dictionary.
  public static func named(_ value: StaticString) -> Self { Self(value) }
}

extension MacroBoundaryString where Tag == HeaderValueReferenceTag {
  /// Uses the supplied literal as a header value.
  public static func literal(_ value: StaticString) -> Self { Self(value) }

  /// Uses the value of the named function parameter as a header value.
  public static func parameter(_ value: StaticString) -> Self { Self(value) }
}

extension MacroBoundaryString where Tag == APIBaseURLTag {
  /// Supplies the absolute base URL validated by `@API`.
  public static func absolute(_ value: StaticString) -> Self { Self(value) }
}

extension MacroBoundaryString where Tag == EndpointPathTag {
  /// Supplies an endpoint path, optionally containing `{parameter}` placeholders.
  public static func path(_ value: StaticString) -> Self { Self(value) }
}

extension MacroBoundaryString where Tag == ParameterReferenceTag {
  /// Refers to a function parameter by its local name.
  public static func parameter(_ value: StaticString) -> Self { Self(value) }
}
