---
name: clawhub-skill-creator
description: >
  Create, validate, and publish OpenClaw skills for ClawHub. Use when the user
  wants to: (1) create a new openclaw skill, (2) scaffold a skill directory,
  (3) write or edit a SKILL.md manifest, (4) package a .skill file, (5) publish
  to ClawHub, (6) debug skill metadata or gating issues. Triggers: "new skill",
  "create skill", "openclaw skill", "clawhub publish", "package skill",
  "SKILL.md", "skill manifest".
---

# ClawHub Skill Creator

**HARD RULE: NEVER publish a skill to ClawHub without the user's explicit instruction to do so.** Creating, packaging, and pushing to GitHub are fine — but `clawhub publish` and `clawhub sync` require explicit user approval every time.

Guide for creating OpenClaw skills. Reference implementation: `~/stremio-unwatched/`.
OpenClaw source and bundled skills: `~/openclaw_repo/`.
Official skill-creator skill: `~/openclaw_repo/skills/skill-creator/`.

## Skill Structure

```
skill-name/
├── SKILL.md              # Required — manifest + instructions
├── scripts/              # Optional — executable code (bash, python, node)
├── references/           # Optional — docs loaded into context on demand
└── assets/               # Optional — files used in output (templates, images)
```

No README.md, CHANGELOG.md, or auxiliary docs — only what the agent needs.

## SKILL.md Format

YAML frontmatter + Markdown body:

```yaml
---
name: my-skill
description: >
  What the skill does and when to use it. This is the PRIMARY trigger mechanism.
  Include all "when to use" info here, NOT in the body. Be specific about
  trigger phrases and use cases.
homepage: https://optional-url.com
metadata:
  {
    "openclaw":
      {
        "emoji": "🔧",
        "os": ["linux", "darwin"],
        "requires":
          {
            "bins": ["curl", "jq"],
            "anyBins": ["node", "bun"],
            "env": ["MY_API_KEY"],
            "config": ["~/.config/myapp"],
          },
        "primaryEnv": "MY_API_KEY",
        "install":
          [
            {
              "id": "curl-brew",
              "kind": "brew",
              "formula": "curl",
              "bins": ["curl"],
              "os": ["darwin"],
              "label": "Install curl (brew)",
            },
          ],
      },
  }
---

# Skill Title

Markdown instructions for the agent. Only loaded AFTER triggering.
```

### Frontmatter Fields

| Field | Required | Notes |
|-------|----------|-------|
| `name` | Yes | Lowercase, hyphen-case, max 64 chars, `^[a-z0-9-]+$` |
| `description` | Yes | Max 1024 chars, no angle brackets. THE trigger mechanism |
| `homepage` | No | External docs URL |
| `metadata` | No | Single-line JSON with `openclaw` key |

Do NOT include other frontmatter fields unless the user specifies them.

### metadata.openclaw Fields

| Field | Type | Purpose |
|-------|------|---------|
| `emoji` | string | Display icon |
| `os` | string[] | `"linux"`, `"darwin"`, `"win32"` |
| `requires.bins` | string[] | ALL must be on PATH |
| `requires.anyBins` | string[] | At least ONE must be on PATH |
| `requires.env` | string[] | Required env vars |
| `requires.config` | string[] | Required config file paths |
| `primaryEnv` | string | Main env var for UI display |
| `always` | boolean | Skip all gating checks |
| `install` | array | Auto-install specs (see below) |

### Install Spec Kinds

- `brew` — `formula`, `bins`, `os`
- `node` — `package`, `bins`
- `go` — `module`, `bins`
- `uv` — `package`, `bins`
- `download` — `url`, `archive`, `extract`, `stripComponents`, `targetDir`, `bins`

## Creation Process

Follow these steps in order:

### 1. Understand the Skill

Ask the user:
- What should this skill do? Concrete examples of usage.
- What triggers should activate it?
- What external tools/APIs/services does it interact with?

