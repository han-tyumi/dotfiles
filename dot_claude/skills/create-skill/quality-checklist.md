# Quality Checklist

Verify these before finalizing a skill. Not all apply to every skill.

## Is a skill the right mechanism?

- [ ] This is NOT an "always do X" rule (belongs in CLAUDE.md).
- [ ] This is NOT a file-scoped rule (belongs in `.claude/rules/` with `paths`).
- [ ] This is NOT deterministic enforcement (belongs in a hook — skills are advisory and the model can ignore them).
- [ ] This is NOT solely an external service connection (belongs in MCP).
- [ ] This is NOT solely an isolated worker config (belongs in a subagent).

If any of the above fail, redirect to the correct mechanism.

## Structure

- [ ] SKILL.md exists with valid YAML frontmatter between `---` markers.
- [ ] SKILL.md is under 500 lines.
- [ ] Name uses only lowercase letters, numbers, and hyphens (max 64 chars).
- [ ] Combined `description` + `when_to_use` is under 1,536 characters and front-loads the key use case.
- [ ] Description is written in third person ("Processes files", not "I can
      help" or "Use this to").
- [ ] Description includes keywords that match how users naturally ask.
- [ ] Supporting files (if any) are referenced from SKILL.md with relative links.
- [ ] References are one level deep (no nested chains A -> B -> C).
- [ ] Reference files over 100 lines have a table of contents or clear heading
      structure so Claude can see the full scope when previewing.
- [ ] Simple skills stay simple -- no supporting files unless SKILL.md would
      exceed ~200 lines.

## Content

- [ ] Instructions are direct and imperative, not conversational.
- [ ] Steps are numbered when order matters, bulleted when it doesn't.
- [ ] Specific commands and paths are used, not vague references.
- [ ] No unnecessary preamble, motivation, or filler text.
- [ ] No information Claude already knows (don't explain standard concepts).
- [ ] Consistent terminology throughout (one term per concept).
- [ ] No duplication of information available in CLAUDE.md or other skills.
- [ ] No time-sensitive information (use "current" / "legacy" sections instead).
- [ ] Verification steps are included (tests, expected outputs, validation).
- [ ] Feedback loops for quality-critical tasks (validate -> fix -> repeat).
- [ ] Specificity matches fragility (exact scripts for fragile ops, general
      guidance for flexible tasks).

## Frontmatter

- [ ] Only fields that change behavior are included (no defaults restated).
- [ ] `disable-model-invocation: true` is set for skills with dangerous or
      hard-to-reverse side effects (deploys, messages, builds). Normal file
      writes are permission-gated and don't need this.
- [ ] `allowed-tools` is set when the skill should restrict tool access.
- [ ] `context: fork` is only used when content forms a complete task.
- [ ] `argument-hint` is set when the skill accepts arguments.
- [ ] `paths` is set when the skill applies only to specific file types.

## Token efficiency

- [ ] Description is concise (loaded into every request unless
      `disable-model-invocation: true`).
- [ ] Reference material is in supporting files, not inlined in SKILL.md.
- [ ] Dynamic context injection (`` !`command` ``) is used instead of asking
      Claude to fetch data that's always needed.
- [ ] `disable-model-invocation: true` is set for expensive or rarely-needed
      skills.
- [ ] Most useful instructions live in the first ~5,000 tokens of SKILL.md.
      After auto-compaction, reattached skills keep only their first 5K
      tokens (combined 25K budget across all reattached skills).

## Safety

- [ ] No secrets, credentials, or tokens in skill files.
- [ ] Destructive operations require user confirmation.
- [ ] `allowed-tools` restricts access when the skill doesn't need all tools.
- [ ] Hooks validate dangerous operations when fine-grained control is needed.
