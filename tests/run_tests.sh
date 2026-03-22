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

  local key
  key=$(echo -n "$tmpdir" | shasum | cut -c1-16)

  popd > /dev/null
  rm -rf "$tmpdir"
  rm -f "/tmp/code-quiz-diff-${key}"

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
    local has_diff_file
    has_diff_file=$(echo "$output" | jq -r '.reason' 2>/dev/null | grep -c '/tmp/code-quiz-diff-' || echo "0")
    if [ "$decision" = "block" ] && [ "$has_diff_file" -gt 0 ]; then
      echo "PASS: $name"
      PASS=$((PASS + 1))
    else
      echo "FAIL: $name (expected decision:block with /tmp/code-quiz-diff- path, got: $output)"
      FAIL=$((FAIL + 1))
    fi
  fi
}

# Helper: run hook in a repo where HEAD was saved before optional new commits
# $1 = test name, $2 = payload template, $3 = transcript path,
# $4 = expected ("exit0" or "block"), $5 = make new commits ("true"/"false"),
# $6 = leave uncommitted changes ("true"/"false", optional, default false)
# $7 = committed filename (optional, default "newfile.js")
run_test_with_saved_head() {
  local name="$1"
  local payload_template="$2"
  local transcript="$3"
  local expected="$4"
  local make_new_commits="${5:-false}"
  local dirty="${6:-false}"
  local committed_file="${7:-newfile.js}"

  local tmpdir
  tmpdir=$(mktemp -d)
  pushd "$tmpdir" > /dev/null

  git init -q
  git config user.email "test@test.com"
  git config user.name "Test"
  git commit --allow-empty -q -m "init"

  # Simulate what UserPromptSubmit hook does: save HEAD keyed by CWD
  local key
  key=$(echo -n "$tmpdir" | shasum | cut -c1-16)
  local hash_file="/tmp/code-quiz-head-${key}"
  git rev-parse HEAD > "$hash_file"

  if [ "$make_new_commits" = "true" ]; then
    echo "changed" > "$committed_file"
    git add "$committed_file"
    git commit -q -m "add $committed_file"
  fi

  if [ "$dirty" = "true" ]; then
    echo "dirty" > dirty.js
    git add dirty.js
  fi

  local payload="${payload_template/TRANSCRIPT_PLACEHOLDER/$transcript}"
  local output exit_code=0
  output=$(echo "$payload" | bash "$HOOK_SCRIPT" 2>/dev/null) || exit_code=$?

  popd > /dev/null
  rm -rf "$tmpdir"
  rm -f "$hash_file"
  rm -f "/tmp/code-quiz-diff-${key}"

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
    local has_diff_file
    has_diff_file=$(echo "$output" | jq -r '.reason' 2>/dev/null | grep -c '/tmp/code-quiz-diff-' || echo "0")
    if [ "$decision" = "block" ] && [ "$has_diff_file" -gt 0 ]; then
      echo "PASS: $name"
      PASS=$((PASS + 1))
    else
      echo "FAIL: $name (expected decision:block with /tmp/code-quiz-diff- path, got: $output)"
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

run_test_with_saved_head "New commits without Edit/Write triggers quiz" \
  "$NORMAL" "$FIXTURES_DIR/transcript_no_edit.jsonl" "block" "true"

run_test_with_saved_head "New commits AND uncommitted changes triggers quiz" \
  "$NORMAL" "$FIXTURES_DIR/transcript_no_edit.jsonl" "block" "true" "true"

run_test_with_saved_head "Saved HEAD unchanged, no Edit/Write: no quiz" \
  "$NORMAL" "$FIXTURES_DIR/transcript_no_edit.jsonl" "exit0" "false"

run_test "Edit tool + only .md changes: no quiz" \
  "$NORMAL" "$FIXTURES_DIR/transcript_with_edit.jsonl" "exit0" "test.md"

run_test_with_saved_head "New commits with only .md files: no quiz" \
  "$NORMAL" "$FIXTURES_DIR/transcript_no_edit.jsonl" "exit0" "true" "false" "plan.md"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
