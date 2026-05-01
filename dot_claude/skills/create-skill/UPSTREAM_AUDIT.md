# Upstream Audit

This skill is a curated, synthesized digest of Anthropic's skill-authoring guidance. The upstream sources evolve. This file lists what to check, when it was last reviewed, and a place to record findings.

## Last reviewed

`2026-05-01`

## Sources to verify

When auditing, fetch each source and look for changes that affect the local files (`SKILL.md`, `frontmatter-reference.md`, `examples.md`, `quality-checklist.md`).

- [ ] **Claude Code skills doc** — https://code.claude.com/docs/en/skills
  - Watch for: new frontmatter fields, changes to character-budget caps, new string substitutions, changes to `disable-model-invocation` / `user-invocable` semantics, changes to subagent (`context: fork`) patterns.
- [ ] **Agent Skills best practices** — https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
  - Watch for: description-writing rules, validation constraints (reserved words, XML tags), multi-model testing guidance, structural recommendations.
- [ ] **Agent Skills spec** — https://agentskills.io/specification
  - Watch for: spec version bumps, new required/optional fields, format changes.
- [ ] **Anthropic reference skills** — https://github.com/anthropics/skills
  - Watch for: new archetype patterns, anti-patterns, conventions Anthropic adopts in their own skills.

## Audit log

Newest first. Record what changed upstream and what was updated locally.

### 2026-05-01

- Found stale "250 char description limit" claim in `SKILL.md:102`, `SKILL.md:199`, `quality-checklist.md:20`, and `frontmatter-reference.md:20`. Current docs: combined `description` + `when_to_use` truncated at 1,536 chars in skill listing. Updated all four.
- `frontmatter-reference.md` was missing `when_to_use` and `arguments` rows. Added.
- `frontmatter-reference.md` substitutions table was missing `${CLAUDE_EFFORT}`. Added.
- `create-skill`'s own frontmatter lacked `when_to_use`. Added to model the pattern.

## Audit procedure

When the scheduled agent runs:

1. Read this file to understand the source list.
2. Fetch each source with WebFetch.
3. Diff against the local files (`SKILL.md`, `examples.md`, `frontmatter-reference.md`, `quality-checklist.md`).
4. Report findings — list of stale claims, missing fields, deprecated patterns. Do not auto-edit; semantic drift needs human review.
5. If no drift, just bump the "Last reviewed" date and append a "no changes" entry to the audit log.
