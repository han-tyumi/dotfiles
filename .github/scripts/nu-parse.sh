#!/usr/bin/env bash
# Parse the first-party nu sources against a nu_scripts revision.
#
# Nushell resolves `use` at parse time and home-manager copies config.nu into the
# store unparsed, so a parse error — in one of these files or in the external they
# import — only surfaces at shell start. Both the branch gate and the scheduled pin
# bump run this, so they cannot drift apart.
#
# Exit 1 means a file failed; every setup abort exits 2, so the scheduled bump can
# tell "upstream is ahead of the pinned nushell" from "the gate could not run".
#
# Usage: nu-parse.sh <nu-binary> [nu_scripts-sha]
#   sha defaults to the revision .chezmoiexternals/shared.toml pins.
set -euo pipefail
trap 'exit 2' ERR

nu=${1:?usage: nu-parse.sh <nu-binary> [nu_scripts-sha]}
sha=${2:-$(sed -n 's/.*"--revision", "\([0-9a-f]\{40\}\)".*/\1/p' .chezmoiexternals/shared.toml)}
if [[ ! $sha =~ ^[0-9a-f]{40}$ ]]; then
  echo "expected one 40-hex revision, got: ${sha:-<none>}" >&2
  exit 2
fi

nushell="private_Library/private_Application Support/private_nushell"
scripts="$PWD/$nushell/scripts"
autoload="$nushell/autoload"

# Name the scratch paths before creating any of them, so the trap below is armed
# before the first side effect.
commands=()
for template in "$scripts"/commands/symlink_*.nu.tmpl; do
  [[ -e $template ]] || continue
  name=$(basename "$template" .nu.tmpl)
  commands+=("$scripts/commands/${name#symlink_}.nu")
done

# The scratch layout lands inside the chezmoi source tree, where chezmoi reads
# community/ and commands/*.nu as source entries that collide with the external
# and the symlink_ templates owning those targets, so drop it on the way out.
cleanup() {
  rm -rf "$scripts/community" "${commands[@]}"
}
trap cleanup EXIT

# Reproduce the runtime layout the imports resolve against: community/ is the
# external, and commands/*.nu are symlinks to the ~/.local/bin CLIs.
git init -q "$scripts/community"
git -C "$scripts/community" fetch -q --depth 1 https://github.com/nushell/nu_scripts.git "$sha"
git -C "$scripts/community" checkout -q FETCH_HEAD

for link in "${commands[@]}"; do
  name=$(basename "$link" .nu)
  ln -sfn "$PWD/private_dot_local/bin/executable_$name" "$link"
done

files=(dot_config/nix-darwin/nushell/config.nu "$scripts/commands/mod.nu" "$autoload"/*.nu)
while IFS= read -r cli; do
  files+=("$cli")
done < <(grep -l '^#!/usr/bin/env nu' private_dot_local/bin/executable_*)

trap - ERR
echo "$("$nu" --version) vs nu_scripts $sha"

# nu-check exits non-zero on a parse error; bare nu-check only prints false. The
# lib dir has to be absolute — nu resolves no module from a relative NU_LIB_DIRS
# entry, and a runner has no populated default lib dir to fall back to.
failed=0
for file in "${files[@]}"; do
  # These import modules generated on the machine — mise's activation module, which
  # config.nu writes at runtime, and broot's launcher, which home-manager builds —
  # so no checkout can resolve them.
  if [[ $file == */30-mise.nu || $file == */40-broot.nu ]]; then
    continue
  fi
  if "$nu" --no-config-file -I "$scripts" -c "nu-check --debug \"$file\"" > /dev/null; then
    echo "ok      $file"
  else
    echo "FAIL    $file"
    failed=1
  fi
done

# Not every dependency on the external is parse-time: menus.nu reads a keybinding
# out of it with `open --raw`. Assert each referenced path exists rather than
# running the fragments, which would execute an imported module's export-env body
# — upstream code, at a revision nobody has reviewed yet.
while IFS= read -r reference; do
  if [[ -e $scripts/$reference ]]; then
    echo "present $reference"
  else
    echo "MISSING $reference"
    failed=1
  fi
done < <(grep -ohE "community/[^ \"')]+" "$autoload"/*.nu | sort -u)

exit $failed
