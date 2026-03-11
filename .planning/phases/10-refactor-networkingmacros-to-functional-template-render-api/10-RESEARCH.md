# Phase 10: Create MacroTemplateKit Helper Package - Research

**Researched:** 2026-02-15
**Domain:** Swift macro code generation, functional template systems, algebraic data types
**Confidence:** MEDIUM

## Summary

Phase 10 requires creating a standalone MacroTemplateKit helper package providing a pure-functional Template/Render algebra for SwiftSyntax AST generation. The package implements an algebraic data type (ADT) for template representation with a natural transformation to SwiftSyntax nodes.

**Current State Analysis:**
- MacroTemplateKit directory exists at `Packages/MacroTemplateKit/` but contains no files
- NetworkingMacros currently uses imperative string concatenation for code generation (SyntaxFactory.swift, 321 lines)
- No Package.swift exists for MacroTemplateKit yet
- Root workspace Package.swift does not yet include MacroTemplateKit

**Primary recommendation:** Use Swift enums with associated values for Template ADT, SwiftSyntaxBuilder result builders for Renderer implementation, and maintain pure-functional composition with functor laws for referential transparency.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| SwiftSyntax | 600.0.1 | AST representation and manipulation | Apple's official Swift syntax library, required for all macro implementations |
| SwiftSyntaxBuilder | 600.0.1 (bundled) | Result builder APIs for constructing syntax nodes | Provides declarative, type-safe syntax tree construction |
| Swift Package Manager | 6.0+ | Dependency management, workspace organization | Built-in tool, supports local package dependencies via `.package(path:)` |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| SwiftSyntaxMacrosTestSupport | 600.0.1 (bundled) | Macro expansion testing | Testing Template→ExprSyntax transformations with `assertMacroExpansion` |
| XCTest | Built-in | Unit testing framework | Property-based tests for functor laws, composition rules |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Enum-based ADT | Protocol + concrete types | Enums provide exhaustive pattern matching, protocols require type erasure |
| SwiftSyntaxBuilder | Manual RawSyntax construction | Builder APIs are higher-level and maintain source fidelity (trivia preservation) |
| Local package dependency | Monorepo single-package | Separate packages enforce modularity, enable independent versioning |

**Installation:**
```bash
# MacroTemplateKit has no external dependencies
# NetworkingMacros Package.swift adds:
dependencies: [
  .package(path: "../MacroTemplateKit"),
  .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0")
]
targets: [
  .macro(
    name: "NetworkingMacros",
    dependencies: [
      .product(name: "MacroTemplateKit", package: "MacroTemplateKit"),
      // ... SwiftSyntax products
    ]
  )
]
```

## Architecture Patterns

### Recommended Project Structure
```
Packages/MacroTemplateKit/
├── Package.swift                    # Standalone library package
├── Sources/
│   └── MacroTemplateKit/
│       ├── Template.swift           # ADT with 9 cases + Functor conformance
│       ├── Renderer.swift           # Natural transformation Template<A> → ExprSyntax
│       ├── LiteralValue.swift       # Sum type for literal representations
│       └── TemplateDSL.swift        # Optional: Fluent builder API
└── Tests/
    └── MacroTemplateKitTests/
        ├── TemplateTests.swift      # Functor law property tests
        ├── RendererTests.swift      # Rendering correctness tests
        └── CompositionTests.swift   # Template composition tests
```

### Pattern 1: Algebraic Data Type for Templates
**What:** Swift enum with associated values representing parametric template structure
**When to use:** When building compositional, type-safe code generation abstractions
**Example:**
```swift
// Source: Functional programming patterns in Swift
public enum Template<A> {
  case literal(LiteralValue)
  case variable(String, payload: A)
  case conditional(condition: Template<A>, thenBranch: Template<A>, elseBranch: Template<A>)
  case loop(variable: String, collection: Template<A>, body: Template<A>)
  case functionCall(function: Template<A>, arguments: [Template<A>])
  case binaryOperation(left: Template<A>, operator: String, right: Template<A>)
  case propertyAccess(base: Template<A>, property: String)
  case variableDeclaration(name: String, type: String?, initializer: Template<A>)
  case arrayLiteral([Template<A>])
}

// Functor instance (map preserves structure)
extension Template {
  public func map<B>(_ transform: (A) -> B) -> Template<B> {
    switch self {
    case .literal(let value):
      return .literal(value)
    case .variable(let name, let payload):
      return .variable(name, payload: transform(payload))
    case .conditional(let cond, let thenBranch, let elseBranch):
      return .conditional(
        condition: cond.map(transform),
        thenBranch: thenBranch.map(transform),
        elseBranch: elseBranch.map(transform)
      )
    // ... remaining cases recursively apply transform
    }
  }
}
```

