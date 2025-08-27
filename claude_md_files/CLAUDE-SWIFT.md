# CLAUDE-SWIFT.md

This file provides guidance to Claude Code when working with Swift applications for iOS/macOS.

## Core Development Philosophy

### KISS (Keep It Simple, Stupid)

Simplicity should be a key goal in design. Choose straightforward solutions over complex ones whenever possible. Simple solutions are easier to understand, maintain, and debug.

### YAGNI (You Aren't Gonna Need It)

Avoid building functionality on speculation. Implement features only when they are needed, not when you anticipate they might be useful in the future.

### Protocol-Oriented Architecture

Build with protocols and protocol extensions. Each component should have a single, clear responsibility and be testable through protocol abstraction.

### Performance by Default

With Swift's compiler optimizations and value types, focus on clean, readable code. Use value types (structs) by default, reference types (classes) only when needed.

### Design Principles (MUST FOLLOW)

- **MVVM Architecture**: MUST organize by features with ViewModels
- **Protocol-Oriented Programming**: MUST use protocols over inheritance
- **Fail Fast**: MUST validate inputs early with guard statements, throw errors immediately

## 🤖 AI Assistant Guidelines

### Context Awareness

- When implementing features, always check existing patterns first
- Prefer protocol composition over inheritance in all designs
- Use existing extensions before creating new ones
- Check for similar functionality in other modules/features

### Common Pitfalls to Avoid

- Creating duplicate functionality
- Overwriting existing tests
- Modifying core frameworks without explicit instruction
- Adding dependencies without checking existing alternatives

### Workflow Patterns

- Preferably create tests BEFORE implementation (TDD)
- Use "think hard" for architecture decisions
- Break complex tasks into smaller, testable units
- Validate understanding before implementation

### Search Command Requirements

**CRITICAL**: Always use `rg` (ripgrep) instead of traditional `grep` and `find` commands:

```bash
# ❌ Don't use grep
grep -r "pattern" .

# ✅ Use rg instead
rg "pattern"

# ❌ Don't use find with name
find . -name "*.swift"

# ✅ Use rg with file filtering
rg --files | rg "\.swift$"
# or
rg --files -g "*.swift"
```

## 🚀 Swift Key Features

### Language Features

- **Async/Await**: Modern concurrency with structured tasks
- **Property Wrappers**: @State, @Published, @ObservedObject for reactive programming
- **Result Builders**: SwiftUI's declarative syntax
- **Actors**: Thread-safe reference types with isolation
- **Generics & Associated Types**: Type-safe reusable code

### Swift Type System (MANDATORY)

- **MUST use `some View` for SwiftUI** view return types
- **MUST use opaque types** where appropriate (`some Protocol`)
- **NEVER force unwrap** - use guard let or if let

```swift
// ✅ CORRECT: Modern Swift typing
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Hello, World!")
    }
}

func makeView() -> some View {
    ContentView()
}

// ❌ FORBIDDEN: Force unwrapping
let value = optionalValue! // Never do this
```

### SwiftUI + Combine Example (WITH MANDATORY DOCUMENTATION)

```swift
/**
 * Contact form view using SwiftUI and Combine.
 *
 * Leverages @StateObject for view model lifecycle management
 * and Combine for reactive data flow. Form data is validated before submission.
 *
 * - Note: Uses async/await for network operations
 * - SeeAlso: `ContactViewModel` for business logic
 */
struct ContactFormView: View {
    /// View model handling form state and submission logic
    @StateObject private var viewModel = ContactViewModel()

    var body: some View {
        Form {
            TextField("Email", text: $viewModel.email)
                .textFieldStyle(.roundedBorder)
                .disabled(viewModel.isSubmitting)

            TextEditor(text: $viewModel.message)
                .frame(minHeight: 100)
                .disabled(viewModel.isSubmitting)

            Button(action: {
                Task {
                    await viewModel.submit()
                }
            }) {
                if viewModel.isSubmitting {
                    ProgressView()
                } else {
                    Text("Send")
                }
            }
            .disabled(viewModel.isSubmitting || !viewModel.isValid)
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") { }
        } message: {
            Text(viewModel.errorMessage)
        }
    }
}
```

