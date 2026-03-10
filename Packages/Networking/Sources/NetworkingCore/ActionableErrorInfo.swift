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