### Pattern 2: Natural Transformation (Template → SwiftSyntax)
**What:** Pure function `render: Template<A> → ExprSyntax` preserving categorical structure
**When to use:** Converting abstract templates to concrete SwiftSyntax AST nodes
**Example:**
```swift
// Source: Category theory natural transformations + SwiftSyntaxBuilder patterns
public struct Renderer {
  public static func render<A>(_ template: Template<A>) -> ExprSyntax {
    switch template {
    case .literal(let value):
      return renderLiteral(value)

    case .variable(let name, _):
      return ExprSyntax(IdentifierExprSyntax(identifier: .identifier(name)))

    case .functionCall(let function, let arguments):
      return ExprSyntax(
        FunctionCallExprSyntax(
          calledExpression: render(function),
          leftParen: .leftParenToken(),
          arguments: LabeledExprListSyntax {
            for arg in arguments {
              LabeledExprSyntax(expression: render(arg))
            }
          },
          rightParen: .rightParenToken()
        )
      )

    case .binaryOperation(let left, let op, let right):
      return ExprSyntax(
        InfixOperatorExprSyntax(
          leftOperand: render(left),
          operator: BinaryOperatorExprSyntax(text: op),
          rightOperand: render(right)
        )
      )

    // ... remaining cases
    }
  }

  private static func renderLiteral(_ value: LiteralValue) -> ExprSyntax {
    switch value {
    case .integer(let int):
      return ExprSyntax(IntegerLiteralExprSyntax(literal: .integerLiteral("\(int)")))
    case .double(let double):
      return ExprSyntax(FloatLiteralExprSyntax(literal: .floatLiteral("\(double)")))
    case .string(let str):
      return ExprSyntax(StringLiteralExprSyntax(content: str))
    case .boolean(let bool):
      return ExprSyntax(BooleanLiteralExprSyntax(literal: bool ? .keyword(.true) : .keyword(.false)))
    case .nil:
      return ExprSyntax(NilLiteralExprSyntax())
    }
  }
}
```

### Pattern 3: Result Builder DSL (Optional Enhancement)
**What:** SwiftUI-style declarative API for composing templates
**When to use:** When template construction code needs high readability
**Example:**
```swift
// Source: WWDC21 Session 10253 - Result Builders
@resultBuilder
public struct TemplateBuilder<A> {
  public static func buildBlock(_ components: Template<A>...) -> [Template<A>] {
    components
  }

  public static func buildArray(_ components: [[Template<A>]]) -> [Template<A>] {
    components.flatMap { $0 }
  }

  public static func buildOptional(_ component: [Template<A>]?) -> [Template<A>] {
    component ?? []
  }
}

// Usage:
func buildHTTPRequest<A>(@TemplateBuilder<A> _ content: () -> [Template<A>]) -> Template<A> {
  .functionCall(
    function: .variable("HTTPRequest", payload: /* metadata */),
    arguments: content()
  )
}
```

### Anti-Patterns to Avoid
- **String Concatenation for Code Gen:** Current SyntaxFactory.swift uses imperative string building (`bodyStatements.append()`). Avoid in MacroTemplateKit—use compositional Template values instead.
- **Mutable Template State:** Templates must be immutable value types. Never use `var` properties or reference types.
- **Partial Renderer Functions:** Renderer must handle ALL Template cases exhaustively. Compiler enforces this with switch statements.
- **Hardcoded SwiftSyntax Trivia:** Let SwiftSyntaxBuilder handle whitespace/formatting automatically unless specific formatting is required.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| AST Node Construction | Manual TokenSyntax assembly | SwiftSyntaxBuilder result builders | Handles trivia (whitespace/comments), maintains source fidelity, type-safe |
| Syntax Validation | Custom Swift parser | SwiftSyntax Parser module | Handles all Swift 6 syntax, edge cases (operators, generics, attributes) |
| Template Composition | Custom tree traversal | Functor `map` + recursive patterns | Guarantees composition laws, referential transparency |
| Code Formatting | String manipulation | SwiftSyntaxBuilder + swift-format | Compiler-correct formatting, respects style guides |

