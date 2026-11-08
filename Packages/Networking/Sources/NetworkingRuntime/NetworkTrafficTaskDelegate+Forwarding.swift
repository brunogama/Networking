import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension NetworkTrafficTaskDelegate {
  package func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
    forwardingDelegate?.urlSession?(session, didCreateTask: task)
  }

  package func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willBeginDelayedRequest request: URLRequest,
    completionHandler:
      @escaping @Sendable (
        URLSession.DelayedRequestDisposition,
        URLRequest?
      ) -> Void
  ) {
    let selector = #selector(
      URLSessionTaskDelegate.urlSession(
        _:
        task:
        willBeginDelayedRequest:
        completionHandler:
      )
    )
    if let forwardingDelegate, forwardingDelegate.responds(to: selector) {
      forwardingDelegate.urlSession?(
        session,
        task: task,
        willBeginDelayedRequest: request,
        completionHandler: completionHandler
      )
    } else {
      completionHandler(.continueLoading, nil)
    }
  }

  package func urlSession(
    _ session: URLSession,
    taskIsWaitingForConnectivity task: URLSessionTask
  ) {
    forwardingDelegate?.urlSession?(session, taskIsWaitingForConnectivity: task)
  }

  // URLSessionTaskDelegate requires this five-parameter Objective-C callback shape.
  // swiftlint:disable:next function_parameter_count
  package func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping @Sendable (URLRequest?) -> Void
  ) {
    recordRedirect(response: response, request: request)
    let selector = #selector(
      URLSessionTaskDelegate.urlSession(
        _:
        task:
        willPerformHTTPRedirection:
        newRequest:
        completionHandler:
      )
    )
    if let forwardingDelegate, forwardingDelegate.responds(to: selector) {
      forwardingDelegate.urlSession?(
        session,
        task: task,
        willPerformHTTPRedirection: response,
        newRequest: request,
        completionHandler: completionHandler
      )
    } else {
      completionHandler(request)
    }
  }

  package func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler:
      @escaping @Sendable (
        URLSession.AuthChallengeDisposition,
        URLCredential?
      ) -> Void
  ) {
    let selector = #selector(
      URLSessionTaskDelegate.urlSession(
        _:
        task:
        didReceive:
        completionHandler:
      )
    )
    if let forwardingDelegate, forwardingDelegate.responds(to: selector) {
      forwardingDelegate.urlSession?(
        session,
        task: task,
        didReceive: challenge,
        completionHandler: completionHandler
      )
    } else {
      completionHandler(.performDefaultHandling, nil)
    }
  }

  package func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    needNewBodyStream completionHandler: @escaping @Sendable (InputStream?) -> Void
  ) {
    let selector = #selector(
      URLSessionTaskDelegate.urlSession(
        _:
        task:
        needNewBodyStream:
      )
    )
    if let forwardingDelegate, forwardingDelegate.responds(to: selector) {
      forwardingDelegate.urlSession?(
        session,
        task: task,
        needNewBodyStream: completionHandler
      )
    } else {
      completionHandler(nil)
    }
  }

  @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
  package func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    needNewBodyStreamFrom offset: Int64,
    completionHandler: @escaping @Sendable (InputStream?) -> Void
  ) {
    let selector = #selector(
      URLSessionTaskDelegate.urlSession(
        _:
        task:
        needNewBodyStreamFrom:
        completionHandler:
      )
    )
    if let forwardingDelegate, forwardingDelegate.responds(to: selector) {
      forwardingDelegate.urlSession?(
        session,
        task: task,
        needNewBodyStreamFrom: offset,
        completionHandler: completionHandler
      )
    } else {
      completionHandler(nil)
    }
  }

  // swiftlint:disable:next function_parameter_count
  package func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didSendBodyData bytesSent: Int64,
    totalBytesSent: Int64,
    totalBytesExpectedToSend: Int64
  ) {
    forwardingDelegate?.urlSession?(
      session,
      task: task,
      didSendBodyData: bytesSent,
      totalBytesSent: totalBytesSent,
      totalBytesExpectedToSend: totalBytesExpectedToSend
    )
  }

  @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
  package func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didReceiveInformationalResponse response: HTTPURLResponse
  ) {
    forwardingDelegate?.urlSession?(
      session,
      task: task,
      didReceiveInformationalResponse: response
    )
  }

  package func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: (any Error)?
  ) {
    forwardingDelegate?.urlSession?(session, task: task, didCompleteWithError: error)
  }
}
