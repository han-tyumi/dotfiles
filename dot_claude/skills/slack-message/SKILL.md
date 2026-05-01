---
name: slack-message
description: Format Slack messages with proper markup. Use when composing or formatting a Slack message, announcement, or post.
when_to_use: User asks to compose or convert text for Slack, mentions pasting into Slack, posting in a channel, or Slack-specific markup (bold, lists, code blocks).
---

# Slack Message Formatting

When helping compose a Slack message, apply Slack's markup syntax. Slack's
markup is a small, Slack-specific dialect — not standard Markdown.

Source: [Slack Help — Format your messages with markup](https://slack.com/help/articles/360039953113-Format-your-messages-in-Slack-with-markup).

## Supported markup

| Format | Syntax |
|---|---|
| Bold | `*text*` |
| Italic | `_text_` |
| Strikethrough | `~text~` |
| Inline code | `` `text` `` |
| Code block | ```` ```text``` ```` |
| Blockquote | `>text` (one `>` per line) |
| Link | `[text](https://url)` |

## Not supported via markup

- **Lists.** Slack explicitly says "automatic formatting for bulleted, numbered,
  and indented lists won't be applied" in markup mode. Lists only work via the
  compose toolbar, not pasted markup. Use dashes or asterisks as plain text if
  you need visual bullets, but they won't render as a styled list.
- **Headings.** `#` does nothing.
- **Images.** Can't embed via markup; paste or upload.
- **Nested formatting** beyond the basics.

## Common mistakes

- Bold is `*text*`, **not** `**text**`. Double asterisks render literally.
- Links use `[text](url)` in the compose box. The `<url|text>` form is for the
  Slack API / Block Kit payloads, **not** what you paste.
- Slack auto-unfurls bare URLs, so `https://example.com` on its own is fine too.

## Mentions and emoji

Typed inline, not part of the markup spec:

- User: `@username` (Slack resolves via autocomplete)
- Group: `@here`, `@channel`
- Emoji: `:emoji_name:` (e.g. `:white_check_mark:`)

## Guidelines

- Output raw markup the user can paste directly into Slack.
- Use emoji sparingly for visual structure (e.g. `:white_check_mark:` for done,
  `:rotating_light:` for alerts, `:point_right:` for action items).
- For longer messages, use blockquotes and bold for hierarchy. Don't reach for
  lists — they don't render.
- Keep messages scannable.
