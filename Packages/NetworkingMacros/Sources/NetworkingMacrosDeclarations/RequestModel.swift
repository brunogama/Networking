import NetworkingCore

/// Generates request properties from annotated stored properties.
///
/// The annotated structure must explicitly conform to ``Request`` and declare `typealias Response`.
/// Use ``Header(_:)`` for
/// request-specific header fields and ``Body(_:)`` for JSON payload fields. The generated request
/// inherits query items and timeout from ``Request`` unless the structure provides overrides.
@attached(member, names: arbitrary)
public macro RequestModel(method: HTTPMethod, path: StaticString) =
  #externalMacro(module: "NetworkingMacrosPlugin", type: "RequestModelMacro")
