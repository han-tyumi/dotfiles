# Upstream Audit

This skill is a curated, synthesized digest of Anthropic's skill-authoring guidance. The upstream sources evolve. This file lists what to check, when it was last reviewed, and a place to record findings.

## Last reviewed

`2026-05-01`

## Sources to verify

When auditing, fetch each source and look for changes that affect the local files (`SKILL.md`, `frontmatter-reference.md`, `examples.md`, `quality-checklist.md`).

### Core (directly about skills)

- [ ] **Claude Code skills doc** — https://code.claude.com/docs/en/skills
  - Watch for: new frontmatter fields, changes to character-budget caps, new string substitutions, changes to `disable-model-invocation` / `user-invocable` semantics, changes to subagent (`context: fork`) patterns, bundled skills additions.
- [ ] **Agent Skills best practices (Anthropic)** — https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
  - Watch for: description-writing rules, validation constraints (reserved words, XML tags), multi-model testing guidance, structural recommendations.
- [ ] **Agent Skills spec (open standard)** — https://agentskills.io/specification
  - Watch for: spec version bumps, new required/optional fields, format changes.
- [ ] **Anthropic reference skills repo** — https://github.com/anthropics/skills
  - Watch for: new archetype patterns, anti-patterns, conventions Anthropic adopts in their own skills.

### Adjacent (constrain skill design)

- [ ] **Best practices** — https://code.claude.com/docs/en/best-practices
  - Watch for: CLAUDE.md authoring patterns, when to prefer skills over CLAUDE.md, ecosystem-level recommendations.
- [ ] **Features overview** — https://code.claude.com/docs/en/features-overview
  - Watch for: decision tables (skill vs hook vs subagent vs MCP vs CLAUDE.md), context-cost trade-offs, feature layering.
- [ ] **Hooks** — https://code.claude.com/docs/en/hooks
  - Watch for: lifecycle events, when hooks supersede skills (deterministic enforcement vs advisory), `hooks` frontmatter field for skills.
- [ ] **Subagents** — https://code.claude.com/docs/en/sub-agents
  - Watch for: `context: fork` patterns, skill preloading via `skills:` field, agent types (Explore/Plan/general-purpose) and their semantics.
- [ ] **Plugins** — https://code.claude.com/docs/en/plugins
  - Watch for: skill packaging, plugin manifest schema, namespacing, distribution path for finished skills.
- [ ] **The .claude directory** — https://code.claude.com/docs/en/claude-directory
  - Watch for: skill location conventions, scope hierarchy (enterprise/personal/project/plugin), discovery rules.
- [ ] **Context window** — https://code.claude.com/docs/en/context-window
  - Watch for: skill loading lifecycle, description budget, post-compaction reattachment budgets (25K combined, 5K per skill).
- [ ] **Memory (CLAUDE.md, auto memory)** — https://code.claude.com/docs/en/memory
  - Watch for: when to use CLAUDE.md vs skills, auto-memory mechanics, path-specific rules in `.claude/rules/`.

### Cross-cutting

- [ ] **How Claude Code works** — https://code.claude.com/docs/en/how-claude-code-works
  - Watch for: agentic loop changes, what Claude sees at startup, system prompt construction, when auto-compaction fires — the architectural mental model that explains *why* skill authoring rules exist.

## Audit log

Newest first. Record what changed upstream and what was updated locally.

### 2026-05-01

- Found stale "250 char description limit" claim in `SKILL.md:102`, `SKILL.md:199`, `quality-checklist.md:20`, and `frontmatter-reference.md:20`. Current docs: combined `description` + `when_to_use` truncated at 1,536 chars in skill listing. Updated all four.
- `frontmatter-reference.md` was missing `when_to_use` and `arguments` rows. Added.
- `frontmatter-reference.md` substitutions table was missing `${CLAUDE_EFFORT}`. Added.
- `create-skill`'s own frontmatter lacked `when_to_use`. Added to model the pattern.
- Source list expanded from 4 to 13 entries to cover the broader ecosystem (hooks, subagents, plugins, context-window, memory, etc.) — previous list was too narrow and missed legitimate audit targets.
- `SKILL.md`: expanded the decision tree to cover deterministic-vs-advisory distinction (skills vs hooks) and `.claude/rules/` loading-strategy distinction. Added a "Token cost" section with the 25K/5K compaction-reattachment numbers and the "ultrathink" trigger word. Added plugin-conversion link.
- `examples.md`: added a "skill + MCP" archetype; extended the forked-subagent archetype with the `skills:` preloading pattern.
- `frontmatter-reference.md`: expanded `paths` row with glob examples; expanded `agent` row with descriptions of Explore/Plan/general-purpose semantics; noted enterprise/managed considerations for `disable-model-invocation`.
- `quality-checklist.md`: added items for the broader mechanisms (rules vs CLAUDE.md vs hook vs MCP vs subagent considered before adopting a skill).

## Audit procedure

When the scheduled agent runs:

1. Read this file to understand the source list.
2. Fetch each source with WebFetch.
3. Diff against the local files (`SKILL.md`, `examples.md`, `frontmatter-reference.md`, `quality-checklist.md`).
4. Report findings — list of stale claims, missing fields, deprecated patterns. Do not auto-edit; semantic drift needs human review.
5. If no drift, just bump the "Last reviewed" date and append a "no changes" entry to the audit log.
