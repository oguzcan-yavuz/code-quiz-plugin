---
name: quiz
description: Quiz the developer on recent AI-assisted code changes to reinforce comprehension. Use when the developer runs /quiz manually.
---

# Code Comprehension Quiz

You are conducting a comprehension quiz. The goal is to help the developer understand the code changes that were just made — not to test or judge them. There is no pass/fail.

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

## Step 2: Count changed lines and determine question count

Count only `+` and `-` lines in the diff, excluding lines starting with `+++` or `---`.

| Changed lines | Questions |
|---------------|-----------|
| < 20          | 2–3       |
| 20–100        | 4–5       |
| > 100         | 6–8       |

## Step 3: Create tasks and announce the quiz

Before announcing, generate the question topics based on the diff (you don't need the full question text yet — just the category). Then create one task per question using TaskCreate, with subjects like `"Q1 · Big picture"`, `"Q2 · Control flow"`, `"Q3 · Edge cases"`, `"Q4 · Design tradeoffs"`. Also create a final task: `"Comprehension summary"`.

Then tell the user: "Time for a quick comprehension quiz on the changes just made. [N] questions. Type **skip** at any time to end early."

## Step 4: Ask questions one at a time

Before asking each question, mark its task as `in_progress` using TaskUpdate. Draw from the most applicable of these four categories (for small diffs of 2–3 questions, pick the best fit rather than forcing all four):

- **Big picture** — What problem does this change solve? Why this approach over alternatives?
- **Control flow** — Walk me through what happens when [key function/path] is called
- **Edge cases** — What inputs or states could cause unexpected behavior here?
- **Design tradeoffs** — Why this data structure / pattern? What does this trade off?

Ask the question. Wait for the answer. Evaluate conversationally ("Exactly — and worth noting that..." / "Close, but you missed..."). Then mark the task `completed` using TaskUpdate. Then move to the next question.

If the user types **skip** at any point, mark the current task `completed`, mark all remaining question tasks `deleted` using TaskUpdate, say "No worries — quiz ended." Give the brief summary (Step 5) and stop.

## Step 5: Comprehension summary

Mark the `"Comprehension summary"` task as `in_progress` using TaskUpdate. Then give a 2–4 sentence summary:
- What the developer understood well
- Anything worth revisiting or that was missed

Keep it constructive. No grades, no scores. Then mark the task `completed`.

## Step 6: Save quiz state

After delivering the comprehension summary — whether the quiz finished normally or the user typed `skip` — always perform these steps before exiting:

1. Run `mkdir -p ~/.claude/code-quiz` to ensure the directory exists.
2. Read `~/.claude/code-quiz/state.json` if it exists; default to `{}` if missing or unreadable.
3. Set the `lastQuizHead` field for this repo root: `state["<repoRoot>"] = { "lastQuizHead": "<output of git rev-parse HEAD>" }`.
4. Write the updated JSON back to `~/.claude/code-quiz/state.json`.

This ensures the next `/quiz` run only covers changes made after this session.
