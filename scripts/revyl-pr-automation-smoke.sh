#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRANCH="${REVYL_SMOKE_BRANCH:-codex/revyl-pr-automation-smoke}"
REMOTE="${REVYL_SMOKE_REMOTE:-origin}"
TARGET_FILE="${REVYL_SMOKE_FILE:-docs/revyl-pr-automation-smoke.md}"
COMMIT_MESSAGE="${REVYL_SMOKE_COMMIT_MESSAGE:-Trigger Revyl PR automation smoke}"

cd "$ROOT_DIR"

current_branch="$(git branch --show-current)"
if [[ "$current_branch" != "$BRANCH" ]]; then
  if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    git switch "$BRANCH"
  else
    echo "Branch '$BRANCH' was not found locally." >&2
    echo "Create the PR branch first, or set REVYL_SMOKE_BRANCH to an existing branch." >&2
    exit 2
  fi
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Working tree has local changes. Commit or stash them before triggering the smoke commit." >&2
  git status --short >&2
  exit 2
fi

timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
mkdir -p "$(dirname "$TARGET_FILE")"

cat >"$TARGET_FILE" <<EOF
# Revyl PR Automation Smoke Trigger

Last trigger: $timestamp

This file is intentionally updated by \`scripts/revyl-pr-automation-smoke.sh\`
to create a tiny commit that re-runs Revyl GitHub PR automation.
EOF

git add "$TARGET_FILE"
git commit -m "$COMMIT_MESSAGE"
git push "$REMOTE" "$BRANCH"

echo "Triggered Revyl PR automation with $TARGET_FILE at $timestamp."
