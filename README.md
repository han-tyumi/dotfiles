# dotfiles

Personal macOS (aarch64-darwin) configuration managed by [chezmoi](https://chezmoi.io),
composed from **Nix Darwin** (flakes) + **Home Manager**, with **mise** for language
runtimes and **Homebrew** for GUI apps.

## Bootstrap a fresh Mac

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/han-tyumi/dotfiles/main/bootstrap.sh)"
```

Installs chezmoi, prompts for the machine's layers and overlays, generates per-machine SSH
keys, clones any private overlays, then applies — which triggers the one-time installers for
Homebrew, Nix, and nix-darwin. Re-running the one-liner is safe; each stage self-guards.

## How it's organized

Configuration is composed from **layers** chosen per machine: an always-on `shared` layer,
in-repo layers such as `personal`, and private `overlays` cloned per machine. A layer can
contribute system config (`darwin.nix`), user config (`home.nix`), or both.

See **[CLAUDE.md](CLAUDE.md)** for the full architecture, the layer model, common commands,
and the conventions this repo follows.
