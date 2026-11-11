import Foundation

/// A file downloaded to URLSession's temporary storage with its HTTP response.
package struct HTTPFileDownload: Sendable {
  package let temporaryFileURL: URL
  package let response: HTTPResponse

  package init(temporaryFileURL: URL, response: HTTPResponse) {
    self.temporaryFileURL = temporaryFileURL
    self.response = response
  }
}
