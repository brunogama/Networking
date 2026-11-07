import NetworkingCore

extension RequestCancellation {
  enum State {
    case pending(Waiter?)
    case finished(Result<HTTPResponse, HTTPError>)
  }
}
