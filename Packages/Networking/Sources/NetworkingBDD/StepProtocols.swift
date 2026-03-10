import NetworkingRuntime
import NetworkingTesting
import Foundation

// MARK: - Base Step Protocol

/// Base protocol for all BDD step types.
///
/// Steps are the building blocks of BDD scenarios. Each step
/// represents a single action or assertion in the Given-When-Then flow.
///
/// ## Implementation
///
/// Implement specific step protocols (`GivenStep`, `WhenStep`, `ThenStep`)
/// rather than this base protocol directly:
///
/// ```swift
/// struct MockResponse: GivenStep {
///   let path: String
///   let statusCode: Int
///
///   func setup(context: ScenarioContext) async throws {
///     context.mockClient.expect(.path(path))
///       .andReturn(.success(statusCode: statusCode, data: Data()))
///   }
/// }
/// ```
public protocol ScenarioStep: Sendable {
  /// Executes this step with the given context.
  ///
  /// - Parameter context: The scenario context for state management
  /// - Throws: `BDDError` or other errors on failure
  func execute(context: ScenarioContext) async throws
}

// MARK: - Given Step Protocol

/// Protocol for Given steps that set up preconditions.
///
/// Given steps prepare the test environment before the action is performed.
/// They configure mocks, set initial state, and establish preconditions.
///
/// ## Usage
///
/// ```swift
/// struct GivenMockResponse: GivenStep {
///   let path: String
///   let json: Data
///
///   func setup(context: ScenarioContext) async throws {
///     context.mockClient.expect(.path(path))
///       .andReturn(.success(statusCode: 200, data: json))
///       .atLeastOnce()
///   }
/// }
/// ```
///
/// ## Design Guidelines
///
/// - Given steps should not perform network requests
/// - Given steps should not make assertions
/// - Given steps should be idempotent when possible
public protocol GivenStep: ScenarioStep {
  /// Sets up the preconditions for this step.
  ///
  /// - Parameter context: The scenario context
  /// - Throws: Errors if setup fails
  func setup(context: ScenarioContext) async throws
}

extension GivenStep {
  /// Default implementation calls `setup(context:)`.
  public func execute(context: ScenarioContext) async throws {
    try await setup(context: context)
  }
}

// MARK: - When Step Protocol

/// Protocol for When steps that perform actions.
///
/// When steps execute the behavior being tested, typically making
/// HTTP requests and recording responses.
///
/// ## Usage
///
/// ```swift
/// struct WhenGET: WhenStep {
///   let path: String
///
///   func perform(context: ScenarioContext) async throws {
///     let baseURL = try context.require(.baseURL)
///     let url = baseURL.appendingPathComponent(path)
///     let request = HTTPRequest(method: .get, url: url)
///
///     context.recordRequest(request)
///
///     do {
///       let response = try await context.mockClient.execute(request)
///       context.recordResponse(response)
///     } catch {
///       context.recordError(error)
///       throw error
///     }
///   }
/// }
/// ```
///
/// ## Design Guidelines
///
/// - When steps should execute exactly one logical action
/// - When steps should record the response/error in context
/// - When steps may throw errors that will be caught by Then steps
public protocol WhenStep: ScenarioStep {
  /// Performs the action for this step.
  ///
  /// - Parameter context: The scenario context
  /// - Throws: Errors if the action fails
  func perform(context: ScenarioContext) async throws
}

extension WhenStep {
  /// Default implementation calls `perform(context:)`.
  public func execute(context: ScenarioContext) async throws {
    try await perform(context: context)
  }
}

// MARK: - Then Step Protocol

/// Protocol for Then steps that verify outcomes.
///
/// Then steps make assertions about the state after the action,
/// verifying that the expected outcomes occurred.
///
/// ## Usage
///
/// ```swift
/// struct ThenStatusIs: ThenStep {
///   let expectedStatus: HTTPStatus
///
///   func verify(context: ScenarioContext) throws {
///     let response = try context.requireResponse()
///     guard response.status == expectedStatus else {
///       throw BDDError.statusMismatch(
///         expected: expectedStatus.rawValue,
///         actual: response.status.rawValue
///       )
///     }
///   }
/// }
/// ```
///
/// ## Design Guidelines
///
/// - Then steps should only make assertions
/// - Then steps should not modify context state
/// - Then steps should throw descriptive errors on failure
public protocol ThenStep: ScenarioStep {
  /// Verifies the expected outcome.
  ///
  /// - Parameter context: The scenario context
  /// - Throws: Errors if verification fails
  func verify(context: ScenarioContext) throws
}

extension ThenStep {
  /// Default implementation calls `verify(context:)`.
  public func execute(context: ScenarioContext) async throws {
    try verify(context: context)
  }
}

// MARK: - And/But Steps

/// Protocol for And steps that continue the previous step type.
///
/// And steps inherit the semantic type of the preceding step
/// (Given, When, or Then).
public protocol AndStep: ScenarioStep {
  /// The underlying step to execute.
  var underlyingStep: any ScenarioStep { get }
}

extension AndStep {
  public func execute(context: ScenarioContext) async throws {
    try await underlyingStep.execute(context: context)
  }
}

