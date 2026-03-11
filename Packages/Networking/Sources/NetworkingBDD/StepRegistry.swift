import NetworkingRuntime
import NetworkingTesting
import Foundation

// swiftlint:disable file_length

// MARK: - Step Registry

/// Registry for matching Gherkin step text to step definitions.
///
/// The registry uses regex patterns to match step text and captures
/// parameters for injection into step implementations.
///
/// ## Usage
///
/// ```swift
/// let registry = StepRegistry()
///
/// registry.given("the base URL is \"(.+)\"") { context, matches in
///   let url = matches[0]
///   context.set(URL(string: url)!, for: .baseURL)
/// }
///
/// registry.when("I make a GET request to \"(.+)\"") { context, matches in
///   let path = matches[0]
///   // ... execute request
/// }
///
/// registry.then("the status should be (\\d+)") { context, matches in
///   let status = Int(matches[0])!
///   // ... verify status
/// }
/// ```
///
/// - Note: `@unchecked Sendable` justification:
///   All mutable state (`givenSteps`, `whenSteps`, `thenSteps`) is protected
///   by an internal `NSLock`. All public methods synchronize access via this lock.
public final class StepRegistry: @unchecked Sendable {
  // MARK: - Types

  /// A registered step definition.
  public struct StepDefinition: Sendable {
    /// The regex pattern for matching.
    public let pattern: BDDStepPattern

    /// Compiled regex.
    let regex: NSRegularExpression

    /// Step type (given/when/then).
    public let stepType: SemanticStepType

    /// The step implementation.
    let implementation: @Sendable (ScenarioContext, [BDDStepCaptureText]) async throws -> Void
  }

  // MARK: - Properties

  private let lock = NSLock()
  private var givenSteps: [StepDefinition] = []
  private var whenSteps: [StepDefinition] = []
  private var thenSteps: [StepDefinition] = []

  // MARK: - Initialization

  public init() {}

  // MARK: - Registration

  /// Registers a Given step definition.
  ///
  /// - Parameters:
  ///   - pattern: Regex pattern for matching step text
  ///   - implementation: The step implementation
  public func given(
    _ pattern: BDDStepPattern,
    implementation: @escaping @Sendable (ScenarioContext, [BDDStepCaptureText]) async throws -> Void
  ) throws {
    let regex = try compilePattern(pattern)
    let definition = StepDefinition(
      pattern: pattern,
      regex: regex,
      stepType: .given,
      implementation: implementation
    )

    lock.withLock {
      givenSteps.append(definition)
    }
  }

  /// Registers a When step definition.
  ///
  /// - Parameters:
  ///   - pattern: Regex pattern for matching step text
  ///   - implementation: The step implementation
  public func when(
    _ pattern: BDDStepPattern,
    implementation: @escaping @Sendable (ScenarioContext, [BDDStepCaptureText]) async throws -> Void
  ) throws {
    let regex = try compilePattern(pattern)
    let definition = StepDefinition(
      pattern: pattern,
      regex: regex,
      stepType: .when,
      implementation: implementation
    )

    lock.withLock {
      whenSteps.append(definition)
    }
  }

  /// Registers a Then step definition.
  ///
  /// - Parameters:
  ///   - pattern: Regex pattern for matching step text
  ///   - implementation: The step implementation
  public func then(
    _ pattern: BDDStepPattern,
    implementation: @escaping @Sendable (ScenarioContext, [BDDStepCaptureText]) async throws -> Void
  ) throws {
    let regex = try compilePattern(pattern)
    let definition = StepDefinition(
      pattern: pattern,
      regex: regex,
      stepType: .then,
      implementation: implementation
    )

    lock.withLock {
      thenSteps.append(definition)
    }
  }

  // MARK: - Step Matching

  /// Finds a matching step definition for the given step.
  ///
  /// - Parameters:
  ///   - step: The Gherkin step to match
  ///   - semanticType: The semantic type (given/when/then)
  /// - Returns: Tuple of (definition, captured matches)
  /// - Throws: `BDDError.undefinedStep` or `BDDError.ambiguousStep`
  public func findMatch(
    for step: GherkinStep,
    semanticType: SemanticStepType
  ) throws -> (StepDefinition, [BDDStepCaptureText]) {
    let matches = matchingDefinitions(for: step.text, semanticType: semanticType)
    return try resolveMatch(matches, for: step.text)
  }

  /// Executes a step using the registered definitions.
  ///
  /// - Parameters:
  ///   - step: The step to execute
  ///   - semanticType: The semantic type
  ///   - context: The scenario context
  /// - Throws: Errors from step execution
  public func execute(
    step: GherkinStep,
    semanticType: SemanticStepType,
    context: ScenarioContext
  ) async throws {
    let (definition, captures) = try findMatch(for: step, semanticType: semanticType)
    try await definition.implementation(context, captures)
  }

  // MARK: - Step Existence

  /// Checks if a step definition exists for the given text.
  ///
  /// - Parameters:
  ///   - text: The step text
  ///   - type: The semantic type
  /// - Returns: True if a matching definition exists
  public func hasDefinition(
    for text: BDDStepText,
    type: SemanticStepType
  ) -> BDDDefinitionAvailabilityFlag {
    let definitions = stepDefinitions(for: type)
    return BDDDefinitionAvailabilityFlag(
      definitions.contains { definition in
        matchStep(text, against: definition.regex) != nil
      }
    )
  }

