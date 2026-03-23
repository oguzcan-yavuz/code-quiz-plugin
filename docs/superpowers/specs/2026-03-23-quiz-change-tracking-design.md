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
   - Run `git diff <savedHash> HEAD` — committed changes since last quiz
   - Run `git diff HEAD` — uncommitted staged/unstaged changes
   - Run `git ls-files --others --exclude-standard` for untracked files; read each and format as a pseudo-diff (e.g. `+++ <filename>\n+ <line>` per line)
   - Concatenate all three as the working diff
   - Count `+`/`-` lines across the full concatenated diff for question-count purposes (Step 2)
4. **If no saved hash (first run):** use `git diff HEAD` + untracked files (same untracked handling as above)
5. If the combined diff is empty, tell the user "No changes found since the last quiz." and stop. For first run with no saved state, say "No uncommitted changes found. Run /quiz after making some changes."

## State Update (new Step 6 in the skill)

After the comprehension summary is delivered — whether the quiz finishes normally or the user types `skip` — perform the following as an explicit final step:

1. Run `mkdir -p ~/.claude/code-quiz` to ensure the directory exists
2. Read `~/.claude/code-quiz/state.json` if it exists (default to `{}` if missing)
3. Set `state[repoRoot].lastQuizHead = $(git rev-parse HEAD)`
4. Write the updated object back to `~/.claude/code-quiz/state.json`

This is always the last action before the skill exits, regardless of how the quiz ended.

## Edge Cases

- **No git repo:** `git rev-parse --show-toplevel` fails — skip state tracking entirely, fall back to `git diff HEAD` only
- **Saved hash no longer valid** (e.g., after rebase/force-push): `git diff <hash> HEAD` will fail — tell the user "Quiz state was reset (saved commit no longer exists, likely due to a rebase or force-push). Showing uncommitted changes only." then fall back to `git diff HEAD` + untracked files and clear the stale entry
- **First run:** no state file or no entry for this repo — treat identically to the no-saved-hash path above
