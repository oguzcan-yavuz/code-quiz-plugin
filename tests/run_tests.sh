#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/../hooks/stop"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
PASS=0
FAIL=0

# Helper: run hook in an isolated temp git repo
# $1 = test name, $2 = payload template, $3 = transcript path,
# $4 = expected ("exit0" or "block"), $5 = file to dirty (optional)
run_test() {
  local name="$1"
  local payload_template="$2"
  local transcript="$3"
  local expected="$4"
  local dirty_file="${5:-}"

  local tmpdir
  tmpdir=$(mktemp -d)
  pushd "$tmpdir" > /dev/null

  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  git commit --allow-empty -q -m "init"

  # Produce a non-empty diff if a file name was supplied
  if [ -n "$dirty_file" ]; then
    echo "changed" > "$dirty_file"
    git add "$dirty_file"
  fi

  local payload="${payload_template/TRANSCRIPT_PLACEHOLDER/$transcript}"
  local output exit_code=0
  output=$(echo "$payload" | bash "$HOOK_SCRIPT" 2>/dev/null) || exit_code=$?

  popd > /dev/null
  rm -rf "$tmpdir"

  if [ "$expected" = "exit0" ]; then
    if [ "$exit_code" -eq 0 ] && [ -z "$output" ]; then
      echo "PASS: $name"
      PASS=$((PASS + 1))
    else
      echo "FAIL: $name (expected silent exit 0, got exit=$exit_code output='$output')"
      FAIL=$((FAIL + 1))
    fi
  elif [ "$expected" = "block" ]; then
    local decision
    decision=$(echo "$output" | jq -r '.decision' 2>/dev/null || echo "")
    local has_diff_marker
    has_diff_marker=$(echo "$output" | jq -r '.reason' 2>/dev/null | grep -c 'DIFF:' || echo "0")
    if [ "$decision" = "block" ] && [ "$has_diff_marker" -gt 0 ]; then
      echo "PASS: $name"
      PASS=$((PASS + 1))
    else
      echo "FAIL: $name (expected decision:block with DIFF: marker, got: $output)"
      FAIL=$((FAIL + 1))
    fi
  fi
}

NORMAL='{"session_id":"t","transcript_path":"TRANSCRIPT_PLACEHOLDER","cwd":"/tmp","permission_mode":"default","hook_event_name":"Stop","stop_hook_active":false}'
REENTRY='{"session_id":"t","transcript_path":"TRANSCRIPT_PLACEHOLDER","cwd":"/tmp","permission_mode":"default","hook_event_name":"Stop","stop_hook_active":true}'

echo "=== code-quiz stop hook tests ==="
echo ""

run_test "stop_hook_active:true is a no-op" \
  "$REENTRY" "$FIXTURES_DIR/transcript_with_edit.jsonl" "exit0"

run_test "Edit tool + changes triggers quiz" \
  "$NORMAL" "$FIXTURES_DIR/transcript_with_edit.jsonl" "block" "test.js"

run_test "Write tool + changes triggers quiz" \
  "$NORMAL" "$FIXTURES_DIR/transcript_with_write.jsonl" "block" "test.js"

run_test "No Edit/Write tools: no quiz" \
  "$NORMAL" "$FIXTURES_DIR/transcript_no_edit.jsonl" "exit0" "test.js"

run_test "Edit tool but empty diff: no quiz" \
  "$NORMAL" "$FIXTURES_DIR/transcript_with_edit.jsonl" "exit0"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
