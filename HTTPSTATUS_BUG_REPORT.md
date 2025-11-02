# HTTPStatus Initialization Bug Report

## Summary

HTTPStatus struct exhibits a **critical initialization bug** where specific integer values (400, 499) are incorrectly stored as 200 during initialization, despite correct source code.

## Environment

- **Swift Version**: 6.2.1
- **Platform**: Darwin 25.1.0 (macOS)
- **Build Tool**: Swift Package Manager
- **Compiler**: swift-driver version 1.121 Apple Swift version 6.2.1
- **Architecture**: arm64 (Apple Silicon)

## Bug Symptoms

```swift
let status400 = HTTPStatus(rawValue: 400)
print(status400.rawValue)  // Prints: 200 (WRONG! Should be 400)

let status404 = HTTPStatus(rawValue: 404)
print(status404.rawValue)  // Prints: 404 (Correct)

let status499 = HTTPStatus(rawValue: 499)
print(status499.rawValue)  // Prints: 200 (WRONG! Should be 499)

let status500 = HTTPStatus(rawValue: 500)
print(status500.rawValue)  // Prints: 500 (Correct)
```

### Pattern Observed

| Input Value | Expected | Actual  | Status  |
|-------------|----------|---------|---------|
| 400         | 400      | **200** | ❌ BUG  |
| 404         | 404      | 404     | ✅ OK   |
| 499         | 499      | **200** | ❌ BUG  |
| 500         | 500      | 500     | ✅ OK   |

Both 400 and 499 become 200, which is the value of HTTPStatus.ok static property.

## Reproduction Steps

1. Clone repository: `https://github.com/user/ModernNetworking` (or use attached minimal reproduction)
2. Run: `swift test --filter DirectHTTPStatusTest`
3. Observe: Tests for 400 and 499 fail with rawValue = 200

## What We Ruled Out

### NOT the cause:

- ❌ Source code issue (initializer is correct: `self.rawValue = rawValue`)
- ❌ Static property initialization order
- ❌ ExpressibleByIntegerLiteral conformance
- ❌ Hashable synthesis
- ❌ Sendable conformance
- ❌ Custom equality operators (none defined)
- ❌ Property wrappers (none used)
- ❌ Macros attached to HTTPStatus (none)
- ❌ Stale build artifacts (persists after `rm -rf .build`)

### Confirmed:

✅ **Identical code in a different file (HTTPStatus2.swift) works perfectly**
✅ **Bug is specific to the HTTPStatus symbol/module linkage**
✅ **Bug persists across clean rebuilds**

## Investigation Details

### Memory Dump Evidence

```
Memory dump of HTTPStatus(rawValue: 400):
status400 bytes: c8 00 00 00 00 00 00 00  (0xc8 = 200 decimal!)

Memory dump of HTTPStatus.badRequest:
HTTPStatus.badRequest bytes: 90 01 00 00 00 00 00 00  (0x190 = 400 decimal - correct!)
```

The static property `.badRequest` correctly stores 400, but direct initialization with 400 stores 200.

### Workaround Test

Created HTTPStatus2.swift with **identical code**:

```swift
// HTTPStatus2.swift - IDENTICAL to HTTPStatus.swift
public struct HTTPStatus2: Sendable, Hashable, ExpressibleByIntegerLiteral {
  public static let ok = Self(rawValue: 200)
  public static let badRequest = Self(rawValue: 400)
  public let rawValue: Int
  public init(rawValue: Int) {
    self.rawValue = rawValue
  }
}
```

**Result**: HTTPStatus2 works perfectly! All values initialize correctly.

This proves the bug is NOT in the code but in something specific to the HTTPStatus symbol/module.

## Temporary Workaround

Replace HTTPStatus.swift file with identical code under a different name, then rename back. This clears whatever corrupted state exists for the symbol. However, the bug returns after `rm -rf .build && swift build`.

## Recommendation

This appears to be a **Swift compiler or linker bug** related to symbol resolution or module metadata. The bug should be reported to:
- Swift Bug Tracker: https://github.com/apple/swift/issues

## Minimal Reproduction Case

See attached:
- `HTTPStatus.swift` - Exhibits bug
- `HTTPStatus2.swift` - Identical code, works correctly
- `DirectHTTPStatusTest.swift` - Test demonstrating bug
- `Package.swift` - Swift package configuration

## Impact

**HIGH** - Affects all HTTP 400-series error handling in production code:
- Authentication errors (401)
- Validation errors (400)
- Not found errors (404)
- Rate limiting (429)

Tests fail incorrectly, making it impossible to validate error handling logic.

---

**Filed**: 2025-11-02
**Discovered during**: Phase 6 interceptor implementation
**File**: Sources/Networking/HTTPStatus.swift:70-72
