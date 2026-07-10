#!/bin/bash
# Evaluate the nix-darwin flake's eval-only fixtures (the set CI runs in
# .github/workflows/eval.yml), composing in overlay layers so test-all covers them
# too. machine.nix is chezmoi-rendered and absent from the source tree, so synthesize
# one in a throwaway copy, leaving the workspace untouched.
set -eu

src="${CONDUCTOR_WORKSPACE_PATH:-$PWD}/dot_config/nix-darwin"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp -R "$src/." "$tmp/"

# Overlay layers live in their own repos, cloned next to the applied flake. Compose
# each one in so test-all validates it. Point CONDUCTOR_OVERLAY_<name> at a worktree
# to validate that layer's in-progress edits instead of the installed clone.
installed_overlays="$HOME/.config/nix-darwin/overlays"
if [ -d "$installed_overlays" ]; then
  for path in "$installed_overlays"/*/; do
    [ -d "$path" ] || continue
    name="$(basename "$path")"
    override_var="CONDUCTOR_OVERLAY_${name}"
    source_path="${!override_var:-$path}"
    mkdir -p "$tmp/overlays/$name"
    cp -R "$source_path/." "$tmp/overlays/$name/"
    rm -rf "$tmp/overlays/$name/.git"
  done
fi

cat > "$tmp/machine.nix" <<'EOF'
{
  hostname = "conductor";
  username = "runner";
  nixbldGid = 350;
  appStore = false;
  layers = [ ];
}
EOF

for fixture in test-minimal test-personal test-all; do
  echo "==> nix eval $fixture"
  nix eval --no-write-lock-file --extra-experimental-features 'nix-command flakes' \
    "$tmp#darwinConfigurations.$fixture.system.drvPath"
done
echo "All fixtures evaluate."
