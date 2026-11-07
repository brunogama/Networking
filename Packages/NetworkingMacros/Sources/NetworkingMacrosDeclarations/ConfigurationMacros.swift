/// Applies literal default headers to every endpoint of an `@API` protocol.
///
/// Method-level `@Headers` values override matching default header names.
/// Use a dictionary literal, for example
/// `@DefaultHeaders([.named("Accept"): .literal("application/json")])`.
@attached(member)
public macro DefaultHeaders(_ headers: DefaultHeaderMap) =
  #externalMacro(module: "NetworkingMacrosPlugin", type: "DefaultHeadersMacro")

/// Sets a positive default timeout for every endpoint of an `@API` protocol.
///
/// Use a Duration literal in seconds, milliseconds, microseconds, or nanoseconds,
/// for example `@Timeout(.milliseconds(250))`. Other expressions are diagnosed.
@attached(member)
public macro Timeout(_ duration: Duration) =
  #externalMacro(module: "NetworkingMacrosPlugin", type: "TimeoutMacro")
