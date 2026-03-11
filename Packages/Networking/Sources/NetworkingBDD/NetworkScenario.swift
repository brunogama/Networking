import NetworkingRuntime
import NetworkingTesting
import Foundation

// swiftlint:disable file_length

// MARK: - Network Scenario

/// A type-safe BDD scenario builder for network testing.
///
/// `NetworkScenario` uses phantom types to enforce the correct
/// Given-When-Then ordering at compile time. You cannot call `.when()`
/// before `.given()`, or `.then()` before `.when()`.
///
/// ## Usage
///
/// ```swift
/// let scenario = NetworkScenario("User authentication")
///   .given {
///     MockResponse(path: "/login", status: 200)
///   }
///   .when {
///     POST("/login", body: credentials)
///   }
///   .then {
///     StatusIs(.ok)
///     BodyContains("token")
///   }
///
/// try await scenario.run(with: context)
/// ```
///
/// ## Phase Transitions
///
/// - `Initial` -> `GivenDefined` via `.given()`
/// - `GivenDefined` -> `WhenDefined` via `.when()`
/// - `WhenDefined` -> `Complete` via `.then()`
///
/// Only `Complete` scenarios can be executed with `.run()`.
public struct NetworkScenario<Phase: ScenarioPhaseProtocol>: Sendable {
  /// The scenario name.
  public let name: BDDScenarioName

  /// Optional description.
  public let description: BDDDescriptionText?

  /// Tags for filtering.
  public let tags: [Tag]

  /// Given steps (preconditions).
  let givenSteps: [any GivenStep]

  /// When steps (actions).
  let whenSteps: [any WhenStep]

  /// Then steps (assertions).
  let thenSteps: [any ThenStep]

  /// Creates a new scenario in the initial phase.
  ///
  /// - Parameters:
  ///   - name: Scenario name
  ///   - description: Optional description
  ///   - tags: Tags for filtering
  init(
    name: BDDScenarioName,
    description: BDDDescriptionText? = nil,
    tags: [Tag] = [],
    givenSteps: [any GivenStep] = [],
    whenSteps: [any WhenStep] = [],
    thenSteps: [any ThenStep] = []
  ) {
    self.name = name
    self.description = description
    self.tags = tags
    self.givenSteps = givenSteps
    self.whenSteps = whenSteps
    self.thenSteps = thenSteps
  }
}

// MARK: - Initial Phase

extension NetworkScenario where Phase == ScenarioPhase.Initial {
  /// Creates a new scenario.
  ///
  /// - Parameters:
  ///   - name: Scenario name
  ///   - description: Optional description
  ///   - tags: Tags for filtering
  public init(
    _ name: BDDScenarioName,
    description: BDDDescriptionText? = nil,
    tags: [Tag] = []
  ) {
    self.name = name
    self.description = description
    self.tags = tags
    self.givenSteps = []
    self.whenSteps = []
    self.thenSteps = []
  }

  /// Defines the Given steps (preconditions).
  ///
  /// - Parameter builder: A builder that produces Given steps
  /// - Returns: Scenario in GivenDefined phase
  public func given(
    @GivenStepBuilder builder: () -> [any GivenStep]
  ) -> NetworkScenario<ScenarioPhase.GivenDefined> {
    NetworkScenario<ScenarioPhase.GivenDefined>(
      name: name,
      description: description,
      tags: tags,
      givenSteps: builder(),
      whenSteps: [],
      thenSteps: []
    )
  }

  /// Defines a single Given step.
  ///
  /// - Parameter step: The Given step
  /// - Returns: Scenario in GivenDefined phase
  public func given<S: GivenStep>(
    _ step: S
  ) -> NetworkScenario<ScenarioPhase.GivenDefined> {
    NetworkScenario<ScenarioPhase.GivenDefined>(
      name: name,
      description: description,
      tags: tags,
      givenSteps: [step],
      whenSteps: [],
      thenSteps: []
    )
  }
}

// MARK: - GivenDefined Phase

