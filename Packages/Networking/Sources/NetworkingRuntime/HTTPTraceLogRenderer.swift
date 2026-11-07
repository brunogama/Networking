import Foundation

enum HTTPTraceLogRenderer {
  static func render(
    _ trace: HTTPTrace,
    format: NetworkDiagnostics.LogFormat,
    codec: JSONCodec
  ) -> String {
    switch format {
    case .curl:
      curl(for: trace.request)
    case .httpie:
      httpie(for: trace.request)
    case .trace:
      serialized(trace, codec: codec)
    }
  }

  private static func curl(for request: HTTPTrace.Message) -> String {
    command(
      executable: "curl",
      arguments: curlArguments(for: request)
    )
  }

  private static func curlArguments(for request: HTTPTrace.Message) -> [String] {
    var arguments = ["--request", request.method ?? "GET"]
    for header in request.headers.sorted(by: headerOrder) {
      arguments.append(contentsOf: ["--header", "\(header.key): \(header.value)"])
    }
    if let body = stringBody(request.body) {
      arguments.append(contentsOf: ["--data-raw", body])
    }
    if let url = request.url?.absoluteString { arguments.append(url) }
    return arguments
  }

  private static func httpie(for request: HTTPTrace.Message) -> String {
    var arguments = [request.method ?? "GET"]
    if let url = request.url?.absoluteString { arguments.append(url) }
    arguments += request.headers.sorted(by: headerOrder).map { "\($0.key):\($0.value)" }
    if let body = stringBody(request.body) {
      arguments.append(contentsOf: ["--raw", body])
    }
    return command(executable: "http", arguments: arguments)
  }

  private static func headerOrder(
    _ left: (key: String, value: String),
    _ right: (key: String, value: String)
  ) -> Bool {
    left.key.localizedCaseInsensitiveCompare(right.key) == .orderedAscending
  }

  private static func stringBody(_ body: Data?) -> String? {
    guard let body else { return nil }
    return String(data: body, encoding: .utf8) ?? body.base64EncodedString()
  }

  private static func command(executable: String, arguments: [String]) -> String {
    ([executable] + arguments).map(shellQuoted).joined(separator: " ")
  }

  private static func shellQuoted(_ value: String) -> String {
    guard !value.isEmpty, value.allSatisfy(isShellSafe) else {
      return "'\(value.replacingOccurrences(of: "'", with: "'\\\"'\\\"'"))'"
    }
    return value
  }

  private static func isShellSafe(_ character: Character) -> Bool {
    character.isLetter || character.isNumber || "-._/:=".contains(character)
  }

  private static func serialized(_ trace: HTTPTrace, codec: JSONCodec) -> String {
    guard let data = try? codec.encode(trace), let output = String(data: data, encoding: .utf8)
    else {
      return "HTTP trace id=\(trace.id.rawValue)"
    }
    return output
  }
}
