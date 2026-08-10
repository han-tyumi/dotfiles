# Settings
$env.config.show_banner = false

# Mise activation: write the nu module and add its dir to NU_LIB_DIRS.
let mise_path = $env.HOME | path join ".config" "mise" "mise.nu"
^mise activate nu | save $mise_path --force
$env.NU_LIB_DIRS ++= [($mise_path | path dirname)]

# Module imports live in the autoload/ fragments, each its own parse unit. Nushell
# resolves `use` at parse time and parses this file as a single unit, so one
# unparseable module here — an external that never cloned, an upstream ahead of the
# nu nixpkgs pins, a typo mid-edit — would take every other line with it: prompt,
# completions, history, hooks, aliases.