extension NetworkScenario where Phase == ScenarioPhase.GivenDefined {
  /// Defines the When steps (actions).
  ///
  /// - Parameter builder: A builder that produces When steps
  /// - Returns: Scenario in WhenDefined phase
  public func when(
    @WhenStepBuilder builder: () -> [any WhenStep]
  ) -> NetworkScenario<ScenarioPhase.WhenDefined> {
    NetworkScenario<ScenarioPhase.WhenDefined>(
      name: name,
      description: description,
      tags: tags,
      givenSteps: givenSteps,
      whenSteps: builder(),
      thenSteps: []
    )
  }

  /// Defines a single When step.
  ///
  /// - Parameter step: The When step
  /// - Returns: Scenario in WhenDefined phase
  public func when<S: WhenStep>(
    _ step: S
  ) -> NetworkScenario<ScenarioPhase.WhenDefined> {
    NetworkScenario<ScenarioPhase.WhenDefined>(
      name: name,
      description: description,
      tags: tags,
      givenSteps: givenSteps,
      whenSteps: [step],
      thenSteps: []
    )
  }
}

// MARK: - WhenDefined Phase

extension NetworkScenario where Phase == ScenarioPhase.WhenDefined {
  /// Defines the Then steps (assertions).
  ///
  /// - Parameter builder: A builder that produces Then steps
  /// - Returns: Scenario in Complete phase
  public func then(
    @ThenStepBuilder builder: () -> [any ThenStep]
  ) -> NetworkScenario<ScenarioPhase.Complete> {
    NetworkScenario<ScenarioPhase.Complete>(
      name: name,
      description: description,
      tags: tags,
      givenSteps: givenSteps,
      whenSteps: whenSteps,
      thenSteps: builder()
    )
  }

  /// Defines a single Then step.
  ///
  /// - Parameter step: The Then step
  /// - Returns: Scenario in Complete phase
  public func then<S: ThenStep>(
    _ step: S
  ) -> NetworkScenario<ScenarioPhase.Complete> {
    NetworkScenario<ScenarioPhase.Complete>(
      name: name,
      description: description,
      tags: tags,
      givenSteps: givenSteps,
      whenSteps: whenSteps,
      thenSteps: [step]
    )
  }
}

// MARK: - Complete Phase

extension NetworkScenario where Phase == ScenarioPhase.Complete {
  /// Runs the scenario with the given context.
  ///
  /// Executes all steps in order: Given -> When -> Then.
  /// If any step fails, execution stops and the error is thrown.
  ///
  /// - Parameter context: The scenario context
  /// - Throws: Errors from step execution
  /// - Returns: The scenario result
  @discardableResult
  public func run(with context: ScenarioContext) async throws -> ScenarioResult {
    let startTime = Date()
    var stepResults: [StepResultEntry] = []

    try await executeGivenSteps(context: context, stepResults: &stepResults)
    await executeWhenSteps(context: context, stepResults: &stepResults)
    try await executeThenSteps(context: context, stepResults: &stepResults)

    let totalDuration = MeasurementDuration(Date().timeIntervalSince(startTime))

    let scenarioDef = ScenarioDefinition(
      name: name,
      description: description,
      tags: tags
    )

    return ScenarioResult(
      scenario: .scenario(scenarioDef),
      stepResults: stepResults,
      duration: totalDuration
    )
  }

  private func executeGivenSteps(
    context: ScenarioContext,
    stepResults: inout [StepResultEntry]
  ) async throws {
    for step in givenSteps {
      let result = await executeGivenStep(step, context: context)
      stepResults.append(result.entry)
      if let error = result.error {
        throw error
      }
    }
  }

  private func executeWhenSteps(
    context: ScenarioContext,
    stepResults: inout [StepResultEntry]
  ) async {
    for step in whenSteps {
      let result = await executeWhenStep(step, context: context)
      stepResults.append(result.entry)
      if let error = result.error {
        context.lastError = error
      }
    }
  }

  private func executeThenSteps(
    context: ScenarioContext,
    stepResults: inout [StepResultEntry]
  ) async throws {
    for step in thenSteps {
      let result = await executeThenStep(step, context: context)
      stepResults.append(result.entry)
      if let error = result.error {
        throw error
      }
    }
  }

