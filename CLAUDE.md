# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project state

Scope is a native macOS (SwiftUI) shell-configuration manager for zsh: env vars, PATH, aliases, functions, profiles, machine overrides, optional iCloud sync. The Xcode project is currently the unmodified template (`ScopeApp.swift` + placeholder `ContentView.swift`); the real intent lives in `Design/`.

**Read `Design/` before implementing anything.** Start with `Design/11_AI_Coding_Assistant_Brief.md` (architecture rules + the 16-step implementation order) and `Design/00_README.md` (MVP and non-goals). Other docs: `06_Technical_Architecture`, `07_Data_Model`, `08_Sync_Architecture`, `09_Shell_Integration`, `05_Visual_Design_System`, `12_Decisions_and_Open_Questions`. Visual references are in `Design/assets/`.

## Build / test

Single Xcode project, scheme `Scope`, macOS only (deployment target 26.0, Swift 5 mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, file-system-synchronized groups, so new files in `Scope/` are picked up without editing the pbxproj).

```sh
xcodebuild -project Scope.xcodeproj -scheme Scope build
xcodebuild -project Scope.xcodeproj -scheme Scope test                      # unit + UI tests
xcodebuild -project Scope.xcodeproj -scheme Scope test -only-testing:ScopeTests
xcodebuild -project Scope.xcodeproj -scheme Scope test -only-testing:ScopeTests/ScopeTests/example   # single test
```

Unit tests use Swift Testing (`import Testing`, `@Test`, `#expect`), not XCTest. `ScopeUITests` uses XCTest.

Because the default actor isolation is MainActor, pure domain/serialization types and services meant for background use must be explicitly marked `nonisolated` (or `Sendable`) to be testable and usable off the main actor.

## Architecture rules (from the design pack)

- **Structured app data is the source of truth.** Never treat `.zshrc` as the database or rewrite user dotfiles. Scope writes a deterministic generated file (e.g. `~/.scope/generated.zsh`) atomically and only inserts/removes a narrowly marked `source` hook in the user's startup file, always with a backup.
- Layering: SwiftUI → application services → domain model → infrastructure (persistence, CloudKit, Keychain, shell parser/generator, filesystem, process runner). Keep shell escaping/generation out of views; put filesystem, process, Keychain, and sync behind protocols for injection.
- Three file categories: Scope-owned (replace atomically), user-owned startup files (hook only), detected external config (read-only).
- Config is composed from Global → Profile → Machine scopes into an `EffectiveConfiguration`; generated output must be stable/deterministic to allow golden-file tests.
- Secrets live in Keychain, never synced or logged as plaintext. Use OSLog; never log secret values or resolved generated config.
- Validate generated config (shell syntax check) before Apply; imports must never silently drop user lines.

## Things to watch

- The app target has `ENABLE_APP_SANDBOX = YES`. Writing to `~/.scope/` and editing `~/.zshrc`, plus launching `Process` shells, will need entitlement/user-granted-access decisions; check `Design/09_Shell_Integration.md` and `12_Decisions_and_Open_Questions.md` before choosing an approach.
- Use the `swiftui-pro` skill when writing or reviewing SwiftUI code.
