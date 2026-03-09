module commands {
  const local_flake_dir = ' ~/.config/nix-darwin'
  const system_flake_dir = '/etc/nix-darwin'

  # Applies various updates related to Chezmoi, Nix Darwin, and Home Manager.
  export def apploi [
    --all (-A)      # Apply everything.
    --chezmoi (-c)  # Apply Chezmoi's state.
    --update (-u)   # Update Nix channels and flake inputs.
    --switch (-s)   # Switch to the latest nix-darwin configuration.
    --clean (-C)    # Clean the Nix store.
    --mise (-m)     # Upgrade mise plugins and tools.
  ]: nothing -> nothing {
    let all = $all or not ($chezmoi or $update or $switch or $clean or $mise)
    let chezmoi = $all or $chezmoi
    let update = $all or $update
    let switch = $all or $switch
    let clean = $all or $clean
    let mise = $all or $mise
    
    let original_dir = (pwd)

    if $chezmoi {
      let source_path = (^chezmoi source-path)
      log $"Changing to ($source_path)\n\n"
      cd $source_path
    
      log $"Applying Chezmoi's state\n\n"
      ^chezmoi apply
    }

    if ($system_flake_dir | path type) != 'symlink' {
      log $"Linking ($local_flake_dir) to ($system_flake_dir)"
      ^sudo ln -s $local_flake_dir $system_flake_dir
    }


    log $"Changing to ($system_flake_dir)\n\n"
    cd $system_flake_dir

    try {
      if $update {
        log "Updating Nix channels\n\n"
        ^sudo -i nix-channel --add https://github.com/nix-darwin/nix-darwin/archive/master.tar.gz darwin
        ^sudo -i nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
        ^sudo -i nix-channel --update

        log "\nUpdating nix-darwin flake inputs\n\n"
        ^nix flake update
      }

      if $switch {
        for file in [bash zsh] {
          let from = $'/etc/($file)rc'
          let to = $'($from).before-nix-darwin'
          if ($from | path exists) {
            log $"\nBacking up ($from) to ($to)\n"
            ^sudo mv $from $to
          }
        }

        log "\nApplying nix-darwin configuration\n\n"
        # Issue with `/tmp` symlink; we use `/private/tmp` directly instead.
        ^sudo TMPDIR=/private/tmp darwin-rebuild switch
      }

      if $clean {
        log "\nCleaning up Nix store\n\n"
        ^sudo -H nix-collect-garbage --delete-old
      }

      if $mise {
        log "\nUpgrading mise plugins\n\n"
        ^mise plugins upgrade

        log "\n\nUpgrading outdated mise tools\n\n"
        ^mise upgrade
      }
    } catch {|err|
      log $"\nError: ($err)\n"
    }

    log $"\n\nChanging back to ($original_dir)"
    cd $original_dir
  }

  export def reload []: nothing -> nothing {
    exec nu
  }

  def log [text: string]: nothing -> nothing {
    $text
    | split row "\n"
    | each {|line|
      if ($line | is-empty) {
        print -e ''
      } else {
        print -ne $'>> ($line) ...'
      }
    }
    | ignore
  }
}

export use commands *
