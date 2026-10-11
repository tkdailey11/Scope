# 03 — Information Architecture

## Recommended sidebar

```text
Scope

Configuration
  Overview
  Environment
  PATH
  Aliases
  Functions

Profiles
  Global
  Work
  Personal
  + Add Profile

Machines
  This Mac
  Other synced Macs…

Sync
  iCloud

Utilities
  Diagnostics
  Backups
```

## Navigation philosophy

The sidebar separates **what is being configured** from **where it applies**.

- Configuration pages answer: “What kind of thing am I editing?”
- Profiles and Machines answer: “Where does this apply?”
- Filters within each configuration page allow quick scope narrowing.

## Overview screen

The Overview screen should be useful, not decorative.

Recommended content:

- Active profile card.
- Shell card: detected shell and version.
- Configuration status: valid / warnings / errors.
- Counts: variables, PATH additions, aliases, functions.
- Effective configuration summary.
- Last sync state if iCloud is enabled.
- Primary actions:
  - Add configuration item
  - Test Configuration
  - View Generated Config

Avoid making the Overview a terminal emulator. Relay already owns that interaction pattern.

## Environment screen

Primary table columns:

- Name
- Value
- Scope
- Storage
- Enabled

Toolbar:

- Search
- Scope filter
- Add Variable

Selecting a row opens inspector/editor behavior in either a sheet or right-side detail panel.

## PATH screen

Primary content is a reorderable list.

Each row may show:

- drag handle;
- position;
- path;
- validation status;
- scope badge;
- source badge;
- context menu.

Warnings appear inline below affected rows or in a compact issue card.

## Aliases screen

Table layout similar to Environment:

- Alias
- Command
- Scope
- Enabled

## Functions screen

Two-column layout is recommended:

- left: searchable list of function names and scope;
- right: code editor and metadata.

This keeps longer function bodies readable.

## Diagnostics

Diagnostics should answer “Why isn't this working?”

Examples:

- detected shell;
- shell startup file chain;
- whether Scope's generated file exists;
- whether the source hook is present;
- invalid generated syntax;
- duplicate PATH entries;
- missing PATH directories;
- aliases shadowing commands;
- variable conflicts;
- iCloud sync status.