/// Protocol for But steps that provide negative conditions.
///
/// But steps are semantically similar to And steps but indicate
/// a negative or contrasting condition.
public protocol ButStep: ScenarioStep {
  /// The underlying step to execute.
  var underlyingStep: any ScenarioStep { get }
}

extension ButStep {
  public func execute(context: ScenarioContext) async throws {
    try await underlyingStep.execute(context: context)
  }
}

// MARK: - Step Collections

/// A collection of Given steps.
public struct GivenSteps: Sendable {
  /// The steps in this collection.
  public let steps: [any GivenStep]

  /// Creates a new collection.
  public init(_ steps: [any GivenStep]) {
    self.steps = steps
  }

  /// Executes all steps in order.
  public func execute(context: ScenarioContext) async throws {
    for step in steps {
      try await step.execute(context: context)
    }
  }
}

/// A collection of When steps.
public struct WhenSteps: Sendable {
  /// The steps in this collection.
  public let steps: [any WhenStep]

  /// Creates a new collection.
  public init(_ steps: [any WhenStep]) {
    self.steps = steps
  }

  /// Executes all steps in order.
  public func execute(context: ScenarioContext) async throws {
    for step in steps {
      try await step.execute(context: context)
    }
  }
}

/// A collection of Then steps.
public struct ThenSteps: Sendable {
  /// The steps in this collection.
  public let steps: [any ThenStep]

  /// Creates a new collection.
  public init(_ steps: [any ThenStep]) {
    self.steps = steps
  }

  /// Executes all steps in order.
  public func execute(context: ScenarioContext) async throws {
    for step in steps {
      try await step.execute(context: context)
    }
  }
}

// MARK: - Step Description

/// Protocol for steps that provide a description.
public protocol DescribableStep: ScenarioStep {
  /// Human-readable description of this step.
  var stepDescription: String { get }
}

// MARK: - Type-Erased Step Wrappers

/// Type-erased wrapper for any Given step.
public struct AnyGivenStep: GivenStep {
  private let _setup: @Sendable (ScenarioContext) async throws -> Void

  /// The description of the wrapped step.
  public let stepDescription: String?

  /// Creates a type-erased wrapper.
  public init<S: GivenStep>(_ step: S) {
    self._setup = step.setup
    self.stepDescription = (step as? DescribableStep)?.stepDescription
  }

  /// Creates a wrapper from a closure.
  public init(
    description: String? = nil,
    setup: @escaping @Sendable (ScenarioContext) async throws -> Void
  ) {
    self._setup = setup
    self.stepDescription = description
  }

  public func setup(context: ScenarioContext) async throws {
    try await _setup(context)
  }
}

/// Type-erased wrapper for any When step.
public struct AnyWhenStep: WhenStep {
  private let _perform: @Sendable (ScenarioContext) async throws -> Void

  /// The description of the wrapped step.
  public let stepDescription: String?

  /// Creates a type-erased wrapper.
  public init<S: WhenStep>(_ step: S) {
    self._perform = step.perform
    self.stepDescription = (step as? DescribableStep)?.stepDescription
  }

  /// Creates a wrapper from a closure.
  public init(
    description: String? = nil,
    perform: @escaping @Sendable (ScenarioContext) async throws -> Void
  ) {
    self._perform = perform
    self.stepDescription = description
  }

  public func perform(context: ScenarioContext) async throws {
    try await _perform(context)
  }
}

/// Type-erased wrapper for any Then step.
public struct AnyThenStep: ThenStep {
  private let _verify: @Sendable (ScenarioContext) throws -> Void

  /// The description of the wrapped step.
  public let stepDescription: String?

  /// Creates a type-erased wrapper.
  public init<S: ThenStep>(_ step: S) {
    self._verify = step.verify
    self.stepDescription = (step as? DescribableStep)?.stepDescription
  }

  /// Creates a wrapper from a closure.
  public init(
    description: String? = nil,
    verify: @escaping @Sendable (ScenarioContext) throws -> Void
  ) {
    self._verify = verify
    self.stepDescription = description
  }

  public func verify(context: ScenarioContext) throws {
    try _verify(context)
  }
}

// MARK: - Composite Steps

/// A composite Given step that runs multiple steps.
public struct CompositeGivenStep: GivenStep {
  private let steps: [any GivenStep]

  /// Creates a composite step.
  public init(_ steps: [any GivenStep]) {
    self.steps = steps
  }

  public func setup(context: ScenarioContext) async throws {
    for step in steps {
      try await step.setup(context: context)
    }
  }
}

/// A composite When step that runs multiple steps.
public struct CompositeWhenStep: WhenStep {
  private let steps: [any WhenStep]

  /// Creates a composite step.
  public init(_ steps: [any WhenStep]) {
    self.steps = steps
  }

  public func perform(context: ScenarioContext) async throws {
    for step in steps {
      try await step.perform(context: context)
    }
  }
}

/// A composite Then step that runs multiple steps.
public struct CompositeThenStep: ThenStep {
  private let steps: [any ThenStep]

  /// Creates a composite step.
  public init(_ steps: [any ThenStep]) {
    self.steps = steps
  }

  public func verify(context: ScenarioContext) throws {
    for step in steps {
      try step.verify(context: context)
    }
  }
}
