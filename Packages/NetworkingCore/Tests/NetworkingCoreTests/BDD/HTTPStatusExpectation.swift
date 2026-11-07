import Foundation
import Testing
@testable import NetworkingCore

struct HTTPStatusExpectation: Sendable {
  let code: Int
  let expected: HTTPStatus
  let isServerError: Bool
}
