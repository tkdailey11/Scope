# 02 — Product Requirements

## Core entities

Scope manages six first-class concepts:

1. **Environment Variables**
2. **PATH Entries**
3. **Aliases**
4. **Shell Functions**
5. **Profiles**
6. **Machines**

Secrets are a storage behavior applied to environment variables rather than a separate primary entity.

## Functional requirements

### Environment Variables

- Add, edit, delete, enable, and disable variables.
- Name validation compatible with shell variable rules.
- Values support plain text and references such as `$HOME`.
- Optional secure storage in macOS Keychain.
- Show effective scope: Global, Profile, or Machine.
- Show source/ownership: Scope-managed, imported, or detected-only.
- Mask secret values by default.
- Copy variable name/value through explicit actions.

### PATH Management

- Display PATH as ordered rows rather than a colon-delimited string.
- Drag to reorder user-managed entries.
- Add and remove entries.
- Expand `~` and variables for validation while preserving user-authored form.
- Detect duplicate entries.
- Detect missing directories.
- Distinguish system/base PATH entries from Scope additions.
- Show which profile or machine contributes each entry.
- Preview effective PATH after composition.

### Aliases

- Add, edit, delete, enable, and disable aliases.
- Show alias name, command, scope, and status.
- Validate alias name.
- Detect duplicate/conflicting alias definitions.
- Search and filter.

### Functions

- Create named shell functions.
- Code editor with monospaced text and lightweight syntax highlighting.
- Validate syntax before apply when practical.
- Enable/disable and scope functions.
- Duplicate/conflict detection.

### Profiles

- Global profile always exists.
- User-created profiles such as Work or Personal.
- One or more profiles may be active depending on final product decision; MVP recommendation is one active named profile plus Global plus Machine overrides.
- Profile changes should clearly show inheritance.
- Per-item scope should be visible at a glance.

### Machines

- Assign a stable local machine identifier.
- Display human-readable machine name.
- Allow machine-only overrides.
- Machine-specific items should not become portable unless explicitly converted.

### Configuration preview

- Show generated `.zsh` content.
- Allow copying generated content.
- Show an effective configuration summary before applying changes.
- Present validation warnings/errors.

### Test Configuration

- Launch an isolated temporary shell using the proposed generated config.
- Do not modify the user's active config simply to test.
- Provide a small terminal-like sheet/window for commands such as `echo $PATH`, `which node`, or alias testing.
- Make it obvious the test shell is temporary.

### Apply

- Write generated configuration atomically.
- Ensure a Scope source hook exists in the appropriate shell startup file.
- Back up files before first modification and before any migration/removal operation.
- Report whether a new shell is required for changes to take effect.

### Import

MVP import should be conservative.

- Detect likely aliases, exports, PATH modifications, and simple functions from common zsh files.
- Present imports for review before creating Scope-managed entries.
- Never delete imported source lines automatically in the first release.
- Allow the user to mark duplicates as intentionally ignored.

### iCloud Sync

- Optional, off until the user enables it.
- Sync portable configuration records.
- Never sync Keychain secret values through the configuration record.
- Support explicit conflict resolution.
- Machine-only items remain local.

## Quality requirements

- Generated config should be deterministic.
- All destructive actions should be reversible through backup/history where practical.
- App launch should not require spawning a shell unless discovery/validation is running.
- Basic management UI should remain functional even if the current shell config contains invalid syntax.
