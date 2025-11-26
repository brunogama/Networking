//
//  Hashing.swift
//  PlaygroundDependencies
//
//  Created by Bruno da Gama Porciuncula on 21/09/25.
//



public struct Hashing<N> {
    public let hash: (N, inout Hasher) -> Void
    public init(hash: @escaping (N, inout Hasher) -> Void) { self.hash = hash }
}