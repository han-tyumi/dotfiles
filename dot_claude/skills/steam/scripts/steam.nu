#!/usr/bin/env nu

# Read this Steam account through the Steam Web API: the owned library, recent
# playtime, achievements, wishlist, and profile, plus store details for any app.
#
# The Web API key and the account's SteamID64 live in the OS credential store
# (Windows Credential Manager, macOS Keychain) under the `steam` service. Each call
# reads them through the Python keyring CLI, so neither sits in an environment
# variable, a file, or a process argument. Output is a table at a terminal and
# CSV (tables) or JSON (everything else) when piped.

const KEYRING = ['--quiet' '--from' 'keyring==25.7.0' 'keyring']
const SERVICE = 'steam'
const API = 'https://api.steampowered.com'
const STORE_BATCH_SIZE = 100

def keyring-get [name: string]: nothing -> string {
  let result = (^uvx ...$KEYRING get $SERVICE $name | complete)
  let value = ($result.stdout | str trim)
  if $result.exit_code != 0 or ($value | is-empty) {
    error make {msg: $"No `($name)` under `($SERVICE)` in the credential store. Run `nu steam.nu setup` in a terminal."}
  }
  $value
}

def api-get [path: string, params: record]: nothing -> any {
  let key = (keyring-get web-api-key)
  let query = ($params | merge {key: $key} | url build-query)
  let response = try {
    http get --full --allow-errors $"($API)/($path)/?($query)"
  } catch {|err|
    error make {msg: ($err.msg | str replace --all $key '<key>')}
  }
  if $response.status == 200 {
    return $response.body
  }
  let detail = match ($response.body | describe) {
    $type if ($type | str starts-with 'record') => ($response.body | get -o playerstats.error | default '')
    _ => ''
  }
  let hint = if $response.status == 403 { ' (key rejected: check it at https://steamcommunity.com/dev/apikey)' } else { '' }
  error make {msg: ($"Steam returned HTTP ($response.status) for ($path)($hint) ($detail)" | str trim)}
}

def steamid []: nothing -> string {
  keyring-get steamid
}

def resolve-steamid [account: string]: nothing -> string {
  if $account =~ '^\d{17}$' {
    return $account
  }
  let profile_match = ($account | parse --regex 'steamcommunity\.com/profiles/(?<id>\d{17})')
  if ($profile_match | is-not-empty) {
    return $profile_match.0.id
  }
  let vanity = ($account | str replace --regex '^.*steamcommunity\.com/id/' '' | str trim --char '/')
  let resolved = (api-get ISteamUser/ResolveVanityURL/v1 {vanityurl: $vanity}).response
  if $resolved.success != 1 {
    error make {msg: $"No Steam account has the custom URL `($vanity)`."}
  }
  $resolved.steamid
}

def unix-date [seconds?: int]: nothing -> any {
  if $seconds == null or $seconds == 0 {
    return null
  }
  $seconds | into string | into datetime --format '%s' | format date '%Y-%m-%d'
}

def hours [minutes?: int]: nothing -> float {
  ($minutes | default 0) / 60 | math round --precision 1
}

def store-names [appids: list<int>]: nothing -> record {
  $appids
  | chunks $STORE_BATCH_SIZE
  | each {|batch|
      let request = {
        ids: ($batch | each {|appid| {appid: $appid} })
        context: {language: english, country_code: US}
        data_request: {include_basic_info: true}
      }
      let input = ($request | to json --raw | url encode --all)
      http get $"($API)/IStoreBrowseService/GetItems/v1/?input_json=($input)"
      | get -o response.store_items
      | default []
    }
  | flatten
  | where {|item| ($item.name? | default '') != '' }
  | reduce --fold {} {|item, names| $names | insert ($item.appid | into string) $item.name }
}

def emit []: any -> any {
  let data = $in
  if (is-terminal --stdout) {
    return $data
  }
  let text = if ($data | describe | str starts-with 'table') {
    $data | to csv
  } else {
    $data | to json --raw
  }

  # A reader that stops early (`head`) closes the pipe; that is not a failure.
  try { print --raw $text } catch { exit 0 }
}

# Query this Steam account through the Steam Web API.
def main []: nothing -> nothing {
  print (help main)
}

# Store the Web API key and the account's SteamID64 in the OS credential store.
# Interactive: run it yourself in a terminal.
def "main setup" []: nothing -> nothing {
  print 'Get a Web API key at https://steamcommunity.com/dev/apikey.'

  # Each prompt prints on its own line rather than through `input`, which redraws
  # its prompt on every key event and so repeats it once per character of a paste.
  print 'Web API key (input is hidden):'
  let key = (input --suppress-output | str trim)
  if ($key | is-empty) {
    error make {msg: 'No key entered; nothing stored.'}
  }
  $key | ^uvx ...$KEYRING set $SERVICE web-api-key
  print 'SteamID64, profile URL, or custom URL name:'
  let account = (input | str trim)
  let resolved_id = (resolve-steamid $account)
  $resolved_id | ^uvx ...$KEYRING set $SERVICE steamid
  let persona = (api-get ISteamUser/GetPlayerSummaries/v2 {steamids: $resolved_id}).response.players.0?.personaname?
  print $"Stored SteamID64 ($resolved_id) \(($persona | default 'unknown persona'))."
}

