# Quiz Change Tracking Design

**Date:** 2026-03-23
**Status:** Approved

## Problem

The `/quiz` skill uses `git diff HEAD` to find changes to quiz the developer on. Since auto-detection was removed and the tool is now manually triggered, committed changes since the last quiz are invisible — `git diff HEAD` only returns uncommitted working tree changes.

## Goal

Track which commit the last quiz ran on, so subsequent `/quiz` runs can include all changes (committed and uncommitted) since then.

## State Storage

A JSON file at `~/.claude/code-quiz/state.json`, keyed by absolute repo root path:

```json
{
  "/Users/alice/dev/myproject": {
    "lastQuizHead": "abc1234"
  }
}
```

- Stored at user level (`~/.claude/`) — not in the project repo
- Repo root resolved via `git rev-parse --show-toplevel`
- File is created on first quiz completion; missing keys are treated as first-run

## Diff Collection (Step 1 of the skill)

1. Get repo root: `git rev-parse --show-toplevel`
2. Read `~/.claude/code-quiz/state.json` and look up the current repo root
3. **If a saved hash exists:**
   - `git diff <savedHash> HEAD` — committed changes since last quiz
   - `git diff HEAD` — uncommitted staged/unstaged changes
   - Untracked files: `git ls-files --others --exclude-standard`, read each file and format as a pseudo-diff
   - Concatenate all three as the working diff
4. **If no saved hash (first run):** use `git diff HEAD` + untracked files only
5. If the combined diff is empty, tell the user "No changes found since the last quiz." and stop

## State Update (end of quiz)

After Step 5 (comprehension summary) completes — whether the quiz finishes normally or the user types `skip` — write the current HEAD to state:

```
git rev-parse HEAD → write to ~/.claude/code-quiz/state.json[repoRoot].lastQuizHead
```

This ensures the next quiz only covers new changes.

## Edge Cases

- **No git repo:** `git rev-parse --show-toplevel` fails — fall back to current behavior (no state tracking)
- **Saved hash no longer exists** (e.g., after rebase/force-push): `git diff <hash> HEAD` will fail — fall back to `git diff HEAD` + untracked files and clear the stale entry
- **First run:** no state file or no entry for this repo — use current behavior, no changes to messaging
