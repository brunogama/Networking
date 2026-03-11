# Phase 0 Research: Audit URLSession and Apple APIs for Async/Await Modernization

**Phase**: 00-audit-urlsession-async-await-modernization
**Research Date**: 2026-02-14
**Status**: Complete

---

## Executive Summary

This research identifies modernization opportunities for URLSession and Apple APIs in the Networking framework. The codebase is **already highly modernized** with Swift 6 async/await patterns, but contains **3 critical areas** requiring attention:

1. **URLSession delegate-based patterns** (FileTransferOperations, SecurityConfiguration)
2. **Legacy DispatchQueue usage** (CacheStorageProviders)
3. **Completion handler patterns** (if any remain in testing utilities)

**Key Finding**: The core `NetworkClient` already uses modern async/await APIs (`session.data(for:)`), so the audit will focus on **delegate patterns** and **background transfer operations** that cannot use the async API directly.

---

## 1. Current State Analysis

### 1.1 Already Modernized (✅)

**NetworkClient** (`Sources/Networking/NetworkClient.swift`):
```swift
// ✅ ALREADY MODERN: Uses async URLSession API
private func performRequest(_ request: HTTPRequest) async throws -> HTTPResponse {
  let urlRequest = try buildURLRequest(from: request)
  let (data, response) = try await session.data(for: urlRequest)
  // Process response...
}
```

**WebSocketClient** (`Sources/Networking/WebSocketClient.swift`):
```swift
// ✅ ALREADY MODERN: Actor-based with async/await
public actor WebSocketClient {
  public func connect(to url: URL) throws -> AsyncThrowingStream<WebSocketMessage, Error>
  public func send(_ message: WebSocketMessage) async throws
}
```

### 1.2 Requires Modernization (⚠️)

#### A. URLSession Delegate Patterns

**FileTransferOperations** (`Sources/Networking/FileTransferOperations.swift`):
- **Issue**: Uses `URLSessionDownloadDelegate` for background transfers
- **Pattern**: Delegate callbacks instead of async/await
- **Complexity**: HIGH (background transfers require delegates, but bridging can be improved)

```swift
// ⚠️ LEGACY PATTERN: Delegate-based callbacks
private final class BackgroundTransferDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
  func urlSession(_ session: URLSession,
                  downloadTask: URLSessionDownloadTask,
                  didFinishDownloadingTo location: URL) {
    // Callback-based completion
  }

  func urlSession(_ session: URLSession,
                  downloadTask: URLSessionDownloadTask,
                  didWriteData bytesWritten: Int64,
                  totalBytesWritten: Int64,
                  totalBytesExpectedToWrite: Int64) {
    // Progress callback
  }
}
```

**SecurityConfiguration** (`Sources/Networking/SecurityConfiguration.swift`):
- **Issue**: Uses `URLSessionDelegate` for certificate pinning
- **Pattern**: Completion handler for auth challenges
- **Complexity**: MEDIUM (auth challenges require callbacks, but can use continuations)

```swift
// ⚠️ LEGACY PATTERN: Completion handler for auth challenge
public final class SSLPinningValidator: NSObject, URLSessionDelegate {
  public func urlSession(_ session: URLSession,
                         didReceive challenge: URLAuthenticationChallenge,
                         completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    // Completion-based validation
  }
}
```

#### B. DispatchQueue Usage

**CacheStorageProviders** (`Sources/Networking/CacheStorageProviders.swift`):
- **Issue**: Uses `DispatchQueue` for thread safety
- **Pattern**: GCD-based synchronization
- **Complexity**: MEDIUM (can be replaced with actor isolation)

```swift
// ⚠️ LEGACY PATTERN: DispatchQueue for thread safety
private let queue = DispatchQueue(label: "AdvancedMemoryCacheStorage", qos: .utility)
```

---

## 2. Modernization Patterns & Best Practices

### 2.1 URLSession Async/Await API (iOS 15+)

Apple provides **four primary async methods** for URLSession:

#### Method 1: `data(for:)`
**Use Case**: Standard HTTP requests (GET, POST, PUT, DELETE)
```swift
// Modern async API
let (data, response) = try await session.data(for: urlRequest)
```

