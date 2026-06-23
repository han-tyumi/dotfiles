# Skill Examples and Patterns

## Archetypes

### 1. Minimal skill

Not every skill needs supporting files or complex frontmatter. A focused skill
can be just a few lines.

```yaml
---
name: commit-msg
description: Generate a conventional commit message from staged changes.
disable-model-invocation: true
---

Generate a commit message for the staged changes:

1. Run `git diff --cached --stat` and `git diff --cached` to see what changed.
2. Write a conventional commit message: `type(scope): description`.
3. Use the imperative mood. Keep the subject line under 72 characters.
4. Add a body only if the "why" isn't obvious from the subject.
```

Key traits: 10 lines of content, no supporting files, no arguments. Simple task,
simple skill.

### 2. Reference skill (auto-invoked by Claude)

Provides domain knowledge Claude applies to current work. Loads automatically
when Claude determines it's relevant.

```yaml
---
name: api-conventions
description: REST API design patterns for Express.js services in src/api/. Use when writing or reviewing API endpoints.
paths: "src/api/**/*.ts"
---

# API Conventions

## URL patterns
- Use kebab-case: `/user-profiles`, not `/userProfiles`.
- Nest resources: `/users/:id/orders`.
- Use plural nouns for collections.

## Response format
- Always return `{ data, error, meta }`.
- Paginate with `?page=1&limit=20`.
- Include `meta.total` for paginated responses.

## Error format
- Use HTTP status codes correctly.
- Error body: `{ error: { code: "NOT_FOUND", message: "..." } }`.
```

Key traits: no `disable-model-invocation`, `paths` to scope loading, pure
knowledge with no task.

### 3. Task skill (user-invoked only)

Executes a specific workflow with side effects. Only runs when the user types
`/name`.

```yaml
---
name: deploy
description: Build, test, and deploy the application to the staging environment.
disable-model-invocation: true
argument-hint: [environment]
---

# Deploy

Deploy to the `$ARGUMENTS` environment (default: staging).

1. Run the full test suite: `npm test`.
2. Build: `npm run build`.
3. Deploy: `npm run deploy -- --env $ARGUMENTS`.
4. Verify: `curl -s https://$ARGUMENTS.example.com/health | jq .status`.
5. Report the result.

If any step fails, stop and report the error. Do not proceed to the next step.
```

Key traits: `disable-model-invocation: true`, `argument-hint`, numbered steps,
verification, clear failure handling.

### 4. Research skill (forked subagent)

Runs an investigation in isolated context, returning a summary.

```yaml
---
name: deep-research
description: Investigate a topic across the codebase. Returns findings without polluting main context.
context: fork
agent: Explore
argument-hint: [topic to investigate]
---

# Research: $ARGUMENTS

Investigate `$ARGUMENTS` thoroughly:

1. Search for relevant files with Glob and Grep.
2. Read and analyze the key files.
3. Trace the data flow and call graph.
4. Identify patterns, concerns, and dependencies.

Return a structured report:
- **Summary**: 2-3 sentence overview.
- **Key files**: paths and their roles.
- **Data flow**: how data moves through the system.
- **Concerns**: potential issues or risks.
- **Recommendations**: suggested actions.
```

Key traits: `context: fork`, `agent: Explore`, self-contained task, structured
output format.

See also: subagents can preload companion skills via their own `skills:`
frontmatter field — the inverse pattern. Use when you have a custom subagent
in `.claude/agents/` that should always have a skill's content available
without invoking it explicitly.

### 5. Hybrid skill (knowledge + workflow)

Combines reference knowledge with an invocable workflow.

```yaml
---
name: test-patterns
description: Testing conventions and helpers for this project. Also invocable as /test-patterns to generate test scaffolding for a file.
argument-hint: [file to generate tests for]
---

# Testing Patterns

## Conventions (applied automatically)
- Use `vitest` for unit tests, `playwright` for E2E.
- Co-locate test files: `foo.ts` -> `foo.test.ts`.
- Use `describe`/`it` blocks. Name tests as sentences.
- Prefer `toEqual` over `toBe` for objects.

## Generate tests (when invoked with /test-patterns)

If arguments are provided, generate a test file for `$ARGUMENTS`:

1. Read the source file.
2. Identify exported functions and their signatures.
3. Create a test file following the conventions above.
4. Include edge cases: empty input, null, boundary values.
5. Run `npx vitest $ARGUMENTS --run` to verify.
```

Key traits: works both as auto-loaded knowledge and manual workflow, clear
separation between the two modes.

### 6. Skill with supporting files

Keeps SKILL.md focused by moving reference material to separate files.

```yaml
---
name: database-ops
description: Database migration and query patterns. Reference for schema design and migration workflows.
---

# Database Operations

## Quick reference
- Migrations: `npx prisma migrate dev --name <name>`.
- Generate client: `npx prisma generate`.
- Studio: `npx prisma studio`.

## Additional resources
- For schema conventions, see [schema-guide.md](schema-guide.md).
- For migration examples, see [migration-examples.md](migration-examples.md).
- For query patterns, see [query-patterns.md](query-patterns.md).
```

Key traits: SKILL.md is short and actionable, detailed docs in supporting files
referenced with relative links.

### 7. Skill with hooks

Uses lifecycle hooks for validation or automation.

```yaml
---
name: safe-db-query
description: Execute read-only database queries with validation.
allowed-tools: Bash
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "${CLAUDE_SKILL_DIR}/scripts/validate-readonly.sh"
---

# Safe Database Query

Run read-only queries against the database. Write operations are blocked by
the validation hook.

