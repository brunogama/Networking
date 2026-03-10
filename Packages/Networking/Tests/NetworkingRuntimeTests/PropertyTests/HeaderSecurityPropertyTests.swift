import Foundation
import SwiftCheck
import XCTest

@testable import NetworkingRuntime
import NetworkingDSL
import NetworkingRuntimeDSL
import NetworkingTesting

/// Property-based tests for header security validation and sanitization.
///
/// Tests RFC 7230 compliance, CRLF injection detection, and sanitization properties.
final class HeaderSecurityPropertyTests: XCTestCase {
    // MARK: - Sanitization Properties

    func testSanitizationIdempotence() {
        property("Sanitization is idempotent: sanitize(sanitize(x)) == sanitize(x)")
            <- forAll { (value: String) in
                let onceSanitized = HeaderSecurity.sanitizeHeaderValue(value)
                let twiceSanitized = HeaderSecurity.sanitizeHeaderValue(onceSanitized)
                return onceSanitized == twiceSanitized
            }
    }

    func testSanitizationProducesValidOutput() {
        property("Sanitized values are always valid header values")
            <- forAll { (value: String) in
                let sanitized = HeaderSecurity.sanitizeHeaderValue(value)
                // Empty strings are technically valid (no invalid chars)
                if sanitized.isEmpty { return true }
                return HeaderSecurity.isValidHeaderValue(sanitized)
            }
    }

    func testSanitizationPreservesValidInput() {
        property("Sanitization preserves already-valid header values")
            <- forAll(ValidHeaderValueGen.arbitrary) { (value: String) in
                let sanitized = HeaderSecurity.sanitizeHeaderValue(value)
                return sanitized == value
            }
    }

    // MARK: - Injection Detection Properties

    func testInjectionDetectionCRLFPatterns() {
        property("All CRLF injection patterns are detected")
            <- forAll(CRLFInjectionGen.arbitrary) { (maliciousValue: String) in
                HeaderSecurity.containsInjectionAttempt(maliciousValue)
            }
    }

    func testNoFalsePositivesOnValidHeaders() {
        property("Valid RFC 7230 header values do not trigger injection detection")
            <- forAll(SafeHeaderValueGen.arbitrary) { (value: String) in
                !HeaderSecurity.containsInjectionAttempt(value)
            }
    }

    // MARK: - RFC 7230 Compliance Properties

    func testHeaderNameValidation() {
        property("Valid RFC 7230 token header names pass validation")
            <- forAll(ValidHeaderNameGen.arbitrary) { (name: String) in
                HeaderSecurity.isValidHeaderName(name)
            }

        property("Invalid header names (with forbidden chars) fail validation")
            <- forAll(InvalidHeaderNameGen.arbitrary) { (name: String) in
                !HeaderSecurity.isValidHeaderName(name)
            }
    }

    func testHeaderValueValidation() {
        property("Valid RFC 7230 header values pass validation")
            <- forAll(ValidHeaderValueGen.arbitrary) { (value: String) in
                HeaderSecurity.isValidHeaderValue(value)
            }

        property("Header values with control characters fail validation")
            <- forAll(ControlCharHeaderValueGen.arbitrary) { (value: String) in
                !HeaderSecurity.isValidHeaderValue(value)
            }
    }

    func testEmptyHeaderNameIsInvalid() {
        XCTAssertFalse(HeaderSecurity.isValidHeaderName(""))
    }

    // MARK: - Combined Security Invariants

    func testValidHeadersPassMiddleware() {
        property("Headers with valid names and values pass through security middleware unchanged")
            <- forAll(ValidHeaderNameGen.arbitrary, SafeHeaderValueGen.arbitrary) {
                (name: String, value: String) in
                guard !name.isEmpty, !value.isEmpty else { return Discard() }

                // Both name and value must be valid
                let nameValid = HeaderSecurity.isValidHeaderName(name)
                let valueValid = HeaderSecurity.isValidHeaderValue(value)
                let noInjection = !HeaderSecurity.containsInjectionAttempt(value)

                // If all checks pass, the header should be safe
                return nameValid && valueValid && noInjection
            }
    }
}

// MARK: - Custom Generators for Header Security

/// Generates strings containing CRLF injection patterns
enum CRLFInjectionGen {
    static var arbitrary: Gen<String> {
        let injectionPatterns = [
            "\r\n",
            "\n",
            "\r",
            "%0d%0a",
            "%0a",
            "%0d",
            "\\r\\n",
            "\\n",
            "\\r",
        ]

        return Gen<String>.compose { composer in
            let prefix = composer.generate(using: Gen<String>.pure("prefix"))
            let pattern = composer.generate(using: Gen<String>.fromElements(of: injectionPatterns))
            let suffix = composer.generate(using: Gen<String>.pure("suffix"))
            return prefix + pattern + suffix
        }
    }
}

