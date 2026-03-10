// swiftlint:disable file_length
import Foundation

/// Provides actionable error information and recovery suggestions for HTTP errors
public struct ActionableErrorInfo: Sendable {
  // MARK: - Error Information Structure

  /// Represents a specific action that can be taken to resolve an error
  public struct RecoveryAction: Sendable {
    public enum ActionType: Sendable, CaseIterable {
      case immediate  // Can be executed right away
      case delayed  // Requires waiting before execution
      case userInteraction  // Requires user input or decision
      case systemConfiguration  // Requires system-level changes
      case contactSupport  // Requires external assistance
    }

    public let title: RecoveryActionTitle
    public let description: RecoveryActionDescription
    public let type: ActionType
    public let estimatedDuration: RequestTimeout?
    public let prerequisite: RecoveryActionPrerequisite?
    public let canAutoExecute: RecoveryActionAutomationFlag

    public init(
      title: RecoveryActionTitle,
      description: RecoveryActionDescription,
      type: ActionType,
      estimatedDuration: RequestTimeout? = nil,
      prerequisite: RecoveryActionPrerequisite? = nil,
      canAutoExecute: RecoveryActionAutomationFlag = RecoveryActionAutomationFlag(rawValue: false)
    ) {
      self.title = title
      self.description = description
      self.type = type
      self.estimatedDuration = estimatedDuration
      self.prerequisite = prerequisite
      self.canAutoExecute = canAutoExecute
    }

    package init(
      title: String,
      description: String,
      type: ActionType,
      estimatedDuration: TimeInterval? = nil,
      prerequisite: String? = nil,
      canAutoExecute: Bool = false
    ) {
      self.init(
        title: RecoveryActionTitle(rawValue: title),
        description: RecoveryActionDescription(rawValue: description),
        type: type,
        estimatedDuration: estimatedDuration.map(RequestTimeout.init(rawValue:)),
        prerequisite: prerequisite.map(RecoveryActionPrerequisite.init(rawValue:)),
        canAutoExecute: RecoveryActionAutomationFlag(rawValue: canAutoExecute)
      )
    }
  }

  /// Contextual information about when and why the error occurred
  public struct ErrorContext: Sendable {
    public let timestamp: Date
    public let attemptNumber: ActionAttemptCount
    public let networkCondition: NetworkCondition
    public let deviceState: DeviceState
    public let userAction: UserActionName?

    public init(
      timestamp: Date = Date(),
      attemptNumber: ActionAttemptCount = ActionAttemptCount(rawValue: 1),
      networkCondition: NetworkCondition = .unknown,
      deviceState: DeviceState = .normal,
      userAction: UserActionName? = nil
    ) {
      self.timestamp = timestamp
      self.attemptNumber = attemptNumber
      self.networkCondition = networkCondition
      self.deviceState = deviceState
      self.userAction = userAction
    }
  }

  /// Network connectivity state
  public enum NetworkCondition: Sendable, CaseIterable {
    case excellent
    case good
    case poor
    case offline
    case unknown
  }

  /// Device operational state
  public enum DeviceState: Sendable, CaseIterable {
    case normal
    case lowMemory
    case lowBattery
    case backgroundMode
    case restricted
  }

  // MARK: - Properties

  /// The original HTTP error
  public let error: HTTPError

  /// Contextual information about the error occurrence
  public let context: ErrorContext

  /// Ordered list of recovery actions (most likely to succeed first)
  public let recoveryActions: [RecoveryAction]

  /// User-friendly error summary
  public let userMessage: UserMessageText

  /// Technical details for debugging
  public let technicalSummary: TechnicalSummaryText

  /// Impact level of this error on user experience
  public let impactLevel: ImpactLevel

  /// Confidence level in recovery suggestions
  public let confidenceLevel: ConfidenceLevel

  public enum ImpactLevel: Sendable, CaseIterable {
    case minimal  // User can continue with degraded experience
    case moderate  // Some functionality is affected
    case significant  // Major features are unavailable
    case critical  // App functionality is severely impacted
  }

  public enum ConfidenceLevel: Sendable, CaseIterable {
    case low  // 0-40% confidence in recovery
    case medium  // 40-70% confidence in recovery
    case high  // 70-90% confidence in recovery
    case veryHigh  // 90%+ confidence in recovery
  }

