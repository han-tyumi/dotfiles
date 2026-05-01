# Bootstrap a flake.nix + .envrc in PWD and open the flake in $EDITOR.
#
# Skips whichever already exists.
export def main []: nothing -> nothing {
  if not ('flake.nix' | path exists) {
    ^nix flake new -t github:nix-community/nix-direnv .
  } else if not ('.envrc' | path exists) {
    'use flake' | save .envrc
    ^direnv allow
  }

  ^$env.EDITOR flake.nix
}
