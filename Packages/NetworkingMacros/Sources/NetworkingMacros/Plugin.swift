import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Foundation

public struct MacroPluginBoundaryString<Tag>: Sendable, Hashable, Codable,
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

public struct MacroPluginBoundaryBool<Tag>: Sendable, Hashable, Codable,
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
public enum EndpointPathTag: Sendable {}
public enum ParameterReferenceTag: Sendable {}
public enum QueryParameterNameTag: Sendable {}
public enum TemplateURLTag: Sendable {}
public enum HTTPMethodNameTag: Sendable {}
public enum RequestBodyRequiredFlagTag: Sendable {}
public enum VoidReturnAllowedFlagTag: Sendable {}
public enum MacroDiagnosticTextTag: Sendable {}
public enum MacroFunctionNameTag: Sendable {}
public enum MacroTypeReferenceTag: Sendable {}

public typealias HeaderName = MacroPluginBoundaryString<HeaderNameTag>
public typealias HeaderValueReference = MacroPluginBoundaryString<HeaderValueReferenceTag>
public typealias EndpointPath = MacroPluginBoundaryString<EndpointPathTag>
public typealias ParameterReference = MacroPluginBoundaryString<ParameterReferenceTag>
public typealias QueryParameterName = MacroPluginBoundaryString<QueryParameterNameTag>
public typealias TemplateURL = MacroPluginBoundaryString<TemplateURLTag>
public typealias HTTPMethodName = MacroPluginBoundaryString<HTTPMethodNameTag>
public typealias RequestBodyRequiredFlag = MacroPluginBoundaryBool<RequestBodyRequiredFlagTag>
public typealias VoidReturnAllowedFlag = MacroPluginBoundaryBool<VoidReturnAllowedFlagTag>
public typealias MacroDiagnosticText = MacroPluginBoundaryString<MacroDiagnosticTextTag>
public typealias MacroFunctionName = MacroPluginBoundaryString<MacroFunctionNameTag>
public typealias MacroTypeReference = MacroPluginBoundaryString<MacroTypeReferenceTag>

/// Main plugin for all networking macros
@main
struct NetworkingPlugin: CompilerPlugin {
  let providingMacros: [Macro.Type] = [
    APIMacro.self,
    GETMacro.self,
    POSTMacro.self,
    PUTMacro.self,
    PATCHMacro.self,
    DELETEMacro.self,
    DefaultHeadersMacro.self,
    TimeoutMacro.self,
    InterceptorsMacro.self,
    BodyMacro.self,
    HeadersMacro.self,
    CacheableMacro.self,
    MeasuredMacro.self,
  ]
}

/// Errors that can occur during macro expansion
public enum MacroError: Error, Sendable, LocalizedError, CustomStringConvertible {
  case invalidUsage(MacroDiagnosticText)
  case missingAnnotation(MacroDiagnosticText)
  case unsupportedType(MacroDiagnosticText)
  case invalidParameter(MacroDiagnosticText)
  case syntaxError(MacroDiagnosticText)
  case invalidSignature(MacroDiagnosticText)

  public var description: String {
    switch self {
    case .invalidUsage(let message):
      return "Invalid macro usage: \(message)"

    case .missingAnnotation(let message):
      return "Missing required annotation: \(message)"

    case .unsupportedType(let message):
      return "Unsupported type: \(message)"

    case .invalidParameter(let message):
      return "Invalid parameter: \(message)"

    case .syntaxError(let message):
      return "Syntax error: \(message)"

    case .invalidSignature(let message):
      return "Invalid method signature: \(message)"
    }
  }

  public var errorDescription: String? {
    description
  }

  public var recoverySuggestion: String? {
    switch self {
    case .invalidUsage:
      return """
        Ensure the macro is applied to the correct declaration type \
        (e.g., @API on protocols only).
        """

    case .missingAnnotation:
      return "Add the required annotation with proper parameters (e.g., @GET(\"/path\"))."

    case .invalidParameter:
      return "Check parameter annotations (@Path, @Body, @Query, @Header) and their usage."

    case .syntaxError:
      return "Verify Swift syntax is correct in the annotated declaration."

    case .unsupportedType:
      return "Use supported types for parameters and return values."

    case .invalidSignature:
      return "Ensure method signatures follow the expected pattern for API generation."
    }
  }

  public var failureReason: String? {
    switch self {
    case .invalidUsage:
      return "Macro was applied to an incompatible declaration."

    case .missingAnnotation:
      return "Required annotation was not found or was malformed."

    case .invalidParameter:
      return "Parameter configuration is invalid or conflicts with others."

    case .syntaxError:
      return "Swift syntax tree could not be parsed correctly."

    case .unsupportedType:
      return "The specified type is not supported by the macro system."

    case .invalidSignature:
      return "Method signature does not match expected format."
    }
  }
}