  // MARK: - Initialization

  public init(
    error: HTTPError,
    context: ErrorContext = ErrorContext(),
    recoveryActions: [RecoveryAction] = [],
    userMessage: UserMessageText? = nil,
    technicalSummary: TechnicalSummaryText? = nil,
    impactLevel: ImpactLevel? = nil,
    confidenceLevel: ConfidenceLevel? = nil
  ) {
    self.error = error
    self.context = context
    self.recoveryActions =
      recoveryActions.isEmpty
      ? Self.generateRecoveryActions(for: error, context: context) : recoveryActions
    self.userMessage = userMessage ?? Self.generateUserMessage(for: error, context: context)
    self.technicalSummary =
      technicalSummary ?? Self.generateTechnicalSummary(for: error, context: context)
    self.impactLevel = impactLevel ?? Self.determineImpactLevel(for: error, context: context)
    self.confidenceLevel =
      confidenceLevel ?? Self.determineConfidenceLevel(for: error, context: context)
  }

  // MARK: - Factory Methods

  /// Creates actionable error info from an HTTP error with automatic analysis
  public static func analyze(
    _ error: HTTPError,
    context: ErrorContext = ErrorContext()
  ) -> Self {
    Self(error: error, context: context)
  }

  /// Creates actionable error info with custom recovery actions
  public static func withCustomActions(
    error: HTTPError,
    actions: [RecoveryAction],
    context: ErrorContext = ErrorContext()
  ) -> Self {
    Self(error: error, context: context, recoveryActions: actions)
  }
}

// MARK: - Analysis Implementation

extension ActionableErrorInfo {
  private static func action(
    title: String,
    description: String,
    type: RecoveryAction.ActionType,
    estimatedDuration: TimeInterval? = nil,
    prerequisite: String? = nil,
    canAutoExecute: Bool = false
  ) -> RecoveryAction {
    RecoveryAction(
      title: RecoveryActionTitle(rawValue: title),
      description: RecoveryActionDescription(rawValue: description),
      type: type,
      estimatedDuration: estimatedDuration.map(RequestTimeout.init(rawValue:)),
      prerequisite: prerequisite.map(RecoveryActionPrerequisite.init(rawValue:)),
      canAutoExecute: RecoveryActionAutomationFlag(rawValue: canAutoExecute)
    )
  }

