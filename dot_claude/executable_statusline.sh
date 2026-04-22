#!/usr/bin/env bash
# shellcheck disable=SC2154  # fields below are assigned via eval "$(jq @sh)"
# Claude Code statusline (two lines).
#
#   Line 1: <model> · <~/path> on <branch*↑↓> · $<cost> · <duration>
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

# Rate-limit segment: blue label, white percentage (yellow at/above 80%, with countdown).
fmt_rate() {
    local label=$1 resets_at=${3:-} int_pct=${2%%.*}
    [ -z "$int_pct" ] && int_pct=0
    if [ "$int_pct" -ge 80 ]; then
        local tail=""
        [ -n "$resets_at" ] && tail=" $(fmt_countdown "$resets_at")"
        printf '%s%s%s %s%d%% ⚠%s%s' \
            "$BLUE" "$label" "$RESET" "$YELLOW" "$int_pct" "$tail" "$RESET"
    else
        printf '%s%s%s %s%d%%%s' \
            "$BLUE" "$label" "$RESET" "$WHITE" "$int_pct" "$RESET"
    fi
}

# Half-block bar in cyan (matches path). The model also uses cyan but is
# bolded so they're visually distinct. `█` and `▌` are both solid so
# transitions read evenly; `░` is a light-shade pattern for the empty portion.
fmt_bar() {
    local int_pct=${1%%.*}
    [ -z "$int_pct" ] && int_pct=0
    [ "$int_pct" -gt 100 ] && int_pct=100
    local width=10
    local halves=$(( int_pct * width * 2 / 100 ))
    local full=$(( halves / 2 ))
    local half=$(( halves % 2 ))
    local empty=$(( width - full - half ))
    local bar="$CYAN"
    local i
    for ((i = 0; i < full; i++)); do bar+='█'; done
    [ "$half" -eq 1 ] && bar+='▌'
    bar+="$RESET"
    for ((i = 0; i < empty; i++)); do bar+='░'; done
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
        [[ "$header" =~ ^\#\#\ ([^.\ ]+) ]] && branch="${BASH_REMATCH[1]}"
        [[ "$header" =~ ahead\ ([0-9]+) ]] && ahead="${BASH_REMATCH[1]}"
        [[ "$header" =~ behind\ ([0-9]+) ]] && behind="${BASH_REMATCH[1]}"

        # A newline in the output means there's at least one status line after
        # the `## header`.
        [[ "$git_status" == *$'\n'* ]] && dirty="*"
    fi
fi

branch_display=""
if [ -n "$branch" ] && [ -n "$worktree" ]; then
    branch_display="${branch}[${worktree}]"
elif [ -n "$branch" ]; then
    branch_display="$branch"
fi
[ -n "$dirty" ] && branch_display="${branch_display}${dirty}"
[ "$behind" -gt 0 ] && branch_display="${branch_display} ${behind}↓"
[ "$ahead" -gt 0 ]  && branch_display="${branch_display} ${ahead}↑"

cwd_link=$(osc8_wrap "file://${cwd}" "$path_text")

# Path in cyan, branch+status in magenta (each category one color).
if [ -n "$branch_display" ]; then
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
    segments+=("$(fmt_rate 5h "$five_hour_pct" "$five_hour_resets_at")")
fi

if [ -n "$seven_day_pct" ]; then
    segments+=("$(fmt_rate 7d "$seven_day_pct" "$seven_day_resets_at")")
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
    for s in "${segments[@]}"; do
        if [ -z "$line2" ]; then
            line2="$s"
        else
            line2+=" · $s"
        fi
    done
    printf '%s' "$line2"
fi
