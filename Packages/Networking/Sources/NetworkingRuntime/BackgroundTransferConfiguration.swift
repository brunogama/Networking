import NetworkingCore

/// Configuration for background transfer operations.
public struct BackgroundTransferConfiguration: Sendable {
  /// Whether to allow transfers when app is backgrounded.
  public let enableBackgroundTransfer: BackgroundTransferFlag

  /// Background session identifier.
  public let backgroundSessionIdentifier: BackgroundSessionIdentifier

  /// Whether to allow cellular data for background transfers.
  public let allowsCellularAccess: SessionAllowsCellularAccess

  /// Whether to allow expensive network access.
  public let allowsExpensiveNetworkAccess: SessionAllowsExpensiveNetworkAccess

  /// Timeout interval for background transfers.
  public let timeoutIntervalForRequest: SessionRequestTimeout

  /// Resource timeout for background transfers.
  public let timeoutIntervalForResource: SessionRequestTimeout

  /// Configures native background sessions and their network access policy.
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

  /// Disables background sessions until explicitly enabled.
  public static let `default` = Self()
}
