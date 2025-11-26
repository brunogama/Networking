import Foundation

// MARK: - Given Step Builder

/// Result builder for composing Given steps.
///
/// Allows fluent construction of precondition steps:
///
/// ```swift
/// scenario.given {
///   MockResponse(path: "/users", status: 200)
///   MockResponse(path: "/posts", status: 200)
///   BaseURL("https://api.example.com")
/// }
/// ```
@resultBuilder
public struct GivenStepBuilder {
  /// Builds a block of Given steps.
  public static func buildBlock(_ components: any GivenStep...) -> [any GivenStep] {
    components
  }

  /// Builds an array of Given steps.
  public static func buildArray(_ components: [[any GivenStep]]) -> [any GivenStep] {
    components.flatMap { $0 }
  }

  /// Builds an optional Given step.
  public static func buildOptional(_ component: [any GivenStep]?) -> [any GivenStep] {
    component ?? []
  }

  /// Builds the first branch of a conditional.
  public static func buildEither(first component: [any GivenStep]) -> [any GivenStep] {
    component
  }

  /// Builds the second branch of a conditional.
  public static func buildEither(second component: [any GivenStep]) -> [any GivenStep] {
    component
  }

  /// Builds an expression into a component.
  public static func buildExpression(_ expression: any GivenStep) -> [any GivenStep] {
    [expression]
  }

  /// Builds an array expression into a component.
  public static func buildExpression(_ expression: [any GivenStep]) -> [any GivenStep] {
    expression
  }

  /// Builds a final result from components.
  public static func buildFinalResult(_ component: [any GivenStep]) -> [any GivenStep] {
    component
  }
}

// MARK: - When Step Builder

/// Result builder for composing When steps.
///
/// Allows fluent construction of action steps:
///
/// ```swift
/// scenario.when {
///   GET("/users/123")
///   // or
///   POST("/users", body: newUser)
/// }
/// ```
@resultBuilder
public struct WhenStepBuilder {
  /// Builds a block of When steps.
  public static func buildBlock(_ components: any WhenStep...) -> [any WhenStep] {
    components
  }

  /// Builds an array of When steps.
  public static func buildArray(_ components: [[any WhenStep]]) -> [any WhenStep] {
    components.flatMap { $0 }
  }

  /// Builds an optional When step.
  public static func buildOptional(_ component: [any WhenStep]?) -> [any WhenStep] {
    component ?? []
  }

  /// Builds the first branch of a conditional.
  public static func buildEither(first component: [any WhenStep]) -> [any WhenStep] {
    component
  }

  /// Builds the second branch of a conditional.
  public static func buildEither(second component: [any WhenStep]) -> [any WhenStep] {
    component
  }

  /// Builds an expression into a component.
  public static func buildExpression(_ expression: any WhenStep) -> [any WhenStep] {
    [expression]
  }

  /// Builds an array expression into a component.
  public static func buildExpression(_ expression: [any WhenStep]) -> [any WhenStep] {
    expression
  }

  /// Builds a final result from components.
  public static func buildFinalResult(_ component: [any WhenStep]) -> [any WhenStep] {
    component
  }
}

// MARK: - Then Step Builder

/// Result builder for composing Then steps.
///
/// Allows fluent construction of assertion steps:
///
/// ```swift
/// scenario.then {
///   StatusIs(.ok)
///   HeaderExists("Content-Type")
///   BodyContains("success")
/// }
/// ```
@resultBuilder
public struct ThenStepBuilder {
  /// Builds a block of Then steps.
  public static func buildBlock(_ components: any ThenStep...) -> [any ThenStep] {
    components
  }

  /// Builds an array of Then steps.
  public static func buildArray(_ components: [[any ThenStep]]) -> [any ThenStep] {
    components.flatMap { $0 }
  }

  /// Builds an optional Then step.
  public static func buildOptional(_ component: [any ThenStep]?) -> [any ThenStep] {
    component ?? []
  }

  /// Builds the first branch of a conditional.
  public static func buildEither(first component: [any ThenStep]) -> [any ThenStep] {
    component
  }

  /// Builds the second branch of a conditional.
  public static func buildEither(second component: [any ThenStep]) -> [any ThenStep] {
    component
  }

  /// Builds an expression into a component.
  public static func buildExpression(_ expression: any ThenStep) -> [any ThenStep] {
    [expression]
  }

  /// Builds an array expression into a component.
  public static func buildExpression(_ expression: [any ThenStep]) -> [any ThenStep] {
    expression
  }

  /// Builds a final result from components.
  public static func buildFinalResult(_ component: [any ThenStep]) -> [any ThenStep] {
    component
  }
}

// MARK: - Scenario Builder

