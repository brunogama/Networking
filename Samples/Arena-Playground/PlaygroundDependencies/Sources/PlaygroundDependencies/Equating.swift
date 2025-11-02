//
//  Equating.swift
//  PlaygroundDependencies
//
//  Created by Bruno da Gama Porciuncula on 21/09/25.
//



public struct Equating<N> {
    public let equals: (N, N) -> Bool
    public init(equals: @escaping (N, N) -> Bool) { self.equals = equals }
}
