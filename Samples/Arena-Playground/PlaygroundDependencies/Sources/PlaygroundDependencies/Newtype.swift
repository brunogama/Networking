import Foundation

// MARK: - Core protocol

public protocol Newtype: RawRepresentable {
    init(rawValue: RawValue)
}

// MARK: - Witness-backed surface

public protocol NewtypeBacked {
    associatedtype RawValue
    static var newtyping: Newtyping<Self, RawValue> { get }
    static var equating: Equating<RawValue>? { get }
    static var comparing: Comparing<RawValue>? { get }
    static var hashing: Hashing<RawValue>? { get }
    static var stringLiteralExpressing: StringLiteralExpressing<RawValue>? { get }
}

public extension NewtypeBacked {
    static var equating: Equating<RawValue>? { nil }
    static var comparing: Comparing<RawValue>? { nil }
    static var hashing: Hashing<RawValue>? { nil }
    static var stringLiteralExpressing: StringLiteralExpressing<RawValue>? { nil }
}

// MARK: - Witness types (suffix “Ing”)

public struct Newtyping<N, RawValue> {
    public let rawValue: (N) -> RawValue
    public let make: (RawValue) -> N
    public init(rawValue: @escaping (N) -> RawValue, make: @escaping (RawValue) -> N) {
        self.rawValue = rawValue
        self.make = make
    }
}



// MARK: - Bridge RawRepresentable using witnesses

public extension Newtype where Self: NewtypeBacked {
    @inlinable var rawValue: RawValue { Self.newtyping.rawValue(self) }
    @inlinable init(rawValue: RawValue) { self = Self.newtyping.make(rawValue) }
}

// MARK: - Conditional behaviors using witnesses

// Decodable
public extension NewtypeBacked where Self: Decodable, RawValue: Decodable {
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        self = Self.newtyping.make(try c.decode(RawValue.self))
    }
}

// Encodable
public extension NewtypeBacked where Self: Encodable, RawValue: Encodable {
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(Self.newtyping.rawValue(self))
    }
}

// Equatable
public extension NewtypeBacked where Self: Equatable, RawValue: Equatable {
    static func == (left: Self, right: Self) -> Bool {
        if let w = equating {
            return w.equals(Self.newtyping.rawValue(left), Self.newtyping.rawValue(right))
        }
        return Self.newtyping.rawValue(left) == Self.newtyping.rawValue(right)
    }
}

// Comparable
public extension NewtypeBacked where Self: Comparable, RawValue: Comparable {
    static func < (left: Self, right: Self) -> Bool {
        if let w = comparing {
            return w.compare(Self.newtyping.rawValue(left), Self.newtyping.rawValue(right)) == .orderedAscending
        }
        return Self.newtyping.rawValue(left) < Self.newtyping.rawValue(right)
    }
}

// Hashable
public extension NewtypeBacked where Self: Hashable, RawValue: Hashable {
    func hash(into hasher: inout Hasher) {
        if let w = Self.hashing {
            w.hash(Self.newtyping.rawValue(self), &hasher); return
        }
        Self.newtyping.rawValue(self).hash(into: &hasher)
    }
}

// ExpressibleByStringLiteral
public extension NewtypeBacked where Self: ExpressibleByStringLiteral, RawValue: ExpressibleByStringLiteral {
    init(stringLiteral value: RawValue.StringLiteralType) {
        if let w = Self.stringLiteralExpressing {
            self = Self.newtyping.make(w.makeFromStringLiteral(value)); return
        }
        self = Self.newtyping.make(RawValue(stringLiteral: value))
    }
}
