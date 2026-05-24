---
name: git-worktree-generator
description: Use this skill whenever you must create a new worktree for our data project
allowedTools:
  - Read
  - Bash
  - AskUserQuestion
---
The ~/data-platform directory is our project's git root, and contains many worktrees.
Reading the WORKTREES.md file in that directory, create a new worktree when prompted.
The branch may or may not exist in remote. Ask the user for the desired directory and branch names,
check branches that exist in remote, and if there is a match, use it for the worktree. If there is a close
but not exact match, ask the user for confirmation. If there is no match, create a new branch locally.

When deriving the worktree directory name from a branch name, replace slashes with hyphens
(e.g. branch `feat/semantic_layer` → directory `feat-semantic_layer`) to avoid creating nested directories.
