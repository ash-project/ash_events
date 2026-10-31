#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

# Prepare a git worktree of ash_events for development.
#
#   scripts/worktree-setup.sh [worktree-path]
#
# Opt-in and tool-agnostic: nothing in the repo runs it. Call it by hand, or
# from your own local Orca, wt or other worktree tooling configuration. The
# worktree defaults to the current directory, and the primary checkout is found
# through git, so no tool-specific environment variables are needed.
#
# It runs the checked-out code (mise trust and install, mix), so only run it on
# reviewed code, never on an external PR branch.
#
# Each worktree gets its own test database and tidewave port through a
# generated mise.local.toml (POSTGRES_TEST_DATABASE is read by
# config/config.exs). mise applies it in shells where it is activated, and to
# any command run with `mise exec --`. Safe to re-run.

set -euo pipefail

worktree=$(cd "${1:-.}" && git rev-parse --show-toplevel)
root=$(git -C "$worktree" worktree list --porcelain | awk '/^worktree /{print substr($0, 10); exit}')

if [ "$worktree" = "$root" ]; then
  echo "error: $worktree is the primary checkout, not a linked worktree" >&2
  exit 1
fi

cd "$worktree"
echo "==> Setting up worktree $worktree (primary checkout: $root)"

# Reuse the primary checkout's compiled deps. On APFS `cp -c` clones, so this
# is fast and takes no extra space; fall back to a plain copy elsewhere.
for dir in deps _build; do
  if [ -d "$root/$dir" ] && [ ! -e "$dir" ]; then
    cp -Rc "$root/$dir" "$dir" 2>/dev/null || cp -R "$root/$dir" "$dir"
  fi
done

# Unique, Postgres-safe (<= 63 bytes) database name and a stable port, both
# derived from the worktree path.
hash=$(printf '%s' "$worktree" | shasum -a 256 | cut -c1-8)
slug=$(basename "$worktree" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '_' | sed 's/^_*//; s/_*$//' | cut -c1-38)
port=$((40000 + $(printf '%d' "0x$(printf '%s' "$hash" | cut -c1-4)") % 20000))

cat > mise.local.toml <<MISE
[env]
POSTGRES_TEST_DATABASE = "ash_events_test_${slug}_${hash}"
TIDEWAVE_PORT = "${port}"
MISE
mise trust --quiet .
# Install any runtimes from .tool-versions this machine does not have yet.
mise install

# Point this worktree's tidewave MCP entry at its own port, without showing
# .mcp.json as modified.
git update-index --skip-worktree .mcp.json
python3 -I - "$port" <<'PY'
import json, os, sys
path = ".mcp.json"
data = json.load(open(path)) if os.path.exists(path) else {}
data.setdefault("mcpServers", {})["tidewave"] = {
    "type": "http",
    "url": f"http://localhost:{sys.argv[1]}/tidewave/mcp",
}
json.dump(data, open(path, "w"), indent=4)
PY

# Claude sandbox settings for this worktree:
# - the sandbox restricts filesystem writes to the worktree directory
# - read-only gh/git operations are auto-allowed
# - mutative remote operations (push, comment, merge, close, create PR) still
#   require approval
mkdir -p .claude
python3 -I - <<'PY'
import json
settings = {
    "permissions": {
        "allow": [
            "Bash(mix *)",
            "Bash(MIX_ENV=test mix *)",
            "Bash(MIX_ENV=test LOGGER_LEVEL=debug mix *)",
            "Bash(git status:*)",
            "Bash(git log:*)",
            "Bash(git diff:*)",
            "Bash(git add:*)",
            "Bash(git commit:*)",
            "Bash(git stash:*)",
            "Bash(git branch:*)",
            "Bash(git checkout:*)",
            "Bash(git switch:*)",
            "Bash(git show:*)",
            "Bash(git blame:*)",
            "Bash(git fetch:*)",
            "Bash(git merge:*)",
            "Bash(git rebase:*)",
            "Bash(git cherry-pick:*)",
            "Bash(gh issue list:*)",
            "Bash(gh issue view:*)",
            "Bash(gh issue status:*)",
            "Bash(gh pr list:*)",
            "Bash(gh pr view:*)",
            "Bash(gh pr checks:*)",
            "Bash(gh pr diff:*)",
            "Bash(gh pr status:*)",
            "Bash(gh repo view:*)",
            "Bash(mkdir:*)",
            "Bash(find:*)",
            "Bash(tree:*)",
            "Bash(wc:*)",
            "Bash(grep:*)",
            "Bash(ls:*)",
            "WebSearch",
            "WebFetch(domain:hexdocs.pm)",
            "WebFetch(domain:hex.pm)",
            "WebFetch(domain:preview.hex.pm)",
            "WebFetch(domain:github.com)",
            "WebFetch(domain:api.github.com)",
            "WebFetch(domain:raw.githubusercontent.com)",
            "WebFetch(domain:ash-hq.org)",
            "mcp__tidewave__project_eval",
            "mcp__tidewave__get_docs",
            "mcp__tidewave__search_package_docs",
            "mcp__tidewave__get_source_location",
            "mcp__tidewave__get_ash_resources",
            "mcp__tidewave__get_logs",
        ],
        "deny": [],
    },
    "enableAllProjectMcpServers": True,
    "enabledMcpjsonServers": ["tidewave"],
    "sandbox": {
        "enabled": True,
        "filesystem": {"allowWrite": ["."]},
        "network": {
            "allowedDomains": [
                "github.com",
                "api.github.com",
                "hex.pm",
                "repo.hex.pm",
                "hexdocs.pm",
                "preview.hex.pm",
                "ash-hq.org",
            ]
        },
    },
}
json.dump(settings, open(".claude/settings.local.json", "w"), indent=2)
PY

mise exec -- mix deps.get --quiet
# Claude skills from deps' usage rules (gitignored, so generated per checkout)
mise exec -- mix sync_usage_rules
mise exec -- mix test.reset

echo "==> Done. Test database: ash_events_test_${slug}_${hash}, tidewave port: ${port}"