## 🏗️ Project Structure (Feature-Based Modules)

```
Sources/
├── Features/              # Feature-based modules
│   └── [Feature]/
│       ├── Tests/         # Co-located tests (MUST be documented)
│       ├── Views/         # SwiftUI views (MUST have documentation)
│       ├── ViewModels/    # View models (MUST have documentation)
│       ├── Models/        # Data models (MUST document properties)
│       ├── Services/      # API/Data services (MUST document methods)
│       └── Feature.swift  # Public API (MUST have module documentation)
├── Core/
│   ├── UI/               # Shared UI components (MUST have documentation)
│   ├── Extensions/       # Swift extensions (MUST have usage examples)
│   ├── Utilities/        # Helper functions (MUST have documentation)
│   └── Protocols/        # Shared protocols
└── Tests/                # Test utilities and mocks
```

## 🎯 Swift Configuration (STRICT REQUIREMENTS)

### MUST Follow These Compiler Settings

```swift
// Package.swift or Build Settings
.target(
    name: "AppTarget",
    swiftSettings: [
        .unsafeFlags([
            "-warnings-as-errors",
            "-warn-implicit-overrides",
            "-warn-long-function-bodies=100",
            "-warn-long-expression-type-checking=100"
        ])
    ]
)
```

### MANDATORY Type Requirements

- **ALL MACRO CODE EXPANSIONS** must be constructed using the **`SwiftSyntax` AST builder APIs**, not by concatenating raw strings.
- **NEVER use `Any` or `AnyObject`** unless interfacing with Objective-C
- **MUST have explicit type annotations** for public APIs
- **MUST use proper generic constraints** for reusable components
- **MUST use Result type** for error handling in async operations
- **NEVER use force unwrapping** or `try!` - handle errors properly

### Type Safety Hierarchy (STRICT ORDER)

1. **Specific Types**: Always prefer specific types when possible
2. **Generic Constraints**: Use generic constraints for reusable code
3. **Existential Types**: Use `any Protocol` when storing heterogeneous collections
4. **Never `Any`**: Only for Objective-C interop (must be commented)
5. **NEVER use primitives to express Domain**
6. **NEVER use Collections in properties create is own type**
   - When working with dictionaries add `@dynamicMemberLookup`
7. **Always use ID types using the struct**
   - Benefits:
     - Compile-time safety — IDs for different domains aren’t interchangeable.
     - Readability — The type itself carries semantic meaning.
     - Flexibility — The value type (V) can be UUID, Int, String, etc.

```swift
struct Identifier<Entity, Value> {
    let rawValue: Value
}

struct User {}
struct Product {}

typealias UserID = Identifier<User, UUID>
typealias ProductID = Identifier<Product, UUID>

let userID = UserID(rawValue: UUID())
let productID = ProductID(rawValue: UUID())

// This won’t compile, even though both are UUID internally:
func findUser(id: UserID) { /* ... */ }

findUser(id: productID) // ❌ Type mismatch
```

### Swift Project Structure (MANDATORY)

