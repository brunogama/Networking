# Networking Modularization Plan

Last updated: `2026-03-10`
Scope: `Packages/Networking`
Source of truth: `docs/architecture-refactoring-execution-plan.md`

## Target Graph

- `Networking` compatibility umbrella
- `NetworkingCore`
- `NetworkingRuntime`
- `NetworkingDSL`
- `NetworkingRuntimeDSL`
- `NetworkingInterceptorsCompat`
- `NetworkingObservability`
- `NetworkingObservabilityOTLP`
- `NetworkingTesting`
- `NetworkingBDD`
- `NetworkingBDDQuickSupport`

## Immediate Checkpoints

1. Confirm each split target owns the right files and declared dependencies. Completed.
2. Finish moving legacy implementation files out of `Sources/Networking/` into owned module
   directories. Completed for the current buildable graph.
3. Re-home tests into package-local targets and leave `NetworkingTests` as umbrella compatibility
   coverage only. Completed for the current buildable graph.
4. Rebuild and retest `Packages/Networking` with `--package-path`. Completed.
5. Capture logs in `.llm/context/tool-outputs/` and update `session-summary.md`. Completed.

## Constraints

- Keep `Networking` as the consumer-facing umbrella during the first migration.
- Middleware is the canonical extension path.
- Interceptors are compatibility-only and should not receive new feature work.
- Keep Quick/Nimble isolated in `NetworkingBDDQuickSupport`.
- Do not use root `swift test` as a validation signal.

## Known Risks

- The worktree mixes large file moves, test migration, docs edits, and skill work.
- Package boundaries may still expose accidental dependencies until build/test is rerun.
- Some legacy tests are still being edited in place while split test targets are added.

## Validation Status

- `Packages/Networking` build passed with `-warnings-as-errors`.
- `Packages/Networking` tests passed in the modularized package graph.
- `Packages/NetworkingMacros` build passed with `-warnings-as-errors`.
- `Packages/NetworkingMacros` tests passed with 131 passing tests.
