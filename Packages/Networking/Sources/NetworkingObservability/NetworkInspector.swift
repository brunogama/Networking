#if os(iOS) || os(macOS)
import NetworkingRuntime
import SwiftUI

/// A searchable inspector for the sanitized traces retained by a diagnostics recorder.
///
/// Present this view in an application's debug UI; recording must be enabled on its client.
@MainActor
public struct NetworkInspector: View {
  private let diagnostics: NetworkDiagnostics
  @State private var traces: [HTTPTrace] = []
  @State private var search = ""

  /// Creates an inspector for a recorder shared with the application's HTTP client.
  public init(diagnostics: NetworkDiagnostics) { self.diagnostics = diagnostics }

  /// The searchable request list and request details.
  public var body: some View {
    NavigationStack {
      List(filteredTraces.reversed()) { trace in
        NavigationLink(value: trace.id) { row(trace) }
      }
      .overlay {
        if traces.isEmpty {
          VStack(spacing: 8) {
            Image(systemName: "network").font(.largeTitle)
            Text("No requests recorded").font(.headline)
            Text("Requests will appear here as your app makes connections.")
              .font(.callout).foregroundStyle(.secondary)
          }
          .padding()
        }
      }
      .navigationTitle("Network")
      .searchable(text: $search, prompt: "Filter URL or method")
      .toolbar {
        Button("Clear", systemImage: "trash") { diagnostics.clear() }
          .disabled(traces.isEmpty)
      }
      .navigationDestination(for: HTTPTraceID.self) { identity in
        if let trace = traces.first(where: { $0.id == identity }) {
          NetworkTraceDetail(trace: trace)
        } else {
          Text("This request is no longer retained.")
        }
      }
    }
    .task {
      for await _ in diagnostics.changes() { traces = diagnostics.traces }
    }
  }

  private var filteredTraces: [HTTPTrace] {
    guard !search.isEmpty else { return traces }
    return traces.filter {
      "\($0.request.method ?? "") \($0.request.url?.absoluteString ?? "")"
        .localizedCaseInsensitiveContains(search)
    }
  }

  private func row(_ trace: HTTPTrace) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(trace.request.method ?? "HTTP").font(.caption.monospaced().bold())
        Spacer()
        Text(status(trace)).font(.caption.monospaced())
          .foregroundStyle(trace.failure == nil ? Color.secondary : Color.red)
      }
      Text(trace.request.url?.path ?? "/").font(.body).lineLimit(1)
      Text(trace.request.url?.host ?? "Unknown host")
        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
    }
    .padding(.vertical, 4)
  }

  private func status(_ trace: HTTPTrace) -> String {
    if let status = trace.response?.statusCode { return String(status) }
    if trace.failure != nil { return "Failed" }
    return "Running"
  }
}
#endif
