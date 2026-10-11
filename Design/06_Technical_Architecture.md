# 06 — Technical Architecture

## Recommended stack

- Swift
- SwiftUI
- AppKit bridging only where needed
- SwiftData or Core Data for structured local configuration
- CloudKit for optional iCloud sync
- Security / Keychain Services for secrets
- `Process` for shell validation/testing subprocesses
- `FileManager` for generated config and backups

## Target architecture

Use a layered architecture that keeps shell mutation isolated from UI code.

```text
UI / SwiftUI
    ↓
Application Services
    ↓
Domain Model
    ↓
Infrastructure
  ├── Persistence
  ├── CloudKit Sync
  ├── Keychain
  ├── Shell Parser / Generator
  ├── File System
  └── Process Runner
```

## Suggested modules

### ScopeDomain
Pure Swift types and rules:

- EnvironmentVariable
- PathEntry
- Alias
- ShellFunction
- Profile
- Machine
- ScopeTarget
- ValidationIssue
- EffectiveConfiguration

### ScopePersistence
- Local model storage.
- Migration/versioning.
- History metadata.

### ScopeShell
- Shell discovery.
- Startup file discovery.
- Parser for supported import patterns.
- Deterministic generator.
- Syntax validator.
- Test-shell launcher.

### ScopeSecrets
- Keychain read/write/delete.
- Secret references.
- No plaintext secret logging.

### ScopeSync
- CloudKit records.
- Merge/conflict detection.
- Sync state.

### ScopeApp
- SwiftUI views.
- View models / observable app state.
- Command/menu integration.

## Concurrency

Use async/await for:

- filesystem scans;
- shell subprocesses;
- CloudKit operations;
- Keychain reads where wrapped asynchronously.

Keep generated configuration computation deterministic and ideally pure/synchronous once inputs are loaded.

## Safety boundaries

The app should distinguish three file categories:

1. **Scope-owned** — safe to replace atomically.
2. **User-owned startup files** — modify only narrowly to insert/remove Scope's marked hook.
3. **Detected external config** — read-only unless a future explicit migration feature is used.

## Logging

Use structured logging with OSLog.

Never log:

- secret values;
- full generated configuration if it can contain resolved secrets;
- clipboard contents.
