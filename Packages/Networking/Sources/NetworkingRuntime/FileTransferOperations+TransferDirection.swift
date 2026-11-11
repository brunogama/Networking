extension FileTransferOperations {
  enum TransferDirection: Sendable {
    case upload
    case download

    var activePhase: TransferPhase {
      switch self {
      case .upload:
        return .uploading
      case .download:
        return .downloading
      }
    }
  }
}
