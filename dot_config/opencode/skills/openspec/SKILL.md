# OpenSpec — End-to-End Project Development

## Triggers
Use this skill when:
- User wants to start a new project ("new project", "start a project", "bootstrap", "init project")
- User wants to propose a change to an existing OpenSpec project ("propose", "new change", "new feature")
- User wants to continue OpenSpec workflow ("apply", "verify", "archive", "next step", "openspec status")
- User references OpenSpec directly

## Overview

This skill manages the full lifecycle of spec-driven development using the [OpenSpec](https://github.com/Fission-AI/OpenSpec/) framework. The goal is to front-load business decisions through story-first discovery so that implementation flows seamlessly.

**Philosophy**: Human exploration, agent-authored specs. The user provides intent, context, and business rules. The agent produces consistent, verifiable behavior contracts.

**Core principle**: Specs define *externally visible behavior*, not implementation details. If the implementation can change without changing what users see, it doesn't belong in the spec.

---

## Phase 0: Environment Setup

Before any OpenSpec work, verify the environment:

```bash
# Check if openspec is installed
command -v openspec >/dev/null 2>&1 || npm install -g @fission-ai/openspec@latest

# Check version and update if needed
openspec --version
```

If Node.js >= 20.19.0 is not available, inform the user and stop.

---

## Phase 1: Story-First Discovery (New Projects Only)

**Purpose**: Walk through the user journey end-to-end. Each step becomes a capability. Business rules emerge naturally from the narrative.

This is the most important phase. Do NOT rush through it. Use AskUserQuestion for each group. The answers become the foundation for every artifact that follows.

### 1.1 Project Identity

Ask:
- **What is this project called?** (becomes repo/folder name)
- **In one sentence, what does it do?** (becomes the elevator pitch in config.yaml context)
- **Is this a web app or a data/analytics project?** (determines conventions and structure)

### 1.2 The Story

Guide the user through their product narrative with these prompts. Adapt the language based on project type.

**For web apps:**
> "Let's walk through the user journey. Start with: who is the primary user, and what's the first thing they do when they arrive?"

Then iteratively ask:
> "What happens next? What choices does the user have? What does the system do in response?"

Keep asking until the user says the journey is complete. For each step, extract:
- The **actor** (who)
- The **action** (what they do)
- The **system response** (what happens)
- Any **business rules** (constraints, validations, conditions)
- Any **edge cases** the user mentions

**For data/analytics projects:**
> "Let's walk through the data journey. Start with: where does the data come from, and what's the first thing that happens to it?"

Then iteratively ask:
> "What transformation happens next? What business logic is applied? Who consumes the output and how?"

For each step, extract:
- The **source** (where data comes from)
- The **transformation** (what happens to it)
- The **business logic** (rules, definitions, grain)
- The **consumer** (who/what uses the output)
- Any **data quality rules** (not-null, uniqueness, accepted values, relationships)

### 1.3 Business Entities

After the story is complete, summarize the entities that emerged:
> "Based on your story, here are the core business entities I identified: [list]. Did I miss any? Are any of these wrong?"

For each entity, confirm:
- What uniquely identifies it
- Key attributes
- Relationships to other entities

### 1.4 Success Criteria

Ask:
> "How will you know this project is working correctly? What are the key things you'd check?"

These become verification scenarios later.

### 1.5 Constraints and Context

Ask:
> "Are there any constraints I should know about? Existing systems to integrate with, data sources, APIs, team conventions, deployment targets?"

---

## Phase 2: Project Bootstrap

### 2.1 Initialize the project

```bash
# Create project directory
mkdir -p <project-name> && cd <project-name>

# Initialize git
git init

# Initialize OpenSpec
openspec init
```

### 2.2 Generate config.yaml context

Synthesize the discovery answers into the `openspec/config.yaml` context field. The context block should include:

```yaml
schema: spec-driven
context: |
  ## Project: <name>
  <one-sentence description>

  ## Project Type
  <web-app | data-analytics>

  ## Core Entities
  <bulleted list of entities with brief descriptions>

  ## Key Business Rules
  <bulleted list of rules extracted from the story>

  ## Constraints
  <any integration points, existing systems, deployment targets>
```

**Present this to the user for review before writing it.** They may want to adjust wording, add context, or remove items.

### 2.3 Project structure

**For web apps**, create a minimal sensible structure based on the story (don't over-scaffold — let OpenSpec drive what gets built):

```
src/
tests/
```

**For data/analytics (dbt) projects**, use standard dbt conventions:

```
models/
  staging/       # 1:1 with source tables, light renaming/casting
  intermediate/  # Cross-model joins, business logic
  marts/         # Final consumer-facing models
seeds/
macros/
tests/
analyses/
```

Additional dbt conventions to encode in config.yaml rules:
- Staging models: `stg_<source>__<table>.sql`
- Intermediate models: `int_<entity>__<verb>.sql`
- Mart models: `fct_<entity>.sql` or `dim_<entity>.sql`
- Every model gets a YAML schema file with descriptions and tests
- Use `ref()` and `source()` exclusively — no hardcoded table names

### 2.4 CLAUDE.md

Create a project-level `CLAUDE.md` with:
- Project name and description (from discovery)
- OpenSpec workflow reminder: "This project uses OpenSpec for spec-driven development. Run `openspec status` to see current state."
- Project-type-specific conventions (dbt naming if applicable)
- Link to `openspec/config.yaml` for full context

---

## Phase 3: Propose a Change

This phase applies to both new projects (initial build) and existing projects (new features/changes).

### For new projects
The first change is typically the initial build. Name it descriptively (e.g., `initial-build`, `mvp`, or a domain-specific name).

### Process

```bash
# Create change scaffold
openspec new <change-name>

# Check what artifacts are needed
openspec status <change-name>

# Get instructions for the next artifact
openspec instructions <change-name> --artifact proposal
```

### Writing the Proposal

Using the story-first discovery answers, write `proposal.md` covering:

- **Why**: The problem or opportunity (from the story narrative)
- **What Changes**: High-level description of what's being built/changed
- **Capabilities**: Each step from the user journey becomes a capability
  - **New Capabilities**: For greenfield or new features
  - **Modified Capabilities**: For changes to existing behavior
- **Impact**: What existing behavior is affected

Each capability gets a kebab-case name that will become a spec file.

---

## Phase 4: Write Specs

After proposal is approved, create specs for each capability identified.

```bash
openspec instructions <change-name> --artifact specs
```

### Spec format

Each spec file lives at `openspec/changes/<change-name>/specs/<capability>/spec.md` and uses delta format:

```markdown
## ADDED Requirements

### Requirement: <descriptive-name>

#### Scenario: <scenario-name>
- **WHEN** <condition from the user story>
- **THEN** <expected behavior / system response>

#### Scenario: <edge-case>
- **WHEN** <edge case from discovery>
- **THEN** <expected behavior>
```

**Key rules:**
- Use RFC 2119 keywords: SHALL/MUST for requirements, SHOULD for recommendations, MAY for optional
- One spec file per capability (not per entity or per page)
- Scenarios come directly from the story — each step, each business rule, each edge case
- Specs describe WHAT the system does, not HOW it's implemented
- Include the success criteria from Phase 1.4 as verification scenarios

### For dbt projects

Specs should capture:
- Source-to-staging mapping (which source fields map to which staging columns)
- Business logic definitions (how metrics are calculated, how entities are classified)
- Grain of each model (what constitutes a unique row)
- Data quality expectations (not null, unique, accepted values, relationships)
- Consumer expectations (what downstream consumers depend on)

---

## Phase 5: Design (When Needed)

Design is only needed for cross-cutting, complex, or ambiguous changes. Skip it for straightforward work.

```bash
openspec instructions <change-name> --artifact design
```

Indicators that design IS needed:
- Multiple capabilities interact in non-obvious ways
- There are meaningful architectural trade-offs
- The user expressed uncertainty about approach
- Integration with external systems requires coordination

Design covers: Context, Goals/Non-Goals, Decisions (with rationale), Risks/Trade-offs, Open Questions.

---

## Phase 6: Generate Tasks

```bash
openspec instructions <change-name> --artifact tasks
```

Tasks are an implementation checklist derived from specs:

```markdown
## 1. <Task Group>
- [ ] 1.1 <specific, small task>
- [ ] 1.2 <another task>

## 2. <Task Group>
- [ ] 2.1 <task>
```

**Rules:**
- Each task should be completable in one session
- Order by dependency (what must exist before what)
- Group logically (by capability, by layer, by entity)
- For dbt: order as sources → staging → intermediate → marts → tests

---

## Phase 7: Apply (Implementation)

```bash
# See what tasks are pending
openspec status <change-name>

# Get apply instructions
openspec instructions <change-name> --artifact apply
```

Work through tasks sequentially. After completing each task:
- Mark it complete in `tasks.md`: `- [ ]` → `- [x]`
- Commit the code with a message referencing the task number

### Implementation guidance

- Read the relevant spec before implementing each task
- The spec is the contract — implement exactly what it describes
- If implementation reveals a spec gap, update the spec first, then implement
- Don't add behavior that isn't in a spec (no gold-plating)

---

## Phase 8: Verify

After all tasks are complete:

```bash
openspec verify <change-name>
```

This checks:
- **Completeness**: Every spec requirement has corresponding implementation
- **Correctness**: Implementation matches spec behavior
- **Coherence**: No contradictions between specs

If verification fails, fix implementation or update specs as needed.

---

## Phase 9: Archive

Once verified and the change is merged/deployed:

```bash
openspec archive <change-name>
```

This:
1. Merges delta specs into `openspec/specs/` (the source of truth)
2. Moves the change to `openspec/changes/archive/YYYY-MM-DD-<name>/`
3. Specs now reflect the new system behavior

---

## Command Reference

| Action | Command |
|--------|---------|
| Check status | `openspec status` |
| List changes | `openspec list` |
| View details | `openspec show <name>` |
| Validate structure | `openspec validate` |
| Interactive dashboard | `openspec view` |
| Get next instructions | `openspec instructions <name>` |
| Sync specs without archiving | `openspec sync <name>` |
| Archive multiple changes | `openspec bulk-archive` |
| Explore (freeform thinking) | `openspec explore` |

---

## Workflow Summary

```
Story-First Discovery
        |
        v
  Project Bootstrap (git, structure, config.yaml, CLAUDE.md)
        |
        v
  openspec new <change>
        |
        v
  proposal.md  (WHY + WHAT — capabilities from user story)
        |
        v
  specs/*.md   (WHAT exactly — behavior contracts from story steps)
        |
        v
  design.md    (HOW — only if complex/ambiguous)
        |
        v
  tasks.md     (implementation checklist from specs)
        |
        v
  apply        (implement tasks, mark complete)
        |
        v
  verify       (check specs match implementation)
        |
        v
  archive      (merge deltas into source-of-truth specs)
```

---

## Guiding Principles

1. **Fluid not rigid** — No phase gates. Work on what makes sense.
2. **Story-first** — Business narratives drive capabilities, capabilities drive specs, specs drive code.
3. **Behavior, not implementation** — Specs describe what users see, not how it's built.
4. **Front-load decisions** — Business definitions, entity relationships, and workflows are locked down before any code is written. Technical details emerge during implementation.
5. **Delta-based evolution** — Every change is a delta against current specs. History is preserved.
6. **User learning** — Explain what each phase does and why. The user should understand the process, not just follow it.
