#if os(iOS) || os(macOS)
import NetworkingRuntime
import SwiftUI

@MainActor
struct NetworkTraceDetail: View {
  let trace: HTTPTrace

  var body: some View {
    Form {
      Section("Request") {
        Text(trace.request.method ?? "HTTP").font(.headline)
        Text(trace.request.url?.absoluteString ?? "Unavailable URL").textSelection(.enabled)
        Text(trace.startedAt, style: .time).foregroundStyle(.secondary)
      }
      message(trace.request, title: "Request")
      if let response = trace.response {
        Section("Response") {
          Text("Status \(response.statusCode.map(String.init) ?? "unknown")")
        }
        message(response, title: "Response")
      }
      if let failure = trace.failure {
        Section("Failure") { Text(failure).textSelection(.enabled) }
      }
      if let ended = trace.endedAt {
        Section("Duration") {
          Text(seconds(ended.timeIntervalSince(trace.startedAt)))
        }
      }
      ForEach(Array(trace.connections.enumerated()), id: \.offset) { index, connection in
        Section("Connection \(index + 1)") {
          LabeledContent("Protocol", value: connection.protocolName ?? "Unknown")
          LabeledContent("Reused", value: connection.reused ? "Yes" : "No")
          timing("DNS", connection.dns)
          timing("Connect", connection.connect)
          timing("TLS", connection.tls)
          timing("First byte", connection.timeToFirstByte)
        }
      }
    }
    .formStyle(.grouped)
    .navigationTitle("Request details")
  }

  @ViewBuilder
  private func message(_ message: HTTPTrace.Message, title: String) -> some View {
    if !message.headers.isEmpty {
      Section("\(title) headers") {
        ForEach(message.headers.keys.sorted(), id: \.self) { name in
          VStack(alignment: .leading, spacing: 4) {
            Text(name).font(.caption).foregroundStyle(.secondary)
            Text(message.headers[name] ?? "").font(.body.monospaced()).textSelection(.enabled)
          }
        }
      }
    }
    if let body = message.body {
      Section("\(title) body prefix (\(body.count) bytes)") {
        Text(String(data: body, encoding: .utf8) ?? "Binary content")
          .font(.body.monospaced()).textSelection(.enabled)
      }
    }
  }

  private func timing(_ title: String, _ duration: TimeInterval?) -> some View {
    LabeledContent(title, value: duration.map(seconds) ?? "Not measured")
  }

  private func seconds(_ value: TimeInterval) -> String {
    "\(value.formatted(.number.precision(.fractionLength(3)))) s"
  }
}
#endif
