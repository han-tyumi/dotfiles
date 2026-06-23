# Upstream Audit

This skill is a curated, synthesized digest of Anthropic's skill-authoring guidance. The upstream sources evolve. This file lists what to check, when it was last reviewed, and a place to record findings.

## Last reviewed

`2026-06-23`

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

### 2026-06-23

Fanned out one fetcher per source and adversarially re-verified each flagged drift.

- `frontmatter-reference.md`: opening line claimed "all fields are optional" — `name` and `description` are both required per the spec; corrected, and noted the table extends the agentskills.io base spec (the spec's `license`/`compatibility`/`metadata` portability fields are valid but rarely needed, deferred to the spec link).
- `frontmatter-reference.md`: `effort` row omitted `xhigh` (which the same file's substitutions table listed — an internal inconsistency) and pinned `max` to "Opus 4.6 only". Upstream: options are `low/medium/high/xhigh/max`, availability depends on the model. Fixed.
- `frontmatter-reference.md`: added the new `disallowed-tools` field (removes tools from Claude's pool while the skill is active).
- `frontmatter-reference.md`: `name`/`description` rows gained the validation constraints (no XML tags, no reserved words `anthropic`/`claude`, description non-empty/max 1,024 chars).
- `frontmatter-reference.md`: `model` row updated to a current id (`claude-opus-4-8`), plus the `inherit` value and current-turn-only scope.
- `frontmatter-reference.md`: `shell` row now covers ` ```! ` blocks and the Windows `CLAUDE_CODE_USE_POWERSHELL_TOOL=1` requirement; `context` row clarifies a fork inherits the parent conversation (fresh only with Explore/Plan).
- `frontmatter-reference.md`: substitutions table gained the `$name` named-argument row; `${CLAUDE_EFFORT}` notes Ultracode reports as `xhigh`.
- `frontmatter-reference.md`: hooks section corrected from four to five handler types (added `mcp_tool`), added per-handler field summary, and corrected exit-code semantics (exit 1 non-blocking, WorktreeCreate aborts on any non-zero, exit-0-with-JSON for finer control).
- `SKILL.md`: "description loaded into every request" corrected to "at session start" and noted the startup listing is not re-injected after compaction; Step 5 gained name/description validation checks and multi-model testing guidance.
- `quality-checklist.md`: added XML-tag/reserved-word/length checks to Frontmatter and a new Testing section.
- `examples.md`: archetype 8 reworded — `context: fork` keeps tool calls out of main context but (with `general-purpose`) inherits the full parent conversation.
- No fetch failures across all sources. Six alleged drifts were refuted on re-check (license field is out of scope; subagents already in the checklist; plugin-conversion is documented; `context: fork`/`agent:` are valid skill fields) and intentionally not changed.

A follow-up review pass (three lenses — upstream fidelity, mechanics/consistency, dogfooding — each finding adversarially re-verified) caught issues in the edits above:

- `quality-checklist.md`: the "Token efficiency" bullet still read "loaded into every request"; corrected to "at session start" to match `SKILL.md`.
- `frontmatter-reference.md`: the `shell` row's ```` ```! ```` example was malformed markdown (single-backtick span around literal backticks); fixed the escaping.
- `frontmatter-reference.md`: the intro's "superset" framing named base-spec fields it didn't list, reading as incomplete; reworded to "extends" and deferred `license`/`compatibility`/`metadata` to the spec link.
- `SKILL.md`: the compaction behavior was explained twice (token-cost paragraph + lifecycle paragraph); consolidated into the lifecycle paragraph.
- `examples.md`: archetype 8's fork-inheritance caveat was moved out of the key-traits line into its own note to match the other archetypes' concise style.
- Verified against the live context-window doc that the startup skill-description listing genuinely is NOT re-injected after `/compact` ("the skill listing is the one exception. Only skills you actually invoked are preserved") — a review finding that called this wording "misleading" was itself refuted and the wording kept.

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
