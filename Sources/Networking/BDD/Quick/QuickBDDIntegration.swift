import Foundation

#if canImport(Quick) && canImport(Nimble)
import Quick
import Nimble

// MARK: - QuickSpec BDD Extensions

extension QuickSpec {
  /// Runs a type-safe network scenario within a QuickSpec context.
  ///
  /// ```swift
  /// describe("User API") {
  ///   it("should fetch user successfully") {
  ///     await runScenario {
  ///       NetworkScenario("Fetch user by ID")
  ///         .given(GivenBaseURL("https://api.example.com"))
  ///         .given(GivenMockResponse(path: "/users/1", statusCode: 200, json: User.mock))
  ///         .when(WhenGET("/users/1"))
  ///         .then(ThenStatusIs(200))
  ///     }
  ///   }
  /// }
  /// ```
  public func runScenario<Phase: ScenarioPhaseProtocol>(
    file: FileString = #file,
    line: UInt = #line,
    @ScenarioBuilder _ builder: () throws -> NetworkScenario<Phase>
  ) async throws where Phase: CompletePhase {
    let scenario = try builder()
    let context = ScenarioContext()

    do {
      try await scenario.run(with: context)
    } catch {
      fail("Scenario '\(scenario.name)' failed: \(error)", file: file, line: line)
      throw error
    }
  }

  /// Runs a scenario expecting it to fail.
  ///
  /// - Parameters:
  ///   - expectedError: The expected error type
  ///   - builder: Scenario builder closure
  public func runScenarioExpectingFailure<Phase: ScenarioPhaseProtocol, E: Error & Equatable>(
    expectedError: E,
    file: FileString = #file,
    line: UInt = #line,
    @ScenarioBuilder _ builder: () throws -> NetworkScenario<Phase>
  ) async where Phase: CompletePhase {
    let scenario = try? builder()
    guard let scenario = scenario else {
      fail("Failed to build scenario", file: file, line: line)
      return
    }

    let context = ScenarioContext()

    do {
      try await scenario.run(with: context)
      fail("Expected scenario to fail with \(expectedError)", file: file, line: line)
    } catch let error as E {
      expect(error).to(equal(expectedError), file: file, line: line)
    } catch {
      fail("Expected \(E.self), got \(type(of: error)): \(error)", file: file, line: line)
    }
  }
}

// MARK: - BDD DSL Functions for Quick

/// Creates a BDD describe block for a feature.
///
/// ```swift
/// feature("User Management") {
///   scenario("Create new user") {
///     // ...
///   }
/// }
/// ```
public func feature(
  _ name: String,
  file: FileString = #file,
  line: UInt = #line,
  flags: FilterFlags = [:],
  closure: () -> Void
) {
  describe("Feature: \(name)", file: file, line: line, flags: flags, closure: closure)
}

/// Creates a focused BDD feature block.
public func ffeature(
  _ name: String,
  file: FileString = #file,
  line: UInt = #line,
  flags: FilterFlags = [:],
  closure: () -> Void
) {
  fdescribe("Feature: \(name)", file: file, line: line, flags: flags, closure: closure)
}

/// Creates a pending BDD feature block.
public func xfeature(
  _ name: String,
  file: FileString = #file,
  line: UInt = #line,
  flags: FilterFlags = [:],
  closure: () -> Void
) {
  xdescribe("Feature: \(name)", file: file, line: line, flags: flags, closure: closure)
}

/// Creates a BDD scenario block.
///
/// ```swift
/// scenario("User logs in successfully") {
///   // given, when, then steps
/// }
/// ```
public func scenario(
  _ name: String,
  file: FileString = #file,
  line: UInt = #line,
  flags: FilterFlags = [:],
  closure: () -> Void
) {
  context("Scenario: \(name)", file: file, line: line, flags: flags, closure: closure)
}

