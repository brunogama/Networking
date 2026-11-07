import Foundation
import NetworkingCore
import NetworkingRuntime
import Testing

@Suite("Structured request tickets")
struct RequestTicketTests {
  @Test("Success consumes the ticket and makes retained cancellation inert")
  func successfulTicket() async throws {
    let request = try request()
    let result = try await ImmediateTicketClient().withRequest(request) { ticket in
      let cancellation = ticket.cancellation
      return (try await ticket.response(), cancellation)
    }
    #expect(result.0.status == .ok)
    #expect(!result.1.cancel())
  }

  @Test("A cancellation handle stops an active request and its waiter")
  func cancellationDuringWait() async throws {
    let client = ControlledTicketClient()
    let request = try request()
    let cancelled = await client.withRequest(request) { ticket in
      let cancellation = ticket.cancellation
      async let action: Void = Self.cancelWhenStarted(client, cancellation)
      do throws(HTTPError) {
        _ = try await ticket.response()
        await action
        return false
      } catch {
        await action
        return error.category == .cancelled
      }
    }
    #expect(cancelled)
    #expect(await client.didCancel)
    #expect(await client.didFinish)
  }

  @Test("Leaving the scope joins cancelled request work")
  func leavingScope() async throws {
    let client = ControlledTicketClient()
    await client.withRequest(try request()) { _ in
      for await _ in client.started { break }
    }
    #expect(await client.didCancel)
    #expect(await client.didFinish)
  }

  @Test("Cancelling the parent ends request work without a detached task")
  func parentCancellation() async throws {
    let client = ControlledTicketClient()
    let request = try request()
    await withTaskGroup(of: Void.self) { group in
      group.addTask {
        await client.withRequest(request) { ticket in
          do throws(HTTPError) {
            _ = try await ticket.response()
            Issue.record("Expected parent cancellation")
          } catch {
            #expect(error.category == .cancelled)
          }
        }
      }
      for await _ in client.started { break }
      group.cancelAll()
    }
    #expect(await client.didCancel)
    #expect(await client.didFinish)
  }

  @Test("The concrete client exposes typed HTTP failures and preserves their cause")
  func typedClientFailure() async throws {
    let client = NetworkClient(requestMiddlewares: [RejectingTicketMiddleware()])
    let execute: @Sendable (HTTPRequest) async throws(HTTPError) -> HTTPResponse = client.execute
    do {
      _ = try await execute(try request())
      Issue.record("Expected a middleware error")
    } catch let error as HTTPError {
      #expect(error.underlyingError is TicketTestFailure)
      guard case .custom(let domain, _) = error.category else {
        Issue.record("A middleware failure was misclassified as a network failure")
        return
      }
      #expect(domain.rawValue == "Middleware")
    }
  }

  private static func cancelWhenStarted(
    _ client: ControlledTicketClient,
    _ cancellation: RequestCancellation
  ) async {
    for await _ in client.started { break }
    #expect(cancellation.cancel())
    #expect(!cancellation.cancel())
  }

  private func request() throws -> HTTPRequest {
    HTTPRequest(
      method: .get,
      url: HTTPRequestURL(try #require(URL(string: "https://example.test/")))
    )
  }
}
