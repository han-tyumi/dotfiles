---
name: create-skill
description: Create or improve Claude Code skills from a prompt. Handles new skills and updates to existing ones, following Anthropic best practices for scope, invocation, and structure.
when_to_use: User asks to create, improve, audit, or convert a slash command / CLAUDE.md section into a skill, or mentions "skill" in the context of authoring.
argument-hint: [description of the skill to create]
---

# Create Skill

Create or improve Claude Code skills from a user description, following
Anthropic's documented best practices for efficient LLM usage.

## Workflow

### Step 0: New skill or update?

Determine whether the request is for a new skill or an update to an existing one.

**If updating an existing skill**, jump to [Updating existing skills](#updating-existing-skills).

**If creating a new skill**, continue to Step 1.

### Step 1: Determine if a skill is the right mechanism

Before creating a skill, verify the request isn't better served by another
extension. Ask yourself:

| Signal                                    | Use instead            |
|-------------------------------------------|------------------------|
| "Always do X" rule for all sessions       | CLAUDE.md (always loaded) |
| Rule scoped to file types                 | `.claude/rules/` with `paths` frontmatter — loads only when matching files are read, cheaper than CLAUDE.md for niche rules |
| Deterministic enforcement (block, validate, force) | Hook in settings.json — hooks are deterministic; skills are advisory and the model can ignore them |
| External service connection               | MCP server             |
| Isolated worker with custom tools/model   | Subagent definition    |

Create a skill when the request is:
- Reusable knowledge Claude should load on demand (reference skill).
- A repeatable workflow invoked with `/name` (task skill).
- Domain knowledge scoped to specific file patterns (path-scoped skill).
- A combination of knowledge and workflow (hybrid skill).

Note: skills can later be converted to plugins for broader distribution. Start
with a standalone skill; convert to a plugin when sharing across projects or
teams. See https://code.claude.com/docs/en/plugins for the conversion path
and manifest schema.

If a different mechanism is more appropriate, tell the user and help them with
that instead.

### Step 2: Gather requirements

Parse `$ARGUMENTS` for the skill description. If the description is clear enough
to make all key decisions, skip the interview and proceed to drafting.

Otherwise, ask only the questions whose answers aren't obvious from context:

**Always determine:**
1. **Purpose** -- Reference knowledge, task workflow, or hybrid?
2. **Scope** -- Personal (`~/.claude/skills/`) or project (`.claude/skills/`)?
3. **Invocation** -- User-only (`/name`), Claude-auto, or both (default)?
4. **Name** -- Lowercase, numbers, hyphens only. Max 64 chars.

**Determine when relevant:**
5. **Content strategy** (for reference skills) -- Content lives on a spectrum
   from fully inline (all answers in skill files) to fully navigator (points to
   external URLs and sources). Mix freely: quick-reference inline for common
   lookups, URLs for deep dives, `!`command`` for live data. See archetype 9 in
   [examples.md](examples.md).
6. **Arguments** -- Does it accept arguments? What are they?
7. **Isolation** -- Should it run in a subagent (`context: fork`)?
8. **Tool restrictions** -- Should tool access be scoped (`allowed-tools`)?
9. **Model/effort** -- Does it benefit from a specific model or effort level?
10. **Hooks** -- Does it need lifecycle hooks?
11. **Path scoping** -- Should it auto-activate only for certain file patterns?

### Step 3: Research (if needed)

If the skill relates to existing project patterns, tools, or workflows:

- Read relevant files to understand current conventions.
- Check for existing skills that overlap or could be extended instead.
- Check CLAUDE.md and `.claude/rules/` for conventions the skill should follow.
- Read 1-2 of the user's existing skills (if any) to match their style:
  structure, tone, comment style, level of detail. Consistency across skills
  matters.

### Step 4: Draft and create the skill

For complex skills (multiple files, hooks, `context: fork`, or unfamiliar
patterns), read the supporting reference files before drafting:

- [frontmatter-reference.md](frontmatter-reference.md) -- All frontmatter
  fields, string substitutions, dynamic context injection, and decision guides.
- [examples.md](examples.md) -- Archetypes, patterns, and anti-patterns.
- [quality-checklist.md](quality-checklist.md) -- Quality standards to verify
  against before finalizing.

For simple skills, the principles in this file are sufficient. Don't load 600+
lines of reference to create a 15-line skill.

#### Writing the description

The description is the most impactful part of the skill. Claude uses it to
decide when to load the skill. The combined `description` + `when_to_use` text
is truncated at 1,536 characters in the skill listing — front-load the key use
case so it survives the cap.

- Front-load the primary use case. The first phrase should answer "what does this
  do?"
- Include trigger keywords that match how users naturally ask for this
  functionality.
- Be specific enough that Claude can distinguish this skill from others.
- Omit filler like "This skill..." or "Use this to..." -- start with the action.

Good: `Generate React components following our design system in src/components/.`
Bad: `A helpful skill for working with React components in the project.`

Write descriptions in third person. The description is injected into the system
prompt, and wrong point-of-view causes discovery problems.

Good: `Processes Excel files and generates reports.`
Bad: `I can help you process Excel files.`
Bad: `You can use this to process Excel files.`

#### Writing the content

**Write for an LLM.** Be direct and imperative ("Run the tests", not "You should
consider running the tests"). Use specific commands and paths, not vague
references. Structure with headers and numbered steps for sequential workflows.
Avoid preamble, motivation, and filler.

**Claude is already smart.** Only add context it doesn't already have. Challenge
each piece of information: "Does Claude really need this explanation?" If Claude
already knows how PDFs work, don't explain PDFs. If a term is standard, don't
define it. Every token competes with conversation history for context space.

**Match specificity to fragility.** Use high freedom (general guidance) for
flexible tasks where multiple approaches work. Use low freedom (exact scripts,
"run this command") for fragile operations where consistency matters. Most skills
fall somewhere in between.

**Use examples for output quality.** When output format or style matters, include
input/output example pairs. A few well-crafted examples steer Claude more
reliably than descriptions alone -- and can replace verbose instructions entirely
when the pattern is clear from the examples.

**Use consistent terminology.** Pick one term for each concept and use it
throughout. Don't mix "API endpoint", "URL", "route", and "path" for the same
thing.

**Match complexity to the task.** A 15-line SKILL.md with no supporting files is
perfectly valid for simple skills. Only add supporting files when SKILL.md would
exceed ~200 lines or when reference material would distract from the core
instructions.

**Include verification.** Give Claude a way to check its own work: test commands,
expected outputs, validation steps. This is the single highest-leverage thing for
quality.

**Consider token cost.** Skills without `disable-model-invocation` have their
description loaded into every request. Keep it concise. Reference material
belongs in supporting files, not inlined in SKILL.md.

**Lifecycle and compaction.** Full SKILL.md content only enters the
conversation when the skill is invoked, then stays for the rest of the
session. After auto-compaction, each invoked skill is reattached with its
first ~5,000 tokens preserved, sharing a combined ~25,000-token budget
across all reattached skills (filled from the most recently invoked skill
backwards — older invocations can be dropped entirely). Front-load the most
important instructions so they survive compaction.

**Extended thinking.** Including the word `ultrathink` anywhere in the skill
content enables extended thinking when the skill is invoked. Use sparingly —
this materially increases per-turn cost.

**Use doc URLs for deep dives.** For reference skills covering broad topics,
include a table of fetchable URLs rather than inlining all the content. Claude
can WebFetch the relevant URL when more detail is needed. This keeps the skill
compact and current -- the URLs always point to the latest docs.

#### File organization

Simple skills need only SKILL.md. Add supporting files when the skill has
substantial reference material, templates, or bundled scripts:

```
my-skill/
  SKILL.md           # Core instructions (required, under 500 lines)
  reference.md       # Detailed docs (loaded on demand via Read)
  template.md        # Templates for Claude to fill in
  examples/          # Example outputs
  scripts/           # Helper scripts Claude can execute
```

Reference supporting files from SKILL.md with relative links so Claude knows
they exist: `See [reference.md](reference.md) for full API details.`

Keep references one level deep from SKILL.md. Avoid chains where file A
references file B which references file C -- Claude may partially read nested
references. Add a table of contents at the top of reference files over 100 lines
so Claude can see the full scope even when previewing.

#### Creating the files

1. Create the skill directory at the determined scope path.
2. Write `SKILL.md` with proper frontmatter and content.
3. Write any supporting files.
4. If scripts are included, make them executable with `chmod +x`.

### Step 5: Verify

Run through [quality-checklist.md](quality-checklist.md). At minimum confirm:

- SKILL.md has valid YAML frontmatter and is under 500 lines.
- Combined `description` + `when_to_use` is under 1,536 characters and front-loads the key use case.
- Name uses only lowercase letters, numbers, and hyphens.
- `disable-model-invocation: true` is set if the skill has side effects.
- `context: fork` is only used when content forms a complete, self-contained
  task.

Report: skill name, location, invocation method (`/name` or auto), and a brief
summary.

## Updating existing skills

When the request is to update, improve, or review an existing skill:

### 1. Read the existing skill

Read SKILL.md and all supporting files. Understand the current structure, purpose,
frontmatter, and content strategy.

### 2. Identify what to change

Common update types:

- **Add functionality** -- new sections, supporting files, or arguments.
- **Improve quality** -- apply best practices from
  [quality-checklist.md](quality-checklist.md). Fix anti-patterns from
  [examples.md](examples.md).
- **Refactor structure** -- extract supporting files from an overgrown SKILL.md,
  improve description, add missing frontmatter fields.
- **Fix issues** -- broken references, stale content, incorrect frontmatter.
- **Review/audit** -- run the skill through the full quality checklist and report
  findings.

### 3. Apply changes

- Edit existing files rather than rewriting from scratch. Preserve the author's
  style and structure where they work well.
- When extracting to supporting files, keep SKILL.md as the clear entrypoint with
  links to the new files.
- When adding frontmatter fields, only add fields that change behavior.

### 4. Verify

Run Step 5 from the creation workflow. Additionally confirm:

- Existing functionality is preserved (no regressions).
- The skill's description still accurately reflects its content.
- Supporting file references are not broken.

Report what changed and why.

## Rules

- **Never create a skill that duplicates an existing one.** Check first.
- **Never put secrets, credentials, or tokens in skill files.**
- **Prefer editing an existing skill** if the request extends existing
  functionality.
- **Follow the user's CLAUDE.md conventions** for code style and structure.
- **Don't over-engineer.** A 20-line SKILL.md is better than a 200-line one with
  unused flexibility. Not every skill needs supporting files.
