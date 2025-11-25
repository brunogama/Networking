import Foundation
import SwiftCheck
import XCTest

@testable import Networking

/// Property-based tests for InterceptorChain monoid laws.
///
/// Tests that InterceptorChain satisfies the monoid algebraic laws:
/// - Left identity: empty.appending(a) == a
/// - Right identity: a.appending(empty) == a
/// - Associativity: (a.appending(b)).appending(c) == a.appending(b.appending(c))
final class InterceptorChainMonoidTests: XCTestCase {
  // MARK: - Monoid Identity Laws

  func testLeftIdentity() {
    property("Left identity: empty.appending(a) is equivalent to a")
      <- forAll(InterceptorChainGen.arbitrary) { (chain: InterceptorChain) in
        let result = InterceptorChain.empty.appending(chain)
        return Self.chainsAreEquivalent(result, chain)
      }
  }

  func testRightIdentity() {
    property("Right identity: a.appending(empty) is equivalent to a")
      <- forAll(InterceptorChainGen.arbitrary) { (chain: InterceptorChain) in
        let result = chain.appending(.empty)
        return Self.chainsAreEquivalent(result, chain)
      }
  }

  // MARK: - Monoid Associativity Law

  func testAssociativity() {
    property("Associativity: (a.appending(b)).appending(c) == a.appending(b.appending(c))")
      <- forAll(
        InterceptorChainGen.arbitrary,
        InterceptorChainGen.arbitrary,
        InterceptorChainGen.arbitrary
      ) { (a: InterceptorChain, b: InterceptorChain, c: InterceptorChain) in
        let leftAssoc = (a.appending(b)).appending(c)
        let rightAssoc = a.appending(b.appending(c))
        return Self.chainsAreEquivalent(leftAssoc, rightAssoc)
      }
  }

  // MARK: - Count Preservation Properties

  func testAppendingPreservesInterceptorCounts() {
    property("Appending preserves total interceptor counts")
      <- forAll(InterceptorChainGen.arbitrary, InterceptorChainGen.arbitrary) {
        (a: InterceptorChain, b: InterceptorChain) in
        let result = a.appending(b)

        let expectedRequestCount = a.requestInterceptorCount + b.requestInterceptorCount
        let expectedResponseCount = a.responseInterceptorCount + b.responseInterceptorCount

        return result.requestInterceptorCount == expectedRequestCount
          && result.responseInterceptorCount == expectedResponseCount
      }
  }

  func testEmptyChainHasZeroCounts() {
    XCTAssertEqual(InterceptorChain.empty.requestInterceptorCount, 0)
    XCTAssertEqual(InterceptorChain.empty.responseInterceptorCount, 0)
    XCTAssertTrue(InterceptorChain.empty.isEmpty)
  }

  // MARK: - Closure Property

  func testAppendingClosure() {
    property("Appending two chains produces a valid chain (closure)")
      <- forAll(InterceptorChainGen.arbitrary, InterceptorChainGen.arbitrary) {
        (a: InterceptorChain, b: InterceptorChain) in
        // Simply verify that appending produces a chain (doesn't crash)
        let result = a.appending(b)
        // The result should have predictable properties
        return result.requestInterceptorCount >= 0 && result.responseInterceptorCount >= 0
      }
  }

  // MARK: - Helper Methods

  /// Checks if two interceptor chains are equivalent by comparing their structure.
  ///
  /// Since we can't directly compare interceptor instances (they're protocol types),
  /// we compare the counts as a proxy for structural equivalence.
  private static func chainsAreEquivalent(
    _ lhs: InterceptorChain,
    _ rhs: InterceptorChain
  ) -> Bool {
    lhs.requestInterceptorCount == rhs.requestInterceptorCount
      && lhs.responseInterceptorCount == rhs.responseInterceptorCount
  }
}

// MARK: - Test Interceptors

/// Simple request interceptor for testing.
struct TestRequestInterceptor: RequestInterceptor {
  let id: String

  func intercept(
    request: inout HTTPRequest,
    context: InterceptorContext
  ) async throws -> InterceptorResult {
    .proceed
  }
}

/// Simple response interceptor for testing.
struct TestResponseInterceptor: ResponseInterceptor {
  let id: String

  func intercept(
    response: HTTPResponse,
    context: InterceptorContext
  ) async throws -> InterceptorResult {
    .proceed
  }
}

// MARK: - Generators

enum InterceptorChainGen {
  static var arbitrary: Gen<InterceptorChain> {
    Gen<InterceptorChain>.compose { composer in
      // Generate 0-5 request interceptors
      let requestCount = composer.generate(using: Gen.choose((0, 5)))
      let requestInterceptors: [any RequestInterceptor] = (0..<requestCount).map { i in
        TestRequestInterceptor(id: "req-\(i)")
      }

      // Generate 0-5 response interceptors
      let responseCount = composer.generate(using: Gen.choose((0, 5)))
      let responseInterceptors: [any ResponseInterceptor] = (0..<responseCount).map { i in
        TestResponseInterceptor(id: "resp-\(i)")
      }

      return InterceptorChain(
        requestInterceptors: requestInterceptors,
        responseInterceptors: responseInterceptors
      )
    }
  }
}