**Already Used In**:
- `NetworkClient.performRequest(_:)` ✅

#### Method 2: `data(from:)`
**Use Case**: Simple GET requests with URL
```swift
let (data, response) = try await session.data(from: url)
```

#### Method 3: `upload(for:from:)`
**Use Case**: Upload with request body
```swift
let (data, response) = try await session.upload(for: urlRequest, from: bodyData)
```

#### Method 4: `bytes(for:)`
**Use Case**: Streaming response bodies
```swift
let (bytes, response) = try await session.bytes(for: urlRequest)
for try await byte in bytes {
  // Process incrementally
}
```

**Recommendation**: Consider using `bytes(for:)` for large file downloads with progress tracking (replaces delegate-based progress callbacks).

### 2.2 URLSessionDelegate → AsyncStream Bridging

**Pattern**: Bridge delegate callbacks to AsyncStream for actor-safe async iteration.

**Example: Background Download Progress**
```swift
// Modern async pattern using AsyncStream
func downloadFile(from url: URL) -> AsyncThrowingStream<DownloadProgress, Error> {
  AsyncThrowingStream { continuation in
    let delegate = DownloadDelegate(continuation: continuation)
    let task = session.downloadTask(with: url)
    delegate.register(task: task)
    task.resume()
  }
}

// Delegate bridges to continuation
actor DownloadDelegate: NSObject, URLSessionDownloadDelegate {
  private var continuation: AsyncThrowingStream<DownloadProgress, Error>.Continuation?

  func urlSession(_ session: URLSession,
                  downloadTask: URLSessionDownloadTask,
                  didWriteData bytesWritten: Int64,
                  totalBytesWritten: Int64,
                  totalBytesExpectedToWrite: Int64) {
    let progress = DownloadProgress(
      bytesDownloaded: totalBytesWritten,
      totalBytes: totalBytesExpectedToWrite
    )
    continuation?.yield(progress)
  }

  func urlSession(_ session: URLSession,
                  downloadTask: URLSessionDownloadTask,
                  didFinishDownloadingTo location: URL) {
    continuation?.finish()
  }
}
```

**Key Benefits**:
- Actor-safe (continuation operations are Sendable)
- Cancellation support (via AsyncStream)
- No `@unchecked Sendable` required

### 2.3 Completion Handler → Async Continuation

**Pattern**: Wrap completion-based APIs with `withCheckedThrowingContinuation`.

**Example: Auth Challenge Handling**
```swift
// Modern async wrapper
func validateCertificate(for challenge: URLAuthenticationChallenge) async throws -> URLCredential? {
  try await withCheckedThrowingContinuation { continuation in
    // Validate certificate (synchronous validation logic)
    let credential = performValidation(challenge)
    continuation.resume(returning: credential)
  }
}

// Use in delegate
func urlSession(_ session: URLSession,
                didReceive challenge: URLAuthenticationChallenge,
                completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
  Task {
    do {
      let credential = try await validateCertificate(for: challenge)
      completionHandler(.useCredential, credential)
    } catch {
      completionHandler(.cancelAuthenticationChallenge, nil)
    }
  }
}
```

**⚠️ Critical**: Ensure continuation resumes **exactly once** (CONC-06 requirement).

### 2.4 DispatchQueue → Actor Isolation

**Pattern**: Replace DispatchQueue-based thread safety with actor isolation.

**Example: Cache Storage**
```swift
// ⚠️ LEGACY: DispatchQueue for thread safety
class MemoryCacheStorage {
  private let queue = DispatchQueue(label: "cache")
  private var cache: [String: Data] = [:]

  func store(_ data: Data, for key: String) {
    queue.async {
      self.cache[key] = data
    }
  }
}

// ✅ MODERN: Actor isolation
actor MemoryCacheStorage {
  private var cache: [String: Data] = [:]

  func store(_ data: Data, for key: String) {
    cache[key] = data  // Actor-isolated, no queue needed
  }
}
```

**Key Benefits**:
- No manual queue management
- Compiler-enforced thread safety
- Better integration with async/await

---

## 3. Audit Strategy

### 3.1 Systematic Scan Approach

