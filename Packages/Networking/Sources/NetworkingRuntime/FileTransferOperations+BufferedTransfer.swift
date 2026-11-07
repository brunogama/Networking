import NetworkingCore

extension FileTransferOperations {
  struct BufferedTransfer: Sendable {
    let response: HTTPResponse
    let result: FileTransferResult
  }
}
