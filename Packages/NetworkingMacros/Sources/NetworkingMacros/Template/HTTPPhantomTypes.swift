// MARK: - HTTP Method Protocol

/// Marker protocol for HTTP method phantom types.
public protocol HTTPMethodProtocol: Sendable {
  /// The HTTP method string (e.g., "GET", "POST").
  static var methodName: String { get }
}

// MARK: - HTTP Method Phantom Types

/// Namespace for HTTP method phantom types.
public enum HTTPMethod {
  /// GET method - retrieves resources, no request body allowed.
  public enum GET: HTTPMethodProtocol {
    public static let methodName = "GET"
  }

  /// POST method - creates resources, request body allowed.
  public enum POST: HTTPMethodProtocol {
    public static let methodName = "POST"
  }

  /// PUT method - replaces resources, request body allowed.
  public enum PUT: HTTPMethodProtocol {
    public static let methodName = "PUT"
  }

  /// PATCH method - partially updates resources, request body allowed.
  public enum PATCH: HTTPMethodProtocol {
    public static let methodName = "PATCH"
  }

  /// DELETE method - removes resources, no request body allowed.
  public enum DELETE: HTTPMethodProtocol {
    public static let methodName = "DELETE"
  }

  /// HEAD method - retrieves headers only, no request body allowed.
  public enum HEAD: HTTPMethodProtocol {
    public static let methodName = "HEAD"
  }

  /// OPTIONS method - describes communication options, no request body allowed.
  public enum OPTIONS: HTTPMethodProtocol {
    public static let methodName = "OPTIONS"
  }
}

// MARK: - Body Constraint Protocol

/// Marker protocol for body constraint phantom types.
public protocol BodyConstraintProtocol: Sendable {}

/// Marker protocol indicating the method allows a request body.
public protocol BodyAllowedProtocol: BodyConstraintProtocol {}

/// Marker protocol indicating the method does not allow a request body.
public protocol NoBodyProtocol: BodyConstraintProtocol {}

// MARK: - Body Constraint Phantom Types

/// Namespace for body constraint phantom types.
public enum BodyConstraint {
  /// Body is allowed for this HTTP method (POST, PUT, PATCH).
  public enum Allowed: BodyAllowedProtocol {}

  /// Body is not allowed for this HTTP method (GET, DELETE, HEAD, OPTIONS).
  public enum NotAllowed: NoBodyProtocol {}
}

// MARK: - Method to Body Constraint Mapping

/// Associates HTTP methods with their body constraints.
public protocol HTTPMethodWithBodyConstraint: HTTPMethodProtocol {
  associatedtype Body: BodyConstraintProtocol
}

extension HTTPMethod.GET: HTTPMethodWithBodyConstraint {
  public typealias Body = BodyConstraint.NotAllowed
}

extension HTTPMethod.POST: HTTPMethodWithBodyConstraint {
  public typealias Body = BodyConstraint.Allowed
}

extension HTTPMethod.PUT: HTTPMethodWithBodyConstraint {
  public typealias Body = BodyConstraint.Allowed
}

extension HTTPMethod.PATCH: HTTPMethodWithBodyConstraint {
  public typealias Body = BodyConstraint.Allowed
}

extension HTTPMethod.DELETE: HTTPMethodWithBodyConstraint {
  public typealias Body = BodyConstraint.NotAllowed
}

extension HTTPMethod.HEAD: HTTPMethodWithBodyConstraint {
  public typealias Body = BodyConstraint.NotAllowed
}

extension HTTPMethod.OPTIONS: HTTPMethodWithBodyConstraint {
  public typealias Body = BodyConstraint.NotAllowed
}