  private func executeGivenStep(
    _ step: any GivenStep,
    context: ScenarioContext
  ) async -> (entry: StepResultEntry, error: Error?) {
    await executeStep(
      keyword: .given,
      description: (step as? DescribableStep)?.stepDescription ?? "Given step",
      context: context
    ) {
      try await step.execute(context: $0)
    }
  }

  private func executeWhenStep(
    _ step: any WhenStep,
    context: ScenarioContext
  ) async -> (entry: StepResultEntry, error: Error?) {
    await executeStep(
      keyword: .when,
      description: (step as? DescribableStep)?.stepDescription ?? "When step",
      context: context
    ) {
      try await step.execute(context: $0)
    }
  }

  private func executeThenStep(
    _ step: any ThenStep,
    context: ScenarioContext
  ) async -> (entry: StepResultEntry, error: Error?) {
    await executeStep(
      keyword: .then,
      description: (step as? DescribableStep)?.stepDescription ?? "Then step",
      context: context
    ) {
      try await step.execute(context: $0)
    }
  }

  private func executeStep(
    keyword: StepKeyword,
    description: BDDStepText,
    context: ScenarioContext,
    execution: (ScenarioContext) async throws -> Void
  ) async -> (entry: StepResultEntry, error: Error?) {
    let stepStart = Date()

    do {
      try await execution(context)
      return (
        buildStepResultEntry(
          keyword: keyword,
          description: description,
          result: .passed(duration: MeasurementDuration(Date().timeIntervalSince(stepStart)))
        ),
        nil
      )
    } catch {
      return (
        buildStepResultEntry(
          keyword: keyword,
          description: description,
          result: .failed(
            error: error,
            duration: MeasurementDuration(Date().timeIntervalSince(stepStart))
          )
        ),
        error
      )
    }
  }

  private func buildStepResultEntry(
    keyword: StepKeyword,
    description: BDDStepText,
    result: StepResult
  ) -> StepResultEntry {
    StepResultEntry(
      step: GherkinStep(
        keyword: keyword,
        text: description
      ),
      result: result
    )
  }
}

// MARK: - Convenience Functions

/// Creates a new scenario in the initial phase.
///
/// - Parameters:
///   - name: Scenario name
///   - description: Optional description
///   - tags: Tags for filtering
/// - Returns: A new scenario ready for step definition
public func scenario(
  _ name: BDDScenarioName,
  description: BDDDescriptionText? = nil,
  tags: [Tag] = []
) -> NetworkScenario<ScenarioPhase.Initial> {
  NetworkScenario(name, description: description, tags: tags)
}

/// Creates a new scenario with tags.
///
/// - Parameters:
///   - name: Scenario name
///   - tags: Tags for filtering
/// - Returns: A new scenario ready for step definition
public func scenario(
  _ name: BDDScenarioName,
  tags: Tag...
) -> NetworkScenario<ScenarioPhase.Initial> {
  NetworkScenario(name, tags: Array(tags))
}

// MARK: - Scenario Collection

/// A collection of scenarios for batch execution.
public struct ScenarioCollection: Sendable {
  /// The scenarios in this collection.
  public let scenarios: [NetworkScenario<ScenarioPhase.Complete>]

  /// Collection name.
  public let name: BDDScenarioCollectionName

  /// Creates a new scenario collection.
  public init(name: BDDScenarioCollectionName, scenarios: [NetworkScenario<ScenarioPhase.Complete>])
  {
    self.name = name
    self.scenarios = scenarios
  }

  /// Runs all scenarios with the given context factory.
  ///
  /// - Parameter contextFactory: Factory to create context for each scenario
  /// - Returns: Results for all scenarios
  public func runAll(
    contextFactory: @Sendable () -> ScenarioContext
  ) async -> [Result<ScenarioResult, Error>] {
    var results: [Result<ScenarioResult, Error>] = []

    for scenario in scenarios {
      let context = contextFactory()
      do {
        let result = try await scenario.run(with: context)
        results.append(.success(result))
      } catch {
        results.append(.failure(error))
      }
    }

    return results
  }
}
