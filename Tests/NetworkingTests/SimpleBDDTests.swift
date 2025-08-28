import XCTest
import Quick
import Nimble
@testable import Networking
import Foundation

/// Basic BDD tests for core networking functionality using existing APIs
final class SimpleBDDTests: QuickSpec {
  override class func spec() {
    describe("HTTPRequest") {
      context("when creating a basic request") {
        it("should have the correct properties") {
          // Given: A URL and method
          let url = URL(string: "https://api.example.com/users")!
          let method = HTTPMethod.get

          // When: Creating a request
          let request = HTTPRequest(method: method, url: url)

          // Then: Should have correct values
          expect(request.method).to(equal(.get))
          expect(request.url).to(equal(url))
          expect(request.headers).to(beEmpty())
          expect(request.body).to(beNil())
        }

        it("should support headers and body") {
          // Given: Request data
          let url = URL(string: "https://api.example.com/users")!
          let headers = ["Content-Type": "application/json", "Authorization": "Bearer token"]
          let bodyData = Data("test body".utf8)

          // When: Creating request with data
          let request = HTTPRequest(
            method: .post,
            url: url,
            headers: headers,
            body: bodyData
          )

          // Then: Should contain all data
          expect(request.method).to(equal(.post))
          expect(request.url).to(equal(url))
          expect(request.headers).to(equal(headers))
          expect(request.body).to(equal(bodyData))
        }
      }
    }

    describe("HTTPStatus") {
      context("when checking status categories") {
        it("should correctly identify success status codes") {
          let status200 = HTTPStatus(rawValue: 200)
          let status201 = HTTPStatus(rawValue: 201)
          let status299 = HTTPStatus(rawValue: 299)

          expect(status200.isSuccess).to(beTrue())
          expect(status201.isSuccess).to(beTrue())
          expect(status299.isSuccess).to(beTrue())
        }

        it("should correctly identify client error status codes") {
          let status400 = HTTPStatus(rawValue: 400)
          let status404 = HTTPStatus(rawValue: 404)
          let status499 = HTTPStatus(rawValue: 499)

          expect(status400.isClientError).to(beTrue())
          expect(status404.isClientError).to(beTrue())
          expect(status499.isClientError).to(beTrue())
        }

        it("should correctly identify server error status codes") {
          let status500 = HTTPStatus(rawValue: 500)
          let status502 = HTTPStatus(rawValue: 502)
          let status599 = HTTPStatus(rawValue: 599)

          expect(status500.isServerError).to(beTrue())
          expect(status502.isServerError).to(beTrue())
          expect(status599.isServerError).to(beTrue())
        }
      }
    }

    describe("HTTPError") {
      context("when handling different error categories") {
        it("should categorize HTTP errors correctly") {
          // Given: Different HTTP status codes
          let status400 = HTTPStatus(rawValue: 400)
          let status500 = HTTPStatus(rawValue: 500)

          // When: Creating HTTP errors
          let clientError = HTTPError(category: .http(status400))
          let serverError = HTTPError(category: .http(status500))

          // Then: Should have correct categories
          switch clientError.category {
          case .http(let status):
            expect(status.isClientError).to(beTrue())

          default:
            fail("Expected HTTP error category")
          }

          switch serverError.category {
          case .http(let status):
            expect(status.isServerError).to(beTrue())

          default:
            fail("Expected HTTP error category")
          }
        }

        it("should handle network errors") {
          // Given: A network error
          let networkError = HTTPError(category: .network(.connectionLost))

          // When: Checking error properties
          // Then: Should be recoverable
          expect(networkError.recoveryCategory != .nonRecoverable).to(beTrue())
        }

        it("should handle timeout errors") {
          // Given: A timeout error
          let timeoutError = HTTPError(category: .timeout)

          // When: Checking error properties
          // Then: Should be recoverable
          expect(timeoutError.recoveryCategory != .nonRecoverable).to(beTrue())
        }
      }
    }

    describe("CacheMetadata") {
      context("when configuring cache settings") {
        it("should store TTL and tags correctly") {
          // Given: Cache configuration
          let ttl: TimeInterval = 300
          let tags = ["user", "profile"]

          // When: Creating cache metadata
          let metadata = CacheMetadata(ttl: ttl, tags: tags)

          // Then: Should have correct values
          expect(metadata.ttl).to(equal(ttl))
          expect(metadata.tags).to(equal(tags))
          expect(metadata.customKey).to(beNil())
          expect(metadata.isInvalidating).to(beFalse())
        }

        it("should support custom configuration") {
          // Given: Custom cache settings
          let customKey = "custom-key"
          let invalidationTags = ["invalidate-user"]

          // When: Creating metadata with custom settings
          let metadata = CacheMetadata(
            ttl: 600,
            tags: ["data"],
            customKey: customKey,
            isInvalidating: true,
            invalidationTags: invalidationTags
          )

          // Then: Should store all settings
          expect(metadata.ttl).to(equal(600))
          expect(metadata.tags).to(equal(["data"]))
          expect(metadata.customKey).to(equal(customKey))
          expect(metadata.isInvalidating).to(beTrue())
          expect(metadata.invalidationTags).to(equal(invalidationTags))
        }
      }
    }

    describe("ValidatedResponse") {
      context("when creating validated responses") {
        it("should create successful responses") {
          // Given: Response data
          let url = URL(string: "https://api.example.com/data")!
          let request = HTTPRequest(method: .get, url: url)
          let status = HTTPStatus(rawValue: 200)
          let response = HTTPResponse(
            request: request,
            status: status,
            headers: [:],
            body: Data("success".utf8)
          )
          let value = "test data"

          // When: Creating validated response
          let validatedResponse = ValidatedResponse.success(response: response, value: value)

          // Then: Should be valid
          expect(validatedResponse.isValid).to(beTrue())
          expect(validatedResponse.value).to(equal(value))
          expect(validatedResponse.response.status).to(equal(status))
          expect(validatedResponse.validationErrors).to(beEmpty())
        }

        it("should create failed responses") {
          // Given: Response data with error
          let url = URL(string: "https://api.example.com/data")!
          let request = HTTPRequest(method: .get, url: url)
          let status = HTTPStatus(rawValue: 400)
          let response = HTTPResponse(
            request: request,
            status: status,
            headers: [:],
            body: nil
          )
          let value = "error data"
          let error = HTTPError(category: .http(status))

          // When: Creating failed response
          let validatedResponse = ValidatedResponse.failure(
            response: response,
            value: value,
            error: error
          )

          // Then: Should be invalid
          expect(validatedResponse.isValid).to(beFalse())
          expect(validatedResponse.value).to(equal(value))
          expect(validatedResponse.validationErrors).toNot(beEmpty())
          expect(validatedResponse.validationErrors.first).to(beAnInstanceOf(HTTPError.self))
        }
      }
    }
  }
}
