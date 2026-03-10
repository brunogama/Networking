import Foundation
import Testing

@testable import Networking

/// Basic BDD tests for core networking functionality using existing APIs
@Suite("Core networking behavior")
struct SimpleBDDTests {
  @Suite("HTTPRequest")
  struct HTTPRequestBehavior {
    @Suite("When creating a basic request")
    struct WhenCreatingABasicRequest {
      @Test("Has the correct properties")
      func hasTheCorrectProperties() {
        let url = URL(string: "https://api.example.com/users")!
        let request = HTTPRequest(method: .get, url: url)

        #expect(request.method == .get)
        #expect(request.url == url)
        #expect(request.headers.isEmpty)
        #expect(request.body == nil)
      }

      @Test("Supports headers and body")
      func supportsHeadersAndBody() {
        let url = URL(string: "https://api.example.com/users")!
        let headers = ["Content-Type": "application/json", "Authorization": "Bearer token"]
        let bodyData = Data("test body".utf8)

        let request = HTTPRequest(
          method: .post,
          url: url,
          headers: headers,
          body: bodyData
        )

        #expect(request.method == .post)
        #expect(request.url == url)
        #expect(request.headers == headers)
        #expect(request.body == bodyData)
      }
    }
  }

  @Suite("HTTPStatus")
  struct HTTPStatusBehavior {
    @Suite("When checking status categories")
    struct WhenCheckingStatusCategories {
      @Test("Correctly identifies success status codes")
      func correctlyIdentifiesSuccessStatusCodes() {
        #expect(HTTPStatus(rawValue: 200).isSuccess)
        #expect(HTTPStatus(rawValue: 201).isSuccess)
        #expect(HTTPStatus(rawValue: 299).isSuccess)
      }

      @Test("Correctly identifies client error status codes")
      func correctlyIdentifiesClientErrorStatusCodes() {
        #expect(HTTPStatus(rawValue: 400).isClientError)
        #expect(HTTPStatus(rawValue: 404).isClientError)
        #expect(HTTPStatus(rawValue: 499).isClientError)
      }

      @Test("Correctly identifies server error status codes")
      func correctlyIdentifiesServerErrorStatusCodes() {
        #expect(HTTPStatus(rawValue: 500).isServerError)
        #expect(HTTPStatus(rawValue: 502).isServerError)
        #expect(HTTPStatus(rawValue: 599).isServerError)
      }
    }
  }

  @Suite("HTTPError")
  struct HTTPErrorBehavior {
    @Suite("When handling different error categories")
    struct WhenHandlingDifferentErrorCategories {
      @Test("Categorizes HTTP errors correctly")
      func categorizesHTTPErrorsCorrectly() {
        let clientError = HTTPError(category: .http(HTTPStatus(rawValue: 400)))
        let serverError = HTTPError(category: .http(HTTPStatus(rawValue: 500)))

        guard case .http(let clientStatus) = clientError.category else {
          Issue.record("Expected HTTP error category for client error")
          return
        }

        guard case .http(let serverStatus) = serverError.category else {
          Issue.record("Expected HTTP error category for server error")
          return
        }

        #expect(clientStatus.isClientError)
        #expect(serverStatus.isServerError)
      }

      @Test("Handles network errors")
      func handlesNetworkErrors() {
        let networkError = HTTPError(category: .network(.connectionLost))

        #expect(networkError.recoveryCategory != .nonRecoverable)
      }

      @Test("Handles timeout errors")
      func handlesTimeoutErrors() {
        let timeoutError = HTTPError(category: .timeout)

        #expect(timeoutError.recoveryCategory != .nonRecoverable)
      }
    }
  }

  @Suite("CacheMetadata")
  struct CacheMetadataBehavior {
    @Suite("When configuring cache settings")
    struct WhenConfiguringCacheSettings {
      @Test("Stores TTL and tags correctly")
      func storesTTLAndTagsCorrectly() {
        let metadata = CacheMetadata(ttl: 300, tags: ["user", "profile"])

        #expect(metadata.ttl == 300)
        #expect(metadata.tags == ["user", "profile"])
        #expect(metadata.customKey == nil)
        #expect(!metadata.isInvalidating)
      }

      @Test("Supports custom configuration")
      func supportsCustomConfiguration() {
        let metadata = CacheMetadata(
          ttl: 600,
          tags: ["data"],
          customKey: "custom-key",
          isInvalidating: true,
          invalidationTags: ["invalidate-user"]
        )

        #expect(metadata.ttl == 600)
        #expect(metadata.tags == ["data"])
        #expect(metadata.customKey == "custom-key")
        #expect(metadata.isInvalidating)
        #expect(metadata.invalidationTags == ["invalidate-user"])
      }
    }
  }

  @Suite("ValidatedResponse")
  struct ValidatedResponseBehavior {
    @Suite("When creating validated responses")
    struct WhenCreatingValidatedResponses {
      @Test("Creates successful responses")
      func createsSuccessfulResponses() {
        let request = HTTPRequest(
          method: .get,
          url: URL(string: "https://api.example.com/data")!
        )
        let status = HTTPStatus(rawValue: 200)
        let response = HTTPResponse(
          request: request,
          status: status,
          headers: [:],
          body: Data("success".utf8)
        )
        let validatedResponse = ValidatedResponse.success(response: response, value: "test data")

        #expect(validatedResponse.isValid)
        #expect(validatedResponse.value == "test data")
        #expect(validatedResponse.response.status == status)
        #expect(validatedResponse.validationErrors.isEmpty)
      }

      @Test("Creates failed responses")
      func createsFailedResponses() {
        let request = HTTPRequest(
          method: .get,
          url: URL(string: "https://api.example.com/data")!
        )
        let status = HTTPStatus(rawValue: 400)
        let response = HTTPResponse(
          request: request,
          status: status,
          headers: [:],
          body: nil
        )
        let validatedResponse = ValidatedResponse.failure(
          response: response,
          value: "error data",
          error: HTTPError(category: .http(status))
        )

        #expect(!validatedResponse.isValid)
        #expect(validatedResponse.value == "error data")
        #expect(!validatedResponse.validationErrors.isEmpty)

        guard let firstValidationError = validatedResponse.validationErrors.first else {
          Issue.record("Expected a validation error")
          return
        }

        #expect(firstValidationError is HTTPError)
      }
    }
  }
}
