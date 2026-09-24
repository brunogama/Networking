import Foundation
import NetworkingCore

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension NetworkClient {
  package func performRecordedRequest(
    _ urlRequest: URLRequest,
    for request: HTTPRequest,
    recorder: NetworkTrafficRecorder
  ) async throws -> HTTPResponse {
    let token = await recorder.begin(
      requestID: request.id,
      request: urlRequest
    )
    let delegate = makeTrafficDelegate(for: recorder)
    let attempt = RecordedTrafficAttempt(
      token: token,
      recorder: recorder,
      delegate: delegate
    )
    let (data, response) = try await performRecordedDataTask(
      urlRequest,
      for: request,
      attempt: attempt
    )
    let responseSnapshot = NetworkTrafficSnapshot.response(
      from: response,
      body: data,
      policy: recorder.capturePolicy
    )
    do {
      let httpResponse = try makeHTTPResponse(from: response, data: data, request: request)
      await completeTrafficAttempt(
        attempt,
        response: responseSnapshot,
        failure: nil
      )
      return httpResponse
    } catch {
      await completeTrafficAttempt(
        attempt,
        response: responseSnapshot,
        failure: NetworkTrafficSnapshot.failure(from: error)
      )
      throw error
    }
  }

  package func performUnrecordedRequest(
    _ urlRequest: URLRequest,
    for request: HTTPRequest
  ) async throws -> HTTPResponse {
    do {
      let (data, response) = try await session.data(for: urlRequest)
      return try makeHTTPResponse(from: response, data: data, request: request)
    } catch let error as URLError {
      throw mapURLError(error, for: request)
    }
  }

  private func performRecordedDataTask(
    _ urlRequest: URLRequest,
    for request: HTTPRequest,
    attempt: RecordedTrafficAttempt
  ) async throws -> (Data, URLResponse) {
    do {
      return try await session.data(for: urlRequest, delegate: attempt.delegate)
    } catch {
      await completeTrafficAttempt(
        attempt,
        response: nil,
        failure: NetworkTrafficSnapshot.failure(from: error)
      )
      if let urlError = error as? URLError {
        throw mapURLError(urlError, for: request)
      }
      throw error
    }
  }

  private func completeTrafficAttempt(
    _ attempt: RecordedTrafficAttempt,
    response: NetworkTrafficResponse?,
    failure: NetworkTrafficFailure?
  ) async {
    let delegateSnapshot = await attempt.delegate.snapshot()
    await attempt.recorder.complete(
      attempt.token,
      with: NetworkTrafficAttemptResult(
        endedAt: Date(),
        response: response,
        failure: failure,
        delegateSnapshot: delegateSnapshot
      )
    )
  }

  private func makeHTTPResponse(
    from response: URLResponse,
    data: Data,
    request: HTTPRequest
  ) throws -> HTTPResponse {
    guard let httpResponse = response as? HTTPURLResponse else {
      throw HTTPError(
        category: .network(.serverUnreachable),
        request: request
      )
    }
    return HTTPResponse(
      request: request,
      httpURLResponse: httpResponse,
      body: HTTPBody(data)
    )
  }

  private func makeTrafficDelegate(
    for recorder: NetworkTrafficRecorder
  ) -> NetworkTrafficTaskDelegate {
    NetworkTrafficTaskDelegate(
      policy: recorder.capturePolicy,
      forwardingTo: session.delegate as? (any URLSessionTaskDelegate)
    )
  }
}

private struct RecordedTrafficAttempt: Sendable {
  let token: NetworkTrafficAttemptToken
  let recorder: NetworkTrafficRecorder
  let delegate: NetworkTrafficTaskDelegate
}
