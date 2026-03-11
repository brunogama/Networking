import Foundation

extension HTTPError {
  public var userFriendlyDescription: UserMessageText {
    let description = UserMessageText(rawValue: errorDescription ?? "An error occurred")
    let suggestion =
      recoverySuggestions.first ?? RecoveryActionDescription(rawValue: "Please try again later.")
    return UserMessageText(rawValue: "\(description). \(suggestion)")
  }

  public var recoverySuggestions: [RecoveryActionDescription] {
    switch category {
    case .network(let networkError):
      switch networkError {
      case .noConnection:
        return makeRecoverySuggestions(
          "Check your internet connection and try again.",
          "Make sure you're connected to WiFi or cellular data.",
          "Try switching between WiFi and cellular data."
        )
      case .dnsFailure:
        return makeRecoverySuggestions(
          "Check that the server address is correct.",
          "Try again in a moment as this might be a temporary issue.",
          "Contact your network administrator if this persists."
        )
      case .connectionLost:
        return makeRecoverySuggestions(
          "Your connection was interrupted. Please try again.",
          "Check your network stability."
        )
      case .serverUnreachable:
        return makeRecoverySuggestions(
          "The server is temporarily unavailable. Please try again later.",
          "Check if the service is down for maintenance."
        )
      case .sslError:
        return makeRecoverySuggestions(
          "There's a security issue with the connection.",
          "Check your device's date and time settings.",
          "Contact support if this continues."
        )
      }

    case .http(let status):
      switch status.rawValue {
      case 401:
        return makeRecoverySuggestions(
          "You need to log in again.",
          "Check your credentials and try signing in."
        )
      case 403:
        return makeRecoverySuggestions(
          "You don't have permission to access this resource.",
          "Contact your administrator for access."
        )
      case 404:
        return makeRecoverySuggestions(
          "The requested resource could not be found.",
          "Check the URL and try again."
        )
      case 408:
        return makeRecoverySuggestions(
          "The request took too long. Please try again.",
          "Check your connection speed."
        )
      case 429:
        return makeRecoverySuggestions(
          "Too many requests. Please wait a moment and try again.",
          "Reduce the frequency of your requests."
        )
      case 500...503:
        return makeRecoverySuggestions(
          "The server is experiencing issues. Please try again later.",
          "Contact support if this problem continues."
        )
      default:
        return makeRecoverySuggestions(
          "Please try again or contact support if the problem continues."
        )
      }

    case .timeout:
      return makeRecoverySuggestions(
        "The request took too long to complete. Please try again.",
        "Check your connection speed.",
        "Try again with a shorter request or better connection."
      )
    case .cancelled:
      return makeRecoverySuggestions("The request was cancelled. You can try again if needed.")
    case .decoding:
      return makeRecoverySuggestions(
        "There was an issue processing the server response.",
        "Please try again or contact support."
      )
    case .encoding:
      return makeRecoverySuggestions(
        "There was an issue preparing your request.",
        "Please check your input and try again."
      )
    case .configuration:
      return makeRecoverySuggestions(
        "There's a configuration issue with the app.",
        "Please contact support or reinstall the app."
      )
    case .custom(let type, let message):
      if type.lowercased() == "security" {
        return makeRecoverySuggestions(
          "Security issue detected: \(message)",
          "Please check your request and ensure it follows security guidelines.",
          "Contact support if this continues."
        )
      }

      return makeRecoverySuggestions(
        "\(type) issue: \(message)",
        "Please try again or contact support if the problem continues."
      )
    }
  }
}

private func makeRecoverySuggestions(
  _ values: String...
) -> [RecoveryActionDescription] {
  values.map(RecoveryActionDescription.init(rawValue:))
}
