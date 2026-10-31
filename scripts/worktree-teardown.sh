#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

# Clean up a git worktree of ash_events before it is removed.
#
#   scripts/worktree-teardown.sh [worktree-path]
#
# Tool-agnostic counterpart to scripts/worktree-setup.sh: drops the worktree's own test
# database. It never touches the primary checkout's database.

set -euo pipefail

worktree=$(cd "${1:-.}" && git rev-parse --show-toplevel)
root=$(git -C "$worktree" worktree list --porcelain | awk '/^worktree /{print substr($0, 10); exit}')

if [ "$worktree" = "$root" ]; then
  echo "error: $worktree is the primary checkout, not a linked worktree" >&2
  exit 1
fi

cd "$worktree"

# Without a per-worktree database name, mix would target the shared
# ash_events_test database, so refuse rather than drop it.
database=$(mise exec -- sh -c 'printf %s "${POSTGRES_TEST_DATABASE:-}"' 2>/dev/null || true)
if [ -z "$database" ]; then
  echo "==> No per-worktree test database configured; nothing to drop"
  exit 0
fi

echo "==> Dropping test database $database"
mise exec -- mix test.drop
