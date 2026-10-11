# 10 — Roadmap

## Phase 0 — Foundation / prototype

Goal: prove the shell integration model before polishing the full UI.

Deliverables:

- zsh detection;
- config file discovery;
- local data model;
- deterministic generator;
- safe generated-file output;
- hook installation/removal;
- syntax validation;
- unit tests for quoting and composition.

Exit criteria: Scope can create a few config objects and safely apply them to a test account/environment.

## Phase 1 — Core local app

Goal: useful standalone app without sync.

Deliverables:

- Overview;
- Environment editor;
- PATH editor with reorder and validation;
- Alias editor;
- Function editor;
- Global/Profile/Machine scopes;
- pending changes state;
- generated config preview;
- Apply flow;
- basic diagnostics;
- backups.

Exit criteria: developer can use Scope daily on one Mac without editing their Scope-owned file manually.

## Phase 2 — Test + import

Goal: make adoption safer and easier.

Deliverables:

- temporary test shell;
- import scanner for common zsh patterns;
- review-before-import UI;
- duplicate/conflict warnings;
- clearer diagnostics.

Exit criteria: an existing zsh user can migrate selectively without risking their current config.

## Phase 3 — iCloud sync

Goal: make Scope compelling across multiple Macs.

Deliverables:

- CloudKit opt-in;
- portable record sync;
- machine registry;
- per-machine overrides;
- conflict UI;
- missing-secret state;
- sync status and error handling.

Exit criteria: two Macs can share general config while preserving machine-local differences.

## Phase 4 — Polish / beta readiness

Deliverables:

- keyboard shortcuts;
- macOS menu commands;
- accessibility pass;
- onboarding polish;
- empty states;
- performance pass;
- crash/error telemetry strategy if desired;
- icon/export assets;
- App Store/notarization readiness.

## Later possibilities

Only pursue after the core model feels solid:

- Bash support;
- fish support;
- project `.env` management;
- Git-backed storage/export;
- menu bar quick access;
- configuration snapshots/history browser;
- shareable profile templates;
- package-manager-aware PATH recommendations;
- GUI-app environment support through a carefully designed mechanism.
