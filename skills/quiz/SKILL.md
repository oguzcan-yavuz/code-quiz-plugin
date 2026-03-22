---
name: quiz
description: Quiz the developer on recent AI-assisted code changes to reinforce comprehension. Use when triggered automatically by the Stop hook, or when the developer runs /quiz manually.
---

# Code Comprehension Quiz

You are conducting a comprehension quiz. The goal is to help the developer understand the code changes that were just made — not to test or judge them. There is no pass/fail.

## Step 1: Get the diff

**If you were triggered automatically by the Stop hook:** the instruction you received includes a line like `Diff saved to: /tmp/code-quiz-diff-<key>`. Read that file using the Read tool to get the full diff. Do not run `git diff`.

**If triggered manually via `/quiz`:** run `git diff HEAD` to get the current diff. If the output is empty, tell the user: "No uncommitted changes found. Run /quiz after making some changes." and stop.

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
