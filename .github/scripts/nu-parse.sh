#!/usr/bin/env bash
# Parse every first-party nu source against a nu_scripts revision.
#
# Nushell resolves `use` at parse time and home-manager copies config.nu into the
# store unparsed, so a parse error — in one of these files or in the external they
# import — only surfaces at shell start. Both the branch gate and the scheduled pin
# bump run this, so they cannot drift apart.
#
# Usage: nu-parse.sh <nu-binary> [nu_scripts-sha]
#   sha defaults to the revision .chezmoiexternals/shared.toml pins.
set -euo pipefail

nu=${1:?usage: nu-parse.sh <nu-binary> [nu_scripts-sha]}
sha=${2:-$(sed -n 's/.*"--revision", "\([0-9a-f]\{40\}\)".*/\1/p' .chezmoiexternals/shared.toml)}
[[ -n $sha ]] || {
  echo "no nu_scripts revision given and none found in .chezmoiexternals/shared.toml" >&2
  exit 1
}

nushell="private_Library/private_Application Support/private_nushell"
scripts="$PWD/$nushell/scripts"
autoload="$nushell/autoload"

# Reproduce the runtime layout the imports resolve against: community/ is the
# external, and commands/*.nu are symlinks to the ~/.local/bin CLIs. The lib dir
# has to be absolute — nu resolves no module from a relative NU_LIB_DIRS entry,
# and a runner has no populated default lib dir to fall back to.
rm -rf "$scripts/community"
git init -q "$scripts/community"
git -C "$scripts/community" fetch -q --depth 1 https://github.com/nushell/nu_scripts.git "$sha"
git -C "$scripts/community" checkout -q FETCH_HEAD

for template in "$scripts"/commands/symlink_*.nu.tmpl; do
  name=$(basename "$template" .nu.tmpl)
  name=${name#symlink_}
  ln -sfn "$PWD/private_dot_local/bin/executable_$name" "$scripts/commands/$name.nu"
done

files=(dot_config/nix-darwin/nushell/config.nu "$scripts/commands/mod.nu" "$autoload"/*.nu)
while IFS= read -r cli; do
  files+=("$cli")
done < <(grep -l '^#!/usr/bin/env nu' private_dot_local/bin/executable_*)

echo "$("$nu" --version) vs nu_scripts $sha"

# nu-check exits non-zero on a parse error; bare nu-check only prints false.
failed=0
for file in "${files[@]}"; do
  # 30-mise.nu imports the module config.nu generates at runtime, which no
  # checkout has.
  if [[ $file == */30-mise.nu ]]; then
    continue
  fi
  if "$nu" --no-config-file -I "$scripts" -c "nu-check --debug \"$file\"" > /dev/null; then
    echo "ok   $file"
  else
    echo "FAIL $file"
    failed=1
  fi
done

exit $failed
