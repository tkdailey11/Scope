# 04 — UX Flows

## First launch

1. Welcome screen explains that Scope manages a dedicated generated config and does not replace the user's full dotfiles.
2. Detect current login shell.
3. Inspect common startup files in read-only mode.
4. Show findings:
   - shell;
   - likely config files;
   - detected aliases/exports/PATH edits/functions;
   - whether a Scope hook is already installed.
5. Offer:
   - Start Fresh;
   - Review Import.
6. User chooses whether to enable iCloud sync later; do not make sync a prerequisite.
7. Scope creates its local data store and generated config location only when setup is confirmed.

## Add environment variable

1. User clicks Add Variable.
2. Sheet fields:
   - Name;
   - Value;
   - Scope;
   - Enabled;
   - Store securely in Keychain.
3. If Keychain is selected, config record stores only a secret reference.
4. Validate name and obvious syntax issues.
5. Save.
6. Overview/apply state becomes “Changes pending.”
7. User can Preview, Test, or Apply.

## Add PATH entry

1. Add Directory.
2. Enter path or choose directory.
3. Scope checks:
   - exists?;
   - already in effective PATH?;
   - machine-specific-looking absolute path?;
4. User chooses scope.
5. Entry appears in ordered list and can be dragged.
6. Preview shows resulting effective order.

## Add alias

1. Add Alias.
2. Enter name and command.
3. Scope checks conflicts with another Scope alias and optionally whether a command of the same name exists.
4. User chooses scope.
5. Save and optionally Test.

## Add/edit function

1. Add Function.
2. Enter function name.
3. Edit body in code editor.
4. Validate shell syntax in a safe subprocess.
5. Save.
6. Optional Test Configuration opens temporary shell.

## Apply configuration

1. User clicks Apply.
2. Scope generates deterministic config in memory.
3. Validate generated shell syntax.
4. Resolve Keychain placeholders to safe runtime loading strategy.
5. Write temp file.
6. Atomically replace Scope-owned generated file.
7. Ensure startup hook exists.
8. Report success and whether existing shells need reload/new session.

## Test Configuration

1. User selects Test Configuration.
2. Scope generates pending config without committing it.
3. Spawn a temporary zsh process using an isolated startup environment.
4. Present a compact terminal sheet.
5. User can run commands against the proposed state.
6. Closing the sheet terminates the process and discards temporary files.

## Sync conflict

1. Cloud record changes conflict with local edit.
2. Do not silently select a winner for user-authored content.
3. Present side-by-side values with metadata:
   - Local Mac;
   - Other Mac/cloud version;
   - modification date;
   - scope.
4. User chooses Local, Cloud, or Duplicate/Keep Both when valid.
5. Recompute effective configuration and show any new conflicts.

## Import existing config

1. Scope parses only patterns it understands with high confidence.
2. Display candidate items grouped by file and type.
3. User selects items to import.
4. Imported items are created in Scope but original lines remain untouched.
5. After user verifies Scope output, a later advanced workflow may offer cleanup guidance rather than automatic destructive edits.
