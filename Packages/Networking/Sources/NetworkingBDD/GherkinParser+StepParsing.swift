import NetworkingRuntime
import NetworkingTesting
import Foundation

extension GherkinParser {
  func parseSteps(tokens: inout [Token]) throws -> [GherkinStep] {
    var steps: [GherkinStep] = []

    while !tokens.isEmpty {
      consumeBlankTokens(tokens: &tokens)
      guard let token = tokens.first else {
        break
      }

      guard let keyword = stepKeyword(for: token.type) else {
        break
      }

      tokens.removeFirst()
      let stepLocation = makeLocation(from: token)
      let attachments = try parseStepAttachments(tokens: &tokens)

      steps.append(
        GherkinStep(
          keyword: keyword,
          text: BDDStepText(token.text),
          dataTable: attachments.dataTable,
          docString: attachments.docString,
          location: stepLocation
        )
      )
    }

    return steps
  }

  func consumeBlankTokens(tokens: inout [Token]) {
    while tokens.first?.type == .blank {
      tokens.removeFirst()
    }
  }

  func parseStepAttachments(tokens: inout [Token]) throws -> StepAttachments {
    consumeBlankTokens(tokens: &tokens)

    if tokens.first?.type == .docStringDelimiter {
      return StepAttachments(docString: try parseDocString(tokens: &tokens), dataTable: nil)
    }

    if tokens.first?.type == .tableRow {
      return StepAttachments(docString: nil, dataTable: try parseDataTable(tokens: &tokens))
    }

    return StepAttachments(docString: nil, dataTable: nil)
  }

  func parseDocString(tokens: inout [Token]) throws -> DocString {
    guard tokens.first?.type == .docStringDelimiter else {
      throw BDDError.syntaxError(
        message: UserMessageText("Expected doc string delimiter"),
        location: tokens.first.map(makeLocation(from:)) ?? .unknown
      )
    }

    let startToken = tokens.removeFirst()
    let location = makeLocation(from: startToken)
    let result = consumeDocStringContent(tokens: &tokens)

    guard result.terminated else {
      throw BDDError.unterminatedDocString(location: location)
    }

    return DocString(
      contentType: docStringContentType(for: startToken.text),
      content: BDDDocContent(result.lines.joined(separator: "\n"))
    )
  }

  func docStringContentType(for delimiterText: String) -> BDDDocContentType? {
    let delimiter = delimiterText.trimmingCharacters(in: .whitespaces)
    guard delimiter.count > 3 else {
      return nil
    }

    return BDDDocContentType(String(delimiter.dropFirst(3)))
  }

  func consumeDocStringContent(tokens: inout [Token]) -> DocStringParseResult {
    var lines: [String] = []

    while !tokens.isEmpty {
      let token = tokens.removeFirst()
      if token.type == .docStringDelimiter {
        return DocStringParseResult(lines: lines, terminated: true)
      }
      lines.append(token.text)
    }

    return DocStringParseResult(lines: lines, terminated: false)
  }

  func parseDataTable(tokens: inout [Token]) throws -> DataTable {
    var rows: [[BDDExamplesCell]] = []

    while tokens.first?.type == .tableRow {
      let token = tokens.removeFirst()
      let cells = parseTableRow(token.text)
      rows.append(cells)
    }

    return DataTable(rows: rows)
  }

  func parseTableRow(_ line: String) -> [BDDExamplesCell] {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    var cells: [BDDExamplesCell] = []

    // Split by | and trim each cell
    let parts = trimmed.split(separator: "|", omittingEmptySubsequences: false)
    for part in parts {
      let cell = part.trimmingCharacters(in: .whitespaces)
      if !cell.isEmpty {
        cells.append(BDDExamplesCell(cell))
      }
    }

    return cells
  }

  func parseExamples(tokens: inout [Token]) throws -> [ExamplesTable] {
    var examples: [ExamplesTable] = []

    while !tokens.isEmpty {
      consumeBlankTokens(tokens: &tokens)
      let exampleTags = collectTags(tokens: &tokens)

      guard tokens.first?.type == .examples else {
        break
      }

      let examplesToken = tokens.removeFirst()
      let location = makeLocation(from: examplesToken)
      consumeBlankTokens(tokens: &tokens)
      let rows = consumeExampleRows(tokens: &tokens)

      guard !rows.isEmpty else {
        throw BDDError.invalidExamples(
          reason: UserMessageText("Examples table is empty"),
          location: location
        )
      }

      let headers = rows[0].map { BDDExamplesHeader($0.rawValue) }
      let dataRows = Array(rows.dropFirst())

      examples.append(
        ExamplesTable(
          name: examplesToken.text.isEmpty ? nil : BDDExamplesName(examplesToken.text),
          tags: exampleTags,
          headers: headers,
          rows: dataRows,
          location: location
        )
      )
    }

    return examples
  }

  func consumeExampleRows(tokens: inout [Token]) -> [[BDDExamplesCell]] {
    var rows: [[BDDExamplesCell]] = []
    while tokens.first?.type == .tableRow {
      let token = tokens.removeFirst()
      rows.append(parseTableRow(token.text))
    }
    return rows
  }
}