/// Result builder for composing complete scenarios.
///
/// ```swift
/// @ScenarioBuilder
/// func userScenarios() -> [NetworkScenario<ScenarioPhase.Complete>] {
///   scenario("Fetch user")
///     .given { ... }
///     .when { ... }
///     .then { ... }
///
///   scenario("Create user")
///     .given { ... }
///     .when { ... }
///     .then { ... }
/// }
/// ```
@resultBuilder
public struct ScenarioBuilder {
  /// Builds a block of scenarios.
  public static func buildBlock(
    _ components: NetworkScenario<ScenarioPhase.Complete>...
  ) -> [NetworkScenario<ScenarioPhase.Complete>] {
    components
  }

  /// Builds an array of scenarios.
  public static func buildArray(
    _ components: [[NetworkScenario<ScenarioPhase.Complete>]]
  ) -> [NetworkScenario<ScenarioPhase.Complete>] {
    components.flatMap { $0 }
  }

  /// Builds an optional scenario.
  public static func buildOptional(
    _ component: [NetworkScenario<ScenarioPhase.Complete>]?
  ) -> [NetworkScenario<ScenarioPhase.Complete>] {
    component ?? []
  }

  /// Builds the first branch of a conditional.
  public static func buildEither(
    first component: [NetworkScenario<ScenarioPhase.Complete>]
  ) -> [NetworkScenario<ScenarioPhase.Complete>] {
    component
  }

  /// Builds the second branch of a conditional.
  public static func buildEither(
    second component: [NetworkScenario<ScenarioPhase.Complete>]
  ) -> [NetworkScenario<ScenarioPhase.Complete>] {
    component
  }

  /// Builds an expression into a component.
  public static func buildExpression(
    _ expression: NetworkScenario<ScenarioPhase.Complete>
  ) -> [NetworkScenario<ScenarioPhase.Complete>] {
    [expression]
  }

  /// Builds an array expression into a component.
  public static func buildExpression(
    _ expression: [NetworkScenario<ScenarioPhase.Complete>]
  ) -> [NetworkScenario<ScenarioPhase.Complete>] {
    expression
  }

  /// Builds a final result from components.
  public static func buildFinalResult(
    _ component: [NetworkScenario<ScenarioPhase.Complete>]
  ) -> [NetworkScenario<ScenarioPhase.Complete>] {
    component
  }
}

// MARK: - Step Builder Extensions

/// Closure-based Given step for inline definitions.
public struct InlineGivenStep: GivenStep, DescribableStep {
  private let _setup: @Sendable (ScenarioContext) async throws -> Void
  public let stepDescription: String

  /// Creates an inline Given step.
  ///
  /// - Parameters:
  ///   - description: Step description
  ///   - setup: Setup closure
  public init(
    _ description: String,
    setup: @escaping @Sendable (ScenarioContext) async throws -> Void
  ) {
    self.stepDescription = description
    self._setup = setup
  }

  public func setup(context: ScenarioContext) async throws {
    try await _setup(context)
  }
}

/// Closure-based When step for inline definitions.
public struct InlineWhenStep: WhenStep, DescribableStep {
  private let _perform: @Sendable (ScenarioContext) async throws -> Void
  public let stepDescription: String

  /// Creates an inline When step.
  ///
  /// - Parameters:
  ///   - description: Step description
  ///   - perform: Perform closure
  public init(
    _ description: String,
    perform: @escaping @Sendable (ScenarioContext) async throws -> Void
  ) {
    self.stepDescription = description
    self._perform = perform
  }

  public func perform(context: ScenarioContext) async throws {
    try await _perform(context)
  }
}

/// Closure-based Then step for inline definitions.
public struct InlineThenStep: ThenStep, DescribableStep {
  private let _verify: @Sendable (ScenarioContext) throws -> Void
  public let stepDescription: String

  /// Creates an inline Then step.
  ///
  /// - Parameters:
  ///   - description: Step description
  ///   - verify: Verify closure
  public init(
    _ description: String,
    verify: @escaping @Sendable (ScenarioContext) throws -> Void
  ) {
    self.stepDescription = description
    self._verify = verify
  }

  public func verify(context: ScenarioContext) throws {
    try _verify(context)
  }
}

// MARK: - Convenience Functions

/// Creates an inline Given step.
///
/// - Parameters:
///   - description: Step description
///   - setup: Setup closure
/// - Returns: A Given step
public func given(
  _ description: String,
  setup: @escaping @Sendable (ScenarioContext) async throws -> Void
) -> InlineGivenStep {
  InlineGivenStep(description, setup: setup)
}

/// Creates an inline When step.
///
/// - Parameters:
///   - description: Step description
///   - perform: Perform closure
/// - Returns: A When step
public func when(
  _ description: String,
  perform: @escaping @Sendable (ScenarioContext) async throws -> Void
) -> InlineWhenStep {
  InlineWhenStep(description, perform: perform)
}

/// Creates an inline Then step.
///
/// - Parameters:
///   - description: Step description
///   - verify: Verify closure
/// - Returns: A Then step
public func then(
  _ description: String,
  verify: @escaping @Sendable (ScenarioContext) throws -> Void
) -> InlineThenStep {
  InlineThenStep(description, verify: verify)
}
