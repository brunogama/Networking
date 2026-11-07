import NetworkingCore

/// An expected range of observed request counts.
public enum MockCallCountExpectation: Sendable {
  case exactly(RequestCount)
  case atLeast(RequestCount)
  case atMost(RequestCount)
  case between(min: RequestCount, max: RequestCount)

  private var minimum: Int {
    switch self {
    case .exactly(let count), .atLeast(let count), .between(let count, _): return count.rawValue
    case .atMost: return 0
    }
  }

  private var maximum: Int {
    switch self {
    case .exactly(let count), .atMost(let count), .between(_, let count): return count.rawValue
    case .atLeast: return Int.max
    }
  }

  func matches(_ count: Int) -> Bool {
    guard minimum >= 0, minimum <= maximum else { return false }
    return (minimum...maximum).contains(count)
  }

  var description: String {
    switch self {
    case .exactly(let count): return "exactly \(count.rawValue) time(s)"
    case .atLeast(let count): return "at least \(count.rawValue) time(s)"
    case .atMost(let count): return "at most \(count.rawValue) time(s)"
    case .between(let minimum, let maximum):
      return "between \(minimum.rawValue) and \(maximum.rawValue) time(s)"
    }
  }
}
