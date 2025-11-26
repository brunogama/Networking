//
//  Encoding.swift
//  PlaygroundDependencies
//
//  Created by Bruno da Gama Porciuncula on 21/09/25.
//



public struct Encoding<N> {
    public let encode: (N, Encoder) throws -> Void
    public init(encode: @escaping (N, Encoder) throws -> Void) { self.encode = encode }
}
