import Foundation

public extension MacroPluginBoundaryString where Tag == HeaderNameTag {
  static func named(_ value: StaticString) -> Self {
    Self(String(describing: value))
  }
}

public extension MacroPluginBoundaryString where Tag == HeaderValueReferenceTag {
  static func literal(_ value: StaticString) -> Self {
    Self(String(describing: value))
  }

  static func parameter(_ value: StaticString) -> Self {
    Self(String(describing: value))
  }
}

public extension MacroPluginBoundaryString where Tag == EndpointPathTag {
  static func path(_ value: StaticString) -> Self {
    Self(String(describing: value))
  }
}

public extension MacroPluginBoundaryString where Tag == ParameterReferenceTag {
  static func parameter(_ value: StaticString) -> Self {
    Self(String(describing: value))
  }
}

public extension MacroPluginBoundaryString where Tag == QueryParameterNameTag {
  static func named(_ value: StaticString) -> Self {
    Self(String(describing: value))
  }
}

public extension MacroPluginBoundaryString where Tag == TemplateURLTag {
  static func absolute(_ value: StaticString) -> Self {
    Self(String(describing: value))
  }
}

public extension MacroPluginBoundaryString where Tag == HTTPMethodNameTag {
  static func named(_ value: StaticString) -> Self {
    Self(String(describing: value))
  }
}

public extension MacroPluginBoundaryString where Tag == MacroDiagnosticTextTag {
  static func message(_ value: StaticString) -> Self {
    Self(String(describing: value))
  }
}

public extension MacroPluginBoundaryString where Tag == MacroFunctionNameTag {
  static func named(_ value: StaticString) -> Self {
    Self(String(describing: value))
  }
}

public extension MacroPluginBoundaryString where Tag == MacroTypeReferenceTag {
  static func named(_ value: StaticString) -> Self {
    Self(String(describing: value))
  }
}

public extension MacroPluginBoundaryBool where Tag == RequestBodyRequiredFlagTag {
  static var required: Self {
    Self(true)
  }

  static var notRequired: Self {
    Self(false)
  }
}

public extension MacroPluginBoundaryBool where Tag == VoidReturnAllowedFlagTag {
  static var allowed: Self {
    Self(true)
  }

  static var disallowed: Self {
    Self(false)
  }
}
