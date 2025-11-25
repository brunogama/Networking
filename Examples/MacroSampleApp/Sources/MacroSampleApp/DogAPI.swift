import Foundation
import Networking

// MARK: - Dog CEO API Protocol (Macro-generated)

/// Dog CEO API using the @API macro for automatic client generation.
///
/// This demonstrates:
/// - Simple GET requests with no parameters
/// - Path parameter auto-detection from {breed} placeholder
/// - The generated DogAPIImplementation struct
@API(baseURL: "https://dog.ceo/api")
protocol DogAPI {
  /// List all breeds
  @GET("/breeds/list/all")
  func listAllBreeds() async throws -> BreedsResponse

  /// Get a random image for a specific breed
  /// - `breed` is auto-detected as path param from `{breed}` placeholder
  @GET("/breed/{breed}/images/random")
  func getRandomImage(breed: String) async throws -> ImageResponse

  /// Get multiple random images for a breed
  @GET("/breed/{breed}/images/random/{count}")
  func getRandomImages(breed: String, count: Int) async throws -> ImagesResponse

  /// Get a random image from any breed
  @GET("/breeds/image/random")
  func getRandomImageAny() async throws -> ImageResponse
}

// MARK: - Response Models

struct BreedsResponse: Codable, Sendable {
  let message: [String: [String]]
  let status: String
}

struct ImageResponse: Codable, Sendable {
  let message: String
  let status: String
}

struct ImagesResponse: Codable, Sendable {
  let message: [String]
  let status: String
}