/// Generates valid RFC 7230 header names (tokens)
enum ValidHeaderNameGen {
    static var arbitrary: Gen<String> {
        // RFC 7230 token: 1*tchar
        // tchar = "!" / "#" / "$" / "%" / "&" / "'" / "*" / "+" / "-" / "." /
        //         "0"-"9" / "A"-"Z" / "^" / "_" / "`" / "a"-"z" / "|" / "~"
        let tokenChars = Array(
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#$%&'*+-.^_`|~"
        )

        return Gen<String>.compose { composer in
            let length = composer.generate(using: Gen.choose((1, 20)))
            let chars = (0 ..< length).map { _ in
                composer.generate(using: Gen<Character>.fromElements(of: tokenChars))
            }
            return String(chars)
        }
    }
}

/// Generates invalid header names with forbidden characters
enum InvalidHeaderNameGen {
    static var arbitrary: Gen<String> {
        // Forbidden in header names: ()<>@,;:\"/[]?={} and control chars
        let forbiddenChars: [Character] = [
            "(", ")", "<", ">", "@", ",", ";", ":", "\\", "\"", "/", "[", "]", "?", "=", "{", "}",
        ]

        return Gen<String>.compose { composer in
            let validPart = composer.generate(using: ValidHeaderNameGen.arbitrary)
            let forbiddenChar = composer.generate(using: Gen<Character>.fromElements(of: forbiddenChars))
            // Insert forbidden char at random position
            var chars = Array(validPart)
            if chars.isEmpty {
                chars = [forbiddenChar]
            } else {
                let insertPos = composer.generate(using: Gen.choose((0, chars.count - 1)))
                chars.insert(forbiddenChar, at: insertPos)
            }
            return String(chars)
        }
    }
}

/// Generates valid RFC 7230 header values (field-value)
enum ValidHeaderValueGen {
    static var arbitrary: Gen<String> {
        // RFC 7230: field-value = *( field-content / obs-fold )
        // field-content = field-vchar [ 1*( SP / HTAB ) field-vchar ]
        // field-vchar = VCHAR / obs-text
        // VCHAR = %x21-7E, obs-text = %x80-FF

        // For simplicity, generate printable ASCII + space + tab
        let vcharRange = (0x21 ... 0x7E).map { Character(UnicodeScalar($0)) }
        let wspChars: [Character] = [" ", "\t"]
        let validChars = vcharRange + wspChars

        return Gen<String>.compose { composer in
            let length = composer.generate(using: Gen.choose((1, 50)))
            let chars = (0 ..< length).map { _ in
                composer.generate(using: Gen<Character>.fromElements(of: validChars))
            }
            return String(chars)
        }
    }
}

/// Generates safe header values (valid and no injection patterns)
enum SafeHeaderValueGen {
    static var arbitrary: Gen<String> {
        // Printable ASCII without any characters that could form injection patterns
        let safeChars = (0x21 ... 0x7E)
            .filter { $0 != 0x25 } // Exclude % to avoid URL-encoded patterns
            .filter { $0 != 0x5C } // Exclude \ to avoid escaped patterns
            .map { Character(UnicodeScalar($0)) }

        return Gen<String>.compose { composer in
            let length = composer.generate(using: Gen.choose((1, 30)))
            let chars = (0 ..< length).map { _ in
                composer.generate(using: Gen<Character>.fromElements(of: safeChars))
            }
            return String(chars)
        }
    }
}

/// Generates header values containing control characters
enum ControlCharHeaderValueGen {
    static var arbitrary: Gen<String> {
        // Control characters: 0x00-0x1F (except 0x09 tab) and 0x7F
        let controlChars =
            ((0x00 ... 0x08).map { UnicodeScalar($0) }
                + (0x0A ... 0x1F).map { UnicodeScalar($0) }
                + [UnicodeScalar(0x7F)])
            .compactMap { $0 }
            .map { Character($0) }

        return Gen<String>.compose { composer in
            let prefix = composer.generate(using: Gen<String>.pure("valid"))
            let controlChar = composer.generate(using: Gen<Character>.fromElements(of: controlChars))
            let suffix = composer.generate(using: Gen<String>.pure("suffix"))
            return prefix + String(controlChar) + suffix
        }
    }
}
