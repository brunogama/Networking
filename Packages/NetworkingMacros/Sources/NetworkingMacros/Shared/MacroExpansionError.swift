import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftDiagnostics
import Foundation

public enum MacroExpansionError: Error, CustomStringConvertible, Sendable {
  case parameterMismatch(
    path: EndpointPath,
    declared: [ParameterReference],
    required: [ParameterReference]
  )
  case invalidPathTemplate(EndpointPath, suggestion: MacroDiagnosticText?)
  case bodyParameterNotFound(ParameterReference, available: [ParameterReference])
  case queryParameterNotFound(ParameterReference, available: [ParameterReference])
  case multipleHTTPMethods(MacroFunctionName, found: [HTTPMethodName])
  case missingAsyncKeyword(MacroFunctionName)
  case missingThrowsKeyword(MacroFunctionName)
  case nonDecodableReturnType(MacroTypeReference)
  case nonEncodableBodyType(MacroTypeReference)

  public var description: String {
    switch self {
    case .parameterMismatch(let path, let declared, let required):
      return """
        Path parameter mismatch in '\(path)': \
        function has parameters [\(declared.map(\.rawValue).joined(separator: ", "))], \
        but path requires [\(required.map(\.rawValue).joined(separator: ", "))]
        """

    case .invalidPathTemplate(let template, let suggestion):
      if let suggestion = suggestion {
        return "Invalid path template '\(template)': \(suggestion)"
      }
      return "Invalid path template '\(template)'"

    case .bodyParameterNotFound(let param, let available):
      return """
        Body parameter '\(param)' not found in function signature. \
        Available: [\(available.map(\.rawValue).joined(separator: ", "))]
        """

    case .queryParameterNotFound(let param, let available):
      return """
        Query parameter '\(param)' not found in function signature. \
        Available: [\(available.map(\.rawValue).joined(separator: ", "))]
        """

    case .multipleHTTPMethods(let function, let found):
      return """
        Function '\(function)' has multiple HTTP method macros: \
        [\(found.map(\.rawValue).joined(separator: ", "))]. Only one is allowed.
        """

    case .missingAsyncKeyword(let function):
      return "Function '\(function)' must be marked 'async'"

    case .missingThrowsKeyword(let function):
      return "Function '\(function)' must be marked 'throws'"

    case .nonDecodableReturnType(let type):
      return "Return type '\(type)' must conform to Decodable"

    case .nonEncodableBodyType(let type):
      return "Body parameter type '\(type)' must conform to Encodable"
    }
  }
}
