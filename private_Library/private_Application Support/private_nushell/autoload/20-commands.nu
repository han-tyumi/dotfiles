# commands/ → chezmoi-managed helpers (the ~/.local/bin nu CLIs plus git
# wrappers), under <config-dir>/scripts/ which is on the default NU_LIB_DIRS.
#
# Sorts after 10-community.nu so a first-party name shadows an upstream alias,
# and stays out of config.nu so a typo mid-edit costs only these commands.

use commands *
