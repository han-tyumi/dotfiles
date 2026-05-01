# Settings
$env.config.show_banner = false

# Mise activation: write the nu module and add its dir to NU_LIB_DIRS.
let mise_path = $env.HOME | path join ".config" "mise" "mise.nu"
^mise activate nu | save $mise_path --force
$env.NU_LIB_DIRS ++= [($mise_path | path dirname)]

# community/ → github.com/nushell/nu_scripts (chezmoi-external).
# commands/  → chezmoi-managed helpers.
# Both live under <config-dir>/scripts/ which is on default NU_LIB_DIRS.

use community/aliases/git/git-aliases.nu *
use community/aliases/chezmoi/chezmoi-aliases.nu *
use community/aliases/eza/eza-aliases.nu *
use community/aliases/bat/bat-aliases.nu *
use community/aliases/docker/docker-aliases.nu *

# Module dirs with mod.nu can be imported by name.
use community/modules/docker *
use community/modules/capture-foreign-env *

# Module dirs without mod.nu need the primary file.
use community/modules/nix/nix.nu *
use community/modules/clone-all/clone-all.nu *
use community/modules/weather/get-weather.nu *
use community/modules/fuzzy/fuzzy_command_search.nu *

use commands *
