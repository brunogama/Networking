/// Represents the different phases of a network transfer.
public enum TransferPhase: Sendable, Hashable {
  case preparing
  case uploading
  case downloading
  case completed
  case failed
}
