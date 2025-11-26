//
//  File.swift
//  PlaygroundDependencies
//
//  Created by Bruno da Gama Porciuncula on 21/09/25.
//

import Foundation


// MARK: - AnySendable (witness-driven)

public struct AnySendable: @unchecked Sendable {
    // Storage
    public let box: Any
    public  let type: Any.Type
    public  let typeName: String
    
    // Captured witnesses
    private let _equate: ((Any, Any) -> Bool)?
    private let _hash: ((Any, inout Hasher) -> Void)?
    private let _encode: ((Any, Encoder) throws -> Void)?
    private let _compare: ((Any, Any) -> ComparisonResult)?
    private let _describe: ((Any) -> String)?
    private let _debugDescribe: ((Any) -> String)?
    
    // Single generic initializer. Captures conditional witnesses.
    public init<T: Sendable>(_ value: T) {
        self.box = value
        self.type = T.self
        self.typeName = String(reflecting: T.self)
        
        self._equate = Self.makeEquating(T.self)
        self._hash = Self.makeHashing(T.self)
        self._encode = Self.makeEncoding(T.self)
        self._compare = Self.makeComparing(T.self)
        self._describe = Self.makeStringDescribing(T.self)
        self._debugDescribe = Self.makeDebugStringDescribing(T.self)
    }
    
    // Unwrap
    @inlinable public func `as`<U>(_ u: U.Type) -> U? { box as? U }
}

// MARK: - Conditional witness builders

extension AnySendable {
    // defaults
    @inlinable static func makeEquating<T>(_: T.Type) -> ((Any, Any) -> Bool)? { nil }
    @inlinable static func makeHashing<T>(_: T.Type) -> ((Any, inout Hasher) -> Void)? { nil }
    @inlinable static func makeEncoding<T>(_: T.Type) -> ((Any, Encoder) throws -> Void)? { nil }
    @inlinable static func makeComparing<T>(_: T.Type) -> ((Any, Any) -> ComparisonResult)? { nil }
    @inlinable static func makeStringDescribing<T>(_: T.Type) -> ((Any) -> String)? { nil }
    @inlinable static func makeDebugStringDescribing<T>(_: T.Type) -> ((Any) -> String)? { nil }
    
    // constrained overloads
    @inlinable static func makeEquating<T>(_: T.Type) -> ((Any, Any) -> Bool)? where T: Equatable {
        { l, r in (l as? T) == (r as? T) }
    }
    @inlinable static func makeHashing<T>(_: T.Type) -> ((Any, inout Hasher) -> Void)? where T: Hashable {
        { x, into in if let v = x as? T { into.combine(v) } }
    }
    @inlinable static func makeEncoding<T>(_: T.Type) -> ((Any, Encoder) throws -> Void)? where T: Encodable {
        { x, enc in try (x as! T).encode(to: enc) }
    }
    @inlinable static func makeComparing<T>(_: T.Type) -> ((Any, Any) -> ComparisonResult)? where T: Comparable {
        { l, r in
            guard let a = l as? T, let b = r as? T else { return .orderedSame }
            if a < b { return .orderedAscending }
            if a > b { return .orderedDescending }
            return .orderedSame
        }
    }
    @inlinable static func makeStringDescribing<T>(_: T.Type) -> ((Any) -> String)? where T: CustomStringConvertible {
        { x in (x as! T).description }
    }
    @inlinable static func makeDebugStringDescribing<T>(_: T.Type) -> ((Any) -> String)? where T: CustomDebugStringConvertible {
        { x in (x as! T).debugDescription }
    }
}

// MARK: - Conformances via captured witnesses

extension AnySendable: Equatable {
    public static func == (lhs: AnySendable, rhs: AnySendable) -> Bool {
        guard lhs.type == rhs.type, let eq = lhs._equate else { return false }
        return eq(lhs.box, rhs.box)
    }
}

extension AnySendable: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(type))
        _hash?(box, &hasher)
    }
}

public enum AnySendableCodingStrategy { case valueOnly, tagged }

extension AnySendable: Encodable {
    public func encode(to encoder: Encoder) throws {
        try encode(to: encoder, strategy: .valueOnly)
    }
    
    public func encode(to encoder: Encoder, strategy: AnySendableCodingStrategy) throws {
        guard let enc = _encode else {
            throw EncodingError.invalidValue(
                box,
                .init(codingPath: encoder.codingPath, debugDescription: "Underlying value does not conform to Encodable")
            )
        }
        switch strategy {
        case .valueOnly:
            try enc(box, encoder)
        case .tagged:
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(typeName, forKey: .type)
            try enc(box, c.superEncoder(forKey: .value))
        }
    }
    
    private enum CodingKeys: String, CodingKey { case type, value }
}

// Convenience accessors
public extension AnySendable {
    var description: String? { _describe?(box) }
    var debugDescription: String? { _debugDescribe?(box) }
    func compare(_ other: AnySendable) -> ComparisonResult? {
        guard type == other.type, let cmp = _compare else { return nil }
        return cmp(box, other.box)
    }
}
