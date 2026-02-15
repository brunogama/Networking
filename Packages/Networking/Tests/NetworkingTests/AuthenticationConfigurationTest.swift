import XCTest
@testable import Networking
import Foundation

final class AuthenticationConfigurationTest: XCTestCase {
  func testAuthenticationConfigurationCreation() throws {
    // Test that we can create authentication configuration without crashes
    let client = try NetworkClient {
      BaseURL(URL(string: "https://api.example.com")!)
      Authentication {
        BearerToken("test-token")
        RefreshStrategy.none()
      }
    }

    XCTAssertNotNil(client)
  }

  func testRetryConfigurationCreation() throws {
    // Test that we can create retry configuration without crashes
    let client = try NetworkClient {
      BaseURL(URL(string: "https://api.example.com")!)
      Retry {
        MaxAttempts(3)
        BackoffStrategy.exponential()
        InitialDelay(1.0)
      }
    }

    XCTAssertNotNil(client)
  }

  func testCachingConfigurationCreation() throws {
    // Test that we can create caching configuration without crashes
    let client = try NetworkClient {
      BaseURL(URL(string: "https://api.example.com")!)
      Caching {
        Policy.standard()
        Storage.memory(size: .MB(50))
        Duration.ttl(300)
      }
    }

    XCTAssertNotNil(client)
  }
}
