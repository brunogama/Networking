import Foundation

#if canImport(Nimble)
import Nimble

// MARK: - HTTP Response Matchers

/// Matches an HTTP response with a specific status code.
///
/// ```swift
/// expect(response).to(haveStatus(200))
/// expect(response).to(haveStatus(.ok))
/// ```
public func haveStatus(_ expectedStatus: Int) -> Matcher<HTTPResponse> {
  Matcher { actualExpression in
    guard let response = try actualExpression.evaluate() else {
      return MatcherResult(status: .fail, message: .fail("expected response, got nil"))
    }

    let actualStatus = response.status.rawValue
    let matches = actualStatus == expectedStatus

    return MatcherResult(
      bool: matches,
      message: .expectedCustomValueTo(
        "have status \(expectedStatus)",
        actual: "status \(actualStatus)"
      )
    )
  }
}

/// Matches an HTTP response with a specific HTTPStatus.
public func haveStatus(_ expectedStatus: HTTPStatus) -> Matcher<HTTPResponse> {
  haveStatus(expectedStatus.rawValue)
}

/// Matches a successful HTTP response (2xx).
///
/// ```swift
/// expect(response).to(beSuccessful())
/// ```
public func beSuccessful() -> Matcher<HTTPResponse> {
  Matcher { actualExpression in
    guard let response = try actualExpression.evaluate() else {
      return MatcherResult(status: .fail, message: .fail("expected response, got nil"))
    }

    let matches = response.status.isSuccess

    return MatcherResult(
      bool: matches,
      message: .expectedCustomValueTo(
        "be successful (2xx)",
        actual: "status \(response.status.rawValue)"
      )
    )
  }
}

/// Matches an HTTP response that is a redirect (3xx).
public func beRedirect() -> Matcher<HTTPResponse> {
  Matcher { actualExpression in
    guard let response = try actualExpression.evaluate() else {
      return MatcherResult(status: .fail, message: .fail("expected response, got nil"))
    }

    let matches = response.status.isRedirection

    return MatcherResult(
      bool: matches,
      message: .expectedCustomValueTo(
        "be redirect (3xx)",
        actual: "status \(response.status.rawValue)"
      )
    )
  }
}

/// Matches an HTTP response that is a client error (4xx).
public func beClientError() -> Matcher<HTTPResponse> {
  Matcher { actualExpression in
    guard let response = try actualExpression.evaluate() else {
      return MatcherResult(status: .fail, message: .fail("expected response, got nil"))
    }

    let matches = response.status.isClientError

    return MatcherResult(
      bool: matches,
      message: .expectedCustomValueTo(
        "be client error (4xx)",
        actual: "status \(response.status.rawValue)"
      )
    )
  }
}

/// Matches an HTTP response that is a server error (5xx).
public func beServerError() -> Matcher<HTTPResponse> {
  Matcher { actualExpression in
    guard let response = try actualExpression.evaluate() else {
      return MatcherResult(status: .fail, message: .fail("expected response, got nil"))
    }

    let matches = response.status.isServerError

    return MatcherResult(
      bool: matches,
      message: .expectedCustomValueTo(
        "be server error (5xx)",
        actual: "status \(response.status.rawValue)"
      )
    )
  }
}

// MARK: - Header Matchers

/// Matches an HTTP response that has a specific header.
///
/// ```swift
/// expect(response).to(haveHeader("Content-Type"))
/// expect(response).to(haveHeader("Content-Type", withValue: "application/json"))
/// ```
public func haveHeader(_ name: String, withValue value: String? = nil) -> Matcher<HTTPResponse> {
  Matcher { actualExpression in
    guard let response = try actualExpression.evaluate() else {
      return MatcherResult(status: .fail, message: .fail("expected response, got nil"))
    }

    let headerValue = response.headers[name]

    if let expectedValue = value {
      let matches = headerValue == expectedValue
      return MatcherResult(
        bool: matches,
        message: .expectedCustomValueTo(
          "have header '\(name)' with value '\(expectedValue)'",
          actual: headerValue.map { "'\($0)'" } ?? "missing"
        )
      )
    } else {
      let matches = headerValue != nil
      return MatcherResult(
        bool: matches,
        message: .expectedCustomValueTo(
          "have header '\(name)'",
          actual: matches ? "present" : "missing"
        )
      )
    }
  }
}

