import Foundation

public struct MacroBoundaryString<Tag>: Sendable, Hashable, Codable,
  CustomStringConvertible
{
  package let rawValue: String

  package init(rawValue: String) {
    self.rawValue = rawValue
  }

  package init(_ rawValue: String) {
    self.init(rawValue: rawValue)
  }

  public var description: String {
    rawValue
  }
}

public struct MacroBoundaryBool<Tag>: Sendable, Hashable, Codable,
  CustomStringConvertible
{
  package let rawValue: Bool

  package init(rawValue: Bool) {
    self.rawValue = rawValue
  }

  package init(_ rawValue: Bool) {
    self.init(rawValue: rawValue)
  }

  public var description: String {
    String(rawValue)
  }
}

public enum HeaderNameTag: Sendable {}
public enum HeaderValueReferenceTag: Sendable {}
public enum APIBaseURLTag: Sendable {}
public enum EndpointPathTag: Sendable {}
public enum ParameterReferenceTag: Sendable {}
public enum QueryParameterNameTag: Sendable {}
public enum TemplateURLTag: Sendable {}
public enum HTTPMethodNameTag: Sendable {}
public enum MacroDiagnosticTextTag: Sendable {}
public enum MacroFunctionNameTag: Sendable {}
public enum MacroTypeReferenceTag: Sendable {}
public enum MeasuredOperationNameTag: Sendable {}
public enum CacheRevalidationTag: Sendable {}

public typealias HeaderName = MacroBoundaryString<HeaderNameTag>
public typealias HeaderValueReference = MacroBoundaryString<HeaderValueReferenceTag>
public typealias APIBaseURL = MacroBoundaryString<APIBaseURLTag>
public typealias EndpointPath = MacroBoundaryString<EndpointPathTag>
public typealias ParameterReference = MacroBoundaryString<ParameterReferenceTag>
public typealias QueryParameterName = MacroBoundaryString<QueryParameterNameTag>
public typealias TemplateURL = MacroBoundaryString<TemplateURLTag>
public typealias HTTPMethodName = MacroBoundaryString<HTTPMethodNameTag>
public typealias MacroDiagnosticText = MacroBoundaryString<MacroDiagnosticTextTag>
public typealias MacroFunctionName = MacroBoundaryString<MacroFunctionNameTag>
public typealias MacroTypeReference = MacroBoundaryString<MacroTypeReferenceTag>
public typealias MeasuredDuration = Duration
public typealias MeasuredOperationName = MacroBoundaryString<MeasuredOperationNameTag>
public typealias TimeoutDuration = Duration
public typealias CacheAgeLimit = Duration
public typealias CacheRevalidationFlag = MacroBoundaryBool<CacheRevalidationTag>

public extension MacroBoundaryString where Tag == HeaderNameTag {
  static func named(_ value: StaticString) -> Self {
    Self(String(describing: value))
  }
}

public extension MacroBoundaryString where Tag == HeaderValueReferenceTag {
  static func literal(_ value: StaticString) -> Self {
    Self(String(describing: value))
  }

  static func parameter(_ value: StaticString) -> Self {
    Self(String(describing: value))
  }
}

public extension MacroBoundaryString where Tag == APIBaseURLTag {
  static func absolute(_ value: StaticString) -> Self {
    Self(String(describing: value))
  }
}

public extension MacroBoundaryString where Tag == EndpointPathTag {
  static func path(_ value: StaticString) -> Self {
    Self(String(describing: value))
  }
}

public extension MacroBoundaryString where Tag == ParameterReferenceTag {
  static func parameter(_ value: StaticString) -> Self {
    Self(String(describing: value))
  }
}

public extension MacroBoundaryString where Tag == QueryParameterNameTag {
  static func named(_ value: StaticString) -> Self {
    Self(String(describing: value))
  }
}

public extension MacroBoundaryString where Tag == TemplateURLTag {
  static func absolute(_ value: StaticString) -> Self {
    Self(String(describing: value))
  }
}

public extension MacroBoundaryString where Tag == HTTPMethodNameTag {
  static func named(_ value: StaticString) -> Self {
    Self(String(describing: value))
  }
}

public extension MacroBoundaryString where Tag == MacroDiagnosticTextTag {
  static func message(_ value: StaticString) -> Self {
    Self(String(describing: value))
  }
}

public extension MacroBoundaryString where Tag == MacroFunctionNameTag {
  static func named(_ value: StaticString) -> Self {
    Self(String(describing: value))
  }
}

public extension MacroBoundaryString where Tag == MacroTypeReferenceTag {
  static func named(_ value: StaticString) -> Self {
    Self(String(describing: value))
  }
}

public extension MacroBoundaryString where Tag == MeasuredOperationNameTag {
  static func named(_ value: StaticString) -> Self {
    Self(String(describing: value))
  }
}

public extension MacroBoundaryBool where Tag == CacheRevalidationTag {
  static var enabled: Self {
    Self(true)
  }

  static var disabled: Self {
    Self(false)
  }
}

public struct DefaultHeaderMap: Sendable, ExpressibleByDictionaryLiteral, Codable, Equatable {
  private var storage: [HeaderName: HeaderValueReference]

  public init(_ storage: [HeaderName: HeaderValueReference] = [:]) {
    self.storage = storage
  }

  public init(dictionaryLiteral elements: (HeaderName, HeaderValueReference)...) {
    storage = Dictionary(uniqueKeysWithValues: elements)
  }

  public var headers: [HeaderName: HeaderValueReference] {
    storage
  }

  package var rawHeaders: [String: String] {
    Dictionary(uniqueKeysWithValues: storage.map { ($0.key.rawValue, $0.value.rawValue) })
  }
}
