# Single-command files export `main`; re-exporting without `*` keeps the file
# name as the call-site (`apploi -s`). git.nu has multiple commands, so splat.
export use apploi.nu
export use flakify.nu
export use reload.nu
export use git.nu *
