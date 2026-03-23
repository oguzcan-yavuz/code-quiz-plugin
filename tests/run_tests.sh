#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_FILE="$SCRIPT_DIR/../skills/quiz/SKILL.md"
PASS=0
FAIL=0

check() {
  local name="$1"
  local condition="$2"
  if eval "$condition"; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== code-quiz skill tests ==="
echo ""

check "skill file exists" "[ -f '$SKILL_FILE' ]"
check "skill has name: quiz" "grep -q '^name: quiz' '$SKILL_FILE'"
check "skill runs git diff HEAD" "grep -q 'git diff HEAD' '$SKILL_FILE'"
check "skill handles empty diff" "grep -q 'No uncommitted changes found' '$SKILL_FILE'"
check "no hooks defined" "[ \"\$(jq '.hooks | length' '$SCRIPT_DIR/../hooks/hooks.json')\" = '0' ]"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
