import NetworkingCore

package struct HTTPExchange<Phase>: ~Copyable, Sendable {
  package let id: HTTPTraceID?
  private let diagnostics: NetworkDiagnostics?

}

extension HTTPExchange where Phase == ExchangePrepared {
  package init(diagnostics: NetworkDiagnostics?) {
    self.init(id: nil, diagnostics: diagnostics)
  }

  package consuming func start(_ request: HTTPRequest) -> HTTPExchange<ExchangeRunning> {
    HTTPExchange<ExchangeRunning>(id: diagnostics?.start(request), diagnostics: diagnostics)
  }
}

extension HTTPExchange where Phase == ExchangeRunning {
  package consuming func finish(_ response: HTTPResponse) {
    guard let id else { return }
    diagnostics?.finish(id, response: response)
  }

  package consuming func fail(_ error: any Error) {
    guard let id else { return }
    diagnostics?.fail(id, error: error)
  }
}
