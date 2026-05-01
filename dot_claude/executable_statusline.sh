#!/usr/bin/env bash
# shellcheck disable=SC2154  # fields below are assigned via eval "$(jq @sh)"
# Claude Code statusline (two lines).
#
#   Line 1: <model> · <~/path> on <⎇ branch*↑↓> · $<cost> · <duration>
#   Line 2: <bar> <%> · 5h <%> · 7d <%> · +X/-Y
#
# Receives session JSON on stdin. See:
#   https://code.claude.com/docs/en/statusline
#
# Colors come from the terminal's ANSI palette (paired with `theme "dark-ansi"`
# in Claude Code and `catppuccin-mocha` in zellij).

set -u

input=$(cat)

RESET=$'\033[0m'
BOLD=$'\033[1m'
WHITE=$'\033[97m'
RED=$'\033[31m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
BLUE=$'\033[34m'
MAGENTA=$'\033[35m'
CYAN=$'\033[36m'
GREY=$'\033[90m'

# Single jq call for every field: @sh quotes each value for shell, eval sets
# them. One subprocess vs fourteen.
eval "$(jq -r '
    @sh "model=\(.model.display_name // "?")",
    @sh "cwd=\(.workspace.current_dir // .cwd // "")",
    @sh "project_dir=\(.workspace.project_dir // "")",
    @sh "cost=\(.cost.total_cost_usd // 0)",
    @sh "worktree=\(.workspace.git_worktree // "")",
    @sh "context_pct=\(.context_window.used_percentage // "")",
    @sh "five_hour_pct=\(.rate_limits.five_hour.used_percentage // "")",
    @sh "seven_day_pct=\(.rate_limits.seven_day.used_percentage // "")",
    @sh "duration_ms=\(.cost.total_duration_ms // 0)",
    @sh "lines_added=\(.cost.total_lines_added // 0)",
    @sh "lines_removed=\(.cost.total_lines_removed // 0)",
    @sh "output_style=\(.output_style.name // "")",
    @sh "five_hour_resets_at=\(.rate_limits.five_hour.resets_at // "")",
    @sh "seven_day_resets_at=\(.rate_limits.seven_day.resets_at // "")"
' <<<"$input")"

# Trim long context suffix to save horizontal space.
model=${model/ (1M context)/ (1M)}

# Drop decimals so bash arithmetic doesn't error.
duration_ms=${duration_ms%%.*}
lines_added=${lines_added%%.*}
lines_removed=${lines_removed%%.*}

# Detect the real terminal width by reading the parent Claude Code process's
# controlling TTY — Claude Code pipes the statusline's stdin/stdout so $COLUMNS
# is unset, tput falls back to 80, and stty has no TTY unless we point it at
# the parent's /dev/ttysNNN explicitly.
detect_columns() {
    local parent_tty cols
    parent_tty=$(ps -o tty= -p "$PPID" 2>/dev/null | tr -d ' ')
    if [ -n "$parent_tty" ] && [ "$parent_tty" != "??" ]; then
        cols=$(stty size </dev/"$parent_tty" 2>/dev/null | awk '{print $2}')
        if [ -n "$cols" ] && [ "$cols" -gt 0 ]; then
            printf '%s' "$cols"
            return
        fi
    fi
    printf '120'
}

# Keep the first and last N/2 chars with an ellipsis in the middle. Used for
# branch names where both the prefix (ticket) and suffix (description) carry
# meaning.
middle_truncate() {
    local text=$1 max=$2
    if [ "${#text}" -le "$max" ]; then
        printf '%s' "$text"
        return
    fi
    local keep=$(( (max - 1) / 2 ))
    printf '%s…%s' "${text:0:$keep}" "${text: -$keep}"
}

# Keep the last N-1 chars with a leading ellipsis — preserves the basename,
# which is what matters visually when a path overflows.
left_truncate() {
    local text=$1 max=$2
    if [ "${#text}" -le "$max" ]; then
        printf '%s' "$text"
        return
    fi
    printf '…%s' "${text: -$(( max - 1 ))}"
}

