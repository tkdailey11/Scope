# 08 — Sync Architecture

## Goals

- Make portable shell configuration available across a user's Macs.
- Preserve machine-specific differences.
- Avoid syncing secrets as plaintext.
- Make conflicts understandable.

## Recommended approach

Use CloudKit-backed sync for structured Scope records rather than syncing a generated `.zsh` file.

The generated file is an output artifact and should be rebuilt locally on every Mac.

## What syncs

Recommended syncable records:

- Profiles
- Environment variable metadata and non-secret values
- PATH entries that are not machine-only
- Aliases
- Functions
- User preferences related to shared configuration

## What does not sync

- Keychain secret values
- Machine-only configuration
- Generated shell files
- Local backups
- Temporary test configuration
- Machine-local diagnostics

## Secret behavior

A secret-backed variable can sync its metadata:

```text
OPENAI_API_KEY
storage: keychain
scope: Work
```

But each Mac must independently provide the Keychain value.

UI should show a state such as:

> Secret required on this Mac

rather than silently disabling the variable.

## Conflict model

Conflicts matter most when the same record is edited independently.

For MVP:

- use stable record IDs;
- store modified timestamps and device metadata;
- detect incompatible concurrent edits;
- surface a user resolution sheet.

Avoid automatic last-write-wins for function bodies and alias commands where an edit could be meaningful.

## Offline behavior

All editing should work offline.

Cloud sync should reconcile later and should never block local configuration management.

## Profile portability

Profiles are portable by default.

Machine-specific overrides remain outside shared profile records. This allows:

```text
Global
  EDITOR=nvim
  alias gs='git status'

Work
  AWS_PROFILE=work
  PATH += ~/work/bin

This Mac
  JAVA_HOME=/Library/Java/...
```
