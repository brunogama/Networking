#if os(macOS)
import Foundation

final class HTTPDiagnosticsServer: Sendable {
  let baseURL: URL
  private let process: Process
  private let events: FileHandle

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
    guard let port = String(data: line, encoding: .utf8).flatMap(Int.init),
      let url = URL(string: "http://127.0.0.1:\(port)")
    else {
      process.terminate()
      throw CocoaError(.fileReadCorruptFile)
    }
    baseURL = url
    self.process = process
    events = output.fileHandleForReading
  }

  func nextEvent() async throws -> String? {
    var iterator = events.bytes.lines.makeAsyncIterator()
    return try await iterator.next()
  }

  func stop() {
    if process.isRunning { process.terminate() }
    process.waitUntilExit()
  }

  private static let script = """
    import http.server
    class Handler(http.server.BaseHTTPRequestHandler):
        protocol_version = 'HTTP/1.1'
        def do_GET(self):
            if self.path == '/wait':
                self.send_response(200)
                self.send_header('Content-Length', '100')
                self.send_header('Connection', 'close')
                self.end_headers()
                self.wfile.write(b'x')
                self.wfile.flush()
                print('started', flush=True)
                self.connection.recv(1)
                print('disconnected', flush=True)
                return
            if self.path == '/redirect':
                self.send_response(302)
                self.send_header('Location', '/payload')
                self.send_header('Content-Length', '0')
                self.end_headers()
                return
            self.respond(b'payload')
        def do_POST(self):
            self.respond(self.rfile.read(int(self.headers.get('Content-Length', '0'))))
        def respond(self, body):
            self.send_response(200)
            self.send_header('Content-Type', 'text/plain')
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        def log_message(self, *args):
            pass
    with http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler) as server:
        print(server.server_address[1], flush=True)
        server.serve_forever()
    """
}
#endif
