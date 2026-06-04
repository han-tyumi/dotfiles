# Single-command files export `main`; re-exporting without `*` keeps the file
# name as the call-site (`reload`). git.nu has multiple commands, so splat.
export use reload.nu
export use git.nu *
