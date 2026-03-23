# Quiz Change Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Track the HEAD commit at last quiz run so `/quiz` can diff all changes (committed + uncommitted + untracked) since then, not just the current working tree.

**Architecture:** The skill reads a user-level state file (`~/.claude/code-quiz/state.json`) keyed by repo root to get the last quiz HEAD. It builds a combined diff from three sources: committed changes since that HEAD, uncommitted changes, and untracked files. After the quiz ends it writes the current HEAD back to the state file.

**Tech Stack:** Bash (via Claude's shell tools), JSON state file, `git diff`, `git ls-files`, `jq`

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `skills/quiz/SKILL.md` | Modify | Step 1 (diff collection) + new Step 6 (state update) |
| `tests/run_tests.sh` | Modify | Add tests for new behavior; update stale assertions |

---

### Task 1: Update tests to cover new behavior (TDD — write failing tests first)

**Files:**
- Modify: `tests/run_tests.sh`

- [ ] **Step 1: Add failing tests for new skill behavior**

Open `tests/run_tests.sh` and add the following checks after the existing ones (before the `echo ""` summary line):

```bash
check "skill reads state file" "grep -q 'code-quiz/state.json' '$SKILL_FILE'"
check "skill diffs from saved hash" "grep -q 'git diff.*HEAD' '$SKILL_FILE'"
check "skill lists untracked files" "grep -q 'ls-files.*--others' '$SKILL_FILE'"
check "skill writes state after quiz" "grep -q 'lastQuizHead' '$SKILL_FILE'"
check "skill handles stale hash" "grep -q 'no longer exists\|no longer valid\|rebase\|force-push' '$SKILL_FILE'"
check "skill handles empty diff with state" "grep -q 'No changes found since the last quiz' '$SKILL_FILE'"
```

Also update the existing stale assertion — the old "No uncommitted changes found" message now only applies to first-run with no state, which is still in the skill. No change needed there.

- [ ] **Step 2: Run tests to confirm new ones fail**

```bash
bash tests/run_tests.sh
```

Expected: 5 existing tests pass, 6 new tests FAIL (skill not yet updated).

- [ ] **Step 3: Commit failing tests**

```bash
git add tests/run_tests.sh
git commit -m "test: add failing tests for change tracking behavior"
```

---

### Task 2: Update Step 1 of the skill — diff collection

**Files:**
- Modify: `skills/quiz/SKILL.md`

The current Step 1 is:

```
## Step 1: Get the diff

Run `git diff HEAD` to get the current diff. If the output is empty, tell the user: "No uncommitted changes found. Run /quiz after making some changes." and stop.
```

- [ ] **Step 1: Replace Step 1 in the skill with the new diff collection logic**

Replace the entire `## Step 1: Get the diff` section with:

```markdown
## Step 1: Get the diff

1. Run `git rev-parse --show-toplevel` to get the repo root. If this fails (not a git repo), skip state tracking and run `git diff HEAD` only — proceed with whatever that returns.

2. Read `~/.claude/code-quiz/state.json`. If the file does not exist or has no entry for this repo root, treat `lastQuizHead` as absent.

3. **If `lastQuizHead` is present:**
   - Run `git diff <lastQuizHead> HEAD` to get committed changes since last quiz. If this command fails (hash no longer valid), tell the user: "Quiz state was reset (saved commit no longer exists, likely due to a rebase or force-push). Showing uncommitted changes only." Clear the entry for this repo in the state file, then fall through to the no-saved-hash path.
   - Run `git diff HEAD` to get uncommitted changes.
   - Run `git ls-files --others --exclude-standard` for untracked files. For each file listed, read its contents and format as a pseudo-diff: a `+++ <filename>` header line followed by each line of the file prefixed with `+`.
   - Concatenate all three outputs as the working diff.

4. **If `lastQuizHead` is absent (first run or after stale-hash reset):**
   - Run `git diff HEAD` for uncommitted changes.
   - Run `git ls-files --others --exclude-standard` and format untracked files as above.
   - Concatenate both as the working diff.

5. If the combined diff is empty:
   - If this was a first run (no saved state): tell the user "No uncommitted changes found. Run /quiz after making some changes." and stop.
   - Otherwise: tell the user "No changes found since the last quiz." and stop.

Count `+` and `-` lines across the full concatenated diff for Step 2 (exclude lines starting with `+++` or `---`).
```

- [ ] **Step 2: Run tests — expect partial pass**

```bash
bash tests/run_tests.sh
```

Expected: most new tests pass now. `skill writes state after quiz` and possibly `skill handles stale hash` may still fail — Step 6 not yet written.

---

### Task 3: Add Step 6 — state update after quiz

**Files:**
- Modify: `skills/quiz/SKILL.md`

- [ ] **Step 1: Append Step 6 at the end of the skill file**

Add the following after the existing Step 5:

```markdown
## Step 6: Save quiz state

After delivering the comprehension summary — whether the quiz finished normally or the user typed `skip` — always perform these steps before exiting:

1. Run `mkdir -p ~/.claude/code-quiz` to ensure the directory exists.
2. Read `~/.claude/code-quiz/state.json` if it exists; default to `{}` if missing or unreadable.
3. Set the `lastQuizHead` field for this repo root: `state["<repoRoot>"] = { "lastQuizHead": "<output of git rev-parse HEAD>" }`.
4. Write the updated JSON back to `~/.claude/code-quiz/state.json`.

This ensures the next `/quiz` run only covers changes made after this session.
```

- [ ] **Step 2: Run all tests and confirm they pass**

```bash
bash tests/run_tests.sh
```

Expected: all tests PASS, 0 failed.

- [ ] **Step 3: Commit the updated skill**

```bash
git add skills/quiz/SKILL.md
git commit -m "feat: track changes since last quiz via saved HEAD hash"
```

---

### Task 4: Final verification

- [ ] **Step 1: Run full test suite one more time from a clean state**

```bash
bash tests/run_tests.sh
```

Expected output:
```
=== code-quiz skill tests ===

PASS: skill file exists
PASS: skill has name: quiz
PASS: skill runs git diff HEAD
PASS: skill handles empty diff
PASS: no hooks defined
PASS: skill reads state file
PASS: skill diffs from saved hash
PASS: skill lists untracked files
PASS: skill writes state after quiz
PASS: skill handles stale hash
PASS: skill handles empty diff with state

Results: 11 passed, 0 failed
```

- [ ] **Step 2: Commit test results verification (no-op commit for record)**

If tests pass, no additional commit needed — the work is done.
