---
name: character
description: Loads, continues and applies the user's saved character concepts, such as Lenore, from the private han-tyumi/characters repository — canon lore with confidence marks, personality, cross-game translation rules, per-game state, and reference art.
when_to_use: User mentions a saved character or character concept, wants one built, restyled or roleplayed in a game, wants one applied to a new game, or wants a new character recorded. Also when playing or making choices as Lenore, including in Fields of Mistria.
argument-hint: "[character, game, or request]"
---

# character

Request: $ARGUMENTS

The records live in `~/ghq/github.com/han-tyumi/characters`. Before reading, sync it:

```bash
git -C ~/ghq/github.com/han-tyumi/characters pull --ff-only || gh repo clone han-tyumi/characters ~/ghq/github.com/han-tyumi/characters
```

Then read its `AGENTS.md` and follow it. It says what to read for a character and sets
the rules for working on the records.