#### Step 1: Identify All URLSession Usages
```bash
# Find all URLSession references
rg "URLSession" --type swift -l Sources/

# Find delegate implementations
rg "URLSessionDelegate|URLSessionTaskDelegate|URLSessionDataDelegate|URLSessionDownloadDelegate" --type swift -l Sources/
```

**Expected Findings**:
- `NetworkClient.swift` (already modernized ✅)
- `FileTransferOperations.swift` (delegate-based, needs audit ⚠️)
- `WebSocketClient.swift` (already modernized ✅)
- `SecurityConfiguration.swift` (delegate-based, needs audit ⚠️)
- `Testing/MockURLProtocol.swift` (test utility, low priority)

#### Step 2: Identify Completion Handler Patterns
```bash
# Find completion handler parameters
rg "completion:" --type swift -B 2 -A 2 Sources/

# Find @escaping closures (potential callbacks)
rg "@escaping" --type swift -l Sources/
```

**Expected Findings**:
- Middleware protocols (already async ✅)
- Interceptor protocols (already async ✅)
- Delegates in FileTransferOperations and SecurityConfiguration (needs audit ⚠️)

#### Step 3: Identify DispatchQueue Usage
```bash
# Find DispatchQueue usage
rg "DispatchQueue|DispatchGroup|DispatchSemaphore" --type swift -l Sources/
```

**Expected Findings**:
- `CacheStorageProviders.swift` (DispatchQueue for thread safety ⚠️)
- Test utilities (low priority)

#### Step 4: Identify Deprecated Apple APIs
```bash
# Find deprecated URLSession methods (pre-async)
rg "dataTask\(with:|downloadTask\(with:|uploadTask\(with:" --type swift -B 2 -A 2 Sources/
```

**Expected Findings**:
- Background transfer tasks in `FileTransferOperations.swift` (delegates required for background mode ⚠️)

### 3.2 Categorization Matrix

| File | Pattern | Complexity | Priority | Can Modernize? |
|------|---------|------------|----------|----------------|
| `NetworkClient.swift` | `session.data(for:)` | N/A | N/A | Already modern ✅ |
| `WebSocketClient.swift` | AsyncStream | N/A | N/A | Already modern ✅ |
| `FileTransferOperations.swift` | URLSessionDownloadDelegate | HIGH | High | Partial (AsyncStream bridge) |
| `SecurityConfiguration.swift` | URLSessionDelegate (auth) | MEDIUM | High | Yes (continuation wrapper) |
| `CacheStorageProviders.swift` | DispatchQueue | MEDIUM | Medium | Yes (actor isolation) |
| `Testing/MockURLProtocol.swift` | Test utility | LOW | Low | Not critical |

### 3.3 Complexity Estimates

**Complexity Factors**:
1. **Low**: Simple completion → async conversion (1-2 hours)
2. **Medium**: Delegate → AsyncStream bridging (3-5 hours)
3. **High**: Background transfers with state persistence (8-12 hours)

**Estimated Refactoring Effort**:
- `SecurityConfiguration.swift`: 3-4 hours (Medium)
- `CacheStorageProviders.swift`: 2-3 hours (Medium)
- `FileTransferOperations.swift`: 10-15 hours (High, includes testing)

**Total Estimate**: 15-22 hours

---

## 4. Background Transfer Constraints

### 4.1 When Delegates Are Required

**Apple Documentation** (WWDC21 - Use async/await with URLSession):
> "Background URL sessions still require a delegate. The async methods are not available for background sessions because they require the app to be running to resume after suspension."

**Implication**: `FileTransferOperations.swift` **must** use delegates for background transfers, but can modernize the bridging to actors/AsyncStream.

### 4.2 Recommended Pattern for Background Transfers

```swift
actor FileTransferOperations {
  // Modern async interface
  func downloadFile(from url: URL) -> AsyncThrowingStream<DownloadProgress, Error> {
    AsyncThrowingStream { continuation in
      let delegate = BackgroundDelegate(continuation: continuation)
      let task = backgroundSession.downloadTask(with: url)
      // Register delegate and resume task
    }
  }

  // Internal delegate bridges to AsyncStream
  private actor BackgroundDelegate: NSObject, URLSessionDownloadDelegate {
    // Delegate methods yield to continuation
  }
}
```

