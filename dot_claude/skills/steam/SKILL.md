---
name: steam
description: Reads the user's own Steam account through the Steam Web API — owned library with playtime, recently played games, per-game achievements with global rarity, wishlist, and profile — plus store details for any app, via one nushell script that reads the API key from the OS credential store.
when_to_use: User asks about their Steam library, playtime, what they've played recently, achievements, wishlist, Steam profile, or wants a game picked or compared from what they own. Also for store facts about a Steam app (release, studio, genres, Metacritic).
argument-hint: "[question about the Steam account]"
---

# steam

Request: $ARGUMENTS

Run every query through the script:

```bash
nu "${CLAUDE_SKILL_DIR}/scripts/steam.nu" <command> [args]
```

| Command | Returns |
| --- | --- |
| `library [--sort hours\|name\|last_played]` | Every owned game: appid, name, hours, hours_2weeks, last_played |
| `recent` | Games played in the last two weeks |
| `achievements <appid>` | name, achieved, unlocked, global_percent, description; locked first, easiest first |
| `wishlist` | appid, name, priority, added |
| `profile` | Persona, public visibility, level, created, country, current game |
| `app <appid>` | Store details: release, developers, genres, Metacritic, platforms, summary |
| `call <Interface/Method/vN> [name=value ...]` | Raw JSON from any Web API method; `steamid` defaults to the account's |

Piped output is CSV for tables and JSON otherwise. A full library is hundreds of
rows, so filter in the same call rather than reading it all:

```bash
nu "${CLAUDE_SKILL_DIR}/scripts/steam.nu" library | rg -i 'souls'
nu -c "nu '${CLAUDE_SKILL_DIR}/scripts/steam.nu' library | from csv | where hours == 0 | length"
```

Get an appid from `library` before calling `achievements` or `app`.

`app` and global rarity need no key. Everything else reads the Web API key and the
account's SteamID64 from the OS credential store (service `steam`, entries
`web-api-key` and `steamid`).

## Rules

- Never read, print, or echo the key. The script redacts it from its own errors;
  don't route around that with `keyring get` or by logging request URLs.
- `setup` is interactive (hidden key prompt). Never run it; ask the user to run it
  in their own terminal.

## Errors

| Message | Fix |
| --- | --- |
| `No ... in the credential store` | The user runs `nu ~/.claude/skills/steam/scripts/steam.nu setup` |
| `HTTP 403 ... key rejected` | Key revoked or mistyped: the user re-mints it at steamcommunity.com/dev/apikey and reruns `setup` |
| `Steam returned no games` | Usually the account's Game details privacy is not Public; the user sets it in Steam's privacy settings |
| `HTTP 400` from `achievements` | The app has no achievements |
| `HTTP 429` | Rate limited (about 100k calls/day); wait, don't retry in a loop |

For a method the commands don't cover (friends, badges, inventory), find it in the
[IPlayerService](https://partner.steamgames.com/doc/webapi/IPlayerService) and
[ISteamUser](https://partner.steamgames.com/doc/webapi/ISteamUser) references and use `call`.
