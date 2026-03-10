import NetworkingRuntime
import NetworkingTesting
import Foundation

/// A regular scenario with fixed steps.
public struct ScenarioDefinition: Sendable, Identifiable, Equatable {
  public let id: BDDIdentifier
  public let name: BDDScenarioName
  public let description: BDDDescriptionText?
  public let tags: [Tag]
  public let steps: [GherkinStep]
  public let location: GherkinSourceLocation

  public init(
    id: BDDIdentifier = BDDIdentifier(),
    name: BDDScenarioName,
    description: BDDDescriptionText? = nil,
    tags: [Tag] = [],
    steps: [GherkinStep] = [],
    location: GherkinSourceLocation = .unknown
  ) {
    self.id = id
    self.name = name
    self.description = description
    self.tags = tags
    self.steps = steps
    self.location = location
  }
}

/// A parameterized scenario with examples.
public struct ScenarioOutlineDefinition: Sendable, Identifiable, Equatable {
  public let id: BDDIdentifier
  public let name: BDDScenarioName
  public let description: BDDDescriptionText?
  public let tags: [Tag]
  public let steps: [GherkinStep]
  public let examples: [ExamplesTable]
  public let location: GherkinSourceLocation

  public init(
    id: BDDIdentifier = BDDIdentifier(),
    name: BDDScenarioName,
    description: BDDDescriptionText? = nil,
    tags: [Tag] = [],
    steps: [GherkinStep] = [],
    examples: [ExamplesTable] = [],
    location: GherkinSourceLocation = .unknown
  ) {
    self.id = id
    self.name = name
    self.description = description
    self.tags = tags
    self.steps = steps
    self.examples = examples
    self.location = location
  }

  public func expand() -> [ScenarioDefinition] {
    var expanded: [ScenarioDefinition] = []

    for table in examples {
      for row in table.dataRows {
        let substitutedSteps = steps.map { step in
          step.substituting(placeholders: table.headers, with: row)
        }

        let exampleName = zip(table.headers, row)
          .map { "\($0): \($1)" }
          .joined(separator: ", ")

        expanded.append(
          ScenarioDefinition(
            name: BDDScenarioName("\(name.rawValue) [\(exampleName)]"),
            description: description,
            tags: tags + table.tags,
            steps: substitutedSteps,
            location: location
          )
        )
      }
    }

    return expanded
  }
}

/// An examples table for scenario outlines.
public struct ExamplesTable: Sendable, Equatable {
  public let name: BDDExamplesName?
  public let tags: [Tag]
  public let headers: [BDDExamplesHeader]
  public let rows: [[BDDExamplesCell]]
  public let location: GherkinSourceLocation

  public init(
    name: BDDExamplesName? = nil,
    tags: [Tag] = [],
    headers: [BDDExamplesHeader] = [],
    rows: [[BDDExamplesCell]] = [],
    location: GherkinSourceLocation = .unknown
  ) {
    self.name = name
    self.tags = tags
    self.headers = headers
    self.rows = rows
    self.location = location
  }

  public var dataRows: [[BDDExamplesCell]] {
    rows
  }

  public func asMaps() -> [[BDDExamplesHeader: BDDExamplesCell]] {
    rows.map { row in
      Dictionary(uniqueKeysWithValues: zip(headers, row))
    }
  }
}
