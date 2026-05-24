---
name: worktree-cleanup
description: Deletes worktrees whose remote branch has been merged into master, and prunes stale worktree entries
---
The git repo lives at ~/data-platform/.bare (bare repo). Worktrees are checked out under ~/data-platform/.

Steps:
1. Run `git -C ~/data-platform/.bare worktree list --porcelain` to get all worktrees and their branches.
2. Run `git -C ~/data-platform/.bare branch -r --merged origin/master` to get merged remote branches.
3. For each worktree (excluding the bare repo itself and the `master` worktree), check if its local branch has a corresponding remote branch (`origin/<branch>`) that appears in the merged list.
4. Before removing, check for uncommitted or untracked changes with `git -C <worktree-path> status --short`. Warn the user if any exist and confirm before proceeding with `--force`.
5. Remove matching worktrees: `git -C ~/data-platform/.bare worktree remove [--force] <path>`
6. Prune any stale entries (prunable worktrees whose directory no longer exists): `git -C ~/data-platform/.bare worktree prune`
7. Show the final `git -C ~/data-platform/.bare worktree list` so the user can confirm the result.