Use `$ARGUMENTS` as the query topic or question to answer.
```

Key traits: `hooks` for safety, `${CLAUDE_SKILL_DIR}` for bundled scripts,
`allowed-tools` for tool restriction.

### 8. Skill with dynamic context injection

Injects live data before Claude sees the content.

```yaml
---
name: pr-review
description: Review the current pull request with full context.
context: fork
agent: general-purpose
disable-model-invocation: true
---

# PR Review

## Context
- Branch: !`git branch --show-current`
- Diff stats: !`git diff --stat main...HEAD`
- Changed files: !`git diff --name-only main...HEAD`

## Full diff
!`git diff main...HEAD`

## Task
Review this PR for:
1. Correctness and edge cases.
2. Security issues (injection, auth, secrets).
3. Performance concerns.
4. Code style and readability.

Provide feedback organized by severity: critical, warnings, suggestions.
```

Key traits: `` !`command` `` for live data injection, `context: fork` to keep
the review's tool calls out of the main context, `disable-model-invocation: true`
for manual review.

Note: with `agent: general-purpose` the fork inherits the full parent
conversation and CLAUDE.md; use `agent: Explore` or `Plan` when you want it to
start fresh instead.

### 9. Navigator skill (URL-based reference)

Uses a map of doc URLs for deep dives instead of inlining all content. Stays
current and token-efficient. SKILL.md acts as a decision framework and index;
a quick-reference supporting file covers the most common lookups.

```yaml
---
name: infra-ref
description: Infrastructure reference and navigator. Use when answering questions about AWS, Terraform, CI/CD, or deployment configuration.
---

# Infrastructure Reference

## When to look where

| Question about...       | Check                          |
|-------------------------|--------------------------------|
| AWS resource config     | Terraform files in `infra/`    |
| CI/CD pipeline          | `.github/workflows/`           |
| Deploy process          | [deploy-guide.md](deploy-guide.md) |
| Monitoring/alerting     | Grafana dashboards (see URLs)  |

## Documentation URLs

Fetch these for detailed information:

| Topic              | URL                                               |
|--------------------|---------------------------------------------------|
| Terraform AWS      | `https://registry.terraform.io/providers/...`     |
| GitHub Actions     | `https://docs.github.com/en/actions`              |
| Our runbooks       | `https://wiki.example.com/infra/runbooks`         |

## Quick reference

For common lookups, see [quick-reference.md](quick-reference.md).

## Answering questions

1. Check quick-reference.md first.
2. If the answer is there, respond directly.
3. If more detail is needed, fetch the relevant URL.
```

Key traits: SKILL.md is a map, not an encyclopedia. Doc URLs for deep dives.
Quick-reference file for common lookups. Stays current because URLs point to
latest docs.

### 10. Skill paired with an MCP server

When an MCP server provides tools but Claude needs guidance on which to use
when (and the project's safety conventions for them), a skill bridges the
gap. The MCP server supplies connectivity and tool definitions; the skill
teaches the workflow.

```yaml
---
name: db-explorer
description: Inspect the production Postgres schema and run safe read-only queries via the postgres MCP server. Use for schema questions, row counts, or analytical investigation.
allowed-tools: mcp__postgres
---

# Database Explorer

Use the postgres MCP server to investigate the production database safely.

## Common workflows

| Question                  | Tool to use                          |
|---------------------------|--------------------------------------|
| What tables exist?        | `mcp__postgres__list_tables`         |
| Schema of a table?        | `mcp__postgres__describe_table`      |
| Row count?                | `mcp__postgres__query` with `SELECT COUNT(*)` |
| Sample rows?              | `mcp__postgres__query` with `LIMIT 5` |

## Safety rules

- Read-only by default. Never `INSERT`/`UPDATE`/`DELETE` without explicit
  user confirmation.
- For tables over 1M rows, always include `LIMIT` or a `WHERE` clause that
  uses an indexed column.
- Wrap analytical queries in `EXPLAIN ANALYZE` first when the cost is
  uncertain.
```

Key traits: pairs with an MCP server (`allowed-tools: mcp__postgres`) without
duplicating tool definitions. The skill teaches *when* to call which MCP tool
plus the safety conventions for this codebase. MCP provides the connection;
the skill provides the playbook.

## Anti-patterns

### Too vague to trigger

```yaml
# BAD -- Claude can't distinguish this from anything
description: Helps with code

# GOOD -- specific trigger keywords and scope
description: Generate React components following our design system patterns in src/components/.
```

### Side effects without protection

```yaml
# BAD -- Claude might auto-deploy
---
name: deploy
description: Deploy the app
---

# GOOD -- manual invocation only
---
name: deploy
description: Deploy the app
disable-model-invocation: true
---
```

### Guidelines in a forked context

```yaml
# BAD -- subagent gets guidelines but no task to execute
---
name: code-style
description: Code style conventions
context: fork
---
Use 2-space indentation...

# GOOD -- reference skill, no fork needed
---
name: code-style
description: Code style conventions
---
Use 2-space indentation...
```

### Everything in SKILL.md

```yaml
# BAD -- 800 lines of API docs crammed into one file
---
name: api-guide
---
[800 lines of reference material]

# GOOD -- focused SKILL.md with supporting files
---
name: api-guide
---
Quick reference for API patterns.
For full docs, see [api-reference.md](api-reference.md).
```

### Reinventing CLAUDE.md

```yaml
# BAD -- "always do X" belongs in CLAUDE.md, not a skill
---
name: code-rules
description: Rules for all code
---
Always use semicolons. Always use 2-space indentation...

# GOOD -- put it in CLAUDE.md or .claude/rules/ instead
```

### Over-engineered simple skill

```yaml
# BAD -- supporting files and complex structure for a simple task
my-simple-skill/
  SKILL.md
  reference.md
  examples.md
  scripts/helper.sh

# GOOD -- just SKILL.md when the task is straightforward
my-simple-skill/
  SKILL.md
```