# Every owned game with total playtime and last-played date, most played first.
def "main library" [
  --sort: string = 'hours'  # Column to sort by: hours, name, or last_played.
]: nothing -> any {
  let response = (api-get IPlayerService/GetOwnedGames/v1 {
    steamid: (steamid)
    include_appinfo: 1
    include_played_free_games: 1
    skip_unvetted_apps: false
  }).response
  if ($response.games? | is-empty) {
    error make {msg: 'Steam returned no games. Set Profile > Edit Profile > Privacy Settings > Game details to Public, then retry.'}
  }
  let games = ($response.games | each {|game|
    {
      appid: $game.appid
      name: $game.name
      hours: (hours $game.playtime_forever)
      hours_2weeks: (hours $game.playtime_2weeks?)
      last_played: (unix-date $game.rtime_last_played?)
    }
  })
  let sorted = match $sort {
    'name' => ($games | sort-by name)
    'last_played' => ($games | sort-by --reverse last_played)
    _ => ($games | sort-by --reverse hours)
  }
  $sorted | emit
}

# Games played in the last two weeks.
def "main recent" []: nothing -> any {
  (api-get IPlayerService/GetRecentlyPlayedGames/v1 {steamid: (steamid)}).response.games?
  | default []
  | each {|game|
      {
        appid: $game.appid
        name: $game.name
        hours_2weeks: (hours $game.playtime_2weeks)
        hours: (hours $game.playtime_forever)
      }
    }
  | emit
}

# Achievements for one game, with global unlock rarity, locked ones first.
def "main achievements" [
  appid: int  # Steam app id (see `library`).
]: nothing -> any {
  let player = (api-get ISteamUserStats/GetPlayerAchievements/v1 {
    steamid: (steamid)
    appid: $appid
    l: english
  }).playerstats
  let rarity = (
    http get $"($API)/ISteamUserStats/GetGlobalAchievementPercentagesForApp/v2/?gameid=($appid)"
    | get -o achievementpercentages.achievements
    | default []
    | reduce --fold {} {|entry, percents| $percents | insert $entry.name ($entry.percent | into float | math round --precision 1) }
  )
  $player.achievements?
  | default []
  | each {|achievement|
      {
        name: $achievement.name?
        achieved: ($achievement.achieved == 1)
        unlocked: (unix-date $achievement.unlocktime?)
        global_percent: ($rarity | get -o $achievement.apiname)
        description: $achievement.description?
      }
    }
  | sort-by achieved {|row| -1 * ($row.global_percent | default 0) }
  | emit
}

# The wishlist with store names, in wishlist priority order.
def "main wishlist" []: nothing -> any {
  let items = ((api-get IWishlistService/GetWishlist/v1 {steamid: (steamid)}).response.items? | default [])
  let names = (store-names ($items | get appid))
  $items
  | each {|item|
      {
        appid: $item.appid
        name: ($names | get -o ($item.appid | into string))
        priority: $item.priority
        added: (unix-date $item.date_added?)
      }
    }
  | sort-by priority
  | emit
}

# Persona, visibility, level, and what is being played right now.
def "main profile" []: nothing -> any {
  let account_id = (steamid)
  let player = (api-get ISteamUser/GetPlayerSummaries/v2 {steamids: $account_id}).response.players.0
  let level = (api-get IPlayerService/GetSteamLevel/v1 {steamid: $account_id}).response.player_level?
  {
    steamid: $account_id
    persona: $player.personaname
    profile_url: $player.profileurl
    public: ($player.communityvisibilitystate == 3)
    level: $level
    created: (unix-date $player.timecreated?)
    country: $player.loccountrycode?
    playing: $player.gameextrainfo?
  }
  | emit
}

# Store page details for one app: release, studios, genres, Metacritic, summary.
def "main app" [
  appid: int  # Steam app id.
]: nothing -> any {
  let entry = (http get $"https://store.steampowered.com/api/appdetails?appids=($appid)&l=english&cc=us" | get ($appid | into string))
  if not $entry.success {
    error make {msg: $"The store has no app ($appid)."}
  }
  let details = $entry.data
  {
    appid: $appid
    name: $details.name
    type: $details.type
    released: $details.release_date?.date?
    developers: ($details.developers? | default [] | str join ', ')
    publishers: ($details.publishers? | default [] | str join ', ')
    genres: ($details.genres? | default [] | get description | str join ', ')
    metacritic: $details.metacritic?.score?
    platforms: ($details.platforms | transpose platform supported | where supported | get platform | str join ', ')
    summary: $details.short_description?
  }
  | emit
}

# Call any Web API method; steamid defaults to this account's. Returns raw JSON.
@example "Friends list" { nu steam.nu call ISteamUser/GetFriendList/v1 relationship=friend }
@example "Badges" { nu steam.nu call IPlayerService/GetBadges/v1 }
def "main call" [
  method: string     # Interface/Method/version, e.g. ISteamUser/GetFriendList/v1.
  ...params: string  # Extra query parameters as name=value.
]: nothing -> string {
  let extra = ($params | parse '{name}={value}' | reduce --fold {} {|param, query| $query | insert $param.name $param.value })
  api-get $method ({steamid: (steamid)} | merge $extra) | to json --raw
}
