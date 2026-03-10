# Artifact Index

## Created

- `AGENTS.md`
- `skills/modernnetworking-conventions/SKILL.md`
- `skills/modernnetworking-conventions/references/code-standards.md`
- `skills/modernnetworking-conventions/references/package-and-dependencies.md`
- `artifacts/skills/modernnetworking-conventions.skill`
- `skills/swift-testing-bdd/SKILL.md`
- `skills/swift-testing-bdd/references/migration-patterns.md`
- `artifacts/skills/swift-testing-bdd.skill`
- `docs/architecture-refactoring-execution-plan.md`
- `Packages/Networking/Sources/NetworkingCore/`
- `Packages/Networking/Sources/NetworkingRuntime/`
- `Packages/Networking/Sources/NetworkingDSL/`
- `Packages/Networking/Sources/NetworkingRuntimeDSL/`
- `Packages/Networking/Sources/NetworkingInterceptorsCompat/`
- `Packages/Networking/Sources/NetworkingObservability/`
- `Packages/Networking/Sources/NetworkingObservabilityOTLP/`
- `Packages/Networking/Sources/NetworkingTesting/`
- `Packages/Networking/Sources/NetworkingBDD/`
- `Packages/Networking/Sources/NetworkingBDDQuickSupport/`
- `Packages/Networking/Tests/NetworkingCoreTests/`
- `Packages/Networking/Tests/NetworkingRuntimeTests/`
- `Packages/Networking/Tests/NetworkingDSLTests/`
- `Packages/Networking/Tests/NetworkingInterceptorsCompatTests/`
- `Packages/Networking/Tests/NetworkingObservabilityTests/`
- `Packages/Networking/Tests/NetworkingTestingTests/`
- `Packages/Networking/Tests/NetworkingBDDTests/`
- `Packages/Networking/Sources/Networking/Networking.docc/Module-Migration.md`
- `Packages/NetworkingMacros/Sources/NetworkingMacrosDeclarations/`
- `.llm/context/`
- `.llm/context/plans/networking-modularization.md`
- `.llm/context/memory/repo-facts.md`
- `.llm/context/tool-outputs/20260310-validation-summary.md`

## Modified

- `RULES.md`
- `Packages/Networking/Package.swift`
- `Packages/NetworkingMacros/Package.swift`
- `Packages/Networking/Sources/Networking/Networking.swift`
- `Packages/Networking/Sources/Networking/Documentation.docc/Articles/TESTING_GUIDE.md`
- `Packages/Networking/Sources/Networking/Networking.docc/API-Reference.md`
- `Packages/Networking/Sources/Networking/Networking.docc/Getting-Started.md`
- `Packages/Networking/Sources/Networking/Networking.docc/Networking.md`
- `Packages/Networking/Tests/NetworkingTests/BDD/NetworkClientBehaviorSpec.swift`
- `Packages/Networking/Tests/NetworkingTests/NetworkClientTests.swift`
- `Packages/Networking/Tests/NetworkingTests/SimpleBDDTests.swift`
- `Packages/Networking/Tests/NetworkingTests/SimpleFluentTests.swift`
- `Packages/Networking/Tests/NetworkingTests/SimplePropertyTests.swift`
- `.llm/context/README.md`
- `.llm/context/current-plan.yaml`
- `.llm/context/session-summary.md`
- `.llm/context/artifact-index.md`
- `.llm/context/plans/networking-modularization.md`
- `.llm/context/memory/repo-facts.md`

## Read

- `AGENTS.md`
- `RULES.md`
- `docs/architecture-refactoring-execution-plan.md`
- `Packages/Networking/Package.swift`
- `Packages/NetworkingMacros/Package.swift`
- `skills/modernnetworking-conventions/SKILL.md`
- `skills/swift-testing-bdd/SKILL.md`
- `/Users/bruno/.codex/skills/filesystem-context/SKILL.md`
- `Packages/Networking/Sources/Networking/CLAUDE.md`
- `Packages/Networking/Tests/NetworkingTests/CLAUDE.md`
- `Packages/NetworkingMacros/CLAUDE.md`

## Deleted

- Legacy flat source files under `Packages/Networking/Sources/Networking/` for BDD, runtime,
  DSL, observability, testing helpers, and related support types are being removed or re-homed into
  split module targets.
- Legacy tests under `Packages/Networking/Tests/NetworkingTests/` are being deleted or rewritten as
  package-local tests owned by the new modules.
