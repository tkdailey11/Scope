#!/bin/bash
# Print the version the next release ships as: VERSION's major.minor plus the next unused patch.
#
# Release tags (v1.0.1, v1.0.2, ...) are the record of which patch numbers are taken, so the
# next release is one past the highest tag in VERSION's series, or .1 if there is none yet.
# Changing VERSION to 1.1 starts a new series at 1.1.1.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

series="$(tr -d '[:space:]' < VERSION)"
if [[ ! "$series" =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "VERSION must be major.minor, such as 1.0; found '$series'." >&2
    exit 1
fi

# A local checkout may not have tags made by CI; a release must not reuse a published number.
git fetch --tags --quiet 2>/dev/null || echo "warning: could not fetch tags; using local tags only" >&2

last="$(git tag --list "v$series.*" | sed -nE "s/^v${series//./\\.}\.([0-9]+)$/\1/p" | sort -n | tail -1)"
echo "$series.$(( ${last:-0} + 1 ))"
