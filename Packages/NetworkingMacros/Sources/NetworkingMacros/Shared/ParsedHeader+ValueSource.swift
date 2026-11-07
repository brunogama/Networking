extension ParsedHeader {
  enum ValueSource: Equatable, Sendable {
    case literal(String)
    case parameter(String)
  }
}
