import Foundation
import NetworkingCore
/// A ticket identity, distinct from the request and its transport attempts.
public typealias RequestTicketID = Identifier<RequestTicketDomain, UUID>

/// Unique ownership of a scoped request's result or cancellation transition.
///
/// Use `withRequest(_:operation:)` to obtain a running ticket. A ticket cannot be copied or reused
/// after awaiting its response or cancelling it. External completion is checked at runtime.
public struct RequestTicket<Phase>: ~Copyable, Sendable {
  let control: RequestCancellation

  /// The identity of this ticket.
  public var id: RequestTicketID { control.id }
  /// A shareable cancellation capability for UI actions while the ticket awaits a response.
  public var cancellation: RequestCancellation { control }
}

extension RequestTicket where Phase == RequestPending {
  consuming func start() -> RequestTicket<RequestRunning> {
    RequestTicket<RequestRunning>(control: control)
  }
}

extension RequestTicket where Phase == RequestRunning {
  /// Consumes the ticket and awaits its response.
  ///
  /// The first terminal result wins, including races between cancellation and completion.
  /// - Throws: `HTTPError`, with `.cancelled` when cancellation wins.
  public consuming func response() async throws(HTTPError) -> HTTPResponse {
    let result = await control.value()
    return try result.get()
  }

  /// Consumes the ticket and requests cancellation.
  ///
  /// Returns false if a terminal result won the race; cancellation is cooperative.
  @discardableResult
  public consuming func cancel() -> Bool { control.cancel() }
}
