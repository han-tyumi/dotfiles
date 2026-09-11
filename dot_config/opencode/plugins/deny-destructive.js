/**
 * Apply the same recursive-delete policy to OpenCode that Claude Code enforces.
 *
 * OpenCode's own `permission.bash` rules are simple wildcards over the command
 * string, so they cannot tell `rm -rf ./build` from `rm -rf "$HOME/Developer"` —
 * the distinction that matters is where the target resolves to, which needs the
 * command tokenised and its variables expanded. ~/.claude/hooks/deny-destructive.py
 * already does exactly that and carries a test suite, so it is reused verbatim
 * here rather than reimplemented against a second set of edge cases.
 *
 * The hook speaks Claude Code's PreToolUse contract — a tool call as JSON on
 * stdin, exit 2 to refuse with a reason on stderr — so this plugin's job is to
 * translate OpenCode's bash call into that shape and turn a refusal into the
 * thrown error OpenCode expects.
 */

import { homedir } from "node:os";
import { join } from "node:path";

const hookPath = join(homedir(), ".claude", "hooks", "deny-destructive.py");
const DENY_EXIT_CODE = 2;

export const DenyDestructive = async ({ directory, worktree }) => {
  // The hook measures every delete target against a project root. A Conductor
  // session runs in a worktree, which is the boundary work should stay inside.
  const projectDir = worktree ?? directory;

  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool !== "bash") return;

      const command = output.args?.command;
      if (!command) return;

      const hook = Bun.spawn([hookPath], {
        stdin: new TextEncoder().encode(
          JSON.stringify({
            tool_name: "Bash",
            tool_input: { command },
            cwd: directory,
          }),
        ),
        stdout: "ignore",
        stderr: "pipe",
        env: {
          ...process.env,
          CLAUDE_PROJECT_DIR: projectDir,
          // The hook's shebang resolves python3 through PATH, and the
          // environment OpenCode is spawned with is not guaranteed to carry the
          // interactive one.
          PATH: `${process.env.PATH ?? ""}:/usr/bin:/bin`,
        },
      });

      const [reason, exitCode] = await Promise.all([
        new Response(hook.stderr).text(),
        hook.exited,
      ]);

      if (exitCode === DENY_EXIT_CODE) {
        throw new Error(reason.trim());
      }

      // Anything else nonzero means the guard itself did not run. Refusing is
      // the wrong-but-visible failure: an unguarded session is the one that
      // caused this policy to exist, and it announces itself to no one.
      if (exitCode !== 0) {
        throw new Error(
          `deny-destructive guard failed to run (exit ${exitCode}), so this ` +
            `command was not checked. Fix ${hookPath} before continuing.` +
            (reason.trim() ? `\n${reason.trim()}` : ""),
        );
      }
    },
  };
};
