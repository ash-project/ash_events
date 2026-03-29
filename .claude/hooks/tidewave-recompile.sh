# SPDX-FileCopyrightText: 2023 ash_events contributors <https://github.com/ash-project/ash_events/graphs/contributors>
#
# SPDX-License-Identifier: MIT

#!/bin/bash
INPUT=$(cat)
CODE=$(echo "$INPUT" | jq -r '.tool_input.code')

jq -n --arg code "recompile()
$CODE" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    updatedInput: { code: $code }
  }
}'
