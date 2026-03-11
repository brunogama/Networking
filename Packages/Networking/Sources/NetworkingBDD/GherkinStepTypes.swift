import NetworkingRuntime
import NetworkingTesting
import Foundation

/// A single Gherkin step.
public struct GherkinStep: Sendable, Equatable {
  public let keyword: StepKeyword
  public let text: BDDStepText
  public let dataTable: DataTable?
  public let docString: DocString?
  public let location: GherkinSourceLocation

  public init(
    keyword: StepKeyword,
    text: BDDStepText,
    dataTable: DataTable? = nil,
    docString: DocString? = nil,
    location: GherkinSourceLocation = .unknown
  ) {
    self.keyword = keyword
    self.text = text
    self.dataTable = dataTable
    self.docString = docString
    self.location = location
  }

  public func substituting(
    placeholders: [BDDExamplesHeader],
    with values: [BDDExamplesCell]
  ) -> Self {
    var newText = text.rawValue
    for (placeholder, value) in zip(placeholders, values) {
      newText = newText.replacingOccurrences(
        of: "<\(placeholder.rawValue)>",
        with: value.rawValue
      )
    }

    var newDocString = docString
    if let docString {
      var newContent = docString.content.rawValue
      for (placeholder, value) in zip(placeholders, values) {
        newContent = newContent.replacingOccurrences(
          of: "<\(placeholder.rawValue)>",
          with: value.rawValue
        )
      }
      newDocString = DocString(
        contentType: docString.contentType,
        content: BDDDocContent(newContent)
      )
    }

    return Self(
      keyword: keyword,
      text: BDDStepText(newText),
      dataTable: dataTable,
      docString: newDocString,
      location: location
    )
  }
}

public enum StepKeyword: Sendable, CaseIterable, Equatable {
  case given
  case when
  case then
  case and
  case but
  case asterisk

  public var identifier: BDDStepKeywordName {
    switch self {
    case .given: return "Given"
    case .when: return "When"
    case .then: return "Then"
    case .and: return "And"
    case .but: return "But"
    case .asterisk: return "*"
    }
  }

  public var semanticType: SemanticStepType? {
    switch self {
    case .given: return .given
    case .when: return .when
    case .then: return .then
    case .and, .but, .asterisk: return nil
    }
  }
}

public enum SemanticStepType: Sendable, Equatable {
  case given
  case when
  case then

  public var identifier: BDDSemanticStepTypeName {
    switch self {
    case .given: return "given"
    case .when: return "when"
    case .then: return "then"
    }
  }
}

public struct DataTable: Sendable, Equatable {
  public let rows: [[BDDExamplesCell]]

  public init(rows: [[BDDExamplesCell]]) {
    self.rows = rows
  }

  public var headers: [BDDExamplesCell] {
    rows.first ?? []
  }

  public var dataRows: [[BDDExamplesCell]] {
    Array(rows.dropFirst())
  }

  public func asMaps() -> [[BDDExamplesCell: BDDExamplesCell]] {
    let headers = self.headers
    return dataRows.map { row in
      Dictionary(uniqueKeysWithValues: zip(headers, row))
    }
  }

  public var columnCount: BDDTableColumnCount {
    BDDTableColumnCount(rows.first?.count ?? 0)
  }

  public var rowCount: BDDTableRowCount {
    BDDTableRowCount(max(0, rows.count - 1))
  }
}

public struct DocString: Sendable, Equatable {
  public let contentType: BDDDocContentType?
  public let content: BDDDocContent

  public init(contentType: BDDDocContentType? = nil, content: BDDDocContent) {
    self.contentType = contentType
    self.content = content
  }
}

public struct GherkinSourceLocation: Sendable, Equatable {
  public let line: BDDSourceLine
  public let column: BDDSourceColumn
  public let file: BDDSourceFilePath?

  public init(
    line: BDDSourceLine,
    column: BDDSourceColumn,
    file: BDDSourceFilePath? = nil
  ) {
    self.line = line
    self.column = column
    self.file = file
  }

  public static let unknown = Self(line: 0, column: 0, file: nil)

  public var description: String {
    if let file {
      return "\(file.rawValue):\(line.rawValue):\(column.rawValue)"
    }
    return "line \(line.rawValue), column \(column.rawValue)"
  }
}

public struct Tag: Sendable, Hashable {
  public let name: BDDTagText

  public init(_ name: BDDTagText) {
    self.name = name.rawValue.hasPrefix("@") ? name : BDDTagText("@\(name.rawValue)")
  }

  public var rawName: BDDTagText {
    BDDTagText(String(name.rawValue.dropFirst()))
  }
}

extension Tag {
  public static let smoke = Tag(BDDTagText("@smoke"))
  public static let regression = Tag(BDDTagText("@regression"))
  public static let wip = Tag(BDDTagText("@wip"))
  public static let skip = Tag(BDDTagText("@skip"))
  public static let slow = Tag(BDDTagText("@slow"))
  public static let integration = Tag(BDDTagText("@integration"))
  public static let unit = Tag(BDDTagText("@unit"))
  public static let api = Tag(BDDTagText("@api"))
  public static let critical = Tag(BDDTagText("@critical"))
}
