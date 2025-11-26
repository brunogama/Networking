import XCTest
@testable import Networking
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class BasicFluentTests: XCTestCase {
  func testFactoryMethods() throws {
    // Test various factory method combinations
    let standardPolicy = Policy.standard()
    let memoryStorage = Storage.memory(size: .KB(512))
    let ttlDuration = Duration.ttl(120)

    XCTAssertNotNil(standardPolicy)
    XCTAssertNotNil(memoryStorage)
    XCTAssertNotNil(ttlDuration)

    // Test backoff strategies
    let fixedBackoff = BackoffStrategy.fixed()
    let linearBackoff = BackoffStrategy.linear()
    let exponentialBackoff = BackoffStrategy.exponential()
    let customBackoff = BackoffStrategy.custom { attempt in
      Double(attempt) * 0.5
    }

    XCTAssertNotNil(fixedBackoff)
    XCTAssertNotNil(linearBackoff)
    XCTAssertNotNil(exponentialBackoff)
    XCTAssertNotNil(customBackoff)
  }

  func testStorageSizeCalculations() {
    let kbSize = StorageSize.KB(512)
    let mbSize = StorageSize.MB(10)
    let gbSize = StorageSize.GB(1)

    XCTAssertEqual(kbSize.bytes, 512 * 1024)
    XCTAssertEqual(mbSize.bytes, 10 * 1024 * 1024)
    XCTAssertEqual(gbSize.bytes, 1024 * 1024 * 1024)
  }

  func testBackoffStrategyCalculations() {
    let fixed = RetryBackoffStrategy.fixed
    let linear = RetryBackoffStrategy.linear
    let exponential = RetryBackoffStrategy.exponential

    let baseDelay: TimeInterval = 1.0

    // Test fixed backoff
    XCTAssertEqual(fixed.calculateDelay(for: 1, baseDelay: baseDelay), 1.0)
    XCTAssertEqual(fixed.calculateDelay(for: 3, baseDelay: baseDelay), 1.0)

    // Test linear backoff
    XCTAssertEqual(linear.calculateDelay(for: 1, baseDelay: baseDelay), 1.0)
    XCTAssertEqual(linear.calculateDelay(for: 2, baseDelay: baseDelay), 2.0)
    XCTAssertEqual(linear.calculateDelay(for: 3, baseDelay: baseDelay), 3.0)

    // Test exponential backoff
    XCTAssertEqual(exponential.calculateDelay(for: 1, baseDelay: baseDelay), 1.0)
    XCTAssertEqual(exponential.calculateDelay(for: 2, baseDelay: baseDelay), 2.0)
    XCTAssertEqual(exponential.calculateDelay(for: 3, baseDelay: baseDelay), 4.0)
  }
}
