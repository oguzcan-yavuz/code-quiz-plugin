# code-quiz

A Claude Code plugin that quizzes you on AI-assisted code changes to reinforce comprehension.

After Claude edits or creates files, a Stop hook detects the changes and immediately starts a conversational quiz — no waiting for your next message. Claude generates questions scaled to the diff size, drawing on both the diff and the conversation context to ask about big picture, control flow, edge cases, and design tradeoffs.

**You can skip at any time by typing `skip`.**

## How it works

1. Claude makes code changes (Edit or Write tool calls)
2. The Stop hook fires, parses the session transcript to detect edits, runs `git diff HEAD`
3. Claude immediately conducts a quiz using the diff and conversation history
4. At the end, Claude gives a brief summary of what was understood well and what's worth revisiting

No score tracking. No enforcement. Changes are never reverted.

## Manual use

Run `/quiz` at any time to quiz yourself on your current uncommitted changes.

## Requirements

- `jq` must be installed and on your PATH (`brew install jq` on macOS)
- Must be run inside a git repository

## Installation

```
/plugin marketplace add oguzcan-yavuz/code-quiz-plugin
/plugin install code-quiz
```
