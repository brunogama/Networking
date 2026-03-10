import Foundation
import NetworkingCore

extension TransferControls {
  /// Transfer states that control the flow and behavior of active transfers.
  public enum TransferState: Sendable, CaseIterable, Hashable {
    case waiting
    case preparing
    case active
    case paused
    case resuming
    case cancelling
    case cancelled
    case completed
    case failed

    public var identifier: TransferStateName {
      switch self {
      case .waiting: return "waiting"
      case .preparing: return "preparing"
      case .active: return "active"
      case .paused: return "paused"
      case .resuming: return "resuming"
      case .cancelling: return "cancelling"
      case .cancelled: return "cancelled"
      case .completed: return "completed"
      case .failed: return "failed"
      }
    }

    /// Whether the transfer is currently processing data.
    public var isActive: TransferActivityFlag {
      switch self {
      case .active, .resuming:
        return true

      case .waiting, .preparing, .paused, .cancelling, .cancelled, .completed, .failed:
        return false
      }
    }

    /// Whether the transfer can be paused.
    public var canPause: TransferPauseCapabilityFlag {
      switch self {
      case .active, .resuming:
        return true

      case .waiting, .preparing, .paused, .cancelling, .cancelled, .completed, .failed:
        return false
      }
    }

    /// Whether the transfer can be resumed.
    public var canResume: TransferResumeCapabilityFlag {
      switch self {
      case .paused:
        return true

      case .waiting, .preparing, .active, .resuming, .cancelling, .cancelled, .completed, .failed:
        return false
      }
    }

    /// Whether the transfer can be cancelled.
    public var canCancel: TransferCancelCapabilityFlag {
      switch self {
      case .waiting, .preparing, .active, .paused, .resuming:
        return true

      case .cancelling, .cancelled, .completed, .failed:
        return false
      }
    }
  }

  /// Transfer control actions that can be performed.
  public enum ControlAction: Sendable, CaseIterable {
    case pause
    case resume
    case cancel
    case restart
    case prioritize
    case throttle

    public var identifier: TransferControlActionName {
      switch self {
      case .pause: return "pause"
      case .resume: return "resume"
      case .cancel: return "cancel"
      case .restart: return "restart"
      case .prioritize: return "prioritize"
      case .throttle: return "throttle"
      }
    }
  }

  /// Errors that can occur during transfer control operations.
  public enum TransferControlError: Error, LocalizedError {
    case invalidStateTransition(from: TransferState, to: TransferState)
    case transferNotFound(TransferIdentifier)
    case actionNotAllowed(ControlAction, currentState: TransferState)
    case invalidBandwidthLimit(TransferByteRate)
    case resumeDataCorrupted
    case concurrencyLimitExceeded(limit: TransferConcurrencyLimit)

    public var errorDescription: String? {
      switch self {
      case .invalidStateTransition(let from, let to):
        return
          "Invalid state transition from \(from.identifier.rawValue) to \(to.identifier.rawValue)"

      case .transferNotFound(let id):
        return "Transfer with ID \(id.rawValue) not found"

      case .actionNotAllowed(let action, let state):
        return
          "Action '\(action.identifier.rawValue)' not allowed in state '\(state.identifier.rawValue)'"

      case .invalidBandwidthLimit(let limit):
        return "Invalid bandwidth limit: \(limit.rawValue) bytes/sec"

      case .resumeDataCorrupted:
        return "Resume data is corrupted and cannot be used"

      case .concurrencyLimitExceeded(let limit):
        return "Concurrency limit of \(limit) transfers exceeded"
      }
    }
  }
}

extension TransferControls.TransferState: CustomStringConvertible {
  public var description: String {
    switch self {
    case .waiting: return "Waiting"
    case .preparing: return "Preparing"
    case .active: return "Active"
    case .paused: return "Paused"
    case .resuming: return "Resuming"
    case .cancelling: return "Cancelling"
    case .cancelled: return "Cancelled"
    case .completed: return "Completed"
    case .failed: return "Failed"
    }
  }
}