/// Matches an HTTP response that has a Content-Type header matching the given value.
public func haveContentType(_ contentType: String) -> Matcher<HTTPResponse> {
  haveHeader("Content-Type", withValue: contentType)
}

/// Matches an HTTP response with JSON content type.
public func haveJSONContentType() -> Matcher<HTTPResponse> {
  Matcher { actualExpression in
    guard let response = try actualExpression.evaluate() else {
      return MatcherResult(status: .fail, message: .fail("expected response, got nil"))
    }

    let contentType = response.headers["Content-Type"] ?? ""
    let matches = contentType.lowercased().contains("application/json")

    return MatcherResult(
      bool: matches,
      message: .expectedCustomValueTo(
        "have JSON content type",
        actual: "'\(contentType)'"
      )
    )
  }
}

// MARK: - Body Matchers

/// Matches an HTTP response that has a body containing the specified string.
///
/// ```swift
/// expect(response).to(haveBodyContaining("success"))
/// ```
public func haveBodyContaining(_ expectedContent: String) -> Matcher<HTTPResponse> {
  Matcher { actualExpression in
    guard let response = try actualExpression.evaluate() else {
      return MatcherResult(status: .fail, message: .fail("expected response, got nil"))
    }

    guard let body = response.body,
          let bodyString = String(data: body, encoding: .utf8) else {
      return MatcherResult(
        status: .fail,
        message: .expectedCustomValueTo(
          "contain '\(expectedContent)'",
          actual: "no body"
        )
      )
    }

    let matches = bodyString.contains(expectedContent)

    return MatcherResult(
      bool: matches,
      message: .expectedCustomValueTo(
        "contain '\(expectedContent)'",
        actual: matches ? "found" : "not found in body"
      )
    )
  }
}

/// Matches an HTTP response that has a body matching the expected data.
public func haveBody(_ expectedBody: Data) -> Matcher<HTTPResponse> {
  Matcher { actualExpression in
    guard let response = try actualExpression.evaluate() else {
      return MatcherResult(status: .fail, message: .fail("expected response, got nil"))
    }

    let matches = response.body == expectedBody

    return MatcherResult(
      bool: matches,
      message: .expectedCustomValueTo(
        "have matching body",
        actual: matches ? "matches" : "different"
      )
    )
  }
}

/// Matches an HTTP response that has an empty body.
public func haveEmptyBody() -> Matcher<HTTPResponse> {
  Matcher { actualExpression in
    guard let response = try actualExpression.evaluate() else {
      return MatcherResult(status: .fail, message: .fail("expected response, got nil"))
    }

    let isEmpty = response.body == nil || response.body?.isEmpty == true

    return MatcherResult(
      bool: isEmpty,
      message: .expectedCustomValueTo(
        "have empty body",
        actual: isEmpty ? "empty" : "has body"
      )
    )
  }
}

/// Matches an HTTP response that can be decoded as the specified type.
///
/// ```swift
/// expect(response).to(beDecodableAs(User.self))
/// ```
public func beDecodableAs<T: Decodable>(
  _ type: T.Type,
  using decoder: JSONDecoder = JSONDecoder()
) -> Matcher<HTTPResponse> {
  Matcher { actualExpression in
    guard let response = try actualExpression.evaluate() else {
      return MatcherResult(status: .fail, message: .fail("expected response, got nil"))
    }

    guard let body = response.body else {
      return MatcherResult(
        status: .fail,
        message: .expectedCustomValueTo(
          "be decodable as \(T.self)",
          actual: "no body"
        )
      )
    }

    do {
      _ = try decoder.decode(T.self, from: body)
      return MatcherResult(
        status: .matches,
        message: .expectedCustomValueTo(
          "be decodable as \(T.self)",
          actual: "successfully decoded"
        )
      )
    } catch {
      return MatcherResult(
        status: .doesNotMatch,
        message: .expectedCustomValueTo(
          "be decodable as \(T.self)",
          actual: "decode error: \(error.localizedDescription)"
        )
      )
    }
  }
}

