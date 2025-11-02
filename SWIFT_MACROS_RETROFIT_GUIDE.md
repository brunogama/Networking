# Swift Macros for Retrofit-Style API Client Generator

## Comprehensive Research Guide

This document provides detailed information about Swift macros for implementing a Retrofit-style API client generator, covering macro types, SwiftSyntax API usage, best practices, validation, integration patterns, and common pitfalls.

---

## Table of Contents

1. [Swift Macro Types Overview](#1-swift-macro-types-overview)
2. [SwiftSyntax API for AST Manipulation](#2-swiftsyntax-api-for-ast-manipulation)
3. [Best Practices for Macro Expansion](#3-best-practices-for-macro-expansion)
4. [Compile-Time Validation](#4-compile-time-validation)
5. [Swift Package Manager Integration](#5-swift-package-manager-integration)
6. [Common Pitfalls and Solutions](#6-common-pitfalls-and-solutions)
7. [Concrete Implementation Examples](#7-concrete-implementation-examples)
8. [Testing Macros](#8-testing-macros)
9. [Additional Resources](#9-additional-resources)

---

## 1. Swift Macro Types Overview

### Macro Classification

Swift macros are classified into two main categories based on their syntax and usage:

#### 1.1 Freestanding Macros

Freestanding macros use the `#` prefix syntax and act as standalone expressions or declarations.

**Syntax:**
```swift
#macroName(arguments)
```

**Types:**
- **Expression Macros** (`@freestanding(expression)`): Generate expressions
  ```swift
  let (value, code) = #stringify(x + y)
  ```

- **Declaration Macros** (`@freestanding(declaration)`): Generate declarations
  ```swift
  #warning("This feature is deprecated")
  ```

- **Code Item Macros**: Generate statements, expressions, or declarations within function/closure bodies

#### 1.2 Attached Macros

Attached macros use attribute syntax (`@macroName`) and are attached to declarations.

**Types and Use Cases for Retrofit-Style APIs:**

| Macro Type | Attribute | Use Case | Retrofit Equivalent |
|-----------|-----------|----------|---------------------|
| **Peer** | `@attached(peer)` | Create companion declarations alongside the original | Generate implementation methods next to protocol declaration |
| **Accessor** | `@attached(accessor)` | Add accessors to properties | Not directly applicable |
| **Member** | `@attached(member)` | Add members to types/extensions | Generate methods inside a type conforming to API protocol |
| **Member Attribute** | `@attached(memberAttribute)` | Apply attributes to type members | Apply annotations to generated methods |
| **Extension** | `@attached(extension)` | Create conformances and extensions | Add protocol conformances to generated types |

### 1.3 Recommended Approach for Retrofit-Style API

For a Retrofit-style API client generator, you'll primarily use:

1. **Attached Member Macro** (`@attached(member)`) on protocols
   - Applied to protocol: `@API`
   - Generates implementation struct/class with all methods

2. **Attached Peer Macro** (`@attached(peer)`) on protocol methods
   - Applied to methods: `@GET`, `@POST`, etc.
   - Generates metadata for request building

3. **Attached Accessor or Peer Macro** on parameters
   - Applied to parameters: `@Path`, `@Query`, `@Body`, `@Header`
   - Note: Direct parameter annotation is limited; may need to use method-level macros

**Important Constraint:**
Swift macros cannot be directly attached to function parameters. Parameter annotations like `@Path` and `@Query` must be:
- Implemented as property wrappers on protocol properties, OR
- Encoded in method-level macro attributes, OR
- Inferred from parameter names and types

---

## 2. SwiftSyntax API for AST Manipulation

### 2.1 Core SwiftSyntax Concepts

SwiftSyntax provides a **source-accurate syntax tree** representation of Swift code.

**Key Characteristics:**
- Immutable syntax nodes
- Preserves all source information (whitespace, comments)
- Type-safe node hierarchies
- Builder pattern for construction

### 2.2 Essential Syntax Node Types

#### Protocol and Type Nodes

```swift
// Protocol declaration
ProtocolDeclSyntax
├─ attributes: AttributeListSyntax
├─ modifiers: DeclModifierListSyntax
├─ protocolKeyword: TokenSyntax
├─ name: TokenSyntax
├─ inheritanceClause: InheritanceClauseSyntax?
├─ genericWhereClause: GenericWhereClauseSyntax?
└─ memberBlock: MemberBlockSyntax
   └─ members: MemberBlockItemListSyntax

// Function declaration
FunctionDeclSyntax
├─ attributes: AttributeListSyntax
├─ modifiers: DeclModifierListSyntax
├─ funcKeyword: TokenSyntax
├─ name: TokenSyntax
├─ signature: FunctionSignatureSyntax
│  ├─ parameterClause: FunctionParameterClauseSyntax
│  │  └─ parameters: FunctionParameterListSyntax
│  │     └─ FunctionParameterSyntax
│  │        ├─ firstName: TokenSyntax
│  │        ├─ secondName: TokenSyntax?
│  │        ├─ type: TypeSyntax
│  │        └─ defaultValue: InitializerClauseSyntax?
│  └─ returnClause: ReturnClauseSyntax?
└─ body: CodeBlockSyntax?
```

#### Extracting Method Information

```swift
// Example: Extract function parameters
func extractParameters(from function: FunctionDeclSyntax) -> [Parameter] {
    function.signature.parameterClause.parameters.map { param in
        Parameter(
            name: param.secondName?.text ?? param.firstName.text,
            type: param.type.description.trimmingCharacters(in: .whitespaces)
        )
    }
}

// Example: Extract return type
func extractReturnType(from function: FunctionDeclSyntax) -> String? {
    function.signature.returnClause?.type.description
        .trimmingCharacters(in: .whitespaces)
}
```

#### Custom Attribute Extraction

```swift
// Extract macro arguments from @GET("/users/{id}")
func extractMacroArguments(
    from attribute: AttributeSyntax
) -> [LabeledExprSyntax] {
    guard case let .argumentList(arguments) = attribute.arguments else {
        return []
    }
    return Array(arguments)
}

// Example: Parse @GET("/users/{id}")
func parseGETAttribute(_ attribute: AttributeSyntax) -> String? {
    let arguments = extractMacroArguments(from: attribute)
    return arguments.first?.expression.description
        .trimmingCharacters(in: .init(charactersIn: "\""))
}
```

### 2.3 Syntax Tree Exploration Tools

**Swift AST Explorer:**
- URL: https://swift-ast-explorer.com
- Interactive visualization of Swift syntax trees
- Essential for understanding node structure

**Debugging in Xcode:**
```swift
// In macro expansion function
po node  // Print syntax tree structure
```

**Command-line inspection:**
```bash
# Parse Swift file and dump syntax tree
swift-syntax-dev-utils dump-tree MyFile.swift
```

### 2.4 Building Syntax Nodes

Three approaches to create syntax nodes:

#### Approach 1: String Interpolation (Recommended for Most Cases)

```swift
let methodName = "fetchUser"
let returnType = "User"

let method: DeclSyntax = """
    func \(raw: methodName)() async throws -> \(raw: returnType) {
        try await network.request(endpoint: "/users")
    }
    """
```

**String Interpolation Modes:**
- `\(expression)`: Parse and insert as Swift code
- `\(raw: expression)`: Insert as raw identifier/token
- `\(literal: expression)`: Insert as string literal with escaping

#### Approach 2: Result Builder API

```swift
try FunctionDeclSyntax("func fetchUsers() async throws -> [User]") {
    try SwitchExprSyntax("switch method") {
        SwitchCaseSyntax("case .get:") {
            "return try await performGET()"
        }
        SwitchCaseSyntax("case .post:") {
            "return try await performPOST()"
        }
    }
}
```

#### Approach 3: Memberwise Initializers (Verbose, Full Control)

```swift
FunctionDeclSyntax(
    modifiers: DeclModifierListSyntax {
        DeclModifierSyntax(name: .keyword(.public))
    },
    funcKeyword: .keyword(.func),
    name: .identifier("fetchUser"),
    signature: FunctionSignatureSyntax(
        parameterClause: FunctionParameterClauseSyntax(
            parameters: FunctionParameterListSyntax([])
        ),
        returnClause: ReturnClauseSyntax(
            type: IdentifierTypeSyntax(name: .identifier("User"))
        )
    ),
    body: CodeBlockSyntax {
        "// Implementation"
    }
)
```

### 2.5 Key SwiftSyntax Protocols

```swift
// All macro types must conform to:
public protocol Macro {
    // Implemented by specific macro role protocols
}

// Specific macro role protocols:
public protocol ExpressionMacro: FreestandingMacro {
    static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) throws -> ExprSyntax
}

public protocol MemberMacro: AttachedMacro {
    static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax]
}

public protocol PeerMacro: AttachedMacro {
    static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax]
}

public protocol AccessorMacro: AttachedMacro {
    static func expansion(
        of node: AttributeSyntax,
        providingAccessorsOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [AccessorDeclSyntax]
}

public protocol ExtensionMacro: AttachedMacro {
    static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax]
}
```

---

## 3. Best Practices for Macro Expansion

### 3.1 Error Handling Strategy

**Never use `fatalError` in production macros:**
```swift
// ❌ BAD: Crashes compilation
public struct MyMacro: MemberMacro {
    public static func expansion(...) -> [DeclSyntax] {
        guard let name = extractName() else {
            fatalError("Missing name")  // DON'T DO THIS
        }
        // ...
    }
}

// ✅ GOOD: Emit diagnostic
public struct MyMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let name = extractName() else {
            context.diagnose(
                Diagnostic(
                    node: node,
                    message: MyMacroDiagnostic.missingName
                )
            )
            return []  // Return empty array on error
        }
        // ...
    }
}
```

### 3.2 Diagnostic Messages

Define custom diagnostic types:

```swift
import SwiftDiagnostics

enum APIMacroDiagnostic: String, DiagnosticMessage {
    case missingHTTPMethod = "HTTP method annotation (@GET, @POST, etc.) required"
    case invalidPathParameter = "Path parameter '{parameter}' not found in URL"
    case duplicateAnnotation = "Duplicate annotation found"

    var severity: DiagnosticSeverity { .error }

    var message: String { rawValue }

    var diagnosticID: MessageID {
        MessageID(domain: "APIMacros", id: rawValue)
    }
}

// Usage in macro:
context.diagnose(
    Diagnostic(
        node: Syntax(attribute),
        message: APIMacroDiagnostic.missingHTTPMethod
    )
)
```

### 3.3 Unique Name Generation

Use `MacroExpansionContext` for collision-free names:

```swift
// Generate unique backing storage names
let backingPropertyName = context.makeUniqueName("_storage")
let temporaryVarName = context.makeUniqueName("temp")

let property: DeclSyntax = """
    private var \(backingPropertyName): Storage
    """
```

### 3.4 Source Location Preservation

Attach generated code to appropriate source locations:

```swift
// When generating from a function
let generatedFunc = function.with(\.body, newBody)
    .with(\.leadingTrivia, .newline)  // Preserve formatting

// When creating diagnostics
Diagnostic(
    node: Syntax(parameter),  // Point to exact parameter
    message: error,
    highlights: [Syntax(parameter.type)]  // Highlight type specifically
)
```

### 3.5 Incremental Code Generation

Build complex syntax incrementally:

```swift
// Start with basic structure
var members: [DeclSyntax] = []

// Add properties
for parameter in parameters {
    members.append("""
        private let \(raw: parameter.name): \(raw: parameter.type)
        """)
}

// Add initializer
members.append("""
    init(\(raw: parameterList)) {
        \(raw: assignments)
    }
    """)

// Add methods
members.append(contentsOf: generateMethods())

return members
```

### 3.6 Hygiene and Scope

Avoid name collisions:

```swift
// ❌ BAD: Hard-coded names may collide
let code: DeclSyntax = """
    let result = try await network.fetch()
    return result
    """

// ✅ GOOD: Use unique names
let resultName = context.makeUniqueName("result")
let code: DeclSyntax = """
    let \(resultName) = try await network.fetch()
    return \(resultName)
    """
```

---

## 4. Compile-Time Validation

### 4.1 Macro Role Validation

Swift validates macro usage at compile time through:

1. **Attachment Point Validation**
   - `@attached(member)` only on types/extensions
   - `@attached(peer)` on individual declarations
   - `@attached(accessor)` only on properties/subscripts

2. **Signature Validation**
   - Macro arguments must match declaration
   - Generic parameters are type-checked

### 4.2 Custom Validation Logic

Implement validation in macro expansion:

```swift
public struct APIMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // 1. Validate it's a protocol
        guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
            context.diagnose(
                Diagnostic(
                    node: Syntax(declaration),
                    message: APIMacroDiagnostic.onlyApplicableToProtocol
                )
            )
            return []
        }

        // 2. Validate methods have HTTP annotations
        let methods = extractMethods(from: protocolDecl)
        for method in methods {
            guard hasHTTPMethodAnnotation(method) else {
                context.diagnose(
                    Diagnostic(
                        node: Syntax(method),
                        message: APIMacroDiagnostic.missingHTTPMethod
                    )
                )
                continue
            }
        }

        // 3. Validate path parameters
        for method in methods {
            try validatePathParameters(method, context: context)
        }

        return generateImplementation(for: protocolDecl)
    }
}
```

### 4.3 Type Checking Integration

Macros expand **before** type checking:
- Generated code must be syntactically valid
- Type errors in generated code show as regular compilation errors
- Use `DeclSyntax` type to ensure structural validity

```swift
// Macro generates this
let generated: DeclSyntax = """
    func fetchUser(id: String) async throws -> User {
        try await client.request(.get, "/users/\(id)")
    }
    """
// Swift compiler type-checks generated code
// - Validates async/await usage
// - Verifies return type matches
// - Checks client.request signature
```

### 4.4 Testing Validation Logic

```swift
import SwiftSyntaxMacrosTestSupport
import XCTest

final class ValidationTests: XCTestCase {
    func testMacroRequiresProtocol() {
        assertMacroExpansion(
            """
            @API
            struct NotAProtocol {}
            """,
            expandedSource: """
            struct NotAProtocol {}
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@API can only be applied to a protocol",
                    line: 1,
                    column: 1,
                    severity: .error
                )
            ],
            macros: ["API": APIMacro.self]
        )
    }
}
```

---

## 5. Swift Package Manager Integration

### 5.1 Package Structure

Recommended package organization:

```
MyNetworkingMacros/
├── Package.swift
├── Sources/
│   ├── MyNetworkingMacros/          # Macro declarations (public API)
│   │   └── MacroDeclarations.swift
│   ├── MyNetworkingMacrosPlugin/    # Macro implementations (compiler plugin)
│   │   ├── Plugin.swift
│   │   ├── APIMacro.swift
│   │   ├── GETMacro.swift
│   │   └── Diagnostics.swift
│   └── MyNetworkingClient/          # Runtime support code
│       └── NetworkClient.swift
└── Tests/
    └── MyNetworkingMacrosTests/
        └── MacroTests.swift
```

### 5.2 Package.swift Configuration

Complete example:

```swift
// swift-tools-version: 5.9
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "MyNetworkingMacros",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        // Main library that clients import
        .library(
            name: "MyNetworkingMacros",
            targets: ["MyNetworkingMacros"]
        ),
        // Runtime support library
        .library(
            name: "MyNetworkingClient",
            targets: ["MyNetworkingClient"]
        )
    ],
    dependencies: [
        // Swift Syntax dependency
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            from: "509.0.0"  // Swift 5.9+
        )
    ],
    targets: [
        // 1. Macro declarations (what users see)
        .target(
            name: "MyNetworkingMacros",
            dependencies: [
                "MyNetworkingMacrosPlugin",
                "MyNetworkingClient"
            ]
        ),

        // 2. Macro implementations (compiler plugin)
        .macro(
            name: "MyNetworkingMacrosPlugin",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax")
            ]
        ),

        // 3. Runtime support
        .target(
            name: "MyNetworkingClient",
            dependencies: []
        ),

        // 4. Tests
        .testTarget(
            name: "MyNetworkingMacrosTests",
            dependencies: [
                "MyNetworkingMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
            ]
        )
    ]
)
```

### 5.3 Macro Declaration File

`Sources/MyNetworkingMacros/MacroDeclarations.swift`:

```swift
/// Generates an API client implementation for a protocol.
@attached(member, names: named(init), named(client))
@attached(extension, conformances: APIClient, names: named(execute))
public macro API() = #externalMacro(
    module: "MyNetworkingMacrosPlugin",
    type: "APIMacro"
)

/// Marks a method as a GET request.
@attached(peer)
public macro GET(_ path: String) = #externalMacro(
    module: "MyNetworkingMacrosPlugin",
    type: "GETMacro"
)

/// Marks a method as a POST request.
@attached(peer)
public macro POST(_ path: String) = #externalMacro(
    module: "MyNetworkingMacrosPlugin",
    type: "POSTMacro"
)

// Parameter annotations would need to be property wrappers or
// encoded in method signatures, as direct parameter macros aren't supported
```

### 5.4 Plugin Entry Point

`Sources/MyNetworkingMacrosPlugin/Plugin.swift`:

```swift
import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct MyNetworkingMacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        APIMacro.self,
        GETMacro.self,
        POSTMacro.self,
        // Add all macro implementations
    ]
}
```

### 5.5 Client Integration

Users add dependency:

```swift
// In their Package.swift
dependencies: [
    .package(
        url: "https://github.com/yourorg/MyNetworkingMacros.git",
        from: "1.0.0"
    )
]

targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "MyNetworkingMacros", package: "MyNetworkingMacros")
        ]
    )
]
```

Usage:

```swift
import MyNetworkingMacros

@API
protocol UserAPI {
    @GET("/users/{id}")
    func fetchUser(id: String) async throws -> User

    @POST("/users")
    func createUser(user: User) async throws -> User
}

// Macro generates implementation automatically
```

### 5.6 Non-SPM Integration (Xcode Projects)

For Xcode projects not using SPM:

1. **Build macro as executable:**
```bash
swift build -c release --product MyNetworkingMacrosPlugin
```

2. **Add to Xcode build settings:**
```
OTHER_SWIFT_FLAGS = -load-plugin-executable $(BUILD_DIR)/Release/MyNetworkingMacrosPlugin#MyNetworkingMacrosPlugin
```

3. **Binary distribution:**
   - Package macro plugin as XCFramework
   - Include in project with proper code signing

---

## 6. Common Pitfalls and Solutions

### 6.1 Parameter Annotation Limitations

**Problem:** Cannot attach macros directly to function parameters

```swift
// ❌ NOT SUPPORTED
func fetchUser(@Path("id") userId: String) -> User
```

**Solutions:**

**Option 1: Method-level encoding**
```swift
@GET("/users/{id}")
func fetchUser(id: String) -> User  // Infer path parameter from {id}
```

**Option 2: Nested protocol with property wrappers**
```swift
@API
protocol UserAPI {
    associatedtype Parameters {
        @Path var userId: String
        @Query var includeDeleted: Bool
    }

    @GET("/users")
    func fetchUser(params: Parameters) async throws -> User
}
```

**Option 3: Builder pattern**
```swift
@GET
func fetchUser() -> RequestBuilder<User>

// Usage:
api.fetchUser()
    .path("id", userId)
    .query("sort", "name")
    .execute()
```

### 6.2 Async/Await Context

**Problem:** Generated code must respect async context

```swift
// ❌ BAD: Generates non-async code for async protocol
@API
protocol MyAPI {
    func fetchData() async throws -> Data
}
// Generated:
func fetchData() throws -> Data {  // Missing async!
    client.request()
}
```

**Solution:** Detect async in signature
```swift
func generateMethod(for function: FunctionDeclSyntax) -> DeclSyntax {
    let isAsync = function.signature.effectSpecifiers?.asyncSpecifier != nil
    let asyncKeyword = isAsync ? "async " : ""

    return """
        func \(function.name)(...) \(raw: asyncKeyword)throws -> ... {
            \(raw: asyncKeyword.isEmpty ? "" : "await ")client.request(...)
        }
        """
}
```

### 6.3 Generic Type Handling

**Problem:** Preserving generic constraints

```swift
@API
protocol GenericAPI {
    func fetch<T: Decodable>() async throws -> T
}
```

**Solution:** Copy generic clause
```swift
let genericParams = function.genericParameterClause
let genericWhere = function.genericWhereClause

let method: DeclSyntax = """
    func \(function.name)\(genericParams ?? "")(...)
    \(genericWhere ?? "")
    throws -> \(returnType) {
        // ...
    }
    """
```

### 6.4 Visibility and Access Control

**Problem:** Generated code visibility mismatch

**Solution:** Respect original access level
```swift
func accessLevel(of decl: some DeclSyntaxProtocol) -> String? {
    decl.modifiers.first { modifier in
        ["public", "internal", "private", "fileprivate", "open"]
            .contains(modifier.name.text)
    }?.name.text
}

let access = accessLevel(of: protocolDecl) ?? "internal"
let generated: DeclSyntax = """
    \(raw: access) struct \(typeName)Implementation: \(typeName) {
        // ...
    }
    """
```

### 6.5 Circular Dependencies

**Problem:** Macro expansion creating infinite loops

**Prevention:**
- Never call the same macro recursively
- Avoid mutual macro dependencies
- Keep expansion logic simple and directed

### 6.6 Performance Considerations

**Problem:** Slow compilation with complex macros

**Solutions:**
1. **Minimize string parsing**: Use SwiftSyntax APIs instead of regex
2. **Cache computations**: Store intermediate results
3. **Limit generated code size**: Generate helpers, not duplication
4. **Profile macro execution**: Use Instruments to identify bottlenecks

```swift
// ❌ SLOW: Re-parses same content
for _ in 0..<100 {
    let parsed = try parseExpression("\(complexExpression)")
}

// ✅ FAST: Parse once
let parsed = try parseExpression("\(complexExpression)")
for _ in 0..<100 {
    use(parsed)
}
```

### 6.7 Escaping and String Literals

**Problem:** Special characters in generated strings

```swift
// ❌ BAD: Unescaped quotes
let code = """
    let message = "Hello "World""  // Syntax error!
    """
```

**Solution:** Use `\(literal:)` interpolation
```swift
let userInput = "Hello \"World\""
let code = """
    let message = \(literal: userInput)  // Properly escaped
    """
```

### 6.8 Multi-line Protocol Methods

**Problem:** Methods spanning multiple lines with attributes

```swift
@API
protocol ComplexAPI {
    @GET("/users")
    func fetchUsers(
        limit: Int,
        offset: Int,
        sort: String?
    ) async throws -> [User]
}
```

**Solution:** SwiftSyntax preserves multi-line structure
```swift
// Access works correctly regardless of line breaks
let params = function.signature.parameterClause.parameters
// params contains all three parameters
```

---

## 7. Concrete Implementation Examples

### 7.1 Protocol Annotation: @API Macro

**Declaration:**
```swift
@attached(member, names: named(client), named(init))
@attached(extension, conformances: NetworkAPIClient)
public macro API(baseURL: String? = nil) = #externalMacro(
    module: "NetworkMacrosPlugin",
    type: "APIMacro"
)
```

**Implementation:**
```swift
import SwiftSyntax
import SwiftSyntaxMacros
import SwiftSyntaxBuilder

public struct APIMacro: MemberMacro, ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // 1. Validate protocol
        guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
            context.diagnose(
                Diagnostic(
                    node: Syntax(declaration),
                    message: MacroDiagnostic.notAProtocol
                )
            )
            return []
        }

        // 2. Extract base URL from macro arguments
        let baseURL = extractBaseURL(from: node) ?? "https://api.example.com"

        // 3. Generate client property and initializer
        return [
            """
            private let client: NetworkClient
            """,
            """
            public init(client: NetworkClient = .shared) {
                self.client = client
            }
            """
        ]
    }

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // Generate conformance to protocol
        let ext: DeclSyntax = """
            extension \(type.trimmed): NetworkAPIClient {
                public var baseURL: String { "\(raw: baseURL)" }
            }
            """

        return [ext.cast(ExtensionDeclSyntax.self)]
    }

    private static func extractBaseURL(from node: AttributeSyntax) -> String? {
        guard case let .argumentList(arguments) = node.arguments,
              let firstArg = arguments.first,
              let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self) else {
            return nil
        }

        return stringLiteral.segments.description
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
}
```

### 7.2 Method Annotation: @GET Macro

**Declaration:**
```swift
@attached(peer, names: arbitrary)
public macro GET(_ path: String) = #externalMacro(
    module: "NetworkMacrosPlugin",
    type: "HTTPMethodMacro"
)
```

**Implementation:**
```swift
public struct HTTPMethodMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        // 1. Ensure it's a function
        guard let function = declaration.as(FunctionDeclSyntax.self) else {
            return []
        }

        // 2. Extract HTTP method from attribute name
        let httpMethod = extractHTTPMethod(from: node)

        // 3. Extract path
        guard let path = extractPath(from: node) else {
            context.diagnose(
                Diagnostic(
                    node: Syntax(node),
                    message: MacroDiagnostic.missingPath
                )
            )
            return []
        }

        // 4. Extract function details
        let functionName = function.name.text
        let parameters = function.signature.parameterClause.parameters
        let returnType = function.signature.returnClause?.type.description ?? "Void"
        let isAsync = function.signature.effectSpecifiers?.asyncSpecifier != nil
        let throwsKeyword = function.signature.effectSpecifiers?.throwsSpecifier != nil

        // 5. Build parameter list for implementation
        let paramList = parameters.map { param in
            let name = param.secondName?.text ?? param.firstName.text
            let type = param.type.description.trimmingCharacters(in: .whitespaces)
            return "\(name): \(type)"
        }.joined(separator: ", ")

        // 6. Generate path parameter substitution
        let pathWithSubstitutions = generatePathSubstitution(
            path: path,
            parameters: Array(parameters),
            context: context
        )

        // 7. Generate implementation
        let asyncKeyword = isAsync ? "async " : ""
        let throwsClause = throwsKeyword ? "throws " : ""
        let awaitKeyword = isAsync ? "await " : ""

        let implementation: DeclSyntax = """
            func \(raw: functionName)(\(raw: paramList)) \(raw: asyncKeyword)\(raw: throwsClause)-> \(raw: returnType) {
                let endpoint = \(raw: pathWithSubstitutions)
                return \(raw: awaitKeyword)try client.request(
                    method: .\(raw: httpMethod.lowercased()),
                    endpoint: endpoint
                )
            }
            """

        return [implementation]
    }

    private static func extractHTTPMethod(from node: AttributeSyntax) -> String {
        node.attributeName.as(IdentifierTypeSyntax.self)?.name.text ?? "GET"
    }

    private static func extractPath(from node: AttributeSyntax) -> String? {
        guard case let .argumentList(arguments) = node.arguments,
              let firstArg = arguments.first,
              let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self) else {
            return nil
        }

        return stringLiteral.segments.description
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }

    private static func generatePathSubstitution(
        path: String,
        parameters: [FunctionParameterSyntax],
        context: some MacroExpansionContext
    ) -> String {
        // Replace {paramName} with \(paramName)
        var result = "\"\(path)\""

        // Extract path parameter names from {param} patterns
        let pathParams = extractPathParameters(from: path)

        for pathParam in pathParams {
            // Find matching function parameter
            guard let param = parameters.first(where: { p in
                let name = p.secondName?.text ?? p.firstName.text
                return name == pathParam
            }) else {
                context.diagnose(
                    Diagnostic(
                        node: Syntax(context.location(of: parameters.first!)!),
                        message: MacroDiagnostic.missingPathParameter(pathParam)
                    )
                )
                continue
            }

            let paramName = param.secondName?.text ?? param.firstName.text
            result = result.replacingOccurrences(
                of: "{\(pathParam)}",
                with: "\\(\(paramName))"
            )
        }

        return result
    }

    private static func extractPathParameters(from path: String) -> [String] {
        let pattern = "\\{([^}]+)\\}"
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(path.startIndex..., in: path)

        return regex.matches(in: path, range: range).compactMap { match in
            guard let range = Range(match.range(at: 1), in: path) else { return nil }
            return String(path[range])
        }
    }
}
```

### 7.3 Complete Usage Example

```swift
import NetworkMacros

@API(baseURL: "https://api.github.com")
protocol GitHubAPI {
    @GET("/users/{username}")
    func getUser(username: String) async throws -> User

    @GET("/users/{username}/repos")
    func getRepos(username: String, sort: String?) async throws -> [Repository]

    @POST("/repos/{owner}/{repo}/issues")
    func createIssue(owner: String, repo: String, body: IssueBody) async throws -> Issue
}

// Macros generate:
/*
struct GitHubAPIClient: GitHubAPI, NetworkAPIClient {
    private let client: NetworkClient

    public init(client: NetworkClient = .shared) {
        self.client = client
    }

    public var baseURL: String { "https://api.github.com" }

    func getUser(username: String) async throws -> User {
        let endpoint = "/users/\(username)"
        return try await client.request(method: .get, endpoint: endpoint)
    }

    func getRepos(username: String, sort: String?) async throws -> [Repository] {
        let endpoint = "/users/\(username)/repos"
        var queryParams: [String: String] = [:]
        if let sort = sort {
            queryParams["sort"] = sort
        }
        return try await client.request(
            method: .get,
            endpoint: endpoint,
            query: queryParams
        )
    }

    func createIssue(owner: String, repo: String, body: IssueBody) async throws -> Issue {
        let endpoint = "/repos/\(owner)/\(repo)/issues"
        return try await client.request(
            method: .post,
            endpoint: endpoint,
            body: body
        )
    }
}
*/
```

---

## 8. Testing Macros

### 8.1 Test Infrastructure Setup

Add test dependency in Package.swift:

```swift
.testTarget(
    name: "NetworkMacrosTests",
    dependencies: [
        "NetworkMacros",
        .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax")
    ]
)
```

### 8.2 Basic Macro Expansion Tests

```swift
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
@testable import NetworkMacrosPlugin

final class APIMacroTests: XCTestCase {
    let testMacros: [String: Macro.Type] = [
        "API": APIMacro.self,
        "GET": HTTPMethodMacro.self,
        "POST": HTTPMethodMacro.self
    ]

    func testBasicAPIGeneration() {
        assertMacroExpansion(
            """
            @API
            protocol UserAPI {
                @GET("/users/{id}")
                func fetchUser(id: String) async throws -> User
            }
            """,
            expandedSource: """
            protocol UserAPI {
                func fetchUser(id: String) async throws -> User

                private let client: NetworkClient

                public init(client: NetworkClient = .shared) {
                    self.client = client
                }
            }

            extension UserAPI: NetworkAPIClient {
                public var baseURL: String { "https://api.example.com" }
            }
            """,
            macros: testMacros
        )
    }
}
```

### 8.3 Testing Diagnostics

```swift
func testRequiresProtocol() {
    assertMacroExpansion(
        """
        @API
        struct NotAProtocol {
        }
        """,
        expandedSource: """
        struct NotAProtocol {
        }
        """,
        diagnostics: [
            DiagnosticSpec(
                message: "@API can only be applied to a protocol",
                line: 1,
                column: 1,
                severity: .error
            )
        ],
        macros: testMacros
    )
}
```

### 8.4 Testing Edge Cases

```swift
func testMultiplePathParameters() {
    assertMacroExpansion(
        """
        @API
        protocol ComplexAPI {
            @GET("/repos/{owner}/{repo}/issues/{number}")
            func getIssue(owner: String, repo: String, number: Int) async throws -> Issue
        }
        """,
        expandedSource: """
        protocol ComplexAPI {
            func getIssue(owner: String, repo: String, number: Int) async throws -> Issue

            // ... generated implementation with proper path substitution
        }
        """,
        macros: testMacros
    )
}

func testMissingPathParameter() {
    assertMacroExpansion(
        """
        @GET("/users/{id}")
        func fetchUser(userId: String) async throws -> User
        """,
        expandedSource: """
        func fetchUser(userId: String) async throws -> User
        """,
        diagnostics: [
            DiagnosticSpec(
                message: "Path parameter 'id' not found in function parameters",
                line: 1,
                column: 1,
                severity: .error
            )
        ],
        macros: testMacros
    )
}
```

### 8.5 Unit Testing Macro Logic

Test individual helper functions:

```swift
func testPathParameterExtraction() {
    let path = "/users/{id}/repos/{repo}"
    let params = HTTPMethodMacro.extractPathParameters(from: path)

    XCTAssertEqual(params, ["id", "repo"])
}

func testPathSubstitution() {
    let path = "/users/{id}"
    let parameters: [FunctionParameterSyntax] = // ... create test parameters
    let result = HTTPMethodMacro.generatePathSubstitution(
        path: path,
        parameters: parameters,
        context: testContext
    )

    XCTAssertEqual(result, "\"/users/\\(id)\"")
}
```

### 8.6 Integration Testing

Test full macro pipeline:

```swift
func testEndToEndGeneration() {
    let source = """
        import NetworkMacros

        @API(baseURL: "https://api.example.com")
        protocol TestAPI {
            @GET("/test")
            func test() async throws -> String
        }

        let api = TestAPIClient()
        """

    // Compile and verify it type-checks correctly
    // This requires running actual Swift compiler
    // Can use swift-syntax's parsing + type checking
}
```

---

## 9. Additional Resources

### 9.1 Official Documentation

1. **Swift Macros Documentation**
   - [Swift Syntax Macros Guide](https://github.com/swiftlang/swift-syntax/blob/main/Sources/SwiftSyntaxMacros/SwiftSyntaxMacros.docc/SwiftSyntaxMacros.md)
   - [Swift Book: Macros Chapter](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/macros/)

2. **SwiftSyntax Package**
   - [Repository](https://github.com/swiftlang/swift-syntax)
   - [Package Documentation](https://swiftpackageindex.com/swiftlang/swift-syntax/main/documentation/swiftsyntax)

3. **WWDC Sessions**
   - [WWDC 2023: Write Swift Macros](https://developer.apple.com/videos/play/wwdc2023/10166/)
   - [WWDC 2023: Expand on Swift Macros](https://developer.apple.com/videos/play/wwdc2023/10167/)

### 9.2 Community Resources

1. **Examples and Tutorials**
   - [Swift Syntax Examples](https://github.com/swiftlang/swift-syntax/tree/main/Examples)
   - [Swift Macro Testing by Point-Free](https://github.com/pointfreeco/swift-macro-testing)

2. **Tools**
   - [Swift AST Explorer](https://swift-ast-explorer.com) - Interactive syntax tree viewer
   - [Swift Syntax Builder](https://github.com/swiftlang/swift-syntax/tree/main/Sources/SwiftSyntaxBuilder)

3. **Evolution Proposals**
   - [SE-0382: Expression Macros](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0382-expression-macros.md)
   - [SE-0389: Attached Macros](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0389-attached-macros.md)

### 9.3 Reference Implementations

Study these open-source macro implementations:

1. **SwiftUI Observation**
   - [@Observable macro](https://github.com/apple/swift/tree/main/lib/Macros)

2. **Case Paths**
   - [Case Paths Macro](https://github.com/pointfreeco/swift-case-paths)

3. **Dependencies**
   - [Dependency Macros](https://github.com/pointfreeco/swift-dependencies)

### 9.4 Key SwiftSyntax Types Reference

| Type | Purpose | Common Methods |
|------|---------|----------------|
| `TokenSyntax` | Single token | `.text`, `.tokenKind` |
| `DeclSyntax` | Any declaration | `.as(ProtocolDeclSyntax.self)` |
| `ExprSyntax` | Any expression | `.description` |
| `TypeSyntax` | Type annotation | `.trimmed` |
| `FunctionDeclSyntax` | Function declaration | `.signature`, `.name`, `.body` |
| `ProtocolDeclSyntax` | Protocol declaration | `.memberBlock.members` |
| `AttributeSyntax` | Attribute like @GET | `.arguments`, `.attributeName` |
| `FunctionParameterSyntax` | Function parameter | `.firstName`, `.type` |

### 9.5 Macro Role Quick Reference

| Role | Declaration | Use Case | Returns |
|------|-------------|----------|---------|
| Expression | `@freestanding(expression)` | Generate expressions | `ExprSyntax` |
| Declaration | `@freestanding(declaration)` | Generate declarations | `[DeclSyntax]` |
| Peer | `@attached(peer)` | Add sibling declarations | `[DeclSyntax]` |
| Member | `@attached(member)` | Add type members | `[DeclSyntax]` |
| Accessor | `@attached(accessor)` | Add property accessors | `[AccessorDeclSyntax]` |
| Member Attribute | `@attached(memberAttribute)` | Apply attributes to members | `[AttributeSyntax]` |
| Extension | `@attached(extension)` | Add conformances | `[ExtensionDeclSyntax]` |

---

## Summary

Swift macros provide a powerful mechanism for implementing Retrofit-style API client generators through:

1. **Attached Member Macros**: Generate complete API client implementations
2. **SwiftSyntax**: Source-accurate AST manipulation
3. **Compile-time Safety**: Full type checking and validation
4. **SPM Integration**: Seamless package distribution
5. **Testing Support**: Comprehensive test infrastructure

**Key Takeaways:**
- Use `@attached(member)` for protocol-level code generation
- Leverage SwiftSyntax's type-safe node APIs
- Emit diagnostics instead of using `fatalError`
- Test thoroughly with `SwiftSyntaxMacrosTestSupport`
- Parameter annotations require creative workarounds
- Performance matters: minimize parsing and string operations

This guide provides the foundation for building production-ready API client macros in Swift.
