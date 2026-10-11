# 11 — AI Coding Assistant Brief

Use this file as the top-level prompt/context when beginning implementation with an AI coding assistant.

---

## Project

Build **Scope**, a native macOS shell configuration manager written in Swift and SwiftUI.

Scope manages persistent zsh configuration as structured data:

- environment variables;
- PATH entries;
- aliases;
- shell functions;
- profiles;
- machine-specific overrides.

The app must feel native to macOS and visually related to the developer's existing Relay app. Reference `assets/relay_visual_reference.png` and `assets/scope_final_icon_spec.png`.

## Critical architecture rule

Do **not** treat `.zshrc` as Scope's database and do not rewrite arbitrary user dotfiles.

Scope owns a generated file such as:

```text
~/.scope/generated.zsh
```

and installs only a narrowly marked `source` hook into the selected shell startup file.

Structured app data is the source of truth. The generated shell file is deterministic output.

## Initial implementation order

1. Create domain models and scope-composition rules.
2. Implement zsh serialization and escaping with tests.
3. Implement generated-file writing atomically.
4. Implement startup-hook detection/install/remove with backups.
5. Implement shell syntax validation.
6. Build a simple SwiftUI sidebar shell.
7. Build Environment UI.
8. Build PATH UI.
9. Build Alias UI.
10. Build Functions UI.
11. Add profiles and machine overrides.
12. Add generated-config preview and Apply workflow.
13. Add diagnostics.
14. Add temporary Test Configuration shell.
15. Add import.
16. Add iCloud/CloudKit last.

## Engineering preferences

- Prefer small, testable services over large view models.
- Keep shell escaping/generation out of views.
- Use dependency injection/protocols around filesystem, process launching, Keychain, and sync.
- Use async/await for I/O.
- Use OSLog and never log secrets.
- Add unit tests before expanding supported shell syntax.
- Keep generated output stable so snapshot/golden-file tests are possible.

## UI principles

- Dark native macOS aesthetic similar to Relay.
- Scope should be calmer and more configuration-oriented than Relay.
- Use translucent sidebar and blue/navy content surfaces.
- Cyan/blue with restrained violet accent.
- Mostly flat visual treatment; minimal glow.
- Use monospaced text for paths/code/variables.
- PATH is a drag-reorder list.
- Functions use a split list/editor layout.
- Do not put a full terminal permanently on the dashboard.
- “Test Configuration” may open a temporary terminal-like sheet.

## Safety principles

- Never overwrite a user file without backup.
- Never silently delete imported configuration lines.
- Validate generated config before Apply.
- Keychain secrets must not sync as plaintext.
- Conflict resolution should be explicit for meaningful concurrent edits.
- All Scope-owned changes should be reversible.

## Definition of done for MVP

A user can install Scope on one Mac, create/edit all four core configuration types, use Global/Profile/Machine scopes, preview and test the resulting zsh configuration, and apply it through a safe generated-file hook without hand-editing their dotfiles.
