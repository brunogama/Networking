import Foundation
import NetworkingCore
import NetworkingObservability
import NetworkingObservabilityOTLP
import os
import Testing

extension PendingOTLPProtocol {
  enum Event: Sendable { case started, stopped }
}