  // swiftlint:disable cyclomatic_complexity
  /// Generates contextually appropriate recovery actions for the error
  private static func generateRecoveryActions(
    for error: HTTPError,
    context: ErrorContext
  ) -> [RecoveryAction] {
    var actions: [RecoveryAction] = []

    switch error.category {
    case .network(let networkError):
      actions.append(contentsOf: networkRecoveryActions(networkError, context: context))

    case .http(let status):
      actions.append(contentsOf: httpRecoveryActions(status, context: context))

    case .timeout:
      actions.append(contentsOf: timeoutRecoveryActions(context: context))

    case .decoding(let message):
      actions.append(contentsOf: decodingRecoveryActions(message, context: context))

    case .encoding(let message):
      actions.append(contentsOf: encodingRecoveryActions(message, context: context))

    case .cancelled:
      actions.append(contentsOf: cancellationRecoveryActions(context: context))

    case .configuration(let message):
      actions.append(contentsOf: configurationRecoveryActions(message, context: context))

    case .custom(let type, let message):
      actions.append(
        contentsOf: customRecoveryActions(type: type, message: message, context: context)
      )
    }

    // Add universal actions that apply regardless of error type
    actions.append(contentsOf: universalRecoveryActions(context: context))

    // Sort by effectiveness probability and action type priority
    return sortActionsByEffectiveness(actions, for: error, context: context)
  }
  // swiftlint:enable cyclomatic_complexity

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  private static func networkRecoveryActions(
    _ networkError: HTTPError.NetworkError,
    context: ErrorContext
  ) -> [RecoveryAction] {
    switch networkError {
    case .noConnection:
      return [
        RecoveryAction(
          title: "Check Internet Connection",
          description: "Verify that your device is connected to WiFi or cellular data",
          type: .userInteraction,
          estimatedDuration: 30,
          canAutoExecute: false
        ),
        RecoveryAction(
          title: "Switch Network",
          description: "Try switching between WiFi and cellular data",
          type: .userInteraction,
          estimatedDuration: 15,
          canAutoExecute: false
        ),
        RecoveryAction(
          title: "Retry When Connected",
          description: "Automatically retry when connection is restored",
          type: .delayed,
          estimatedDuration: 60,
          canAutoExecute: true
        ),
      ]

    case .dnsFailure:
      return [
        RecoveryAction(
          title: "Check Server Address",
          description: "Verify that the server URL is correct and accessible",
          type: .systemConfiguration,
          estimatedDuration: 120,
          canAutoExecute: false
        ),
        RecoveryAction(
          title: "Try Different DNS",
          description: "Switch to a different DNS server (e.g., 8.8.8.8)",
          type: .systemConfiguration,
          estimatedDuration: 300,
          prerequisite: "Access to network settings",
          canAutoExecute: false
        ),
      ]

    case .connectionLost:
      return [
        RecoveryAction(
          title: "Automatic Retry",
          description: "Retry the request automatically",
          type: .immediate,
          estimatedDuration: 5,
          canAutoExecute: true
        ),
        RecoveryAction(
          title: "Check Network Stability",
          description: "Ensure your network connection is stable",
          type: .userInteraction,
          estimatedDuration: 60,
          canAutoExecute: false
        ),
      ]

    case .serverUnreachable:
      return [
        RecoveryAction(
          title: "Wait and Retry",
          description: "The server may be temporarily unavailable",
          type: .delayed,
          estimatedDuration: 300,
          canAutoExecute: true
        ),
        RecoveryAction(
          title: "Check Service Status",
          description: "Verify if the service is experiencing downtime",
          type: .userInteraction,
          estimatedDuration: 120,
          canAutoExecute: false
        ),
      ]

    case .sslError:
      return [
        RecoveryAction(
          title: "Check Date and Time",
          description: "Ensure your device's date and time are correct",
          type: .systemConfiguration,
          estimatedDuration: 60,
          canAutoExecute: false
        ),
        RecoveryAction(
          title: "Contact Support",
          description: "This may be a security configuration issue",
          type: .contactSupport,
          estimatedDuration: 1800,
          canAutoExecute: false
        ),
      ]
    }
  }

  // swiftlint:disable:next cyclomatic_complexity function_body_length
  private static func httpRecoveryActions(
    _ status: HTTPStatus,
    context: ErrorContext
  ) -> [RecoveryAction] {
    switch status.rawValue {
    case 401:
      return [
        RecoveryAction(
          title: "Sign In Again",
          description: "Your session may have expired. Please log in again.",
          type: .userInteraction,
          estimatedDuration: 60,
          canAutoExecute: false
        ),
        RecoveryAction(
          title: "Refresh Authentication",
          description: "Automatically refresh your authentication token",
          type: .immediate,
          estimatedDuration: 5,
          canAutoExecute: true
        ),
      ]

    case 403:
      return [
        RecoveryAction(
          title: "Check Permissions",
          description: "You may not have permission to access this resource",
          type: .userInteraction,
          estimatedDuration: 300,
          canAutoExecute: false
        ),
        RecoveryAction(
          title: "Contact Administrator",
          description: "Request access from your system administrator",
          type: .contactSupport,
          estimatedDuration: 3600,
          canAutoExecute: false
        ),
      ]

    case 404:
      return [
        RecoveryAction(
          title: "Verify URL",
          description: "Check that the requested resource exists",
          type: .userInteraction,
          estimatedDuration: 60,
          canAutoExecute: false
        ),
        RecoveryAction(
          title: "Use Alternative Endpoint",
          description: "Try accessing the resource through a different path",
          type: .immediate,
          estimatedDuration: 5,
          canAutoExecute: true
        ),
      ]

    case 408:
      return [
        RecoveryAction(
          title: "Retry with Timeout Extension",
          description: "Retry the request with a longer timeout",
          type: .immediate,
          estimatedDuration: 10,
          canAutoExecute: true
        ),
        RecoveryAction(
          title: "Check Connection Speed",
          description: "Verify your internet connection speed is adequate",
          type: .userInteraction,
          estimatedDuration: 120,
          canAutoExecute: false
        ),
      ]

    case 429:
      return [
        RecoveryAction(
          title: "Wait and Retry",
          description: "Wait for the rate limit to reset before retrying",
          type: .delayed,
          estimatedDuration: 300,
          canAutoExecute: true
        ),
        RecoveryAction(
          title: "Reduce Request Frequency",
          description: "Make fewer requests to avoid rate limiting",
          type: .userInteraction,
          estimatedDuration: 0,
          canAutoExecute: false
        ),
      ]

    case 500...503:
      return [
        RecoveryAction(
          title: "Automatic Retry",
          description: "Server error - retry automatically with backoff",
          type: .delayed,
          estimatedDuration: 60,
          canAutoExecute: true
        ),
        RecoveryAction(
          title: "Report Server Issue",
          description: "Report the server problem to technical support",
          type: .contactSupport,
          estimatedDuration: 600,
          canAutoExecute: false
        ),
      ]

    default:
      return [
        RecoveryAction(
          title: "Retry Request",
          description: "Retry the request after a brief delay",
          type: .delayed,
          estimatedDuration: 30,
          canAutoExecute: true
        )
      ]
    }
  }

