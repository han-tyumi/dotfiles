# Single-command files export `main`; re-exporting without `*` keeps the file
# name as the call-site (`reload`). git.nu has multiple commands, so splat.
#
# *.nu symlinks point at ~/.local/bin nu-shebang executables (a shebang is a
# comment to nu), so one source serves as both a PATH script and a completable
# nu command. Such scripts must stay module-clean: consts and defs only.
export use apploi.nu
export use reload.nu
export use wt.nu
export use git.nu *