/// Matches an HTTP response whose decoded body equals the expected value.
public func haveDecodedBody<T: Decodable & Equatable>(
  _ expected: T,
  using decoder: JSONDecoder = JSONDecoder()
) -> Matcher<HTTPResponse> {
  Matcher { actualExpression in
    guard let response = try actualExpression.evaluate() else {
      return MatcherResult(status: .fail, message: .fail("expected response, got nil"))
    }

    guard let body = response.body else {
      return MatcherResult(
        status: .fail,
        message: .expectedCustomValueTo(
          "have body equal to \(expected)",
          actual: "no body"
        )
      )
    }

    do {
      let decoded = try decoder.decode(T.self, from: body)
      let matches = decoded == expected

      return MatcherResult(
        bool: matches,
        message: .expectedCustomValueTo(
          "have body equal to \(expected)",
          actual: "\(decoded)"
        )
      )
    } catch {
      return MatcherResult(
        status: .fail,
        message: .expectedCustomValueTo(
          "have body equal to \(expected)",
          actual: "decode error: \(error.localizedDescription)"
        )
      )
    }
  }
}

// MARK: - Error Matchers

/// Matches an HTTPError with the specified category.
///
/// ```swift
/// expect(error).to(beHTTPError(category: .network(.noConnection)))
/// ```
public func beHTTPError(category: HTTPError.Category) -> Matcher<Error> {
  Matcher { actualExpression in
    guard let error = try actualExpression.evaluate() else {
      return MatcherResult(status: .fail, message: .fail("expected error, got nil"))
    }

    guard let httpError = error as? HTTPError else {
      return MatcherResult(
        status: .doesNotMatch,
        message: .expectedCustomValueTo(
          "be HTTPError with category \(category)",
          actual: "different error type: \(type(of: error))"
        )
      )
    }

    let matches = httpError.category == category

    return MatcherResult(
      bool: matches,
      message: .expectedCustomValueTo(
        "have category \(category)",
        actual: "\(httpError.category)"
      )
    )
  }
}

/// Matches any HTTPError.
public func beHTTPError() -> Matcher<Error> {
  Matcher { actualExpression in
    guard let error = try actualExpression.evaluate() else {
      return MatcherResult(status: .fail, message: .fail("expected error, got nil"))
    }

    let isHTTPError = error is HTTPError

    return MatcherResult(
      bool: isHTTPError,
      message: .expectedCustomValueTo(
        "be HTTPError",
        actual: isHTTPError ? "HTTPError" : "\(type(of: error))"
      )
    )
  }
}

/// Matches a network error.
public func beNetworkError() -> Matcher<Error> {
  Matcher { actualExpression in
    guard let error = try actualExpression.evaluate() else {
      return MatcherResult(status: .fail, message: .fail("expected error, got nil"))
    }

    guard let httpError = error as? HTTPError else {
      return MatcherResult(
        status: .doesNotMatch,
        message: .expectedCustomValueTo(
          "be network error",
          actual: "\(type(of: error))"
        )
      )
    }

    let isNetworkError: Bool
    if case .network = httpError.category {
      isNetworkError = true
    } else {
      isNetworkError = false
    }

    return MatcherResult(
      bool: isNetworkError,
      message: .expectedCustomValueTo(
        "be network error",
        actual: "\(httpError.category)"
      )
    )
  }
}

// MARK: - Request Matchers

