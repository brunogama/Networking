import SwiftUI

struct BenchmarkControls: View {
  @Binding var baseURL: String
  @Binding var iterations: Int
  let isRunning: Bool
  let runAction: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      TextField("Local HTTP(S) endpoint", text: $baseURL)
        .textFieldStyle(.roundedBorder)
      Stepper("\(iterations) samples", value: $iterations, in: 1...100)
        .fixedSize()
      Button("Run benchmark", action: runAction)
        .buttonStyle(.borderedProminent)
        .disabled(isRunning)
    }
  }
}
