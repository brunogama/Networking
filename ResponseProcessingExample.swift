#!/usr/bin/env swift

import Foundation

// This is a standalone example demonstrating the enhanced ResponseProcessing.swift functionality

// Sample usage showcasing the method chaining infrastructure:

/*
// Example 1: Basic method chaining with validation and decoding
let response: HTTPResponse = // ... some HTTP response
let user: User = try response
    .chain()
    .validate(.successStatus)
    .validate(.json)
    .decode(User.self)
    .extractValue()

// Example 2: Complex method chaining with caching and transformation
let processedData = try response
    .chain()
    .validate(.successStatus)
    .validate(.contentType("application/json"))
    .decode(APIResponse.self)
    .map { $0.data }
    .cache(for: .minutes(5))

// Example 3: Error recovery with fallback
let result = try ResponseChain.withRecovery({
    try response
        .chain()
        .validate(.successStatus)
        .decode(User.self)
}, recovery: { error in
    // Fallback to cached data or default value
    let defaultUser = User.default
    return ResponseChain(response: response, value: defaultUser)
})

// Example 4: String transformation
let htmlContent = try response
    .chain()
    .validate(.status(200, 201, 202))
    .asString(encoding: .utf8)
    .map { html in
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
    .extractValue()

// Example 5: Custom validation and transformation
let customValidator = ContentTypeValidator("application/vnd.api+json")
let apiData = try response
    .chain()
    .validate(customValidator)
    .transform(JSONDecoderTransformer(APIData.self))
    .cache(for: .hours(1))
    .extractValue()

// Example 6: Multiple validations
let secureResponse = try response
    .chain()
    .validate(.successStatus)
    .validate(.json)
    .validate(CustomSecurityValidator())
    .decode(SecureData.self)

// The enhanced ResponseProcessing provides:
// 1. Method chaining with fluent syntax
// 2. Type-safe response processing
// 3. Multiple validation strategies
// 4. Response transformation pipelines
// 5. Caching with expiration
// 6. Error recovery mechanisms
// 7. Swift 6 concurrency compliance with Sendable conformance
*/

print("ResponseProcessing enhancement examples loaded successfully!")
print(
  "The enhanced ResponseProcessing.swift provides a fluent, type-safe API for processing HTTP responses with method chaining."
)
