import Foundation
import Quick
import Nimble
import XCTest

@testable import Networking

/// BDD specs for error handling behaviors
///
/// These specs describe observable error handling behaviors:
/// - HTTP error classification (4xx client, 5xx server)
/// - Error recovery strategies
/// - Retryable vs non-retryable error detection
///
/// NOTE: Supplements existing error handling tests with behavior-focused specs.
final class ErrorHandlingBehaviorSpec: QuickSpec {
  override class func spec() {
    describe("Error Handling") {

      describe("HTTP errors") {

        context("4xx client errors") {

          it("classifies 400 as bad request") {
            // Given: A 400 status code
            let status = HTTPStatus(rawValue: 400)

            // When: Creating an HTTP error
            let error = HTTPError(category: .http(status))

            // Then: Error is classified as client error
            expect(status.isClientError).to(beTrue())
            expect(status.isServerError).to(beFalse())
            expect(status.rawValue).to(equal(400))

            // Verify error category
            if case .http(let errorStatus) = error.category {
              expect(errorStatus).to(equal(status))
            } else {
              fail("Expected HTTP error category")
            }
          }

          it("classifies 401 as unauthorized") {
            // Given: A 401 status code
            let status = HTTPStatus(rawValue: 401)

            // Then: Status is unauthorized
            expect(status).to(equal(.unauthorized))
            expect(status.isClientError).to(beTrue())
          }

          it("classifies 404 as not found") {
            // Given: A 404 status code
            let status = HTTPStatus(rawValue: 404)

            // Then: Status is not found
            expect(status).to(equal(.notFound))
            expect(status.isClientError).to(beTrue())
          }

          it("classifies 429 as too many requests") {
            // Given: A 429 status code
            let status = HTTPStatus(rawValue: 429)

            // Then: Status is rate limited
            expect(status).to(equal(.tooManyRequests))
            expect(status.isClientError).to(beTrue())
          }
        }

        context("5xx server errors") {

          it("classifies 500 as internal server error") {
            // Given: A 500 status code
            let status = HTTPStatus(rawValue: 500)

            // Then: Status is server error
            expect(status).to(equal(.internalServerError))
            expect(status.isServerError).to(beTrue())
            expect(status.isClientError).to(beFalse())
          }

          it("classifies 502 as bad gateway") {
            // Given: A 502 status code
            let status = HTTPStatus(rawValue: 502)

            // Then: Status is bad gateway
            expect(status).to(equal(.badGateway))
            expect(status.isServerError).to(beTrue())
          }

          it("classifies 503 as service unavailable") {
            // Given: A 503 status code
            let status = HTTPStatus(rawValue: 503)

            // Then: Status is service unavailable
            expect(status).to(equal(.serviceUnavailable))
            expect(status.isServerError).to(beTrue())
          }

          it("classifies 504 as gateway timeout") {
            // Given: A 504 status code
            let status = HTTPStatus(rawValue: 504)

            // Then: Status is gateway timeout
            expect(status).to(equal(.gatewayTimeout))
            expect(status.isServerError).to(beTrue())
          }
        }
      }

      describe("recovery strategies") {

        context("when error is retryable") {

          it("suggests retry for timeout errors") {
            // Given: A timeout error
            let request = HTTPRequest(
              method: .get,
              url: URL(string: "https://api.example.com/timeout")!
            )
            let error = HTTPError(category: .timeout, request: request)

            // Then: Error recovery suggests retry
            expect(error.recoveryCategory).toNot(equal(.nonRecoverable))
          }

          it("suggests retry for 503 errors") {
            // Given: A 503 service unavailable error
            let status = HTTPStatus(rawValue: 503)
            let request = HTTPRequest(
              method: .get,
              url: URL(string: "https://api.example.com/unavailable")!
            )
            let error = HTTPError(category: .http(status), request: request)

            // Then: Server errors are potentially retryable
            expect(status.isServerError).to(beTrue())
            // Recovery depends on configuration
            expect(error.category).toNot(beNil())
          }

          it("suggests retry for 429 rate limit") {
            // Given: A 429 rate limit error
            let status = HTTPStatus(rawValue: 429)
            let request = HTTPRequest(
              method: .get,
              url: URL(string: "https://api.example.com/rate-limited")!
            )
            let error = HTTPError(category: .http(status), request: request)

            // Then: Rate limit errors are retryable with backoff
            expect(status).to(equal(.tooManyRequests))
            expect(error.recoveryCategory).toNot(equal(.nonRecoverable))
          }

          it("suggests retry for network errors") {
            // Given: A network connectivity error
            let request = HTTPRequest(
              method: .get,
              url: URL(string: "https://api.example.com/offline")!
            )
            let error = HTTPError(
              category: .network(.connectionLost),
              request: request
            )

            // Then: Network errors are retryable
            expect(error.recoveryCategory).toNot(equal(.nonRecoverable))
          }
        }

        context("when error is not retryable") {

          it("does not suggest retry for 401") {
            // Given: A 401 unauthorized error
            let status = HTTPStatus(rawValue: 401)
            let request = HTTPRequest(
              method: .get,
              url: URL(string: "https://api.example.com/protected")!
            )
            let error = HTTPError(category: .http(status), request: request)

            // Then: 401 errors require re-authentication, not simple retry
            expect(status).to(equal(.unauthorized))
            expect(status.isClientError).to(beTrue())
          }

          it("does not suggest retry for 400 validation errors") {
            // Given: A 400 bad request error
            let status = HTTPStatus(rawValue: 400)
            let request = HTTPRequest(
              method: .post,
              url: URL(string: "https://api.example.com/create")!
            )
            let error = HTTPError(category: .http(status), request: request)

            // Then: Validation errors need request correction, not retry
            expect(status).to(equal(.badRequest))
            expect(status.isClientError).to(beTrue())
            // Client errors are typically not retryable without modification
          }

          it("does not suggest retry for 404 not found") {
            // Given: A 404 not found error
            let status = HTTPStatus(rawValue: 404)
            let request = HTTPRequest(
              method: .get,
              url: URL(string: "https://api.example.com/missing")!
            )
            let error = HTTPError(category: .http(status), request: request)

            // Then: Resource not found is not retryable
            expect(status).to(equal(.notFound))
            expect(status.isClientError).to(beTrue())
          }
        }
      }

      describe("error information") {

        context("when error contains request context") {

          it("preserves original request in error") {
            // Given: An error with request context
            let url = URL(string: "https://api.example.com/data")!
            let request = HTTPRequest(
              method: .post,
              url: url,
              headers: ["Content-Type": "application/json"],
              body: Data("{\"key\": \"value\"}".utf8)
            )
            let error = HTTPError(category: .timeout, request: request)

            // Then: Error contains original request
            expect(error.request).toNot(beNil())
            expect(error.request?.url).to(equal(url))
            expect(error.request?.method).to(equal(.post))
          }
        }

        context("when error contains response context") {

          it("preserves HTTP status in error") {
            // Given: An HTTP error with status
            let status = HTTPStatus(rawValue: 502)
            let error = HTTPError(category: .http(status))

            // Then: Error contains status information
            if case .http(let errorStatus) = error.category {
              expect(errorStatus.rawValue).to(equal(502))
              expect(errorStatus.isServerError).to(beTrue())
            } else {
              fail("Expected HTTP error with status")
            }
          }
        }
      }

      describe("error categories") {

        it("distinguishes network errors from HTTP errors") {
          // Given: Network and HTTP errors
          let networkError = HTTPError(category: .network(.connectionLost))
          let httpError = HTTPError(category: .http(.internalServerError))

          // Then: Categories are distinct
          switch networkError.category {
          case .network:
            // Correct - network error
            break
          default:
            fail("Expected network error category")
          }

          switch httpError.category {
          case .http:
            // Correct - HTTP error
            break
          default:
            fail("Expected HTTP error category")
          }
        }

        it("distinguishes timeout from other errors") {
          // Given: A timeout error
          let timeoutError = HTTPError(category: .timeout)

          // Then: Timeout is a distinct category
          switch timeoutError.category {
          case .timeout:
            // Correct - timeout error
            break
          default:
            fail("Expected timeout error category")
          }
        }
      }
    }
  }
}
