# code-quiz

A Claude Code plugin that quizzes you on code changes to reinforce comprehension.

Run `/quiz` after making changes to start a conversational quiz. Claude generates questions scaled to the diff size, drawing on both the diff and the conversation context to ask about big picture, control flow, edge cases, and design tradeoffs.

**You can skip at any time by typing `skip`.**

## Requirements

- Must be run inside a git repository

## Installation

```
/plugin marketplace add oguzcan-yavuz/code-quiz-plugin
/plugin install code-quiz
```

## How it works

1. Make some code changes
2. Run `/quiz`
3. Claude quizzes you on the uncommitted changes — questions are scaled to diff size
4. At the end, Claude gives a brief summary of what was understood well and what's worth revisiting