# Convert a git origin URL (either SSH or HTTPS form) to an
# https://github.com/<owner>/<repo>/tree/<branch> URL. Returns 1 when the
# remote isn't a recognized GitHub URL.
github_tree_url() {
    local branch=$1 url owner repo
    url=$(git -C "$cwd" remote get-url origin 2>/dev/null) || return 1
    if [[ "$url" =~ github\.com[:/]([^/]+)/([^/]+)$ ]]; then
        owner="${BASH_REMATCH[1]}"
        repo="${BASH_REMATCH[2]%.git}"
        printf 'https://github.com/%s/%s/tree/%s' "$owner" "$repo" "$branch"
        return 0
    fi
    return 1
}

# Compact countdown until a unix timestamp: 2h / 42m / 9s. Empty when past.
fmt_countdown() {
    local target=$1
    local now diff
    now=$(date +%s)
    diff=$(( target - now ))
    [ "$diff" -le 0 ] && return
    if [ "$diff" -ge 3600 ]; then
        printf '%dh' "$(( diff / 3600 ))"
    elif [ "$diff" -ge 60 ]; then
        printf '%dm' "$(( diff / 60 ))"
    else
        printf '%ds' "$diff"
    fi
}

fmt_duration() {
    local ms=$1
    local total_s=$(( ms / 1000 ))
    local h=$(( total_s / 3600 ))
    local m=$(( (total_s % 3600) / 60 ))
    local s=$(( total_s % 60 ))
    if [ "$h" -gt 0 ]; then
        printf '%dh%dm' "$h" "$m"
    elif [ "$m" -gt 0 ]; then
        printf '%dm' "$m"
    else
        printf '%ds' "$s"
    fi
}

# Context percentage (no reset, no label). Yellow + ⚠ at/above 80%, else white.
fmt_ctx_pct() {
    local int_pct=${1%%.*}
    [ -z "$int_pct" ] && int_pct=0
    if [ "$int_pct" -ge 80 ]; then
        printf '%s%d%% ⚠%s' "$YELLOW" "$int_pct" "$RESET"
    else
        printf '%s%d%%%s' "$WHITE" "$int_pct" "$RESET"
    fi
}

# Rate-limit segment: blue label, white percentage (yellow at/above 80%, with
# countdown). A ⇡ / ⇣ burn-rate indicator compares the used percentage against
# the fraction of the window that has elapsed: ⇡ when burning faster than even
# pacing (diff > 10pp), ⇣ when slower, blank when within ±10pp.
fmt_rate() {
    local label=$1 resets_at=${3:-} int_pct=${2%%.*} window_seconds=${4:-0}
    [ -z "$int_pct" ] && int_pct=0

    local burn=""
    if [ -n "$resets_at" ] && [ "$window_seconds" -gt 0 ]; then
        local now elapsed elapsed_pct
        now=$(date +%s)
        elapsed=$(( window_seconds - (resets_at - now) ))
        if [ "$elapsed" -gt 0 ]; then
            elapsed_pct=$(( elapsed * 100 / window_seconds ))
            if [ "$int_pct" -gt $(( elapsed_pct + 10 )) ]; then
                burn=" ⇡"
            elif [ "$int_pct" -lt $(( elapsed_pct - 10 )) ]; then
                burn=" ⇣"
            fi
        fi
    fi

    if [ "$int_pct" -ge 80 ]; then
        local countdown="" tail=""
        [ -n "$resets_at" ] && countdown=$(fmt_countdown "$resets_at")
        [ -n "$countdown" ] && tail=" $countdown"
        printf '%s%s%s %s%d%%%s ⚠%s%s' \
            "$BLUE" "$label" "$RESET" "$YELLOW" "$int_pct" "$burn" "$tail" "$RESET"
    else
        printf '%s%s%s %s%d%%%s%s' \
            "$BLUE" "$label" "$RESET" "$WHITE" "$int_pct" "$burn" "$RESET"
    fi
}

