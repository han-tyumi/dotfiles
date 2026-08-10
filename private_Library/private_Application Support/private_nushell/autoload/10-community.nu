# community/ → github.com/nushell/nu_scripts (chezmoi-external), under
# <config-dir>/scripts/ which is on the default NU_LIB_DIRS.
#
# These live in an autoload fragment rather than in config.nu because each
# autoload file is its own parse unit: an upstream module that needs a newer
# nushell than the one nixpkgs pins costs these aliases alone, instead of
# every line of config.nu.

use community/aliases/git/git-aliases.nu *
use community/aliases/chezmoi/chezmoi-aliases.nu *
use community/aliases/eza/eza-aliases.nu *
use community/aliases/bat/bat-aliases.nu *
use community/aliases/docker/docker-aliases.nu *

# Module dirs with mod.nu can be imported by name.
use community/modules/docker *
use community/modules/capture-foreign-env *

# Module dirs without mod.nu need the primary file.
use community/modules/clone-all/clone-all.nu *
use community/modules/weather/get-weather.nu *
use community/modules/fuzzy/fuzzy_command_search.nu *
