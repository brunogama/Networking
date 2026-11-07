import Foundation
import NetworkingCore
import NetworkingRuntime
import Testing
@testable import NetworkingObservability

actor RecordingTraceExporter: TraceExporter {
  private(set) var snapshots: [TraceSpanSnapshot] = []

  func export(_ span: TraceSpan) async {
    snapshots.append(await span.snapshot())
  }
}