  private static func timeoutRecoveryActions(context: ErrorContext) -> [RecoveryAction] {
    [
      RecoveryAction(
        title: "Retry with Extended Timeout",
        description: "Retry the request with a longer timeout period",
        type: .immediate,
        estimatedDuration: 15,
        canAutoExecute: true
      ),
      RecoveryAction(
        title: "Check Network Speed",
        description: "Test your internet connection speed",
        type: .userInteraction,
        estimatedDuration: 120,
        canAutoExecute: false
      ),
      RecoveryAction(
        title: "Switch to Faster Network",
        description: "Connect to a faster network if available",
        type: .userInteraction,
        estimatedDuration: 180,
        canAutoExecute: false
      ),
    ]
  }

  private static func decodingRecoveryActions(
    _ message: HTTPErrorDetail,
    context: ErrorContext
  ) -> [RecoveryAction] {
    [
      RecoveryAction(
        title: "Request Fresh Data",
        description: "The server response format may have changed. Request new data.",
        type: .immediate,
        estimatedDuration: 10,
        canAutoExecute: true
      ),
      RecoveryAction(
        title: "Update App",
        description: "Check if an app update is available to fix compatibility issues",
        type: .userInteraction,
        estimatedDuration: 600,
        canAutoExecute: false
      ),
      RecoveryAction(
        title: "Report Data Format Issue",
        description: "Report the data format problem to support team",
        type: .contactSupport,
        estimatedDuration: 1200,
        canAutoExecute: false
      ),
    ]
  }

  private static func encodingRecoveryActions(
    _ message: HTTPErrorDetail,
    context: ErrorContext
  ) -> [RecoveryAction] {
    [
      RecoveryAction(
        title: "Validate Input Data",
        description: "Check that all required fields are provided and correctly formatted",
        type: .userInteraction,
        estimatedDuration: 120,
        canAutoExecute: false
      ),
      RecoveryAction(
        title: "Simplify Request",
        description: "Try sending a simpler version of the request",
        type: .immediate,
        estimatedDuration: 5,
        canAutoExecute: true
      ),
    ]
  }

  private static func cancellationRecoveryActions(context: ErrorContext) -> [RecoveryAction] {
    [
      RecoveryAction(
        title: "Retry Request",
        description: "The request was cancelled. Try again if needed.",
        type: .immediate,
        estimatedDuration: 5,
        canAutoExecute: true
      ),
      RecoveryAction(
        title: "Check If Action Still Needed",
        description: "Verify if the cancelled action is still necessary",
        type: .userInteraction,
        estimatedDuration: 30,
        canAutoExecute: false
      ),
    ]
  }

  private static func configurationRecoveryActions(
    _ message: HTTPErrorDetail,
    context: ErrorContext
  ) -> [RecoveryAction] {
    [
      RecoveryAction(
        title: "Check App Configuration",
        description: "Verify that the app is properly configured for your environment",
        type: .systemConfiguration,
        estimatedDuration: 300,
        canAutoExecute: false
      ),
      RecoveryAction(
        title: "Reinstall Application",
        description: "Reinstall the app to fix configuration issues",
        type: .userInteraction,
        estimatedDuration: 1200,
        canAutoExecute: false
      ),
      RecoveryAction(
        title: "Contact Technical Support",
        description: "Get help from technical support to resolve configuration issues",
        type: .contactSupport,
        estimatedDuration: 3600,
        canAutoExecute: false
      ),
    ]
  }

