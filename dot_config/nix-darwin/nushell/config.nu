# Settings
$env.config.show_banner = false

# Mise activation: write the nu module and add its dir to NU_LIB_DIRS.
let mise_path = $env.HOME | path join ".config" "mise" "mise.nu"
^mise activate nu | save $mise_path --force
$env.NU_LIB_DIRS ++= [($mise_path | path dirname)]

# Module imports live in the autoload/ fragments. Nushell parses this file as a
# single unit and resolves `use` at parse time, so a parse error in any imported
# module here would discard every line above it too.
