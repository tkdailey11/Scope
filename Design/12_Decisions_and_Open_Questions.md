# 12 — Decisions and Open Questions

## Decisions already made / strongly favored

- Product name: **Scope**.
- Native macOS app.
- Visual family should relate to Relay.
- Final icon direction: refined **Hybrid 1** reticle.
- Flat/modern rendering; little or no glow.
- Environment variables, PATH, aliases, and functions are first-class concepts.
- Profiles and machine-specific configuration are important.
- Optional iCloud sync is a core differentiator.
- Secrets should use Keychain and should not sync as plaintext.
- Scope should generate its own shell file rather than own the entire `.zshrc`.
- Terminal functionality belongs primarily in a temporary Test Configuration workflow, not permanently on Overview.

## Product questions to resolve before beta

### Active profiles
Should users be able to activate exactly one named profile at once, or compose multiple profiles?

**Recommendation for MVP:** one active named profile + Global + Machine. Multi-profile composition adds conflict and ordering complexity that can come later.

### Shell expression vs literal variable values
Should an environment variable value be treated as:

- a literal string;
- a shell expression;
- selectable per item?

**Recommendation:** explicitly support a value mode rather than guessing. Start with literal and expandable-expression modes if implementation remains understandable.

### Where to install the source hook
The exact zsh startup file policy needs testing across common terminal launch modes.

**Recommendation:** implement a shell-startup discovery service and make the chosen file visible to the user.

### Secret injection strategy
If a secret is stored in Keychain, decide how generated shell config obtains it without writing plaintext to disk.

Options include:

- command substitution invoking a Scope helper;
- environment injection at shell launch only;
- generated references to a secure helper executable.

This deserves a dedicated security design before implementation.

### App Store sandboxing
Direct modification of shell configuration and launching subprocesses may influence distribution/sandbox choices.

Resolve early whether Scope is intended for:

- Mac App Store;
- direct distribution/notarization;
- both with capability differences.

### Import depth
Start conservative. Avoid promising arbitrary shell parsing until there is a robust parser strategy.

## Nice-to-have questions

- Git export/backend?
- Project `.env` files?
- Menu bar item?
- Snapshot/history timeline?
- URL scheme / Shortcuts actions?
- Export a human-readable “machine setup” report?
- Share profiles between users?
