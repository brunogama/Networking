/// Byte counts reported by a native file transfer task.
package struct HTTPFileTransferProgress: Sendable, Hashable {
  package let transferredBytes: Int64
  package let totalBytes: Int64?

  package init(transferredBytes: Int64, totalBytes: Int64?) {
    self.transferredBytes = transferredBytes
    self.totalBytes = totalBytes
  }
}