  private static func customRecoveryActions(
    type: HTTPErrorTypeName,
    message: HTTPErrorDetail,
    context: ErrorContext
  ) -> [RecoveryAction] {
    if type.lowercased() == "security" {
      return [
        RecoveryAction(
          title: "Review Request Security",
          description: "Check your request for potentially dangerous content",
          type: .userInteraction,
          estimatedDuration: 180,
          canAutoExecute: false
        ),
        RecoveryAction(
          title: "Contact Security Team",
          description: "Report this security issue to the security team",
          type: .contactSupport,
          estimatedDuration: 1800,
          canAutoExecute: false
        ),
      ]
    } else {
      return [
        RecoveryAction(
          title: RecoveryActionTitle("Review \(type) Configuration"),
          description: RecoveryActionDescription(
            "Check the configuration for \(type.lowercased()) issues"
          ),
          type: .systemConfiguration,
          estimatedDuration: RequestTimeout(rawValue: 300),
          canAutoExecute: RecoveryActionAutomationFlag(rawValue: false)
        ),
        RecoveryAction(
          title: "Contact Support",
          description: "Get help resolving this \(type.lowercased()) issue",
          type: .contactSupport,
          estimatedDuration: 1800,
          canAutoExecute: false
        ),
      ]
    }
  }

  private static func universalRecoveryActions(context: ErrorContext) -> [RecoveryAction] {
    var actions: [RecoveryAction] = []

    // Add context-sensitive universal actions
    if context.attemptNumber > 1 {
      actions.append(
        RecoveryAction(
          title: "Wait Before Retry",
          description: "Wait longer before attempting again",
          type: .delayed,
          estimatedDuration: Double(context.attemptNumber.rawValue * 30),
          canAutoExecute: true
        )
      )
    }

    // Add contact support for repeated failures
    if context.attemptNumber > 3 {
      actions.append(
        RecoveryAction(
          title: "Contact Technical Support",
          description:
            "Multiple attempts have failed. Technical support can help diagnose the issue.",
          type: .contactSupport,
          estimatedDuration: 1800,
          canAutoExecute: false
        )
      )
    }

    if context.networkCondition == .poor {
      actions.append(
        RecoveryAction(
          title: "Improve Network Connection",
          description: "Move to an area with better signal or connect to WiFi",
          type: .userInteraction,
          estimatedDuration: 180,
          canAutoExecute: false
        )
      )
    }

    return actions
  }

  /// Sorts recovery actions by their estimated effectiveness
  private static func sortActionsByEffectiveness(
    _ actions: [RecoveryAction],
    for error: HTTPError,
    context: ErrorContext
  ) -> [RecoveryAction] {
    actions.sorted { action1, action2 in
      let priority1 = actionPriority(action1, for: error, context: context)
      let priority2 = actionPriority(action2, for: error, context: context)
      return priority1 < priority2
    }
  }

  /// Calculates priority score for an action (lower is better)
  private static func actionPriority(
    _ action: RecoveryAction,
    for error: HTTPError,
    context: ErrorContext
  ) -> Int {
    autoExecuteAdjustment(for: action)
      + actionTypePriority(for: action.type)
      + durationPriorityAdjustment(for: action)
      + repeatedFailurePriorityAdjustment(for: action, context: context)
  }

  /// Generates a user-friendly message for the error
  private static func generateUserMessage(
    for error: HTTPError,
    context: ErrorContext
  ) -> UserMessageText {
    let baseMessage = error.userFriendlyDescription

    // Add context-sensitive information
    if context.attemptNumber > 1 {
      return UserMessageText("\(baseMessage) This is attempt #\(context.attemptNumber).")
    }

    if context.networkCondition == .poor {
      return UserMessageText("\(baseMessage) Your network connection appears to be weak.")
    }

    return baseMessage
  }

  /// Generates technical summary for debugging
  private static func generateTechnicalSummary(
    for error: HTTPError,
    context: ErrorContext
  ) -> TechnicalSummaryText {
    var summary = error.debugSummary.rawValue

    summary +=
      "\nContext: Attempt \(context.attemptNumber), Network: \(context.networkCondition), Device: \(context.deviceState)"

    if let userAction = context.userAction {
      summary += "\nTriggered by: \(userAction)"
    }

    return TechnicalSummaryText(summary)
  }

