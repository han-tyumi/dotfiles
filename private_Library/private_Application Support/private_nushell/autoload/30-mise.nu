# mise's activation module, written to ~/.config/mise/mise.nu by config.nu on
# every start. Its export-env sets $env.MISE_SHELL and registers the pre_prompt
# and env_change.PWD hooks that load a directory's mise tools and [env] vars.
#
# The import belongs here rather than in config.nu because nushell resolves `use`
# at parse time — before config.nu's own lines have written the module or put its
# dir on NU_LIB_DIRS. Autoload files are parsed after config.nu has fully run.

use mise.nu *
