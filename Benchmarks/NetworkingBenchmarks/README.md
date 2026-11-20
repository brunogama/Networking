# Networking Performance Lab

This macOS SwiftUI app measures the repository's `NetworkClient` request,
file-transfer, and `SSEClient` paths. It records median and p95 latency,
approximate payload throughput, and the actual protocol names reported by
`URLSessionTaskMetrics`. Request, single-upload, and download workloads receive
three warm-up operations; batch upload receives one warm-up batch. Concurrent
batch uploads exercise aggregate progress callbacks; a second run deliberately
blocks the callback for 1 ms to expose progress-event queue pressure in
Instruments. A slow SSE consumer uses a bounded event buffer and records its
expected overflow. This tests bounded buffering, not upstream transport
suspension. Single-stream samples have no p95.

---

## Run the local server

Install Caddy, then run:

```sh
brew install caddy
bash scripts/run-networking-bench-server.sh
```

The fixture binds only to loopback. Python serves deterministic request,
upload, download, and SSE payloads. The batch-upload endpoint drains request
bodies slowly and responds with a small acknowledgement to create multiple
progress updates without buffering large responses. Caddy serves cleartext
HTTP/1.1 at
`http://localhost:18181` and local TLS at `https://localhost:18443`, advertising
HTTP/2 and HTTP/3. The app accepts a test certificate only for `localhost` and
`127.0.0.1`. Do not use this trust delegate for production.

---

## Run the app

The benchmark package defines no targets or dependencies unless
`NETWORKING_BUILD_BENCHMARKS=1` is set. This keeps benchmark sources out of
ordinary package builds and test runs. Set the variable on every SwiftPM command
that builds or tests the benchmark:

```sh
NETWORKING_BUILD_BENCHMARKS=1 swift run \
  --package-path Benchmarks \
  --configuration release \
  NetworkingBenchmarks
```

Run the benchmark's unit tests with:

```sh
NETWORKING_BUILD_BENCHMARKS=1 swift test --package-path Benchmarks
```

The default endpoint is `https://localhost:18443`. Use the Run button. To compare
protocols, run the app once per endpoint and preserve each command with its JSON
output:

```sh
NETWORKING_BUILD_BENCHMARKS=1 NETWORKING_BENCH_URL=http://localhost:18181 \
  swift run --package-path Benchmarks --configuration release \
  NetworkingBenchmarks --benchmark-and-exit --output=/tmp/networking-http1.json
NETWORKING_BUILD_BENCHMARKS=1 NETWORKING_BENCH_URL=https://localhost:18443 \
  swift run --package-path Benchmarks --configuration release \
  NetworkingBenchmarks --benchmark-and-exit --output=/tmp/networking-tls.json
```

TLS protocol selection remains controlled by URLSession, so results report
observed protocols rather than claiming each request used every advertised
protocol. The command exits nonzero when a workload, payload check, or JSON write
fails. Requests, uploads, downloads, and SSE verify fixture payload counts;
upload fixtures acknowledge only after reading the full expected body. Transfer
responses pass through the client's response middleware and status validation.
Upload throughput counts bytes sent, download throughput counts bytes received,
and SSE throughput counts its 40-byte wire event lines. Batch upload uses eight
concurrent 8 MiB files, one warm-up batch, and three measured batches. A second
batch holds the progress callback for 1 ms per event; this is a deliberate stress
workload, not representative callback guidance. The current batch progress stream
uses `AsyncStream`'s unbounded default, so this probes retained-event allocation
but does not report exact queue depth. The slow-consumer SSE run uses a 32-event
buffer and delays each consumer; stream overflow is expected.

---

## Record Instruments traces

Build once, then launch the benchmark under Instruments. The app writes JSON
and exits with `--benchmark-and-exit`. Use `--benchmark-profile` for memory
traces; it leaves the completed app open until the recording time limit ends.

```sh
NETWORKING_BUILD_BENCHMARKS=1 swift build \
  --package-path Benchmarks \
  --configuration release \
  --product NetworkingBenchmarks
xcrun xctrace record \
  --template Allocations \
  --time-limit 20s \
  --output /tmp/networking-allocations.trace \
  --launch -- Benchmarks/.build/release/NetworkingBenchmarks \
  --benchmark-profile --output=/tmp/networking-allocations.json

xcrun xctrace record \
  --template Leaks \
  --time-limit 25s \
  --output /tmp/networking-leaks.trace \
  --launch -- Benchmarks/.build/release/NetworkingBenchmarks \
  --benchmark-profile --output=/tmp/networking-leaks.json
```

Allocations also records VM Tracker snapshots. Open a trace with
`open -a Instruments <trace-path>`. Preserve JSON, traces, and Xcode/Swift
versions when comparing changes. A local loopback run is a code-path baseline,
not a substitute for measurements on a representative network or device.