  /// Determines the impact level of the error
  private static func determineImpactLevel(
    for error: HTTPError,
    context: ErrorContext
  ) -> ImpactLevel {
    switch error.severity {
    case .low:
      return .minimal

    case .medium:
      return context.attemptNumber > 2 ? .moderate : .minimal

    case .high:
      return .significant

    case .critical:
      return .critical
    }
  }

  /// Determines confidence level in recovery suggestions
  private static func determineConfidenceLevel(
    for error: HTTPError,
    context: ErrorContext
  ) -> ConfidenceLevel {
    if context.attemptNumber > 3 {
      return .low
    }

    if error.isTransientError.rawValue {
      return .high
    }

    return confidenceLevel(for: error)
  }

  private static func autoExecuteAdjustment(for action: RecoveryAction) -> Int {
    action.canAutoExecute.rawValue ? -10 : 0
  }

  // swiftlint:disable:next cyclomatic_complexity
  private static func actionTypePriority(for type: RecoveryAction.ActionType) -> Int {
    switch type {
    case .immediate:
      return 0
    case .delayed:
      return 5
    case .userInteraction:
      return 10
    case .systemConfiguration:
      return 15
    case .contactSupport:
      return 20
    }
  }

  private static func durationPriorityAdjustment(for action: RecoveryAction) -> Int {
    guard let duration = action.estimatedDuration else {
      return 0
    }

    return Int(duration.rawValue / 60)
  }

  private static func repeatedFailurePriorityAdjustment(
    for action: RecoveryAction,
    context: ErrorContext
  ) -> Int {
    guard context.attemptNumber > 3, action.type == .contactSupport else {
      return 0
    }

    return -5
  }

  private static func confidenceLevel(for error: HTTPError) -> ConfidenceLevel {
    switch error.category {
    case .network(.noConnection), .network(.connectionLost), .cancelled:
      return .veryHigh
    case .http(let status) where [401, 403, 404, 429].contains(status.codeValue):
      return .high
    case .timeout:
      return .high
    default:
      return .medium
    }
  }
}

// MARK: - Convenience Extensions

extension ActionableErrorInfo {
  /// Returns only actions that can be automatically executed
  public var autoExecutableActions: [RecoveryAction] {
    recoveryActions.filter { $0.canAutoExecute.rawValue }
  }

  /// Returns actions that require user interaction
  public var userInteractionActions: [RecoveryAction] {
    recoveryActions.filter { $0.type == .userInteraction }
  }

  /// Returns the most recommended action (first in the list)
  public var primaryAction: RecoveryAction? {
    recoveryActions.first
  }

  /// Returns total estimated time to resolve the issue
  public var estimatedResolutionTime: EstimatedResolutionTime {
    recoveryActions.compactMap(\.estimatedDuration).min().map {
      EstimatedResolutionTime($0.rawValue)
    }
      ?? EstimatedResolutionTime(rawValue: 300)
  }

  /// Returns whether this error is likely to resolve automatically
  public var isLikelyToResolveAutomatically: AutomaticResolutionFlag {
    AutomaticResolutionFlag(
      !autoExecutableActions.isEmpty && confidenceLevel.rawValue >= ConfidenceLevel.medium.rawValue
    )
  }
}

// MARK: - Raw Value Support for Enums

extension ActionableErrorInfo.ImpactLevel: Comparable {
  public static func < (lhs: Self, rhs: Self) -> Bool {
    lhs.rawValue < rhs.rawValue
  }

  public var rawValue: ImpactLevelRank {
    switch self {
    case .minimal: return ImpactLevelRank(rawValue: 1)
    case .moderate: return ImpactLevelRank(rawValue: 2)
    case .significant: return ImpactLevelRank(rawValue: 3)
    case .critical: return ImpactLevelRank(rawValue: 4)
    }
  }
}

extension ActionableErrorInfo.ConfidenceLevel {
  public var rawValue: ConfidenceLevelRank {
    switch self {
    case .low: return ConfidenceLevelRank(rawValue: 1)
    case .medium: return ConfidenceLevelRank(rawValue: 2)
    case .high: return ConfidenceLevelRank(rawValue: 3)
    case .veryHigh: return ConfidenceLevelRank(rawValue: 4)
    }
  }
}
