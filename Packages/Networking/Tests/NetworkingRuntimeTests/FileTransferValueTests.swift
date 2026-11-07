import Foundation
import NetworkingCore
@testable import NetworkingRuntime
import Testing

@Suite("File transfer values")
struct FileTransferValueTests {
  @Test(arguments: ["test.jpg", "测试文件.jpg", String(repeating: "a", count: 255) + ".jpg"])
  func metadataPreservesFilename(name: String) {
    let metadata = FileMetadata(name: FileName(name), size: 1024, mimeType: "image/jpeg")
    #expect(metadata.name.rawValue == name)
    #expect(metadata.fileExtension == "jpg")
    #expect(metadata.size == 1024)
  }

  @Test func secureChecksumsMatchKnownVectors() {
    let payload = HTTPBody(Data("abc".utf8))
    let expectedSHA256 = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    let expectedSHA512 =
      "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a"
      + "2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"
    #expect(hexadecimal(ChecksumAlgorithm.sha256.hash(payload)) == expectedSHA256)
    #expect(hexadecimal(ChecksumAlgorithm.sha512.hash(payload)) == expectedSHA512)
    #expect(ChecksumAlgorithm.allCases.count == 2)
  }

  private func hexadecimal(_ body: HTTPBody) -> String {
    body.rawValue.map { String(format: "%02x", $0) }.joined()
  }
}
