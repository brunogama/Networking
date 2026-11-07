import Foundation
import Testing
@testable import NetworkingCore

struct ClientErrorContextExpectation: Sendable {
  let code: Int
  let expected: HTTPStatus
  let method: HTTPMethod
  let path: String
}