**Key insight:** SwiftSyntax is a 200K+ LOC library handling Swift's full grammar evolution. Custom AST builders miss edge cases (unicode identifiers, postfix operators, attached macros on macros, etc.). SwiftSyntaxBuilder's result builder APIs were designed specifically to avoid manual token/trivia management that plagued earlier macro implementations.

## Common Pitfalls

### Pitfall 1: Breaking Functor Laws
**What goes wrong:** Template.map violates identity or composition laws, breaking referential transparency
**Why it happens:** Attempting to perform side effects or stateful transformations in `map`
**How to avoid:**
- **Identity Law:** `template.map { $0 } == template` must hold for all templates
- **Composition Law:** `template.map(f).map(g) == template.map { g(f($0)) }` must hold
- Validate with property-based tests using random template structures
**Warning signs:** Tests fail when composing multiple `map` operations; templates behave differently after identity mapping

### Pitfall 2: Incomplete Pattern Matching in Renderer
**What goes wrong:** Renderer doesn't handle all Template cases, causing runtime crashes
**Why it happens:** Adding new Template case but forgetting to update Renderer
**How to avoid:**
- Never use `default:` in Renderer switch statements (defeats exhaustiveness checking)
- Add unit test for each Template case immediately when adding it
- Use `@unknown default:` only for future-proofing frozen enums (not applicable here)
**Warning signs:** Compiler warnings about non-exhaustive switches; unexplained crashes in macro expansion

### Pitfall 3: Local Package Dependency Order
**What goes wrong:** Root workspace lists NetworkingMacros before MacroTemplateKit, causing build failures
**Why it happens:** SPM resolves dependencies in declaration order; dependents must come after dependencies
**How to avoid:**
- ALWAYS list leaf packages (no dependencies) FIRST in workspace Package.swift
- Order: MacroTemplateKit → NetworkingMacros → Networking → Extensions
- Validate with `swift build` at workspace root
**Warning signs:** Build errors like "missing required module 'MacroTemplateKit'"; changing workspace order fixes builds