/// Matches an HTTP request with the specified method.
public func haveMethod(_ method: HTTPMethod) -> Matcher<HTTPRequest> {
  Matcher { actualExpression in
    guard let request = try actualExpression.evaluate() else {
      return MatcherResult(status: .fail, message: .fail("expected request, got nil"))
    }

    let matches = request.method == method

    return MatcherResult(
      bool: matches,
      message: .expectedCustomValueTo(
        "have method \(method.rawValue)",
        actual: "\(request.method.rawValue)"
      )
    )
  }
}

/// Matches an HTTP request with the specified path.
public func havePath(_ expectedPath: String) -> Matcher<HTTPRequest> {
  Matcher { actualExpression in
    guard let request = try actualExpression.evaluate() else {
      return MatcherResult(status: .fail, message: .fail("expected request, got nil"))
    }

    let actualPath = request.url.path
    let matches = actualPath == expectedPath

    return MatcherResult(
      bool: matches,
      message: .expectedCustomValueTo(
        "have path '\(expectedPath)'",
        actual: "'\(actualPath)'"
      )
    )
  }
}

/// Matches an HTTP request that has a specific header.
public func haveRequestHeader(
  _ name: String,
  withValue value: String? = nil
) -> Matcher<HTTPRequest> {
  Matcher { actualExpression in
    guard let request = try actualExpression.evaluate() else {
      return MatcherResult(status: .fail, message: .fail("expected request, got nil"))
    }

    let headerValue = request.headers[name]

    if let expectedValue = value {
      let matches = headerValue == expectedValue
      return MatcherResult(
        bool: matches,
        message: .expectedCustomValueTo(
          "have header '\(name)' with value '\(expectedValue)'",
          actual: headerValue.map { "'\($0)'" } ?? "missing"
        )
      )
    } else {
      let matches = headerValue != nil
      return MatcherResult(
        bool: matches,
        message: .expectedCustomValueTo(
          "have header '\(name)'",
          actual: matches ? "present" : "missing"
        )
      )
    }
  }
}

// MARK: - Scenario Context Matchers

/// Matches a scenario context that has a response.
public func haveResponse() -> Matcher<ScenarioContext> {
  Matcher { actualExpression in
    guard let context = try actualExpression.evaluate() else {
      return MatcherResult(status: .fail, message: .fail("expected context, got nil"))
    }

    let hasResponse = context.lastResponse != nil

    return MatcherResult(
      bool: hasResponse,
      message: .expectedCustomValueTo(
        "have a response",
        actual: hasResponse ? "has response" : "no response"
      )
    )
  }
}

/// Matches a scenario context that has an error.
public func haveError() -> Matcher<ScenarioContext> {
  Matcher { actualExpression in
    guard let context = try actualExpression.evaluate() else {
      return MatcherResult(status: .fail, message: .fail("expected context, got nil"))
    }

    let hasError = context.lastError != nil

    return MatcherResult(
      bool: hasError,
      message: .expectedCustomValueTo(
        "have an error",
        actual: hasError ? "has error" : "no error"
      )
    )
  }
}

/// Matches a scenario context with a specific context value.
public func haveContextValue<T: Sendable & Equatable>(
  _ key: ContextKey<T>,
  equalTo expected: T
) -> Matcher<ScenarioContext> {
  Matcher { actualExpression in
    guard let context = try actualExpression.evaluate() else {
      return MatcherResult(status: .fail, message: .fail("expected context, got nil"))
    }

    guard let actual = context[key] else {
      return MatcherResult(
        status: .doesNotMatch,
        message: .expectedCustomValueTo(
          "have '\(key.name)' equal to \(expected)",
          actual: "missing"
        )
      )
    }

    let matches = actual == expected

    return MatcherResult(
      bool: matches,
      message: .expectedCustomValueTo(
        "have '\(key.name)' equal to \(expected)",
        actual: "\(actual)"
      )
    )
  }
}

#endif
