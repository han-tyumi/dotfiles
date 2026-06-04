# Single-command files export `main`; re-exporting without `*` keeps the file
# name as the call-site (`reload`). git.nu has multiple commands, so splat.
# apploi.nu symlinks to the ~/.local/bin executable (a shebang is a comment to
# nu), so the one source is both a PATH script and a completable nu command.
export use apploi.nu
export use reload.nu
export use git.nu *
