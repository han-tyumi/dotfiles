# Frontmatter Reference

All fields are optional. Only `description` is recommended for every skill.

For deep dives, fetch these authoritative sources:
- Claude Code skills: `https://code.claude.com/docs/en/skills`
- Agent Skills spec: `https://agentskills.io/specification`
- Skill authoring best practices: `https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices`
- Claude prompting best practices: `https://platform.claude.com/docs/en/docs/build-with-claude/prompt-engineering/claude-prompting-best-practices`
- Example skills: `https://github.com/anthropics/skills` (Anthropic's reference
  implementations, includes document processing, creative, enterprise skills)
- Validation tool: `https://github.com/agentskills/agentskills/tree/main/skills-ref`
  (validate SKILL.md structure and frontmatter)

## Fields

| Field                      | Description                                                                                                            |
|----------------------------|------------------------------------------------------------------------------------------------------------------------|
| `name`                     | Display name and `/slash-command`. Lowercase letters, numbers, hyphens. Max 64 chars. Defaults to directory name.      |
| `description`              | What the skill does and when to use it. Front-load the key use case. Combined with `when_to_use`, truncated at 1,536 chars in listings. |
| `when_to_use`              | Extra trigger phrases / example requests, appended to `description` in the listing. Counts toward the 1,536-char cap.  |
| `argument-hint`            | Hint shown during autocomplete. E.g., `[issue-number]` or `[filename] [format]`.                                      |
| `arguments`                | Named positional arguments for `$name` substitution in the skill content. Space-separated string or YAML list.         |
| `disable-model-invocation` | `true` prevents Claude from loading the skill automatically. Use for workflows with side effects or manual triggers.   |
| `user-invocable`           | `false` hides from the `/` menu. Use for background knowledge users shouldn't invoke directly.                         |
| `allowed-tools`            | Tools allowed without permission prompts. Supports patterns -- see [Tool patterns](#tool-patterns-for-allowed-tools).  |
| `model`                    | Model override: `sonnet`, `opus`, `haiku`, or a full model ID like `claude-opus-4-6`.                                  |
| `effort`                   | Effort level: `low`, `medium`, `high`, `max`. Overrides session effort. `max` is Opus 4.6 only.                        |
| `context`                  | Set to `fork` to run in a forked subagent context. Content becomes the subagent's task prompt.                         |
| `agent`                    | Subagent type when `context: fork` is set. Built-in: `Explore` (read-only, optimized for codebase research), `Plan` (planning-only, no execution), `general-purpose` (full tools). Or a custom agent from `.claude/agents/`. |
| `hooks`                    | Hooks scoped to this skill's lifecycle. Same format as settings-based hooks. Active only while skill is running.        |
| `paths`                    | Glob patterns limiting auto-activation. Accepts a comma-separated string or YAML list. Only affects model invocation.  |
| `shell`                    | Shell for `` !`command` `` blocks: `bash` (default) or `powershell`.                                                   |

## String substitutions

| Variable                  | Description                                                                     |
|---------------------------|---------------------------------------------------------------------------------|
| `$ARGUMENTS`              | All arguments passed when invoking the skill.                                   |
| `$ARGUMENTS[N]` or `$N`  | Specific argument by 0-based index. `$0` is the first argument.                |
| `${CLAUDE_SESSION_ID}`    | Current session ID. Useful for logging or session-specific files.               |
| `${CLAUDE_EFFORT}`        | Current effort level: `low`, `medium`, `high`, `xhigh`, or `max`. Use to adapt instructions to active effort. |
| `${CLAUDE_SKILL_DIR}`     | Directory containing this SKILL.md. Use for referencing bundled scripts.        |

If `$ARGUMENTS` is not present in the skill content, arguments are appended
automatically as `ARGUMENTS: <value>`.

## Dynamic context injection

The `` !`command` `` syntax runs shell commands before content reaches Claude.
The output replaces the placeholder. Use for live data injection:

```yaml
## Current state
- Branch: !`git branch --show-current`
- Status: !`git status --short`
- Last commit: !`git log -1 --oneline`
```

## Invocation control summary

| Frontmatter                      | User can invoke | Claude can invoke | Context cost                                     |
|----------------------------------|-----------------|-------------------|--------------------------------------------------|
| (default)                        | Yes             | Yes               | Description in every request; full content on use |
| `disable-model-invocation: true` | Yes             | No                | Zero until user invokes                           |
| `user-invocable: false`          | No              | Yes               | Description in every request; full content on use |

## Tool patterns for `allowed-tools`

### Built-in tools

Common tools for skill restrictions:

| Tool        | Permission | Use case                          |
|-------------|------------|-----------------------------------|
| `Read`      | No         | Read file contents.               |
| `Glob`      | No         | Find files by pattern.            |
| `Grep`      | No         | Search file contents.             |
| `Write`     | Yes        | Create or overwrite files.        |
| `Edit`      | Yes        | Targeted edits to files.          |
| `Bash`      | Yes        | Execute shell commands.           |
| `WebFetch`  | Yes        | Fetch URL content.                |
| `WebSearch` | Yes        | Search the web.                   |
| `Agent`     | No         | Spawn a subagent.                 |
| `Skill`     | Yes        | Invoke another skill.             |
| `LSP`       | No         | Code intelligence (definitions, references). |

For the full list, see the
[tools reference](https://code.claude.com/docs/en/tools-reference).

### Bash patterns

Bash supports glob wildcards with `*`:

- `Bash(npm run *)` -- any npm run command.
- `Bash(git commit *)` -- git commit with any flags.
- `Bash(pytest *)` -- pytest with any arguments.
- `Bash(* --version)` -- any tool's version check.

The space before `*` enforces a word boundary: `Bash(ls *)` matches `ls -la`
but not `lsof`.

### MCP tool patterns

MCP tools follow the pattern `mcp__<server>__<tool>`:

- `mcp__puppeteer__puppeteer_navigate` -- specific MCP tool.
- `mcp__puppeteer` -- all tools from a server.

### WebFetch patterns

- `WebFetch(domain:example.com)` -- restrict to a specific domain.

## Decision guide

### `disable-model-invocation: true`

Use when:
- The skill has side effects (deploys, sends messages, triggers builds).
- The skill is expensive or slow (many commands, `effort: max`).
- You want full control over when it runs.

### `context: fork`

Use when:
- The skill reads many files and shouldn't pollute main context.
- The skill is self-contained and doesn't need conversation history.
- The skill benefits from isolation (research, analysis, review).

Do NOT use when:
- The skill provides guidelines without a concrete task (subagent gets nothing
  actionable).
- The skill needs to interact with the user mid-execution.
- The skill modifies files the user is actively working on.

### `allowed-tools`

Common patterns:
- Read-only: `Read, Grep, Glob`
- Research: `Read, Grep, Glob, Bash(gh *)`
- Safe execution: `Bash(npm test *), Read`

### `paths`

Use when the skill applies to specific file types or directories:
- Language-specific: `"**/*.py"` or `"**/*.{ts,tsx}"`
- Directory-scoped: `"src/api/**"`
- Test-specific: `"**/*.test.{ts,tsx}"`

### `hooks`

Use for:
- Validating commands before execution (PreToolUse).
- Running linters after file edits (PostToolUse).
- One-time setup when skill starts (`once: true`).

Four handler types are available:
- `command` -- run a shell script. Most common.
- `http` -- POST to an HTTP endpoint.
- `prompt` -- evaluate with a fast model (no tool use).
- `agent` -- evaluate with a model that has tool access.

Additional hook fields:
- `if: "ToolName(pattern)"` -- conditional filter within a matcher (permission
  rule syntax).
- `timeout: 600` -- seconds before canceling.
- `statusMessage: "Validating..."` -- custom spinner message.
- `async: true` -- run in background without blocking (command hooks only).
- `once: true` -- run only once per session, then removed (skills only).

Hooks receive JSON input on stdin (command) or POST body (http). Exit code 2
blocks the operation. See the
[hooks reference](https://code.claude.com/docs/en/hooks) for complete details.

### Combining fields

Common combinations:
- `context: fork` + `agent: Explore` -- isolated read-only research.
- `context: fork` + `disable-model-invocation: true` -- manual heavy tasks.
- `allowed-tools` + `hooks` -- restricted access with validation.
- `paths` + `user-invocable: false` -- auto-loaded domain knowledge for specific
  file types.
