//
//  StringLiteralExpressing.swift
//  PlaygroundDependencies
//
//  Created by Bruno da Gama Porciuncula on 21/09/25.
//



public struct StringLiteralExpressing<Value> {
    public let makeFromStringLiteral: (Value.StringLiteralType) -> Value
    public init(makeFromStringLiteral: @escaping (Value.StringLiteralType) -> Value) {
        self.makeFromStringLiteral = makeFromStringLiteral
    }
}