- **App Target**: [Create using Tuist](https://docs.tuist.dev/en/) project that have the minimum setup
  - The source files that interact with the project will be SPM packages organized using Clean Architecture [Module Name]UI,[Module Name]Domain,[Module Name]Services
- **SPM Architecture**: Must follow Clean Architecture
  - Layers:
    - UI
    - Domain
    - Services
- **Framework Targets**: Reusable modules
- **Test Targets**: MUST achieve 80% code coverage
- **UI Test Targets**: Critical user flows, [PAGE OBJECT UI Iesting](https://martinfowler.com/bliki/PageObject.html), [UI Testing using Page Object pattern in Swift](https://swiftwithmajid.com/2021/03/24/ui-testing-using-page-object-pattern-in-swift/)

### Type Safety Patterns (MANDATORY)

```swift
// ✅ CORRECT: Safe optional handling
guard let userId = UUID(uuidString: stringId) else {
    throw ValidationError.invalidId
}

// ❌ FORBIDDEN: Force unwrapping
let userId = UUID(uuidString: stringId)! // Never do this
```

### Optional Handling Compliance (MANDATORY)

```swift
// ✅ CORRECT: Handle optionals properly
func processData(_ data: String?) async throws -> ProcessedData {
    guard let data = data else {
        throw DataError.missingData
    }
    return try await process(data)
}

// Using nil-coalescing for defaults
let displayName = user.nickname ?? user.fullName ?? "Anonymous"

// ❌ FORBIDDEN: Force unwrapping optionals
func processData(_ data: String?) async -> ProcessedData {
    return await process(data!) // Crash waiting to happen
}
```

## ⚡ Swift Power Features

### Modern Patterns

- Use async/await for ALL asynchronous operations
- Leverage actors for thread-safe state management
- Use property wrappers for reactive UI updates
- Implement proper error handling with Result and throws

### View Model Template

```swift
/// View model for feature functionality
@MainActor
final class FeatureViewModel: ObservableObject {
    @Published private(set) var data: [Item] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?

    private let service: FeatureServiceProtocol

    init(service: FeatureServiceProtocol = FeatureService()) {
        self.service = service
    }

    func loadData() async {
        isLoading = true
        error = nil

        do {
            data = try await service.fetchItems()
        } catch {
            self.error = error
        }

        isLoading = false
    }
}
```

## 🛡️ Data Validation (MANDATORY FOR ALL EXTERNAL DATA)

### MUST Follow These Validation Rules

- **MUST validate ALL external data**: API responses, user inputs, URL parameters
- **MUST use guard statements**: For early returns and validation
- **MUST fail fast**: Validate at system boundaries, throw errors immediately
- **MUST use Codable carefully**: Implement custom decoding when needed
- **NEVER trust external data** without validation

### Model Example (MANDATORY PATTERNS)

```swift
import Foundation

/// User identifier with type safety
struct UserId: Codable, Hashable {
    let value: UUID

    init(from string: String) throws {
        guard let uuid = UUID(uuidString: string) else {
            throw ValidationError.invalidUserId
        }
        self.value = uuid
    }
}

/// User model with comprehensive validation
struct User: Codable {
    let id: UserId
    let email: String
    let username: String
    let age: Int
    let role: UserRole
    let metadata: UserMetadata

    enum UserRole: String, Codable, CaseIterable {
        case admin, user, guest
    }

    struct UserMetadata: Codable {
        let lastLogin: Date
        let preferences: [String: String]?
    }

    /// Custom initializer with validation
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Validate email format
        let email = try container.decode(String.self, forKey: .email)
        guard email.contains("@") else {
            throw ValidationError.invalidEmail
        }
        self.email = email

        // Validate username
        let username = try container.decode(String.self, forKey: .username)
        guard (3...20).contains(username.count),
              username.range(of: "^[a-zA-Z0-9_]+$", options: .regularExpression) != nil else {
            throw ValidationError.invalidUsername
        }
        self.username = username

        // Validate age
        let age = try container.decode(Int.self, forKey: .age)
        guard (18...100).contains(age) else {
            throw ValidationError.invalidAge
        }
        self.age = age

        // Decode remaining properties
        self.id = try container.decode(UserId.self, forKey: .id)
        self.role = try container.decode(UserRole.self, forKey: .role)
        self.metadata = try container.decode(UserMetadata.self, forKey: .metadata)
    }
}

/// API response wrapper with validation
struct APIResponse<T: Codable>: Codable {
    let success: Bool
    let data: T
    let error: String?
    let timestamp: Date
}
```

## 🧪 Testing Strategy (MANDATORY REQUIREMENTS)

### MUST Meet These Testing Standards

- **MINIMUM 80% code coverage** - NO EXCEPTIONS
- **MUST co-locate tests** with features in `Tests` folders
- **MUST use Swkft Testing** with async/await support
- **MUST test business logic** not implementation details
- **MUST mock external dependencies** appropriately
- **NEVER skip tests** for new features or bug fixes

### SonarQube Quality Gates (MUST PASS ALL)

- **Cognitive Complexity**: MAXIMUM 15 per function
- **Cyclomatic Complexity**: MAXIMUM 10 per function
- **Duplicated Lines**: MAXIMUM 3%
- **Technical Debt Ratio**: MAXIMUM 5%
- **ZERO tolerance** for critical/blocker issues
- **ALL new code** must have 80%+ coverage

### Test Example (WITH MANDATORY DOCUMENTATION)

```swift
/**
 * Test suite for UserProfileViewModel.
 *
 * Tests view model state management, async operations, and error handling.
 * Mocks external dependencies to ensure isolated unit tests.
 */
final class UserProfileViewModelTests: XCTestCase {
    private var sut: UserProfileViewModel!
    private var mockService: MockUserService!

    override func setUp() {
        super.setUp()
        mockService = MockUserService()
        sut = UserProfileViewModel(service: mockService)
    }

    override func tearDown() {
        sut = nil
        mockService = nil
        super.tearDown()
    }

    /**
     * Tests that user name updates correctly on form submission.
     *
     * Verifies:
     * - View model accepts user input
     * - Update method calls service with correct data
     * - Success state is properly reflected
     */
    func testUpdateUserName() async throws {
        // Arrange
        let expectedName = "John Doe"
        mockService.updateResult = .success(User.mock(name: expectedName))

        // Act
        sut.userName = expectedName
        await sut.updateProfile()

        // Assert
        XCTAssertEqual(sut.userName, expectedName)
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.isLoading)
        XCTAssertTrue(mockService.updateCalled)
    }
}
```

## 💅 Code Style & Quality

[**MUST FOLLOW STRICTLY GOOGLE'S SWIFT STYLE GUIDE**](https://google.github.io/swift/)

## 🎨 Component Guidelines (STRICT REQUIREMENTS)

### MANDATORY Documentation Comments

**MUST document ALL public APIs following Swift documentation standards**

````swift
/**
 * Calculates the discount price for a product.
 *
 * This method applies a percentage discount to the original price,
 * ensuring the final price doesn't go below the minimum threshold.
 *
 * - Parameters:
 *   - originalPrice: The original price in cents (must be positive)
 *   - discountPercent: The discount percentage (0-100)
 *   - minPrice: The minimum allowed price after discount
 * - Returns: The calculated discount price in cents
 * - Throws: `ValidationError` if any parameter is invalid
 *
 * - Note: All prices are in cents to avoid floating-point issues
 * - Precondition: `originalPrice` must be greater than 0
 * - Postcondition: Result will be >= `minPrice`
 *
 * ## Example
 * ```swift
 * let discountedPrice = try calculateDiscount(
 *     originalPrice: 10000,
 *     discountPercent: 25,
 *     minPrice: 1000
 * )
 * print(discountedPrice) // 7500
 * ```
 */
public func calculateDiscount(
    originalPrice: Int,
    discountPercent: Double,
    minPrice: Int
) throws -> Int {
    // Validate inputs
    guard originalPrice > 0 else {
        throw ValidationError.invalidPrice("Price must be positive")
    }

    guard (0...100).contains(discountPercent) else {
        throw ValidationError.invalidDiscount("Discount must be 0-100%")
    }

    // Calculate discount
    let discountAmount = Double(originalPrice) * (discountPercent / 100)
    let discountedPrice = originalPrice - Int(discountAmount)

    // Ensure price doesn't go below minimum
    return max(discountedPrice, minPrice)
}
````

### MANDATORY SwiftUI View Documentation

````swift
/**
 * Custom button component with multiple styles and sizes.
 *
 * Provides a reusable button with consistent styling and behavior
 * across the application. Supports VoiceOver and Dynamic Type.
 *
 * ## Usage
 * ```swift
 * CustomButton(
 *     title: "Submit",
 *     style: .primary,
 *     size: .medium
 * ) {
 *     await viewModel.submit()
 * }
 * ```
 */
struct CustomButton: View {
    /// Button title text
    let title: String

    /// Visual style of the button
    let style: ButtonStyle

    /// Size variant of the button
    let size: ButtonSize

    /// Action to perform on tap
    let action: () async -> Void

    /// Whether the button is currently disabled
    @Binding var isDisabled: Bool

    enum ButtonStyle {
        case primary, secondary, danger
    }

    enum ButtonSize {
        case small, medium, large
    }

    var body: some View {
        Button(action: {
            Task {
                await action()
            }
        }) {
            Text(title)
                .font(size.font)
                .foregroundColor(style.textColor)
                .padding(size.padding)
                .background(style.backgroundColor)
                .cornerRadius(8)
        }
        .disabled(isDisabled)
        .accessibilityLabel(title)
    }
}
````

### MANDATORY Code Comment Standards

**Documentation must be written using Apple DOCC specification using triple dashes "///".**

```swift
/// Checks if a user has the required permissions based on their role
/// 
/// This function implements hierarchical permission checking where admin users
/// have access to everything, and other roles are checked using bitwise operations
/// for efficient permission validation.
///
/// - Parameters:
///   - userRole: The current user's role
///   - requiredRole: The minimum role required for the operation
/// - Returns: `true` if the user has sufficient permissions, `false` otherwise
///
/// ## Example
/// ```swift
/// let hasAccess = checkPermissions(userRole: .moderator, requiredRole: .user)
/// // Returns true if moderator role includes user permissions
/// ```
func checkPermissions(userRole: Role, requiredRole: Role) -> Bool {
    // Admin can access everything
    if userRole == .admin { return true }

    // Check hierarchical permissions using bitwise operations
    return userRole.rawValue & requiredRole.rawValue == requiredRole.rawValue
}

// 3. TODOs (MUST include issue number)
// TODO: [#123] Implement rate limiting for login attempts

// 4. MARK sections (REQUIRED for organization)
// MARK: - Properties
// MARK: - Lifecycle
// MARK: - Public Methods
// MARK: - Private Methods

### MUST Follow This State Hierarchy

1. **View State**: `@State` ONLY for view-specific state
2. **Shared State**: `@StateObject`/`@ObservedObject` for cross-view state
3. **Environment**: `@EnvironmentObject` for app-wide dependencies
4. **Async State**: Use actors for thread-safe shared mutable state

### MANDATORY MVVM Pattern

```swift

@MainActor
final class UserViewModel: ObservableObject {
    /// Current user data, nil if not loaded
    @Published private(set) var user: User?

    /// Loading state for UI feedback
    @Published private(set) var isLoading = false

    /// Error state for user feedback
    @Published private(set) var error: Error?

    private let userService: UserServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(userService: UserServiceProtocol = UserService()) {
        self.userService = userService
    }

    func fetchUser(id: UserId) async {
        isLoading = true
        error = nil

        do {
            user = try await userService.getUser(id: id)
        } catch {
            self.error = error
            print("Failed to fetch user: \(error.localizedDescription)")
        }

        isLoading = false
    }
}
```

## 🔐 Security Requirements (MANDATORY)

### Input Validation (MUST IMPLEMENT ALL)

- **MUST validate ALL user inputs** before processing
- **MUST validate URL schemes** before opening
- **MUST use Keychain** for sensitive data storage
- **MUST implement App Transport Security** properly
- **NEVER log sensitive data** (passwords, tokens, PII)

### API Security

```swift
// ✅ CORRECT: Secure API handling
func fetchSecureData() async throws -> SecureData {
    guard let token = KeychainManager.shared.getToken() else {
        throw AuthError.notAuthenticated
    }

    var request = URLRequest(url: apiURL)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw NetworkError.invalidResponse
    }

    return try JSONDecoder().decode(SecureData.self, from: data)
}
```

## 🚀 Performance Guidelines

### Swift Optimizations

- **Use value types** (structs) by default
- **Implement lazy properties** for expensive computations
- **Use actors** for concurrent state management
- **Profile with Instruments** regularly

### Build Optimization

```swift
// Package.swift or Xcode Build Settings
.target(
    name: "App",
    swiftSettings: [
        .unsafeFlags([
            "-O",  // Optimize for speed
            "-whole-module-optimization",
            "-cross-module-optimization"
        ], .when(configuration: .release))
    ]
)
```

## ⚠️ CRITICAL GUIDELINES (MUST FOLLOW ALL)

1. **ENFORCE Swift compiler warnings** - Treat warnings as errors
2. **VALIDATE everything** - Guard statements for all optionals
3. **MINIMUM 80% test coverage** - NO EXCEPTIONS
4. **MUST pass ALL SwiftLint rules** - No merging without passing
5. **MUST use MVVM architecture** - Separate concerns properly
6. **MAXIMUM 200 lines per file** - Split if larger
7. **MAXIMUM cyclomatic complexity of 10** - Refactor if higher
8. **MUST handle ALL states** - Loading, error, empty, and success
9. **MUST use semantic commits** - feat:, fix:, docs:, refactor:, test:
10. **MUST write complete documentation** - ALL public APIs documented
11. **MUST pass ALL automated checks** - Before ANY merge
12. **NEVER use force unwrapping** - No exclamation marks in production code
13. **ALL WARNINGS MUST BE FIXED** - Warnings in code must be treated as errors.

## 📦 Swift Package Manager Scripts

```json
// Package.swift
let package = Package(
    name: "MyApp",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "MyApp", targets: ["MyApp"])
    ],
    dependencies: [
        // Add package dependencies here
    ],
    targets: [
        .target(
            name: "MyApp",
            dependencies: []
        ),
        .testTarget(
            name: "MyAppTests",
            dependencies: ["MyApp"]
        )
    ]
)
```

## 📋 Pre-commit Checklist (MUST COMPLETE ALL)

- [ ] Treat warnings as errors. They must be fixed always.
- [ ] Swift compiles with ZERO errors and warnings
- [ ] All inputs validated with guard statements
- [ ] Tests written and passing (MINIMUM 80% coverage)
- [ ] SwiftLint passes with ZERO violations
- [ ] All states handled (loading, error, empty, success)
- [ ] Accessibility requirements met (labels, hints, traits)
- [ ] ZERO print statements in production code
- [ ] ALL public APIs have complete documentation
- [ ] Complex logic has explanatory comments
- [ ] File headers are present
- [ ] TODOs include issue numbers
- [ ] Files under 200 lines
- [ ] Cyclomatic complexity under 10 for all functions
- [ ] No force unwrapping anywhere

### FORBIDDEN Practices

- **NEVER use force unwrapping (!)**
- **NEVER skip tests**
- **NEVER ignore compiler warnings**
- **NEVER trust external data without validation**
- **NEVER exceed complexity limits**
- **NEVER skip documentation**
- **NEVER use print() in production**
- **NEVER store sensitive data in UserDefaults**
- **NEVER ignore memory leaks**
- **NEVER use synchronous network calls on main thread**

---

## 📝 Recent Updates

### August 2025 - Swift Development Standards

Comprehensive Swift/iOS development guide covering:

- **SwiftUI & UIKit Integration**: Modern declarative UI with SwiftUI, UIKit when needed
- **Async/Await Patterns**: Modern concurrency with structured tasks and actors
- **Protocol-Oriented Design**: Composition over inheritance, testable abstractions
- **Type Safety**: Strict optional handling, no force unwrapping, proper error types
- **MVVM Architecture**: Clear separation of concerns with reactive data flow
- **Testing Standards**: XCTest with async support, 80% minimum coverage
- **Documentation Requirements**: Swift documentation comments for all public APIs

---

_This guide is a living document. Update it as new patterns emerge and tools evolve._
_Focus on safety over convenience, clarity over cleverness._
_Last updated: August 2025_
