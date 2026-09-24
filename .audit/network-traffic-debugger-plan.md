# Network traffic debugger plan

The debugger records only data requests made by `NetworkClient`. It is opt in. A caller can inspect a bounded, ordered history of physical requests, redirects, URLSession transaction timings, responses, and transport failures. Default records do not retain query values, credential headers, or body contents.

The change affects `Packages/Networking` only. It does not change the macro package or create a device proxy.

1. Establish the baseline with the existing `NetworkClientTests` suite on the isolated branch.
2. Add an end to end test that sends a request through `NetworkClient` and checks a safe request and response record. Add a real URLSession redirect and timing check where the platform supports it.
3. Add a small recorder model in `NetworkingRuntime`. Attach a per-task delegate to `data(for:delegate:)` and convert Foundation metrics into Sendable values before storing them.
4. Pass the recorder through both direct and builder initialization, including the inner clients used by retries and authentication. Record each physical attempt in its observed order.
5. Check success, failure, redirects, retries, privacy defaults, bounded retention, and concurrency with the tests. Format and lint each changed Swift file, then run the required warnings-as-errors build and full package tests.

The per-task delegate keeps the caller's URLSession and its session delegate. A session-owned delegate hub would require replacing custom sessions and rewriting the transport and pinning path. Connection phase fields remain optional because URLSession can omit them for reused connections, cache hits, or custom protocols.

The final review checks the diff, the test output, and the records from an actual URLSession request. A passing build alone does not satisfy the acceptance check.