**Key Points**:
- Delegates required for background mode
- Bridge delegates to AsyncStream for modern async interface
- Actor isolation for delegate state

---

## 5. Migration Risks & Mitigation

### 5.1 Known Risks

#### Risk 1: Continuation Misuse (CONC-06)
**Description**: Continuation must resume exactly once
**Mitigation**:
- Use `withCheckedThrowingContinuation` (runtime warnings)
- Add unit tests for all code paths
- Document resume guarantees in comments

#### Risk 2: Actor Reentrancy (CONC-09)
**Description**: Check-then-act patterns can break with actor suspension
**Mitigation**:
- Audit all actor methods for state checks before async calls
- Use local copies for validation: `let currentState = state`
- Add reentrancy tests (simulate suspension with `Task.yield()`)

#### Risk 3: Background Session Lifecycle
**Description**: Background sessions outlive app process
**Mitigation**:
- Keep delegate-based pattern for background mode
- Bridge to AsyncStream for progress/completion
- Document background session constraints

### 5.2 Testing Strategy

**Unit Tests**:
- Test continuation resumes exactly once (all paths)
- Test actor reentrancy scenarios
- Test cancellation propagation

**Integration Tests**:
- Test background download with app backgrounding
- Test progress callbacks during network delays
- Test auth challenge handling

**Property-Based Tests**:
- Test retry logic with random failures
- Test concurrent download operations

---

## 6. Apple's Migration Guidance

### 6.1 Official Resources

**WWDC21 - Use async/await with URLSession**:
- Video: https://developer.apple.com/videos/play/wwdc2021/10095/
- Sample Code: https://developer.apple.com/documentation/foundation/url_loading_system/fetching_website_data_into_memory

**Key Takeaways**:
1. Use `data(for:)` for standard requests
2. Use `bytes(for:)` for streaming/large downloads
3. Use `upload(for:from:)` for uploads
4. Delegates still required for background sessions
5. Bridge delegates to AsyncStream for async iteration

### 6.2 Swift Evolution Proposals

**SE-0296**: Async/await
**SE-0300**: Continuations for interfacing async tasks with synchronous code
**SE-0304**: Structured concurrency

**Relevance**: Foundation for all async/await migration patterns.

---

## 7. Recommended Audit Plan

### Phase 0.1: Scan & Inventory (1 hour)
1. Run all search commands (Step 3.1)
2. Create categorization matrix (spreadsheet or Markdown table)
3. Document each finding with:
   - File path
   - Line numbers
   - Current pattern (delegate/completion/DispatchQueue)
   - Recommended pattern (AsyncStream/actor/continuation)
   - Complexity estimate

### Phase 0.2: Prioritization (30 minutes)
1. Rank by:
   - Security impact (auth challenges = highest)
   - User-facing impact (progress tracking = high)
   - Code complexity (file size, dependencies)
2. Create ordered list of refactoring targets

### Phase 0.3: Proof of Concept (2 hours)
1. Choose one **medium complexity** candidate (e.g., `SecurityConfiguration.swift`)
2. Implement async wrapper for auth challenge
3. Write tests for continuation safety
4. Document pattern for team review

### Phase 0.4: Documentation (1 hour)
1. Create `.planning/phases/00-audit-urlsession-async-await-modernization/01-AUDIT-RESULTS.md`
2. Include:
   - Complete inventory table
   - Code snippets of legacy patterns
   - Recommended modernization approach per item
   - Estimated effort per item
   - Total effort estimate
3. Link to this research document

---

## 8. Tools & Techniques

### 8.1 Automated Detection

**SwiftLint Rules**:
- `legacy_random` (detects deprecated APIs, can be extended)
- Custom rule for `DispatchQueue` usage
- Custom rule for `@escaping` in new code

**Example Custom Rule** (`.swiftlint.yml`):
```yaml
custom_rules:
  no_dispatchqueue:
    name: "No DispatchQueue"
    regex: 'DispatchQueue\('
    message: "Use actor isolation instead of DispatchQueue"
    severity: warning

  no_completion_handlers:
    name: "No Completion Handlers"
    regex: 'completion:\s*@escaping'
    message: "Use async/await instead of completion handlers"
    severity: warning
```

### 8.2 Manual Review Checklist

