import Foundation

// swiftlint:disable static_operator
package func == <Tag>(lhs: BoundaryInt<Tag>, rhs: Int) -> Bool {
  lhs.rawValue == rhs
}

package func == <Tag>(lhs: Int, rhs: BoundaryInt<Tag>) -> Bool {
  lhs == rhs.rawValue
}

package func < <Tag>(lhs: BoundaryInt<Tag>, rhs: Int) -> Bool {
  lhs.rawValue < rhs
}

package func < <Tag>(lhs: Int, rhs: BoundaryInt<Tag>) -> Bool {
  lhs < rhs.rawValue
}

package func > <Tag>(lhs: BoundaryInt<Tag>, rhs: Int) -> Bool {
  lhs.rawValue > rhs
}

package func > <Tag>(lhs: Int, rhs: BoundaryInt<Tag>) -> Bool {
  lhs > rhs.rawValue
}

package func <= <Tag>(lhs: BoundaryInt<Tag>, rhs: Int) -> Bool {
  lhs.rawValue <= rhs
}

package func >= <Tag>(lhs: BoundaryInt<Tag>, rhs: Int) -> Bool {
  lhs.rawValue >= rhs
}

package func ~= <Tag>(pattern: Int, value: BoundaryInt<Tag>) -> Bool {
  pattern == value.rawValue
}

package func ~= <Tag>(pattern: Range<Int>, value: BoundaryInt<Tag>) -> Bool {
  pattern.contains(value.rawValue)
}

package func ~= <Tag>(pattern: ClosedRange<Int>, value: BoundaryInt<Tag>) -> Bool {
  pattern.contains(value.rawValue)
}

package func == <Tag>(lhs: BoundaryInt64<Tag>, rhs: Int64) -> Bool {
  lhs.rawValue == rhs
}

package func == <Tag>(lhs: Int64, rhs: BoundaryInt64<Tag>) -> Bool {
  lhs == rhs.rawValue
}

package func < <Tag>(lhs: BoundaryInt64<Tag>, rhs: Int64) -> Bool {
  lhs.rawValue < rhs
}

package func < <Tag>(lhs: Int64, rhs: BoundaryInt64<Tag>) -> Bool {
  lhs < rhs.rawValue
}

package func > <Tag>(lhs: BoundaryInt64<Tag>, rhs: Int64) -> Bool {
  lhs.rawValue > rhs
}

package func > <Tag>(lhs: Int64, rhs: BoundaryInt64<Tag>) -> Bool {
  lhs > rhs.rawValue
}

package func <= <Tag>(lhs: BoundaryInt64<Tag>, rhs: Int64) -> Bool {
  lhs.rawValue <= rhs
}

package func >= <Tag>(lhs: BoundaryInt64<Tag>, rhs: Int64) -> Bool {
  lhs.rawValue >= rhs
}

package func ~= <Tag>(pattern: Int64, value: BoundaryInt64<Tag>) -> Bool {
  pattern == value.rawValue
}

package func ~= <Tag>(pattern: Range<Int64>, value: BoundaryInt64<Tag>) -> Bool {
  pattern.contains(value.rawValue)
}

package func ~= <Tag>(pattern: ClosedRange<Int64>, value: BoundaryInt64<Tag>) -> Bool {
  pattern.contains(value.rawValue)
}

package func == <Tag>(lhs: BoundaryDuration<Tag>, rhs: TimeInterval) -> Bool {
  lhs.rawValue == rhs
}

package func < <Tag>(lhs: BoundaryDuration<Tag>, rhs: TimeInterval) -> Bool {
  lhs.rawValue < rhs
}

package func > <Tag>(lhs: BoundaryDuration<Tag>, rhs: TimeInterval) -> Bool {
  lhs.rawValue > rhs
}

package func < <Tag>(lhs: TimeInterval, rhs: BoundaryDuration<Tag>) -> Bool {
  lhs < rhs.rawValue
}

package func > <Tag>(lhs: TimeInterval, rhs: BoundaryDuration<Tag>) -> Bool {
  lhs > rhs.rawValue
}

package func == <Tag>(lhs: BoundaryBool<Tag>, rhs: Bool) -> Bool {
  lhs.rawValue == rhs
}

package func == <Tag>(lhs: Bool, rhs: BoundaryBool<Tag>) -> Bool {
  lhs == rhs.rawValue
}

package prefix func ! <Tag>(value: BoundaryBool<Tag>) -> Bool {
  !value.rawValue
}

// swiftlint:enable static_operator