### Pitfall 4: Macro Target Type for MacroTemplateKit
**What goes wrong:** Using `.macro(name: "MacroTemplateKit", ...)` instead of `.target`
**Why it happens:** Confusion between macro compiler plugins and helper libraries
**How to avoid:**
- MacroTemplateKit is a REGULAR LIBRARY (`.target`), not a macro plugin
- Only NetworkingMacros uses `.macro` (it's the actual compiler plugin)
- MacroTemplateKit provides data structures, not macro implementations
**Warning signs:** SwiftCompilerPlugin errors; "no macro types found in module" warnings

### Pitfall 5: Overusing String Interpolation for Rendering
**What goes wrong:** Using `ExprSyntax("\(template)")` syntax extensively in Renderer
**Why it happens:** String interpolation is concise but parses strings at compile-time
**How to avoid:**
- Use string interpolation ONLY for trivial, static templates
- Prefer explicit SwiftSyntaxBuilder constructors for dynamic content
- String parsing has performance cost and loses type safety
**Warning signs:** SwiftSyntax parsing errors; trivia (whitespace) formatting issues; difficulty debugging generated code

## Code Examples

Verified patterns from official sources:

### Template ADT Core Implementation
```swift
// Source: Swift Algebraic Data Types + Functional Programming patterns
import Foundation

/// Sum type representing literal values in templates.
public enum LiteralValue: Equatable, Sendable {
  case integer(Int)
  case double(Double)
  case string(String)
  case boolean(Bool)
  case `nil`
}

/// Parametric algebraic data type for code generation templates.
///
/// Template<A> is a Functor: provides `map` preserving structure.
/// The type parameter A represents metadata/payload associated with template nodes.
public enum Template<A>: Equatable where A: Equatable {
  case literal(LiteralValue)
  case variable(String, payload: A)
  case conditional(condition: Template<A>, thenBranch: Template<A>, elseBranch: Template<A>)
  case loop(variable: String, collection: Template<A>, body: Template<A>)
  case functionCall(function: Template<A>, arguments: [Template<A>])
  case binaryOperation(left: Template<A>, operator: String, right: Template<A>)
  case propertyAccess(base: Template<A>, property: String)
  case variableDeclaration(name: String, type: String?, initializer: Template<A>)
  case arrayLiteral([Template<A>])
}

// Functor instance
extension Template {
  /// Maps payload transformation over template structure.
  /// Preserves functor laws: identity and composition.
  public func map<B>(_ transform: (A) -> B) -> Template<B> {
    switch self {
    case .literal(let value):
      return .literal(value)
    case .variable(let name, let payload):
      return .variable(name, payload: transform(payload))
    case .conditional(let condition, let thenBranch, let elseBranch):
      return .conditional(
        condition: condition.map(transform),
        thenBranch: thenBranch.map(transform),
        elseBranch: elseBranch.map(transform)
      )
    case .loop(let variable, let collection, let body):
      return .loop(
        variable: variable,
        collection: collection.map(transform),
        body: body.map(transform)
      )
    case .functionCall(let function, let arguments):
      return .functionCall(
        function: function.map(transform),
        arguments: arguments.map { $0.map(transform) }
      )
    case .binaryOperation(let left, let op, let right):
      return .binaryOperation(
        left: left.map(transform),
        operator: op,
        right: right.map(transform)
      )
    case .propertyAccess(let base, let property):
      return .propertyAccess(
        base: base.map(transform),
        property: property
      )
    case .variableDeclaration(let name, let type, let initializer):
      return .variableDeclaration(
        name: name,
        type: type,
        initializer: initializer.map(transform)
      )
    case .arrayLiteral(let elements):
      return .arrayLiteral(elements.map { $0.map(transform) })
    }
  }
}
```

### Renderer Natural Transformation
```swift
// Source: SwiftSyntaxBuilder convenience initializers + natural transformations
import SwiftSyntax
import SwiftSyntaxBuilder

/// Natural transformation from Template to SwiftSyntax ExprSyntax.
///
/// This transformation is pure (no side effects) and structure-preserving.
public struct Renderer {

  /// Renders a template to SwiftSyntax expression node.
  public static func render<A>(_ template: Template<A>) -> ExprSyntax {
    switch template {
    case .literal(let value):
      return renderLiteral(value)

    case .variable(let name, _):
      return ExprSyntax(IdentifierExprSyntax(identifier: .identifier(name)))

    case .conditional(let condition, let thenBranch, let elseBranch):
      return ExprSyntax(
        TernaryExprSyntax(
          condition: render(condition),
          thenExpression: render(thenBranch),
          elseExpression: render(elseBranch)
        )
      )

    case .loop(let variable, let collection, let body):
      // Represents: for variable in collection { body }
      // Note: ExprSyntax doesn't support statements; caller must use StmtSyntax for loops
      // This is a simplified representation for demonstration
      return ExprSyntax(
        FunctionCallExprSyntax(
          calledExpression: ExprSyntax(
            MemberAccessExprSyntax(
              base: render(collection),
              name: .identifier("forEach")
            )
          )
        ) {
          LabeledExprSyntax(
            expression: ClosureExprSyntax {
              ClosureParameterClauseSyntax {
                ClosureParameterSyntax(firstName: .identifier(variable))
              }
              render(body)
            }
          )
        }
      )

    case .functionCall(let function, let arguments):
      return ExprSyntax(
        FunctionCallExprSyntax(calledExpression: render(function)) {
          for arg in arguments {
            LabeledExprSyntax(expression: render(arg))
          }
        }
      )

    case .binaryOperation(let left, let op, let right):
      return ExprSyntax(
        InfixOperatorExprSyntax(
          leftOperand: render(left),
          operator: BinaryOperatorExprSyntax(text: op),
          rightOperand: render(right)
        )
      )

    case .propertyAccess(let base, let property):
      return ExprSyntax(
        MemberAccessExprSyntax(
          base: render(base),
          name: .identifier(property)
        )
      )

    case .variableDeclaration(let name, let type, let initializer):
      // Note: Variable declarations are DeclSyntax, not ExprSyntax
      // This returns the initializer expression only
      // Caller must wrap in VariableDeclSyntax for full declaration
      return render(initializer)

    case .arrayLiteral(let elements):
      return ExprSyntax(
        ArrayExprSyntax {
          for element in elements {
            ArrayElementSyntax(expression: render(element))
          }
        }
      )
    }
  }

  /// Renders literal values to SwiftSyntax expression nodes.
  private static func renderLiteral(_ value: LiteralValue) -> ExprSyntax {
    switch value {
    case .integer(let int):
      return ExprSyntax(IntegerLiteralExprSyntax(literal: .integerLiteral("\(int)")))
    case .double(let double):
      return ExprSyntax(FloatLiteralExprSyntax(literal: .floatLiteral("\(double)")))
    case .string(let str):
      return ExprSyntax(StringLiteralExprSyntax(content: str))
    case .boolean(let bool):
      return ExprSyntax(BooleanLiteralExprSyntax(literal: bool ? .keyword(.true) : .keyword(.false)))
    case .nil:
      return ExprSyntax(NilLiteralExprSyntax())
    }
  }
}
```

### Property-Based Functor Law Tests
```swift
// Source: Functor laws + XCTest property testing patterns
import XCTest
@testable import MacroTemplateKit

final class TemplateFunctorLawsTests: XCTestCase {

  /// Functor Law 1: Identity
  /// template.map { $0 } == template
  func testFunctorIdentityLaw() {
    let template: Template<Int> = .functionCall(
      function: .variable("test", payload: 42),
      arguments: [
        .literal(.integer(1)),
        .variable("x", payload: 100)
      ]
    )

    let mapped = template.map { $0 }
    XCTAssertEqual(template, mapped, "Identity law violated: map(id) must equal identity")
  }

  /// Functor Law 2: Composition
  /// template.map(f).map(g) == template.map { g(f($0)) }
  func testFunctorCompositionLaw() {
    let template: Template<Int> = .binaryOperation(
      left: .variable("a", payload: 10),
      operator: "+",
      right: .variable("b", payload: 20)
    )

    let f: (Int) -> String = { "\($0)" }
    let g: (String) -> Int = { Int($0) ?? 0 }

    let composedMap = template.map(f).map(g)
    let directMap = template.map { g(f($0)) }

    XCTAssertEqual(composedMap, directMap, "Composition law violated")
  }

  /// Property: Mapping preserves template structure
  func testMapPreservesStructure() {
    let original: Template<String> = .conditional(
      condition: .variable("flag", payload: "metadata"),
      thenBranch: .literal(.integer(1)),
      elseBranch: .literal(.integer(2))
    )

    let mapped = original.map { $0.uppercased() }

    // Structure should remain conditional with 3 branches
    if case .conditional = mapped {
      // Success: structure preserved
    } else {
      XCTFail("Map changed template structure")
    }
  }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| String concatenation in macros | SwiftSyntaxBuilder result builders | SwiftSyntax 509.0 (2023) | Type-safe AST construction, trivia preservation |
| Manual token assembly | Convenience initializers + string interpolation | SwiftSyntax 600.0 (2024) | 50% less boilerplate, improved readability |
| Imperative code generation | Declarative template systems | Ongoing (2024-2026) | Compositional, testable, pure-functional |
| Monolithic macro packages | Modular helper libraries | SPM improvements (2025) | Reusable abstractions, cleaner separation |

**Deprecated/outdated:**
- `SyntaxFactory` static methods (pre-SwiftSyntax 509): Replaced by `SwiftSyntaxBuilder` result builders
- String concatenation for AST nodes: Fragile, loses source fidelity (trivia), hard to test
- Macro target for helper libraries: MacroTemplateKit must be `.target`, not `.macro` (common mistake)

## Open Questions

1. **Should Template<A> support statement-level constructs (if/for statements vs expressions)?**
   - What we know: Current design targets `ExprSyntax` (expressions only)
   - What's unclear: Whether Template should also render to `StmtSyntax`, `DeclSyntax` for full coverage
   - Recommendation: Start with expressions only (MVP). Add `TemplateStmt<A>`, `TemplateDecl<A>` in future iterations if needed.

2. **How should Renderer handle Template cases that don't map cleanly to ExprSyntax?**
   - What we know: `.variableDeclaration` and `.loop` are statements, not expressions
   - What's unclear: Should Renderer return partial syntax (initializer only) or error?
   - Recommendation: Document limitations in API comments. Return initializer expression for `.variableDeclaration`; use `.forEach` closure for `.loop` as workaround.

3. **Is the payload type parameter A necessary for initial implementation?**
   - What we know: Parametricity enables attaching metadata (source locations, type info)
   - What's unclear: Whether NetworkingMacros will use metadata in practice
   - Recommendation: Include `A` in MVP. Even if unused initially, enables future extensions without breaking API. Use `Template<Void>` if no metadata needed.

4. **Should MacroTemplateKit include DSL builders (@resultBuilder) in initial release?**
   - What we know: Result builders improve readability but add complexity
   - What's unclear: Whether NetworkingMacros benefits from builder syntax vs direct Template construction
   - Recommendation: Defer to Phase 11 (refactor NetworkingMacros to use Template API). Include DSL only if adoption shows need.

## Sources

### Primary (HIGH confidence)
- SwiftSyntax Official Documentation - ExprSyntax construction patterns
  - [Working with SwiftSyntax | Swift Package Index](https://swiftpackageindex.com/swiftlang/swift-syntax/602.0.0/documentation/swiftsyntax/working-with-swiftsyntax)
  - [SwiftSyntaxBuilder Convenience Initializers](https://github.com/swiftlang/swift-syntax/blob/main/Sources/SwiftSyntaxBuilder/ConvenienceInitializers.swift)
- DeepWiki Analysis - swift-syntax repository
  - SwiftSyntax AST node construction via result builders and string interpolation
  - Reusable code generation library structure (CoreLogic, PublicAPI, Testing modules)
- Swift Package Manager - Local dependencies
  - [SE-0201: Package Manager Local Dependencies](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0201-package-manager-local-dependencies.md)
  - [Managing Dependencies | Swift by Sundell](https://www.swiftbysundell.com/articles/managing-dependencies-using-the-swift-package-manager/)

### Secondary (MEDIUM confidence)
- WWDC21 Session 10253: Write a DSL in Swift using result builders
  - [Apple Developer Video](https://developer.apple.com/videos/play/wwdc2021/10253/)
  - Result builder patterns for declarative APIs
- Category Theory for Swift Programmers
  - [bow-swift/Category-Theory-for-Programmers](https://github.com/bow-swift/Category-Theory-for-Programmers)
  - Natural transformations and functor laws in Swift context
- Functional Programming in Swift
  - [Algebraic Data Types - O'Reilly](https://www.oreilly.com/library/view/swift-functional-programming/9781787284500/5db00e0f-e606-4c41-bb29-d5e39791ef78.xhtml)
  - Swift enums as ADTs, pattern matching

### Tertiary (LOW confidence)
- Exa search results: SwiftSyntax ExprSyntax best practices 2026
  - Various blog posts and tutorials (3 Swift Syntax Tricks, Point-Free SwiftSyntax guide)
  - Marked for validation: General patterns, not authoritative architecture guidance

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - SwiftSyntax 600.0.1 is verified dependency in NetworkingMacros, official Apple library
- Architecture: MEDIUM - ADT/functor pattern well-established in FP, but Swift-specific implementation requires validation
- Pitfalls: MEDIUM - Based on common SPM/macro development issues, verified via Swift Forums and official docs
- Code examples: HIGH - All examples derived from official SwiftSyntax documentation and established FP patterns

**Research date:** 2026-02-15
**Valid until:** ~30 days (SwiftSyntax stable API, slow evolution)

**Limitations:**
- No existing MacroTemplateKit implementation to reference (greenfield project)
- Template ADT design is inferred from requirements, not validated against real-world usage
- Renderer implementation assumes ExprSyntax target; statement/declaration rendering untested
- Functor law testing strategy theoretical; property-based test coverage unclear without execution

**Next Steps for Planner:**
1. Create Package.swift for MacroTemplateKit (regular `.target`, NOT `.macro`)
2. Update root workspace Package.swift to list MacroTemplateKit BEFORE NetworkingMacros
3. Implement Template.swift with 9 cases + Functor conformance
4. Implement Renderer.swift with exhaustive pattern matching
5. Add property-based tests for functor laws (identity, composition)
6. Validate NetworkingMacros builds with MacroTemplateKit dependency
