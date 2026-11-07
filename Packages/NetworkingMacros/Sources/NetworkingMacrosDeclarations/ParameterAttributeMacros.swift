/// Uses a function parameter as the JSON request body of a POST, PUT, or PATCH endpoint.
///
/// The named parameter must exist and conform to `Encodable`. Generated methods use
/// the codec supplied to the API factory. Only one body annotation is permitted.
/// Use `@Body(.parameter("user"))` on the endpoint method.
@attached(peer)
public macro Body(_ parameterName: ParameterReference) =
  #externalMacro(module: "NetworkingMacrosPlugin", type: "BodyMacro")

/// Marks a stored property as a request-specific HTTP header.
///
/// Apply this only inside a type annotated with ``RequestModel(method:path:)``. The generated
/// request converts the property's textual representation into the supplied header field.
@attached(accessor)
public macro Header(_ name: StaticString? = nil) =
  #externalMacro(module: "NetworkingMacrosPlugin", type: "HeaderMacro")

/// Marks a stored property as one field in a generated JSON request body.
///
/// Apply this only inside a type annotated with ``RequestModel(method:path:)``. The generated
/// payload preserves the supplied key as a JSON coding key.
@attached(accessor)
public macro Body(_ key: StaticString? = nil) =
  #externalMacro(module: "NetworkingMacrosPlugin", type: "BodyMacro")

/// Applies a dictionary of literal headers and explicit function-parameter references.
///
/// Use `@Headers([.named("Authorization"): .parameter("token")])` to read a parameter,
/// or `.literal("application/json")` to use a constant. Names and literal values must
/// not contain CR or LF. Parameter references must name a function parameter.
@attached(peer)
public macro Headers(_ headers: DefaultHeaderMap) =
  #externalMacro(module: "NetworkingMacrosPlugin", type: "HeadersMacro")