  // MARK: - Clear

  /// Removes all registered step definitions.
  public func clear() {
    lock.withLock {
      givenSteps.removeAll()
      whenSteps.removeAll()
      thenSteps.removeAll()
    }
  }

  // MARK: - Private Helpers

  private func compilePattern(_ pattern: BDDStepPattern) throws -> NSRegularExpression {
    do {
      return try NSRegularExpression(pattern: "^" + pattern.rawValue + "$", options: [])
    } catch {
      throw BDDError.invalidStepPattern(
        pattern: pattern,
        error: UserMessageText(error.localizedDescription)
      )
    }
  }

  private func matchStep(
    _ text: BDDStepText,
    against regex: NSRegularExpression
  ) -> [BDDStepCaptureText]? {
    let rawText = text.rawValue
    let range = NSRange(rawText.startIndex..<rawText.endIndex, in: rawText)
    guard let match = regex.firstMatch(in: rawText, options: [], range: range) else {
      return nil
    }

    var captures: [BDDStepCaptureText] = []
    for i in 1..<match.numberOfRanges {
      if let range = Range(match.range(at: i), in: rawText) {
        captures.append(BDDStepCaptureText(String(rawText[range])))
      } else {
        captures.append("")
      }
    }

    return captures
  }

  private func stepDefinitions(for semanticType: SemanticStepType) -> [StepDefinition] {
    lock.withLock {
      switch semanticType {
      case .given:
        return givenSteps
      case .when:
        return whenSteps
      case .then:
        return thenSteps
      }
    }
  }

  private func matchingDefinitions(
    for stepText: BDDStepText,
    semanticType: SemanticStepType
  ) -> [(StepDefinition, [BDDStepCaptureText])] {
    stepDefinitions(for: semanticType).compactMap { definition in
      guard let captures = matchStep(stepText, against: definition.regex) else {
        return nil
      }
      return (definition, captures)
    }
  }

  private func resolveMatch(
    _ matches: [(StepDefinition, [BDDStepCaptureText])],
    for stepText: BDDStepText
  ) throws -> (StepDefinition, [BDDStepCaptureText]) {
    if matches.isEmpty {
      throw BDDError.undefinedStep(stepText)
    }

    if matches.count > 1 {
      throw BDDError.ambiguousStep(stepText, matchCount: RequestCount(matches.count))
    }

    return matches[0]
  }
}

// MARK: - Step Registry Extensions

extension StepRegistry {
  /// Convenience method to register a Given step with a simple closure.
  public func given(
    _ pattern: BDDStepPattern,
    step: @escaping @Sendable (ScenarioContext) async throws -> Void
  ) throws {
    try given(pattern) { context, _ in
      try await step(context)
    }
  }

  /// Convenience method to register a When step with a simple closure.
  public func when(
    _ pattern: BDDStepPattern,
    step: @escaping @Sendable (ScenarioContext) async throws -> Void
  ) throws {
    try when(pattern) { context, _ in
      try await step(context)
    }
  }

  /// Convenience method to register a Then step with a simple closure.
  public func then(
    _ pattern: BDDStepPattern,
    step: @escaping @Sendable (ScenarioContext) async throws -> Void
  ) throws {
    try then(pattern) { context, _ in
      try await step(context)
    }
  }
}

// MARK: - Step Registry Builder

/// Result builder for fluent step registration.
@resultBuilder
public struct StepRegistryBuilder {
  /// Builds a block of step registrations.
  public static func buildBlock(_ registrations: StepRegistration...) -> [StepRegistration] {
    registrations
  }
}

/// A step registration for the builder.
public struct StepRegistration: Sendable {
  let register: @Sendable (StepRegistry) throws -> Void

  /// Creates a Given step registration.
  public static func given(
    _ pattern: BDDStepPattern,
    implementation: @escaping @Sendable (ScenarioContext, [BDDStepCaptureText]) async throws -> Void
  ) -> Self {
    Self { registry in
      try registry.given(pattern, implementation: implementation)
    }
  }

  /// Creates a When step registration.
  public static func when(
    _ pattern: BDDStepPattern,
    implementation: @escaping @Sendable (ScenarioContext, [BDDStepCaptureText]) async throws -> Void
  ) -> Self {
    Self { registry in
      try registry.when(pattern, implementation: implementation)
    }
  }

  /// Creates a Then step registration.
  public static func then(
    _ pattern: BDDStepPattern,
    implementation: @escaping @Sendable (ScenarioContext, [BDDStepCaptureText]) async throws -> Void
  ) -> Self {
    Self { registry in
      try registry.then(pattern, implementation: implementation)
    }
  }
}

extension StepRegistry {
  /// Registers steps using the builder pattern.
  ///
  /// ```swift
  /// let registry = StepRegistry()
  /// try registry.register {
  ///   .given("the base URL is \"(.+)\"") { context, matches in
  ///     // ...
  ///   }
  ///   .when("I make a GET request") { context, _ in
  ///     // ...
  ///   }
  /// }
  /// ```
  public func register(
    @StepRegistryBuilder _ builder: () -> [StepRegistration]
  ) throws {
    let registrations = builder()
    for registration in registrations {
      try registration.register(self)
    }
  }
}
// swiftlint:enable file_length