/// Creates a focused BDD scenario block.
public func fscenario(
  _ name: String,
  file: FileString = #file,
  line: UInt = #line,
  flags: FilterFlags = [:],
  closure: () -> Void
) {
  fcontext("Scenario: \(name)", file: file, line: line, flags: flags, closure: closure)
}

/// Creates a pending BDD scenario block.
public func xscenario(
  _ name: String,
  file: FileString = #file,
  line: UInt = #line,
  flags: FilterFlags = [:],
  closure: () -> Void
) {
  xcontext("Scenario: \(name)", file: file, line: line, flags: flags, closure: closure)
}

// MARK: - Scenario Outline Support

/// Creates a scenario outline that runs with multiple data sets.
///
/// ```swift
/// scenarioOutline(
///   "User lookup returns correct status",
///   examples: [
///     ["userId": "1", "status": "200"],
///     ["userId": "999", "status": "404"],
///   ]
/// ) { example in
///   let userId = example["userId"]!
///   let status = Int(example["status"]!)!
///
///   // ... steps using userId and status
/// }
/// ```
public func scenarioOutline(
  _ name: String,
  file: FileString = #file,
  line: UInt = #line,
  flags: FilterFlags = [:],
  examples: [[String: String]],
  closure: @escaping ([String: String]) -> Void
) {
  context("Scenario Outline: \(name)", file: file, line: line, flags: flags) {
    for (index, example) in examples.enumerated() {
      let exampleDesc = example.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
      context("Example \(index + 1): \(exampleDesc)", file: file, line: line, flags: flags) {
        closure(example)
      }
    }
  }
}

/// Creates a focused scenario outline.
public func fscenarioOutline(
  _ name: String,
  file: FileString = #file,
  line: UInt = #line,
  flags: FilterFlags = [:],
  examples: [[String: String]],
  closure: @escaping ([String: String]) -> Void
) {
  fcontext("Scenario Outline: \(name)", file: file, line: line, flags: flags) {
    for (index, example) in examples.enumerated() {
      let exampleDesc = example.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
      context("Example \(index + 1): \(exampleDesc)", file: file, line: line, flags: flags) {
        closure(example)
      }
    }
  }
}

// MARK: - Background Support

/// Creates a BDD background block that runs before each scenario.
///
/// ```swift
/// feature("User API") {
///   background {
///     // Setup that runs before each scenario
///   }
///
///   scenario("Fetch user") { ... }
/// }
/// ```
public func background(
  file: FileString = #file,
  line: UInt = #line,
  closure: @escaping () -> Void
) {
  beforeEach(file: file, line: line, closure: closure)
}

/// Creates an async BDD background block.
public func background(
  file: FileString = #file,
  line: UInt = #line,
  closure: @escaping () async -> Void
) {
  beforeEach(file: file, line: line, closure: closure)
}

// MARK: - Step Execution Helpers

/// Executes Given steps in a Quick test.
public func given(
  _ description: String,
  file: FileString = #file,
  line: UInt = #line,
  closure: @escaping () async throws -> Void
) {
  it("Given \(description)", file: file, line: line) {
    await expectNoThrow(file: file, line: line) {
      try await closure()
    }
  }
}

/// Executes When steps in a Quick test.
public func when(
  _ description: String,
  file: FileString = #file,
  line: UInt = #line,
  closure: @escaping () async throws -> Void
) {
  it("When \(description)", file: file, line: line) {
    await expectNoThrow(file: file, line: line) {
      try await closure()
    }
  }
}

/// Executes Then steps in a Quick test.
public func then(
  _ description: String,
  file: FileString = #file,
  line: UInt = #line,
  closure: @escaping () async throws -> Void
) {
  it("Then \(description)", file: file, line: line) {
    await expectNoThrow(file: file, line: line) {
      try await closure()
    }
  }
}

/// Helper function to expect no throw in async context.
private func expectNoThrow(
  file: FileString,
  line: UInt,
  closure: @escaping () async throws -> Void
) async {
  do {
    try await closure()
  } catch {
    fail("Unexpected error: \(error)", file: file, line: line)
  }
}

#endif
