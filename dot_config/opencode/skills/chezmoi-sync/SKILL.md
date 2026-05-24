---
name: chezmoi-sync
description: >
  Detect direct edits to dotfiles managed by chezmoi, merge them back into the
  chezmoi source tree, commit, and push. Use when the user asks to sync dotfiles,
  reconcile chezmoi changes, commit dotfile edits, or after making direct edits
  to ~/.config/ files that chezmoi manages.
---

# Chezmoi Sync Skill

Detect drift between the live dotfiles (`~/.config/`, `~/.bashrc`, etc.) and the
chezmoi source tree (`~/dotfiles/`), merge changes back into source, commit, and push.

## When to Use

- User asks to "sync dotfiles", "reconcile chezmoi", "commit my dotfile changes"
- After making direct edits to `~/.config/` or other managed paths
- Before starting a new dotfile edit session — check for existing drift first
- User says "I edited ~/.config/hypr/hyprland.conf, save it to chezmoi"

## Source Tree Layout

```
~/dotfiles/                          # chezmoi source directory
├── .chezmoidata.yaml                # Per-host variables (gpu, monitors, packages)
├── .chezmoiignore                   # Static ignores
├── .chezmoiignore.tmpl              # Per-host ignores
├── dot_bashrc.tmpl                  # Templated shell configs
├── dot_zshenv.tmpl
├── dot_config/                      # ~/.config/*
│   ├── hypr/
│   │   ├── hyprland.conf.tmpl       # Template — sources omarchy defaults + user overlays
│   │   ├── monitors.conf.tmpl       # Generated from .chezmoidata.yaml monitor list
│   │   ├── envs.conf.tmpl           # GPU-specific env vars
│   │   ├── autostart.conf.tmpl      # Host-specific autostart
│   │   ├── bindings.conf            # Static — edit directly
│   │   └── ...
│   ├── waybar/
│   │   ├── config.jsonc.tmpl        # Template with host-conditionals
│   │   └── style.css                # Static
│   └── ...
├── dot_local/bin/                   # Custom scripts
├── dot_ssh/                         # Encrypted (age)
└── run_onchange_before_10-install-packages.sh.tmpl
```

## Workflow

### Step 1: Detect Drift

```bash
chezmoi status        # Shows modified files (M = modified in dest, R = removed, etc.)
chezmoi diff          # Shows full unified diff of all drift
```

Status codes:
- `M` — destination modified (user edited `~/.config/...` directly)
- `MM` — both source and destination modified
- `R` — source file removed but still exists at destination

### Step 2: Classify Each Drifted File

For each file in `chezmoi status`:

| File type | Action |
|---|---|
| `.tmpl` file with drift (e.g. `hyprland.conf.tmpl`) | `chezmoi merge ~/.config/hypr/hyprland.conf` — 3-way merge |
| Static file (e.g. `bindings.conf`, `style.css`) | `chezmoi add --force ~/.config/hypr/bindings.conf` — overwrite source with dest |
| Generated template (e.g. `monitors.conf` from `monitors.conf.tmpl`) | Edit `.chezmoidata.yaml`, then `chezmoi apply` — do NOT merge rendered output |
| Script in `~/.local/bin/` | `chezmoi add --force ~/.local/bin/script-name` |
| File the user wants to discard (revert to source) | `chezmoi apply <file>` — overwrite dest with source |

### Step 3: Merge Each File

**For static files (overwrite source with destination):**
```bash
chezmoi add --force ~/.config/hypr/bindings.conf
```

**For template files (3-way merge):**
```bash
chezmoi merge ~/.config/hypr/hyprland.conf
```
This opens a 3-way merge showing: source, destination, and base. Resolve conflicts, save, and the source tree updates.

**For bulk merge (all modified files at once):**
```bash
chezmoi status | grep -E '^[AMM]' | awk '{print $2}' | while read f; do
  chezmoi add --force "$HOME/$f"
done
```

