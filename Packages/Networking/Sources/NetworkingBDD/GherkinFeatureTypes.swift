import NetworkingRuntime
import NetworkingTesting
import Foundation

/// Represents a complete Gherkin feature file.
public struct GherkinFeature: Sendable, Identifiable, Equatable {
  public let id: BDDIdentifier
  public let name: BDDFeatureName
  public let description: BDDDescriptionText?
  public let tags: [Tag]
  public let background: GherkinBackground?
  public let scenarios: [GherkinScenario]
  public let location: GherkinSourceLocation

  public init(
    id: BDDIdentifier = BDDIdentifier(),
    name: BDDFeatureName,
    description: BDDDescriptionText? = nil,
    tags: [Tag] = [],
    background: GherkinBackground? = nil,
    scenarios: [GherkinScenario] = [],
    location: GherkinSourceLocation = .unknown
  ) {
    self.id = id
    self.name = name
    self.description = description
    self.tags = tags
    self.background = background
    self.scenarios = scenarios
    self.location = location
  }
}

/// Background steps that run before each scenario in a feature.
public struct GherkinBackground: Sendable, Equatable {
  public let name: BDDDescriptionText?
  public let steps: [GherkinStep]
  public let location: GherkinSourceLocation

  public init(
    name: BDDDescriptionText? = nil,
    steps: [GherkinStep] = [],
    location: GherkinSourceLocation = .unknown
  ) {
    self.name = name
    self.steps = steps
    self.location = location
  }
}

/// A Gherkin scenario, either regular or parameterized.
public enum GherkinScenario: Sendable, Identifiable, Equatable {
  case scenario(ScenarioDefinition)
  case outline(ScenarioOutlineDefinition)

  public var id: BDDIdentifier {
    switch self {
    case .scenario(let definition): return definition.id
    case .outline(let definition): return definition.id
    }
  }

  public var name: BDDScenarioName {
    switch self {
    case .scenario(let definition): return definition.name
    case .outline(let definition): return definition.name
    }
  }

  public var tags: [Tag] {
    switch self {
    case .scenario(let definition): return definition.tags
    case .outline(let definition): return definition.tags
    }
  }

  public var steps: [GherkinStep] {
    switch self {
    case .scenario(let definition): return definition.steps
    case .outline(let definition): return definition.steps
    }
  }

  public var location: GherkinSourceLocation {
    switch self {
    case .scenario(let definition): return definition.location
    case .outline(let definition): return definition.location
    }
  }
}
