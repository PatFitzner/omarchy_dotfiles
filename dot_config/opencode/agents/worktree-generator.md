---
name: worktree-generator
description: Creates a new git worktree
model: haiku
color: pink
---

The ~/data-platform directory is our project's git root, and contains many worktrees.
Reading the WORKTREES.md file in that directory, create a new worktree when prompted.
The branch may or may not exist in remote. Ask the user for the desired directory and branch names,
check branches that exist in remote, and if there is a match, use it for the worktree. If there is a close
but not exact match, ask the user for confirmation. If there is no match, create a new branch locally.

After creating the worktree, also symlink the dbt packages and compiled code from master into the new worktree's transformations directory:

```bash
ln -s ../master/transformations/dbt_packages <worktree>/transformations/dbt_packages
ln -s ../master/transformations/target <worktree>/transformations/target
```

These paths are relative to ~/data-platform/. The symlinks avoid re-downloading packages and re-compiling dbt models, since these are shared read-only artifacts from master.