### Step 4: Verify Clean State

```bash
chezmoi status    # Should be empty or only show expected differences
chezmoi diff      # Should show no unexpected changes
```

### Step 5: Commit and Push

```bash
chezmoi cd        # cd into ~/dotfiles/
git add -A
git diff --cached --stat   # Review what's being committed
git commit -m "<concise message describing changes>"
git push
```

**Commit message conventions:**
- `hypr: rebind SUPER+O to obsidian with wayland flags`
- `waybar: replace opencode-chat with claude-chat module`
- `hypridle: adjust lock/sleep timeouts, enable kbd backlight`
- `local/bin: update session-start workspace routing`

### Step 6: Re-apply (safety net)

```bash
chezmoi apply --force
```
Ensures the destination matches the newly-committed source. Catches any merge artifacts.

## Template-Aware Routing

Some files are Go templates driven by `.chezmoidata.yaml`. For these, do NOT merge the rendered output back — instead edit the data source:

| Rendered file | Edit this instead |
|---|---|
| `~/.config/hypr/monitors.conf` | `~/dotfiles/.chezmoidata.yaml` → `hosts.<hostname>.monitors` |
| `~/.config/hypr/envs.conf` | `~/dotfiles/.chezmoidata.yaml` → `hosts.<hostname>.gpu` |
| `~/.config/hypr/autostart.conf` | `~/dotfiles/.chezmoidata.yaml` → host-specific section or edit `.tmpl` directly |
| `~/.config/waybar/config.jsonc` | Edit `~/dotfiles/dot_config/waybar/config.jsonc.tmpl` directly (has host-conditionals) |
| `~/.bashrc` | Edit `~/dotfiles/dot_bashrc.tmpl` directly |

**Rule:** If the source file ends in `.tmpl`, check whether the drift is in the template logic or in the data. If it's data (monitor specs, package lists, GPU flag), edit `.chezmoidata.yaml`. If it's config structure, edit the `.tmpl`.

## Files to Ignore

These appear in `chezmoi status` but should NOT be merged:

- `~/.config/strawberry/strawberry.conf` — app state (geometry, last playlist), not user config
- `~/.local/bin/pacman_installed_packages.txt` — runtime output, in `.chezmoiignore`
- Any file under `~/.local/state/` or `~/.cache/` — never tracked

## Quick Commands Reference

| Task | Command |
|---|---|
| See what changed | `chezmoi status && chezmoi diff` |
| Merge one file back to source | `chezmoi add --force ~/.config/hypr/bindings.conf` |
| 3-way merge a template file | `chezmoi merge ~/.config/hypr/hyprland.conf` |
| Apply source to destination (revert) | `chezmoi apply ~/.config/hypr/hyprland.conf` |
| Edit source and apply | `chezmoi edit --apply ~/.config/hypr/hyprland.conf` |
| Enter source dir | `chezmoi cd` |
| Commit + push | `chezmoi cd && git add -A && git commit -m "msg" && git push` |
| Full sync pipeline | `chezmoi status` → classify → merge/merge → `chezmoi cd && git add -A && git commit -m "msg" && git push` → `chezmoi apply --force` |

## Decision Tree

```
User wants to sync dotfiles
  │
  ├─ chezmoi status → empty? → "No drift, all clean"
  │
  ├─ For each modified file:
  │   │
  │   ├─ Is it strawberry.conf or other app state? → SKIP
  │   │
  │   ├─ Is the source a .tmpl?
  │   │   ├─ Is the change in data (monitors, packages, gpu)? → Edit .chezmoidata.yaml, then chezmoi apply
  │   │   └─ Is the change in config structure? → chezmoi merge <file>
  │   │
  │   └─ Is the source static (no .tmpl)? → chezmoi add --force <file>
  │
  ├─ chezmoi status → verify clean
  │
  ├─ chezmoi cd && git add -A && git commit -m "..." && git push
  │
  └─ chezmoi apply --force → safety net
```
