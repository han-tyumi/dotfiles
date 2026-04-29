let mise_path = $env.HOME | path join ".config" "mise" "mise.nu"
^mise activate nu | save $mise_path --force
$env.NU_LIB_DIRS = ($env.NU_LIB_DIRS | append ($mise_path | path dirname))
