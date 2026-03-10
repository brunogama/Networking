import Foundation
import Testing

@testable import NetworkingTesting
import NetworkingRuntime
import NetworkingObservability
import NetworkingDSL
import NetworkingRuntimeDSL

@Suite("SequentialMock Tests", .serialized)
struct SequentialMockTests {
  // MARK: - Test 1: Sequential requests match in order

  @Test("Sequential requests match in order")
  func sequentialRequestsMatchInOrder() async throws {
    // Arrange: Create SequentialMock with 2 expectations
    // First rule
    let expectFirst = Expect {
      Method(.get)
      Path("/auth/token")
    }
    let respondFirst = Respond {
      Status(.ok)
      Body(HTTPBody(Data(#"{"token": "abc123"}"#.utf8)))
    }

    // Second rule
    let expectSecond = Expect {
      Method(.get)
      Path("/users/me")
    }
    let respondSecond = Respond {
      Status(.ok)
      Body(HTTPBody(Data(#"{"id": 1, "name": "Alice"}"#.utf8)))
    }

    let rules: [MockRule] = [
      MockRule(expectation: expectFirst, response: respondFirst),
      MockRule(expectation: expectSecond, response: respondSecond),
    ]

    let mock = try SequentialMock(rules: rules)

    let session = mock.createSession()

    // Act: Execute first request
    let tokenURL = URL(string: "https://api.example.com/auth/token")!
    let (tokenData, tokenResponse) = try await session.data(from: tokenURL)

    // Assert: Token response is correct
    let tokenHTTPResponse = try #require(tokenResponse as? HTTPURLResponse)
    #expect(tokenHTTPResponse.statusCode == 200)

    let tokenJSON = try JSONDecoder().decode([String: String].self, from: tokenData)
    #expect(tokenJSON["token"] == "abc123")

    // Act: Execute second request
    let userURL = URL(string: "https://api.example.com/users/me")!
    let (userData, userResponse) = try await session.data(from: userURL)

    // Assert: User response is correct
    let userHTTPResponse = try #require(userResponse as? HTTPURLResponse)
    #expect(userHTTPResponse.statusCode == 200)

    // Verify data not empty
    #expect(!userData.isEmpty)

    // Assert: All expectations consumed
    try await mock.verifyAllExpectationsConsumed()
  }

  // MARK: - Test 2: Different responses for identical requests

  @Test("Different responses for identical requests")
  func differentResponsesForIdenticalRequests() async throws {
    // Arrange: Same path, different responses
    let firstExpect = Expect {
      Method(.get)
      Path("/api/data")
    }
    let firstRespond = Respond {
      Status(.ok)
      Body(HTTPBody(Data(#"{"value": "first"}"#.utf8)))
    }

    let secondExpect = Expect {
      Method(.get)
      Path("/api/data")
    }
    let secondRespond = Respond {
      Status(.ok)
      Body(HTTPBody(Data(#"{"value": "second"}"#.utf8)))
    }

    let rules: [MockRule] = [
      MockRule(expectation: firstExpect, response: firstRespond),
      MockRule(expectation: secondExpect, response: secondRespond),
    ]

    let mock = try SequentialMock(rules: rules)
    let session = mock.createSession()
    let dataURL = URL(string: "https://api.example.com/api/data")!

    // Act: Execute first request
    let (firstData, _) = try await session.data(from: dataURL)
    let firstJSON = try JSONDecoder().decode([String: String].self, from: firstData)

    // Assert: First response
    #expect(firstJSON["value"] == "first")

    // Act: Execute second request
    let (secondData, _) = try await session.data(from: dataURL)
    let secondJSON = try JSONDecoder().decode([String: String].self, from: secondData)

    // Assert: Second response (different from first)
    #expect(secondJSON["value"] == "second")

    // Assert: All expectations consumed
    try await mock.verifyAllExpectationsConsumed()
  }

  // MARK: - Test 3: Mismatched request does not match

  @Test("Mismatched request does not match stub")
  func mismatchedRequestDoesNotMatch() async throws {
    // Arrange: Expecting GET /expected
    let expectRule = Expect {
      Method(.get)
      Path("/expected")
    }
    let respondRule = Respond {
      Status(.ok)
    }

    let rules: [MockRule] = [
      MockRule(expectation: expectRule, response: respondRule)
    ]

    let mock = try SequentialMock(rules: rules)
    let session = mock.createSession()

    // Act: Try to execute GET /wrong-path
    let wrongURL = URL(string: "https://api.example.com/wrong-path")!

    // Assert: Request should fail (no matching stub)
    do {
      _ = try await session.data(from: wrongURL)
      Issue.record("Expected request to fail due to mismatch")
    } catch {
      // Expected: URLError when no matching stub found
      #expect(true, "Request correctly failed due to mismatch")
    }
  }

  // MARK: - Test 4: Unexpected call after all expectations consumed

  @Test("Unexpected call after expectations consumed")
  func unexpectedCallAfterExpectationsConsumed() async throws {
    // Arrange: Only 1 expectation
    let expectRule = Expect {
      Method(.get)
      Path("/only-one")
    }
    let respondRule = Respond {
      Status(.ok)
    }

    let rules: [MockRule] = [
      MockRule(expectation: expectRule, response: respondRule)
    ]

    let mock = try SequentialMock(rules: rules)
    let session = mock.createSession()
    let onlyURL = URL(string: "https://api.example.com/only-one")!

    // Act: First request succeeds
    let (_, firstResponse) = try await session.data(from: onlyURL)
    let firstHTTP = try #require(firstResponse as? HTTPURLResponse)
    #expect(firstHTTP.statusCode == 200)

    // Act: Second request should fail (no more expectations)
    do {
      _ = try await session.data(from: onlyURL)
      Issue.record("Expected second request to fail")
    } catch {
      // Expected: No more stubs to consume
      #expect(true, "Second request correctly failed")
    }
  }

  // MARK: - Test 5: Verify unconsumed expectations throws

  @Test("Verify all expectations consumed throws when incomplete")
  func verifyAllExpectationsConsumedThrows() async throws {
    // Arrange: 2 expectations
    let firstExpect = Expect {
      Method(.get)
      Path("/first")
    }
    let firstRespond = Respond {
      Status(.ok)
    }

    let secondExpect = Expect {
      Method(.get)
      Path("/second")
    }
    let secondRespond = Respond {
      Status(.ok)
    }

    let rules: [MockRule] = [
      MockRule(expectation: firstExpect, response: firstRespond),
      MockRule(expectation: secondExpect, response: secondRespond),
    ]

    let mock = try SequentialMock(rules: rules)
    let session = mock.createSession()
    let firstURL = URL(string: "https://api.example.com/first")!

    // Act: Only call first endpoint
    _ = try await session.data(from: firstURL)

    // Note: The consumption tracker tracks how many stubs were consumed by MockURLProtocol.
    // After calling first endpoint, 1 stub is consumed, 1 remains.
    // MockURLProtocol consumes stubs when they match, so we need to wait for that.
    try await Task.sleep(for: .milliseconds(200))

    // For this test, we verify the behavior by checking that after consuming
    // only 1 of 2 stubs, verification throws with remaining = 1
    var didThrow = false
    do {
      try await mock.verifyAllExpectationsConsumed()
    } catch let error as SequentialMockError {
      didThrow = true
      if case .unconsumedExpectations(let remaining) = error {
        #expect(remaining == 1, "Expected 1 unconsumed expectation, got \(remaining)")
      } else {
        Issue.record("Expected unconsumedExpectations error, got \(error)")
      }
    } catch {
      Issue.record("Unexpected error type: \(error)")
    }

    // The verification should throw because we only called 1 of 2 endpoints
    #expect(didThrow, "Expected verification to throw unconsumedExpectations")
  }
}
