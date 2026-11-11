import NetworkingCore

/// Configuration for background transfer operations.
public struct BackgroundTransferConfiguration: Sendable {

  public let enableBackgroundTransfer: BackgroundTransferFlag

  public let backgroundSessionIdentifier: BackgroundSessionIdentifier

  public let allowsCellularAccess: SessionAllowsCellularAccess

  public let allowsExpensiveNetworkAccess: SessionAllowsExpensiveNetworkAccess

  public let timeoutIntervalForRequest: SessionRequestTimeout

  public let timeoutIntervalForResource: SessionRequestTimeout

  public init(
    enableBackgroundTransfer: BackgroundTransferFlag = false,
    backgroundSessionIdentifier: BackgroundSessionIdentifier = "Networking.BackgroundTransfer",
    allowsCellularAccess: SessionAllowsCellularAccess = true,
    allowsExpensiveNetworkAccess: SessionAllowsExpensiveNetworkAccess = false,
    timeoutIntervalForRequest: SessionRequestTimeout = 60.0,
    timeoutIntervalForResource: SessionRequestTimeout = 3600.0
  ) {
    self.enableBackgroundTransfer = enableBackgroundTransfer
    self.backgroundSessionIdentifier = backgroundSessionIdentifier
    self.allowsCellularAccess = allowsCellularAccess
    self.allowsExpensiveNetworkAccess = allowsExpensiveNetworkAccess
    self.timeoutIntervalForRequest = timeoutIntervalForRequest
    self.timeoutIntervalForResource = timeoutIntervalForResource
  }

  public static let `default` = Self()
}
