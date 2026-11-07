struct MacroPluginBoundaryString<Tag>: Sendable, Hashable, Codable,
  CustomStringConvertible
{
  package let rawValue: String

  package init(rawValue: String) {
    self.rawValue = rawValue
  }

  package init(_ rawValue: String) {
    self.init(rawValue: rawValue)
  }

  var description: String {
    rawValue
  }
}
