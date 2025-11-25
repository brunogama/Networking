import Foundation
import Networking
import Observation

@Observable
@MainActor
final class DogViewModel {
  // MARK: - State

  var breeds: [String] = []
  var selectedBreed: String?
  var currentImageURL: String?
  var isLoading = false
  var isLoadingImage = false
  var error: String?
  var httpieLog: String = ""

  // MARK: - Dependencies

  private let api: DogAPIImplementation
  private let logCapture: LogCaptureMiddleware

  // MARK: - Initialization

  init() {
    let logCapture = LogCaptureMiddleware()
    self.logCapture = logCapture

    let client = NetworkClient(
      requestMiddlewares: [logCapture],
      responseMiddlewares: [logCapture]
    )

    self.api = DogAPIImplementation(client: client)
  }

  // MARK: - Actions

  func loadBreeds() async {
    isLoading = true
    error = nil
    logCapture.clear()

    do {
      let response = try await api.listAllBreeds()
      breeds = response.message.keys.sorted()
      httpieLog = logCapture.log
    } catch {
      self.error = error.localizedDescription
      httpieLog = logCapture.log
    }

    isLoading = false
  }

  func loadRandomImage(for breed: String) async {
    isLoadingImage = true
    error = nil
    logCapture.clear()

    do {
      let response = try await api.getRandomImage(breed: breed)
      currentImageURL = response.message
      httpieLog = logCapture.log
    } catch {
      self.error = error.localizedDescription
      currentImageURL = nil
      httpieLog = logCapture.log
    }

    isLoadingImage = false
  }
}