For each URLSession usage:
- [ ] Is it using async API (`data(for:)`, `bytes(for:)`, etc.)? ✅
- [ ] Is it using delegates? If yes, why? (Background mode? Auth challenges?)
- [ ] Can delegates be bridged to AsyncStream?
- [ ] Are continuations used correctly (resume exactly once)?
- [ ] Is state managed by actors (not DispatchQueue)?

### 8.3 Testing Tools

**Concurrency Testing**:
- `Task.detached` for race condition testing
- `Task.yield()` for reentrancy testing
- SwiftCheck for property-based testing of async flows

**Example Reentrancy Test**:
```swift
@Test
func actor_downloadFile_handlesReentrancy() async throws {
  let operations = FileTransferOperations(httpClient: mockClient)

  // Start first download
  let stream1 = operations.downloadFile(from: url1)

  // Simulate suspension with Task.yield()
  await Task.yield()

  // Start second download (tests reentrancy)
  let stream2 = operations.downloadFile(from: url2)

  // Both should complete successfully
  // ...
}
```

---

## 9. Success Criteria for Phase 0

### 9.1 Deliverables

1. **Complete Inventory** (`.planning/phases/00-audit-urlsession-async-await-modernization/01-AUDIT-RESULTS.md`):
   - All URLSession usages categorized
   - All completion handlers identified
   - All DispatchQueue usages documented
   - Complexity estimates for each item

2. **Prioritized Refactoring List**:
   - Ordered by security/UX impact and complexity
   - Estimated effort per item
   - Recommended patterns documented

3. **Proof of Concept**:
   - One medium-complexity modernization implemented
   - Tests demonstrate continuation safety
   - Pattern documented for team use

4. **No Blocking Issues for Phase 1**:
   - All async/await compliance issues identified
   - No surprises during Phase 2 (DX) implementation

### 9.2 Quality Gates

- [ ] All search commands executed and results documented
- [ ] Every URLSession usage has a categorization
- [ ] Complexity estimates validated by senior engineer
- [ ] Proof of concept passes all tests
- [ ] Zero `@unchecked Sendable` added without justification

---

## 10. References & Resources

### 10.1 Apple Documentation
- [URLSession Async/Await](https://developer.apple.com/documentation/foundation/urlsession)
- [WWDC21: Use async/await with URLSession](https://developer.apple.com/videos/play/wwdc2021/10095/)
- [Swift Concurrency Documentation](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

### 10.2 Community Resources
- [Modern Networking in iOS with URLSession and async/await](https://dev.to/markkazakov/modern-networking-in-ios-with-urlsession-and-asyncawait-a-practical-guide-4o0o)
- [URLSession Async Await: API Requests & JSON Decoding](https://www.avanderlee.com/concurrency/urlsession-async-await-network-requests-in-swift/)
- [Swift 6 Concurrency Migration Guide](https://anubhavgiri01.medium.com/concurrency-in-ios-part-6-a-practical-migration-guide-from-gcd-callbacks-to-swift-concurrency-006d1b3055c8)

### 10.3 Internal Documentation
- `/Users/bruno/Developer/Inbox/ModernNetworking/CLAUDE.md` (project guidelines)
- `/Users/bruno/Developer/Inbox/ModernNetworking/Sources/Networking/CLAUDE.md` (core library patterns)
- `.planning/phases/01-swift-6-concurrency-compliance/` (Phase 1 context)

---

## 11. Next Steps (for PLAN.md)

After this research is approved, Phase 0 planning should:

1. **Define audit scope**: Which files will be audited in detail
2. **Create audit checklist**: Specific patterns to search for
3. **Assign complexity scores**: Use this research as baseline
4. **Schedule proof of concept**: Pick one file to modernize
5. **Define deliverable format**: Template for audit results

**Expected PLAN.md sections**:
- Scope (files to audit)
- Search patterns (ripgrep commands)
- Categorization criteria (low/medium/high complexity)
- Deliverable template (audit results table format)
- Success criteria (all URLSession usages documented)

---

**Research Status**: ✅ Complete
**Ready for Planning**: Yes
**Blocking Issues**: None
**Recommended Next Phase**: Create detailed audit plan (PLAN.md)
