#if os(macOS)
import Foundation

final class LocalResponseLimitServer {
  let port: Int
  private let process: Process

  init() throws {
    let output = Pipe()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
    process.arguments = ["-u", "-c", Self.script]
    process.standardOutput = output
    process.standardError = Pipe()
    try process.run()
    var line = Data()
    while let byte = try output.fileHandleForReading.read(upToCount: 1), !byte.isEmpty {
      if byte[byte.startIndex] == 10 { break }
      line.append(byte)
    }
    guard let value = String(data: line, encoding: .utf8), let port = Int(value) else {
      process.terminate()
      throw CocoaError(.fileReadCorruptFile)
    }
    self.process = process
    self.port = port
  }

  func stop() {
    if process.isRunning { process.terminate() }
    process.waitUntilExit()
  }

  private static let script = """
    import http.server, socketserver
    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200)
            self.send_header('Transfer-Encoding', 'chunked')
            self.end_headers()
            try:
                for _ in range(128):
                    self.wfile.write(b'400\\r\\n' + b'x' * 1024 + b'\\r\\n')
                    self.wfile.flush()
                self.wfile.write(b'0\\r\\n\\r\\n')
            except (BrokenPipeError, ConnectionResetError):
                pass
        def log_message(self, *args):
            pass
    with socketserver.TCPServer(('127.0.0.1', 0), Handler) as server:
        print(server.server_address[1], flush=True)
        server.handle_request()
    """
}
#endif
