# 01 — Product Vision

## One-line description

**Scope is a native macOS app for visually managing persistent shell configuration across variables, PATH entries, aliases, functions, profiles, and Macs.**

## Problem

On macOS, persistent shell configuration is fragmented across files and mechanisms such as `.zshrc`, `.zprofile`, `.profile`, project `.env` files, and `launchd` behavior. Experienced developers can manage these manually, but the workflow is still opaque, error-prone, and difficult to sync cleanly across machines.

Common pain points:

- PATH is edited as one long string rather than as structured data.
- The same setting may be duplicated across multiple startup files.
- Users forget whether a value applies to interactive shells, login shells, GUI apps, a single machine, or a project.
- Dotfiles syncing tends to be all-or-nothing.
- Secrets should not be placed casually in plaintext config files or cloud sync.
- A malformed shell startup file can make a terminal session unpleasant or unusable.

## Product thesis

The shell configuration itself should be treated as structured data, while the generated shell file remains transparent and inspectable.

Scope should make common changes easy without pretending shell syntax does not exist. Advanced users should always be able to see exactly what Scope is generating.

## Product principles

### 1. Native first
Scope should feel like a high-quality Mac utility: fast launch, keyboard-friendly controls, native typography, standard interactions, and restrained use of visual effects.

### 2. Safe by default
Scope should never casually rewrite an entire `.zshrc`. It should own a dedicated generated file and add a clearly marked source hook to the user's shell startup file.

### 3. Transparent
Every UI action should map to visible shell output. Users should be able to inspect the generated config at any time.

### 4. Structured where structure helps
PATH should be a reorderable list. Aliases should be key/value rows. Functions should use a code editor. Profiles should compose predictably.

### 5. Portable, not blindly identical
A user's laptop and desktop may share most settings but differ in a few paths, tools, or secrets. Sync should support inheritance and machine-specific overrides.

### 6. Secrets are different
Secret values belong in Keychain and should never be silently copied into iCloud or plaintext config.

## Primary users

### Developer who wants convenience
Comfortable with the shell but tired of editing dotfiles for simple tasks.

### Developer with multiple Macs
Wants aliases, functions, and general environment setup shared while keeping machine-specific paths local.

### Newer technical user
Understands environment variables conceptually but does not yet know which shell file to edit.

## Product personality

Scope should feel:

- precise;
- calm;
- modern;
- technical without being intimidating;
- transparent rather than magical.

It should not feel:

- like a toy;
- like a terminal skin;
- like a corporate admin console;
- like a full IDE.
