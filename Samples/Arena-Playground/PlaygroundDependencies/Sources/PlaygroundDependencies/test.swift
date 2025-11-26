//
//  test.swift
//  PlaygroundDependencies
//
//  Created by Bruno da Gama Porciuncula on 21/09/25.
//


func main() {
    
    print(faker.address.postcode())
    
}

import Foundation

@preconcurrency import Fakery




let faker = Faker()

// MARK: - Witness types (suffix “Ing”)
