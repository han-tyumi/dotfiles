# Custom git wrappers that augment the community/aliases/git aliases.
# `gXx` names = smart wrappers around the `gX` family.

def "nu-complete local branches" []: any -> list<any> {
  ^git branch | lines | each {|b| $b | str substring 2.. }
}

def "nu-complete remotes" []: any -> list<string> {
  ^git remote | lines
}

# Pull if behind, push if ahead, no-op if in sync.
@search-terms "push" "pull" "sync" "upstream"
@example "Sync the current branch with upstream" { gpx }
@example "Push with --force-with-lease" { gpx --force }
export def gpx [
  --force (-f)  # Push with --force-with-lease instead of plain push.
]: nothing -> nothing {
  let upstream = (^git rev-parse --abbrev-ref '@{u}' | complete)
  if $upstream.exit_code != 0 {
    print "No upstream set. Run `git push -u <remote> <branch>` first."
    return
  }

  let ahead = (^git rev-list --count '@{u}..HEAD' | str trim | into int)
  let behind = (^git rev-list --count 'HEAD..@{u}' | str trim | into int)

  if ($ahead > 0) and ($behind > 0) {
    print "Branch has diverged from upstream. Pull/rebase manually."
  } else if ($behind > 0) {
    ^git pull
  } else if ($ahead > 0) {
    if $force {
      ^git push --force-with-lease
    } else {
      ^git push
    }
  } else {
    print "In sync with upstream."
  }
}

# Hard-reset the current branch to its upstream.
@search-terms "reset" "upstream"
@example "Reset the branch to match its upstream" { grhx }
export def grhx []: nothing -> nothing {
  let upstream = (^git rev-parse --abbrev-ref '@{u}' | complete)
  if $upstream.exit_code != 0 {
    print "No upstream set. Run `git push -u <remote> <branch>` first."
    return
  }

  ^git reset --hard '@{u}'
}

# List, switch, create, or interactively delete branches.
#
# Bare:     list branches with tracking info.
# <name>:   switch to branch, or create-and-switch if missing.
# --delete: interactively pick branches to delete (skips current branch).
@search-terms "branch" "switch" "checkout" "delete"
@example "List all local branches with tracking info" { gbx }
@example "Switch to or create a branch" { gbx feat-foo }
@example "Bulk-delete merged branches interactively" { gbx --delete }
export def gbx [
  branch?: string@"nu-complete local branches"  # Branch to switch to or create.
  --delete (-d)                                  # Interactively pick branches to delete.
]: nothing -> nothing {
  let current = (^git branch --show-current | str trim)
  let local_branches = (^git branch | lines | each {|b| $b | str substring 2.. })

  if $delete {
    let candidates = ($local_branches | where $it != $current)
    if ($candidates | is-empty) {
      print "No branches to delete (only the current branch exists)."
      return
    }
    let to_delete = ($candidates | input list --multi "Select branches to delete:")
    if ($to_delete | is-empty) { return }
    for b in $to_delete {
      ^git branch -D $b
    }
    return
  }

  if ($branch | is-empty) {
    ^git branch -vv
    return
  }

  if ($branch in $local_branches) {
    ^git switch $branch
  } else {
    ^git switch -c $branch
  }
}

# Manage git remotes without the awkward `git remote ...` syntax.
#
# Bare:           list remotes (verbose).
# <name>:         show remote details.
# -a <name> <uri>: add a remote.
# -r <old> <new>: rename a remote.
# -d <name>:      delete a remote.
# -s <name> <uri>: set the URL for a remote.
# -u <name>:      fetch updates for a remote.
@search-terms "remote" "origin" "upstream"
@example "List all remotes" { grx }
@example "Show details for one remote" { grx origin }
@example "Add a new remote" { grx --add origin git@github.com:user/repo.git }
@example "Rename a remote" { grx --rename old new }
@example "Update a remote URL" { grx --set origin git@github.com:user/repo.git }
export def grx [
  name?: string@"nu-complete remotes"  # Remote name.
  uri?: string                          # URL for --add/--set, or the new name for --rename.
  --add (-a)     # Add a new remote.
  --rename (-r)  # Rename an existing remote.
  --delete (-d)  # Delete a remote.
  --set (-s)     # Set the URL of a remote.
  --update (-u)  # Fetch updates from a remote.
]: nothing -> nothing {
  if ($name | is-empty) {
    ^git remote -v
  } else if $add {
    ^git remote add $name $uri
  } else if $rename {
    ^git remote rename $name $uri
  } else if $delete {
    ^git remote remove $name
  } else if $set {
    ^git remote set-url $name $uri
  } else if $update {
    ^git remote update $name
  } else {
    ^git remote show $name
  }
}

# Open .gitignore at the repo root in $EDITOR.
@search-terms "gitignore" "ignore"
@example "Edit the repo's .gitignore" { gig }
@example "Mark an empty dir as trackable but otherwise ignored" { gig --empty-dir }
export def gig [
  --empty-dir  # Write ignore-all-except-self pattern (preserves an empty dir in git).
]: nothing -> nothing {
  if $empty_dir {
    ['# Ignore everything in this directory' '*' '# Except this file' '!.gitignore']
    | str join (char newline)
    | save .gitignore
  } else {
    let root = (^git rev-parse --show-toplevel | str trim)
    ^$env.EDITOR $"($root)/.gitignore"
  }
}

# Show contributor commit-count histogram, sorted descending.
@search-terms "history" "authors" "contributors" "histogram"
@example "Top contributors in the repo" { gha }
export def gha []: any -> table {
  ^git log --pretty='%h»¦«%aN»¦«%s»¦«%aD'
  | lines
  | split column '»¦«' sha committer desc date
  | histogram committer commits
  | sort-by commits --reverse
}
