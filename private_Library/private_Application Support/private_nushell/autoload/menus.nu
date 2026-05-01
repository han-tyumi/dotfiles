# Zoxide menu — `use` triggers export-env, which appends the menu and its
# keybinding. Also adds Alt-E "open editor".
use community/custom-menus/zoxide-menu.nu

# Fuzzy directory picker (Ctrl-S). Upstream is a bare record literal, so load
# it via `from nuon` rather than copying the keybind inline.
$env.config = ($env.config | upsert keybindings (
  $env.config.keybindings | append (
    open --raw ($nu.default-config-dir | path join "scripts/community/custom-menus/fuzzy/directory.nu")
    | from nuon
  )
))
