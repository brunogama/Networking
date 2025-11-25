# Proposal: Achieve 95% Unit Test Coverage

## Why

The ModernNetworking framework currently has approximately 93% file coverage but several critical modules lack dedicated unit tests:

1. **FileTransferOperations.swift** (893 lines) - Complex actor-based file transfer system with zero test coverage
2. **KeychainService.swift** (270+ lines) - Security-sensitive credential storage completely untested
3. **ErrorRecoveryStrategies.swift** (386 lines) - Core retry/recovery logic with no dedicated tests
4. **CircuitBreakerMiddleware.swift** (295 lines) - Fault tolerance pattern implementation untested
5. **SecurityConfiguration.swift** (200+ lines) - TLS validation and certificate pinning not tested
6. **RequestTimingMiddleware.swift** (220+ lines) - Request timing measurement untested
7. **TransferControls.swift** (200+ lines) - Transfer control operations untested

These gaps represent significant risk areas:
- **Security**: KeychainService handles sensitive credentials without test validation
- **Reliability**: CircuitBreaker and ErrorRecovery strategies are fault tolerance mechanisms that must work correctly
- **Performance**: RequestTiming metrics collection affects observability
- **Core functionality**: FileTransfer operations are complex actor-based systems prone to concurrency bugs

The project conventions specify:
- Test pyramid: 80% unit, 15% integration, 5% E2E
- Minimum coverage: 90% domain logic, 70% application layer, 50% infrastructure
- All tests must pass, warnings are errors

Reaching 95% coverage ensures production quality for this AAA-rated framework.

## What Changes

Add comprehensive unit tests for the 7 untested source files, totaling approximately 160-200 new tests across:

### Test Files to Create

1. **FileTransferOperationsTests.swift** (~50 tests)
   - FileTransferResult initialization and properties
   - FileMetadata validation and computed properties
   - FileTransferConfiguration validation
   - Actor isolation and concurrency tests

2. **KeychainServiceTests.swift** (~25 tests)
   - Store/retrieve string values
   - Store/retrieve data
   - Delete operations
   - Configuration options (accessibility, sync)
   - Error handling
   - Thread safety (actor isolation)

3. **ErrorRecoveryStrategiesTests.swift** (~40 tests)
   - AutomaticRetryStrategy exponential backoff
   - Jitter calculation
   - Maximum attempt limits
   - AuthenticationRefreshStrategy token refresh
   - Recovery strategy protocol conformance
   - canRecover predicates

4. **CircuitBreakerMiddlewareTests.swift** (~30 tests)
   - State transitions (closed -> open -> half-open -> closed)
   - Failure threshold triggering
   - Recovery timeout behavior
   - Success threshold in half-open state
   - Rolling window failure counting
   - shouldCountFailure predicate

5. **SecurityConfigurationTests.swift** (~20 tests)
   - CertificatePinningConfiguration validation
   - PublicKeyPinningConfiguration validation
   - TLSConfiguration defaults and customization
   - ValidationFailureAction behaviors

6. **RequestTimingMiddlewareTests.swift** (~20 tests)
   - RequestMetrics creation and properties
   - Timing accuracy
   - Metadata generation
   - Configuration options
   - Concurrent timing tracking

7. **TransferControlsTests.swift** (~20 tests)
   - TransferState transitions
   - ControlAction validation
   - TransferControlError messages
   - Bandwidth throttling
   - State predicates (isActive, canPause, canResume, canCancel)

## Impact

### Affected Code

- `Tests/NetworkingTests/` - Add 7 new test files
- No changes to production code (tests only)

### Dependencies

- XCTest framework (already available)
- MockNetworkClient (existing test utility)
- MockURLProtocol (existing test utility)

### Testing Requirements

**Before:**
- ~45 test files
- ~250 tests
- 93% file coverage

**After:**
- ~52 test files
- ~450 tests (160-200 new)
- 95%+ file coverage

### Performance Implications

- Test execution time: +30-60 seconds
- CI pipeline: Minimal impact (parallel test execution)
- No runtime impact (tests only)

## Breaking Changes

**None** - This change only adds test files.

## Design Decisions

### Why Not Mock Keychain?

Keychain tests will use a real Keychain with test-specific service identifiers and cleanup in tearDown(). This ensures:
- Real Security framework behavior tested
- No false positives from mock divergence
- Platform-specific behaviors caught

### Why Actor Isolation Tests?

CircuitBreakerMiddleware and FileTransferOperations use actors. Tests must verify:
- No data races under concurrent access
- Proper state isolation
- Swift 6 strict concurrency compliance

### Why Property-Based Tests?

For ErrorRecoveryStrategies (exponential backoff, jitter), property-based tests ensure:
- Mathematical properties hold (delay increases exponentially)
- Jitter stays within bounds
- Edge cases covered automatically

## Open Questions

1. **Should we target 95% or 98% coverage?**
   - **Recommendation**: 95% is sufficient for production quality. 98% would require testing trivial code paths with diminishing returns.

2. **Should we add integration tests for Keychain + NetworkClient?**
   - **Recommendation**: Yes, add 5-10 integration tests verifying credential storage flows.

3. **Should CircuitBreaker tests use real delays?**
   - **Recommendation**: No, use protocol-based time injection for fast, deterministic tests.

4. **Priority order for implementation?**
   - **Recommendation**: Security-critical first (KeychainService, CircuitBreaker, ErrorRecovery), then observability (Timing), then features (FileTransfer, TransferControls).
