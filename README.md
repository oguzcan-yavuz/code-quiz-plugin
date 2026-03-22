# code-quiz

A Claude Code plugin that quizzes you on AI-assisted code changes to reinforce comprehension.

After Claude edits or creates files, a Stop hook detects the changes and immediately starts a conversational quiz — no waiting for your next message. Claude generates questions scaled to the diff size, drawing on both the diff and the conversation context to ask about big picture, control flow, edge cases, and design tradeoffs.

**You can skip at any time by typing `skip`.**

## Requirements

- `jq` must be installed and on your PATH (`brew install jq` on macOS)
- Must be run inside a git repository

## Installation

```
/plugin marketplace add oguzcan-yavuz/code-quiz-plugin
/plugin install code-quiz
```

## How it works

1. When you submit a prompt, a hook records the current git HEAD
2. Claude makes code changes — directly via Edit/Write, or through subagents that commit
3. The Stop hook compares the current HEAD to the recorded one:
   - If new commits exist, it diffs from the saved HEAD to the current HEAD
   - If no new commits, it diffs uncommitted changes against HEAD
   - Both committed and uncommitted changes are included if present
4. Claude immediately conducts a quiz using the diff and conversation history
5. At the end, Claude gives a brief summary of what was understood well and what's worth revisiting

This means the quiz works whether Claude edits files directly or delegates to subagents that commit (e.g. when using the superpowers plugin).

No score tracking. No enforcement. Changes are never reverted.

## Manual use

Run `/quiz` at any time to quiz yourself on your current uncommitted changes.
