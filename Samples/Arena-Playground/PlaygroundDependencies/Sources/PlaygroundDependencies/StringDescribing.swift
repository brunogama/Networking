//
//  StringDescribing.swift
//  PlaygroundDependencies
//
//  Created by Bruno da Gama Porciuncula on 21/09/25.
//



public struct StringDescribing<N> {
    public let description: (N) -> String
    public init(description: @escaping (N) -> String) { self.description = description }
}
