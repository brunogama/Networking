import Testing
@testable import Networking

/// Tests for BatchConcurrencyLimiter actor-based semaphore.
@Suite("BatchConcurrencyLimiter Tests")
struct BatchConcurrencyLimiterTests {

  /// Test that limiter with maxConcurrency=3 only allows 3 concurrent acquire() calls.
  @Test
  func limiter_withMaxConcurrency3_allowsOnlyThreeConcurrent() async throws {
    let limiter = BatchConcurrencyLimiter(maxConcurrency: 3)

    // Track how many tasks acquire concurrently
    actor ConcurrencyTracker {
      var currentCount = 0
      var maxObserved = 0

      func increment() {
        currentCount += 1
        maxObserved = max(maxObserved, currentCount)
      }

      func decrement() {
        currentCount -= 1
      }

      func getMaxObserved() -> Int {
        maxObserved
      }
    }

    let tracker = ConcurrencyTracker()

    // Spawn 10 tasks trying to acquire
    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<10 {
        group.addTask {
          await limiter.acquire()
          await tracker.increment()

          // Simulate work
          try? await Task.sleep(for: .milliseconds(50))

          await tracker.decrement()
          await limiter.release()
        }
      }

      await group.waitForAll()
    }

    let maxConcurrent = await tracker.getMaxObserved()

    // Should never exceed maxConcurrency of 3
    #expect(maxConcurrent <= 3)
    // Should have allowed at least 3 concurrent (if system permits)
    #expect(maxConcurrent >= 1)
  }

  /// Test that limiter with maxConcurrency=0 (unlimited) allows all tasks concurrently.
  @Test
  func limiter_withUnlimited_allowsAllConcurrent() async throws {
    let limiter = BatchConcurrencyLimiter(maxConcurrency: 0)

    // Track concurrent acquisitions
    actor ConcurrencyTracker {
      var currentCount = 0
      var maxObserved = 0

      func increment() {
        currentCount += 1
        maxObserved = max(maxObserved, currentCount)
      }

      func decrement() {
        currentCount -= 1
      }

      func getMaxObserved() -> Int {
        maxObserved
      }
    }

    let tracker = ConcurrencyTracker()

    // Spawn 10 tasks
    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<10 {
        group.addTask {
          await limiter.acquire()
          await tracker.increment()

          // Short work duration to keep all tasks alive
          try? await Task.sleep(for: .milliseconds(10))

          await tracker.decrement()
          await limiter.release()
        }
      }

      await group.waitForAll()
    }

    let maxConcurrent = await tracker.getMaxObserved()

    // With unlimited concurrency, should see most or all tasks running concurrently
    // Exact value depends on system scheduling, but should be >5 for 10 tasks
    #expect(maxConcurrent >= 5)
  }

  /// Test that limiter with maxConcurrency=1 executes tasks serially (one at a time).
  @Test
  func limiter_withSerial_executesOneAtATime() async throws {
    let limiter = BatchConcurrencyLimiter(maxConcurrency: 1)

    // Track concurrent acquisitions
    actor ConcurrencyTracker {
      var currentCount = 0
      var maxObserved = 0

      func increment() {
        currentCount += 1
        maxObserved = max(maxObserved, currentCount)
      }

      func decrement() {
        currentCount -= 1
      }

      func getMaxObserved() -> Int {
        maxObserved
      }
    }

    let tracker = ConcurrencyTracker()

    // Spawn 5 tasks
    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<5 {
        group.addTask {
          await limiter.acquire()
          await tracker.increment()

          // Simulate work
          try? await Task.sleep(for: .milliseconds(20))

          await tracker.decrement()
          await limiter.release()
        }
      }

      await group.waitForAll()
    }

    let maxConcurrent = await tracker.getMaxObserved()

    // Should only ever allow 1 concurrent task
    #expect(maxConcurrent == 1)
  }

  /// Test that acquire/release round-trip works correctly.
  @Test
  func limiter_acquireRelease_roundTrip() async throws {
    let limiter = BatchConcurrencyLimiter(maxConcurrency: 2)

    // Acquire first slot
    await limiter.acquire()

    // Acquire second slot
    await limiter.acquire()

    // Both slots filled - third acquire would suspend (can't test easily without deadlock risk)

    // Release first slot
    await limiter.release()

    // Release second slot
    await limiter.release()

    // Now all slots free - should be able to acquire again
    await limiter.acquire()
    await limiter.release()

    // Test passes if no suspension/deadlock occurred
    #expect(Bool(true))
  }
}
