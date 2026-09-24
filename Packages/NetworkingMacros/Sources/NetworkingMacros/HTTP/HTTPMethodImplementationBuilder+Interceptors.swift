extension HTTPMethodImplementationBuilder {
  static func requestInterceptorStep(shortCircuit: String) -> String {
    """
    var interceptedRequest = preparedRequest
    let requestResult = try await interceptors.executeRequestInterceptors(
      request: &interceptedRequest,
      context: context
    )
    switch requestResult {
    case .proceed:
      break
    case .shortCircuit(let interceptedResponse):
    \(indent(shortCircuit))
    case .retry:
      throw InterceptorError.invalidResult(reason: "Request interceptor requested a retry")
    }
    let response: HTTPResponse
    let httpError: HTTPError?
    do {
      response = try await client.execute(interceptedRequest)
      httpError = nil
    } catch let error as HTTPError {
      guard case .http = error.category, let failedResponse = error.response else {
        throw error
      }
      response = failedResponse
      httpError = error
    }
    """
  }

  static func responseInterceptorStep() -> String {
    """
    let responseResult = try await interceptors.executeResponseInterceptors(
      response: response,
      context: context
    )
    let finalResponse: HTTPResponse
    switch responseResult {
    case .proceed:
      if let httpError { throw httpError }
      finalResponse = response
    case .shortCircuit(let interceptedResponse):
      finalResponse = interceptedResponse
    case .retry(let delay):
      guard context.attemptCount.rawValue < 10 else {
        throw InterceptorError.maxRetriesExceeded(maxAttempts: 10)
      }
      if let delay {
        try await Task.sleep(for: .seconds(delay.rawValue))
      }
      context = context.incrementingAttempt()
      continue
    }
    """
  }
}