# Foreground-only shade ramp — half-blocks expose the terminal background.
# Tip `░▒▓` is a sub-bar showing progress toward the next 10%; any nonzero
# remainder shows it, so single-percent moves register visually.
fmt_bar() {
    local int_pct=${1%%.*}
    [ -z "$int_pct" ] && int_pct=0
    [ "$int_pct" -gt 100 ] && int_pct=100
    local width=10
    local full=$(( int_pct / 10 ))
    local remainder=$(( int_pct % 10 ))
    local tip_glyphs=('' '░' '▒' '▓')
    local tip=${tip_glyphs[$(( (remainder + 2) / 3 ))]}
    local empty=$(( width - full - (remainder > 0 ? 1 : 0) ))
    local bar="$CYAN"
    local cell
    for ((cell = 0; cell < full; cell++)); do bar+='█'; done
    [ -n "$tip" ] && bar+="$tip"
    bar+="${RESET}${GREY}"
    for ((cell = 0; cell < empty; cell++)); do bar+='░'; done
    bar+="$RESET"
    printf '%s' "$bar"
}

# OSC 8 hyperlink wrap. Terminals that don't support it just show the text.
# The `\\` sequences emit literal backslashes as part of the ST terminator
# `\e\\`, not quote-escapes.
# shellcheck disable=SC1003
osc8_wrap() {
    local url=$1 text=$2
    printf '\033]8;;%s\033\\%s\033]8;;\033\\' "$url" "$text"
}

