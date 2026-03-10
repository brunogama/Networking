import Foundation
import NetworkingCore

/// Protocol marker for HTTP methods that allow request body.
///
/// Only HTTP methods that semantically support request bodies conform to this protocol.
/// This enables compile-time enforcement of HTTP constraints, preventing common mistakes
/// like attempting to add a body to a GET request.
///
/// ## Conforming Types
///
/// The framework provides conformances for the standard body-allowed methods:
/// - ``POSTMethod``
/// - ``PUTMethod``
/// - ``PATCHMethod``
///
/// ## Usage with TypedHTTPRequest
///
/// Use this protocol as a generic constraint to restrict methods that accept bodies:
///
/// ```swift
/// extension TypedHTTPRequest where Method: BodyAllowedMethod {
///     func withJSONBody<T: Encodable>(_ value: T) throws -> Self {
///         // Implementation
///     }
/// }
/// ```
///
/// This ensures that code like the following will not compile:
///
/// ```swift
/// let request = TypedHTTPRequest<GETMethod, ProductionEnvironment>(path: "/users")
/// request.withJSONBody(user)  // ❌ Compile error: GETMethod does not conform to BodyAllowedMethod
/// ```
public protocol BodyAllowedMethod: HTTPMethodType {}

// MARK: - Standard Conformances

extension POSTMethod: BodyAllowedMethod {}
extension PUTMethod: BodyAllowedMethod {}
extension PATCHMethod: BodyAllowedMethod {}
