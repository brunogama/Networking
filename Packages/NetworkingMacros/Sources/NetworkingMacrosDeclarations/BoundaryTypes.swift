/// Distinguishes the static strings accepted by networking macro arguments.
public struct MacroBoundaryString<Tag>: Sendable, Hashable {
  private let value: String

  private init(_ value: StaticString) {
    self.value = String(describing: value)
  }
}

extension MacroBoundaryString where Tag == HeaderNameTag {

  public static func named(_ value: StaticString) -> Self { Self(value) }
}

extension MacroBoundaryString where Tag == HeaderValueReferenceTag {

  public static func literal(_ value: StaticString) -> Self { Self(value) }

  public static func parameter(_ value: StaticString) -> Self { Self(value) }
}

extension MacroBoundaryString where Tag == APIBaseURLTag {

  public static func absolute(_ value: StaticString) -> Self { Self(value) }
}

extension MacroBoundaryString where Tag == EndpointPathTag {

  public static func path(_ value: StaticString) -> Self { Self(value) }
}

extension MacroBoundaryString where Tag == ParameterReferenceTag {

  public static func parameter(_ value: StaticString) -> Self { Self(value) }
}