# Compact path: basename when cwd matches the VS-Code-level project_dir;
# <project-basename>/<rel> when cwd is inside it; full ~/path otherwise.
# The `on` connector distinguishes the path from the branch, so no trailing
# slash is needed to signal directory-ness.
home_tilde="${cwd/#$HOME/~}"
path_text="$home_tilde"
if [ -n "$project_dir" ] && [ -n "$cwd" ]; then
    project_basename=${project_dir##*/}
    if [ "$cwd" = "$project_dir" ]; then
        path_text="$project_basename"
    elif [ "${cwd#"$project_dir"/}" != "$cwd" ]; then
        path_text="${project_basename}/${cwd#"$project_dir"/}"
    fi
fi

# Single `git status --branch --porcelain=v1` yields branch, ahead/behind, and
# dirty-status in one shell-out. Parsing uses pure-bash expansions (no sed,
# head, or wc subprocesses).
branch=""
ahead=0
behind=0
dirty=""
if [ -n "$cwd" ]; then
    git_status=$(GIT_OPTIONAL_LOCKS=0 git -C "$cwd" status --branch --porcelain=v1 2>/dev/null || true)
    if [ -n "$git_status" ]; then
        header=${git_status%%$'\n'*}

        # Header is `## <branch>[...<upstream>] [ahead N, behind M]` or
        # `## HEAD (no branch)`. Strip prefix, then the upstream separator,
        # then any trailing ` [ahead/behind]` / ` (no branch)` suffix.
        header_main=${header#\#\# }
        branch=${header_main%%...*}
        branch=${branch%% *}
        [[ "$header" =~ ahead\ ([0-9]+) ]] && ahead="${BASH_REMATCH[1]}"
        [[ "$header" =~ behind\ ([0-9]+) ]] && behind="${BASH_REMATCH[1]}"

        # A newline in the output means there's at least one status line after
        # the `## header`.
        [[ "$git_status" == *$'\n'* ]] && dirty="*"
    fi
fi

worktree_marker=""
[ -n "$worktree" ] && worktree_marker="⎇ "

branch_suffix=""
[ -n "$dirty" ] && branch_suffix="${branch_suffix}${dirty}"
[ "$behind" -gt 0 ] && branch_suffix="${branch_suffix} ${behind}↓"
[ "$ahead" -gt 0 ]  && branch_suffix="${branch_suffix} ${ahead}↑"

# Budget remaining horizontal space so long paths and branches don't wrap.
# Claude Code's notifications (auto-compact, mode banner) render on their own
# line below the statusline, so we don't reserve right-edge space for them.
columns=$(detect_columns)
line1_fixed=45
budget=$(( columns - line1_fixed ))

branch_max=60
branch_min=12
path_max=100
path_min=8
connector_len=4   # " on " between path and branch.

if [ "$budget" -lt $(( branch_max + path_max + connector_len )) ]; then
    branch_max=$(( budget / 2 ))
    [ "$branch_max" -lt "$branch_min" ] && branch_max=$branch_min
    path_max=$(( budget - branch_max - connector_len ))
    [ "$path_max" -lt "$path_min" ] && path_max=$path_min
fi

path_text_truncated=$(left_truncate "$path_text" "$path_max")

# `⎇ ` prefix marks worktree sessions; the name itself is already in the
# path (cwd's basename usually matches the worktree), so we don't repeat it.
branch_avail=$(( branch_max - ${#worktree_marker} ))
branch_truncated=$(middle_truncate "$branch" "$branch_avail")

cwd_link=$(osc8_wrap "file://${cwd}" "$path_text_truncated")

# Link wraps only the branch name — the worktree marker and dirty/ahead/
# behind suffix aren't navigable.
branch_linked="$branch_truncated"
if [ -n "$branch" ]; then
    branch_url=$(github_tree_url "$branch") && \
        branch_linked=$(osc8_wrap "$branch_url" "$branch_truncated")
fi
branch_display="${worktree_marker}${branch_linked}${branch_suffix}"

# Path in cyan, branch+status in magenta (each category one color).
if [ -n "$branch" ]; then
    path_display="${CYAN}${cwd_link}${RESET} on ${MAGENTA}${branch_display}${RESET}"
else
    path_display="${CYAN}${cwd_link}${RESET}"
fi

# Line 1: model · path (on branch) · $cost · duration.
# Each category keeps one signature color: bold cyan model, cyan path, magenta
# branch/status, yellow cost, blue duration.
printf '%s%s%s%s · %s · %s$%.2f%s' \
    "$BOLD" "$CYAN" "$model" "$RESET" \
    "$path_display" \
    "$YELLOW" "$cost" "$RESET"
if [ "${duration_ms:-0}" -gt 0 ]; then
    printf ' · %s%s%s' "$BLUE" "$(fmt_duration "$duration_ms")" "$RESET"
fi
printf '\n'

segments=()

if [ -n "$context_pct" ]; then
    segments+=("$(printf '%s %s' "$(fmt_bar "$context_pct")" "$(fmt_ctx_pct "$context_pct")")")
fi

if [ -n "$five_hour_pct" ]; then
    segments+=("$(fmt_rate 5h "$five_hour_pct" "$five_hour_resets_at" 18000)")
fi

if [ -n "$seven_day_pct" ]; then
    segments+=("$(fmt_rate 7d "$seven_day_pct" "$seven_day_resets_at" 604800)")
fi

if [ "${lines_added:-0}" -gt 0 ] || [ "${lines_removed:-0}" -gt 0 ]; then
    segments+=("$(printf '%s+%d%s/%s-%d%s' \
        "$GREEN" "$lines_added" "$RESET" \
        "$RED" "$lines_removed" "$RESET")")
fi

if [ -n "$output_style" ] && [ "$output_style" != "default" ]; then
    segments+=("$output_style")
fi

if [ "${#segments[@]}" -gt 0 ]; then
    line2=""
    for segment in "${segments[@]}"; do
        if [ -z "$line2" ]; then
            line2="$segment"
        else
            line2+=" · $segment"
        fi
    done
    printf '%s' "$line2"
fi
