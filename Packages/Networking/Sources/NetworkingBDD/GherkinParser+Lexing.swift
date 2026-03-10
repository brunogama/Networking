import NetworkingRuntime
import NetworkingTesting
import Foundation

extension GherkinParser {
  func tokenize(lines: [String]) -> [Token] {
    var tokens: [Token] = []

    for (lineIndex, line) in lines.enumerated() {
      let lineNumber = lineIndex + 1
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      tokens.append(contentsOf: self.tokens(for: trimmed, lineNumber: lineNumber))
    }

    return tokens
  }

  func tokens(for line: String, lineNumber: Int) -> [Token] {
    blankTokens(for: line, lineNumber: lineNumber)
      ?? commentTokens(for: line, lineNumber: lineNumber)
      ?? tagTokens(for: line, lineNumber: lineNumber)
      ?? docStringDelimiterTokens(for: line, lineNumber: lineNumber)
      ?? tableRowTokens(for: line, lineNumber: lineNumber)
      ?? [tokenizeLine(line, lineNumber: lineNumber)]
  }

  func blankTokens(for line: String, lineNumber: Int) -> [Token]? {
    guard line.isEmpty else {
      return nil
    }

    return [Token(type: .blank, text: "", line: lineNumber, column: 1)]
  }

  func commentTokens(for line: String, lineNumber: Int) -> [Token]? {
    guard line.hasPrefix("#") else {
      return nil
    }

    return [Token(type: .comment, text: line, line: lineNumber, column: 1)]
  }

  func tagTokens(for line: String, lineNumber: Int) -> [Token]? {
    guard line.hasPrefix("@") else {
      return nil
    }

    return
      line
      .components(separatedBy: .whitespaces)
      .filter { $0.hasPrefix("@") }
      .map { Token(type: .tag, text: $0, line: lineNumber, column: 1) }
  }

  func docStringDelimiterTokens(for line: String, lineNumber: Int) -> [Token]? {
    guard line.hasPrefix("\"\"\"") || line.hasPrefix("```") else {
      return nil
    }

    return [Token(type: .docStringDelimiter, text: line, line: lineNumber, column: 1)]
  }

  func tableRowTokens(for line: String, lineNumber: Int) -> [Token]? {
    guard line.hasPrefix("|") else {
      return nil
    }

    return [Token(type: .tableRow, text: line, line: lineNumber, column: 1)]
  }

  func tokenizeLine(_ line: String, lineNumber: Int) -> Token {
    for (keyword, type) in Self.lineKeywords where line.hasPrefix(keyword) {
      let text = String(line.dropFirst(keyword.count))
      return Token(
        type: type,
        text: text.trimmingCharacters(in: .whitespaces),
        line: lineNumber,
        column: 1
      )
    }

    return Token(type: .text, text: line, line: lineNumber, column: 1)
  }
}
