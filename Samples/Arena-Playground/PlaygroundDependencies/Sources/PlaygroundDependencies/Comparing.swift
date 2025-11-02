//
//  Comparing.swift
//  PlaygroundDependencies
//
//  Created by Bruno da Gama Porciuncula on 21/09/25.
//



public struct Comparing<N> {
    public let compare: (N, N) -> ComparisonResult
    public init(compare: @escaping (N, N) -> ComparisonResult) { self.compare = compare }
}
