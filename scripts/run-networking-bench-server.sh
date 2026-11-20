#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")/.." rev-parse --show-toplevel)"
command -v caddy >/dev/null || {
	echo "Install Caddy to provide local HTTP/1.1, HTTP/2, and HTTP/3." >&2
	exit 1
}
command -v python3 >/dev/null || {
	echo "python3 is required for the local benchmark origin." >&2
	exit 1
}

export XDG_CONFIG_HOME="${TMPDIR:-/tmp}/networking-benchmark-caddy-config"
export XDG_DATA_HOME="${TMPDIR:-/tmp}/networking-benchmark-caddy-data"

python3 "$ROOT/Benchmarks/NetworkingBenchmarkServer/server.py" &
origin_pid=$!
caddy run --config "$ROOT/Benchmarks/NetworkingBenchmarkServer/Caddyfile" --adapter caddyfile &
caddy_pid=$!
cleanup() {
	kill "$caddy_pid" "$origin_pid" 2>/dev/null || true
	wait "$caddy_pid" "$origin_pid" 2>/dev/null || true
}
trap cleanup EXIT INT TERM
wait "$caddy_pid"
