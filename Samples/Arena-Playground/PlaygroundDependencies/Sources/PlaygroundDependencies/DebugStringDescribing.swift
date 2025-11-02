//
//  DebugStringDescribing.swift
//  PlaygroundDependencies
//
//  Created by Bruno da Gama Porciuncula on 21/09/25.
//

public struct DebugStringDescribing<N> {
    public let debugDescription: (N) -> String
    public init(debugDescription: @escaping (N) -> String) { self.debugDescription = debugDescription }
}
