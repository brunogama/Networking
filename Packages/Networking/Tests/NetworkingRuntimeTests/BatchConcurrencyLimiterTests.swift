@testable import NetworkingRuntime
import NetworkingDSL
import NetworkingRuntimeDSL
import NetworkingTesting
import Testing

@Suite("BatchConcurrencyLimiter Tests")
struct BatchConcurrencyLimiterTests {
  @Test("A cancelled waiter stops waiting without consuming a permit")
  func cancelledWaiterStopsWaiting() async throws {
    let limiter = BatchConcurrencyLimiter(maxConcurrency: 1)
    let completion = CompletionState()
    await limiter.acquire()

    let waiter = Task {
      let acquired = await limiter.acquire()
      await completion.finish(entered: acquired)
    }

    try await Task.sleep(for: .milliseconds(20))
    waiter.cancel()
    try await Task.sleep(for: .milliseconds(20))

    #expect(await completion.isFinished)
    #expect(!(await completion.entered))

    await limiter.release()
    await waiter.value
  }

  @Test
  func limiter_withMaxConcurrency3_allowsOnlyThreeConcurrent() async throws {
    let limiter = BatchConcurrencyLimiter(maxConcurrency: 3)

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

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<10 {
        group.addTask {
          await limiter.acquire()
          await tracker.increment()

          try? await Task.sleep(for: .milliseconds(50))

          await tracker.decrement()
          await limiter.release()
        }
      }

      await group.waitForAll()
    }

    let maxConcurrent = await tracker.getMaxObserved()

    #expect(maxConcurrent <= 3)
    #expect(maxConcurrent >= 1)
  }

  @Test
  func limiter_withUnlimited_allowsAllConcurrent() async throws {
    let limiter = BatchConcurrencyLimiter(maxConcurrency: 0)

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

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<10 {
        group.addTask {
          await limiter.acquire()
          await tracker.increment()

          try? await Task.sleep(for: .milliseconds(10))

          await tracker.decrement()
          await limiter.release()
        }
      }

      await group.waitForAll()
    }

    let maxConcurrent = await tracker.getMaxObserved()

    #expect(maxConcurrent >= 5)
  }

  @Test
  func limiter_withSerial_executesOneAtATime() async throws {
    let limiter = BatchConcurrencyLimiter(maxConcurrency: 1)

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

    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<5 {
        group.addTask {
          await limiter.acquire()
          await tracker.increment()

          try? await Task.sleep(for: .milliseconds(20))

          await tracker.decrement()
          await limiter.release()
        }
      }

      await group.waitForAll()
    }

    let maxConcurrent = await tracker.getMaxObserved()

    #expect(maxConcurrent == 1)
  }

  @Test
  func limiter_acquireRelease_roundTrip() async throws {
    let limiter = BatchConcurrencyLimiter(maxConcurrency: 2)

    await limiter.acquire()

    await limiter.acquire()

    await limiter.release()

    await limiter.release()

    await limiter.acquire()
    await limiter.release()

    #expect(Bool(true))
  }
}

private actor CompletionState {
  private(set) var isFinished = false
  private(set) var entered = false

  func finish(entered: Bool) {
    isFinished = true
    self.entered = entered
  }
}
