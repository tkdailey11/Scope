# Scope — Product Design Pack

Scope is a native macOS shell-configuration manager for environment variables, PATH entries, aliases, shell functions, profiles, machine-specific overrides, and optional iCloud sync.

This pack is intended to be usable directly with an AI coding assistant. It captures product intent, UX, visual language, architecture, data model, shell integration strategy, sync behavior, and a staged implementation roadmap.

## Design anchors

- **Platform:** macOS, native SwiftUI-first experience.
- **Audience:** developers and power users who want a safer, clearer alternative to hand-editing shell dotfiles.
- **Core promise:** manage persistent shell configuration visually without hiding or taking ownership of the rest of the user's shell setup.
- **Design family:** should feel recognizably related to Relay without looking like a second terminal emulator.
- **Primary visual reference:** `assets/relay_visual_reference.png`
- **Final icon spec:** `assets/scope_final_icon_spec.png`

## Recommended reading order

1. `01_Product_Vision.md`
2. `02_Product_Requirements.md`
3. `03_Information_Architecture.md`
4. `04_UX_Flows.md`
5. `05_Visual_Design_System.md`
6. `06_Technical_Architecture.md`
7. `07_Data_Model.md`
8. `08_Sync_Architecture.md`
9. `09_Shell_Integration.md`
10. `10_Roadmap.md`
11. `11_AI_Coding_Assistant_Brief.md`
12. `12_Decisions_and_Open_Questions.md`

## MVP definition

A strong v1 should let a user:

- discover their current shell and existing configuration files;
- manage environment variables;
- manage PATH as an ordered list;
- manage aliases;
- manage shell functions;
- organize configuration into Global, Profile, and Machine scopes;
- preview the generated shell configuration;
- test the proposed configuration in an isolated shell;
- apply it safely by sourcing a Scope-managed generated file from the user's existing shell configuration;
- optionally sync portable configuration with iCloud;
- keep secrets in Keychain rather than syncing plaintext values.

## Non-goals for v1

- becoming a complete dotfiles manager;
- replacing terminal emulators;
- rewriting arbitrary user-maintained `.zshrc` content;
- supporting every shell on day one;
- automatic conflict resolution that silently overwrites user changes;
- managing system-wide privileged environment configuration.