Don't ask too many questions at once.

### 2. Plan Reusable Contents

For each use case, identify:
- **Scripts** — code that would be rewritten each time (auth flows, API calls, data processing)
- **References** — documentation the agent needs while working (API docs, schemas, business rules)
- **Assets** — files used in output (templates, boilerplate)

### 3. Initialize the Skill

Create the skill directory. If working in the openclaw repo, use the bundled initializer:

```bash
~/openclaw_repo/skills/skill-creator/scripts/init_skill.py <name> --path <dir> [--resources scripts,references,assets]
```

Otherwise, manually create the directory structure.

### 4. Implement

Write scripts, references, and assets. Then write SKILL.md.

**Script patterns:**
- Bash: `#!/usr/bin/env bash` + `set -euo pipefail`
- Credential caching: `~/.openclaw/credentials/<service>.json` with `chmod 600`
- Use `$OPENCLAW_CREDENTIALS_DIR` if set, fallback to `~/.openclaw/credentials`
- Output JSON for agent parsing, or human-readable tables

**SKILL.md body guidelines:**
- Written for another AI agent, not a human
- Imperative/infinitive form
- Under 500 lines — split into references/ if larger
- Reference bundled resources and explain when to read them
- Don't duplicate content between SKILL.md body and reference files

### 5. Push to GitHub

Create a **private** GitHub repo for the skill and push:

```bash
cd <skill-directory>
git init
git add -A
git commit -m "Initial skill"
gh repo create PatFitzner/<skill-name> --private --source . --push
```

The repo stays private until the skill is published to ClawHub (step 7).

### 6. Validate and Package

```bash
# Validate only
~/openclaw_repo/skills/skill-creator/scripts/quick_validate.py <path/to/skill>

# Package into .skill file (validates first)
~/openclaw_repo/skills/skill-creator/scripts/package_skill.py <path/to/skill> [output-dir]
```

The .skill file is a zip archive with .skill extension. No symlinks allowed.

### 7. Publish to ClawHub

**REQUIRES EXPLICIT USER INSTRUCTION. Never run publish/sync autonomously.**

When the user explicitly asks to publish:

```bash
# Install CLI (if not already installed)
npm i -g clawhub

# Login (GitHub OAuth, account must be 1+ week old)
clawhub login

# Publish
clawhub publish <path> --slug <slug> --name <name> --version <semver>

# Or sync all local skills
clawhub sync --all
```

After publishing, make the GitHub repo public:

```bash
gh repo edit PatFitzner/<skill-name> --visibility public
```

## Key Design Principles

1. **Context window is shared** — only include what the agent doesn't already know
2. **Description is the trigger** — all "when to use" info goes in frontmatter description
3. **Progressive disclosure** — metadata (always loaded, ~100 words) → SKILL.md body (on trigger) → references (on demand)
4. **Match freedom to fragility** — narrow bridge = strict scripts; open field = flexible instructions
5. **Test scripts** by running them before finalizing
6. **Token cost per skill** in system prompt: `195 + sum(97 + len(name) + len(description) + len(location))` chars

## Naming Conventions

- Lowercase hyphen-case: `my-cool-skill`
- Verb-led when possible: `generate-report`, `sync-calendar`
- Namespace by tool when it helps: `gh-review-pr`, `bq-audit-table`
- Directory name matches skill name exactly

## Reference Example

`~/stremio-unwatched/` is a complete working skill with:
- Auth flow with credential caching
- Multiple scripts (bash + node)
- API reference docs
- Proper metadata with os/bins/anyBins gating

Study it when building skills with similar patterns.

## Skill Discovery Locations

Skills are loaded from (highest to lowest precedence):
1. `<workspace>/skills/` — project-specific
2. `~/.openclaw/skills/` — user-global
3. Bundled with OpenClaw installation
4. Extra dirs from `skills.load.extraDirs` in `~/.openclaw/openclaw.json`
