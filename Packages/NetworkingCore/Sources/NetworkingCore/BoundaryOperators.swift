extension Tagged where RawValue: Equatable {
  package static func == (lhs: Self, rhs: RawValue) -> Bool { lhs.rawValue == rhs }
}

extension Tagged where RawValue: Comparable {
  package static func < (lhs: Self, rhs: RawValue) -> Bool { lhs.rawValue < rhs }
  package static func > (lhs: Self, rhs: RawValue) -> Bool { lhs.rawValue > rhs }
  package static func <= (lhs: Self, rhs: RawValue) -> Bool { lhs.rawValue <= rhs }
  package static func >= (lhs: Self, rhs: RawValue) -> Bool { lhs.rawValue >= rhs }

  package static func ~= (pattern: Range<RawValue>, value: Self) -> Bool {
    pattern.contains(value.rawValue)
  }

}

extension Tagged where RawValue == Bool {
  package static prefix func ! (value: Self) -> Bool { !value.rawValue }
}
