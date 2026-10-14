---
name: telegram-search
description: Search the user's Telegram messages across all chats, groups and channels with typo-tolerant, Arabic-aware matching. Use when the user asks to find a message, deal, price, product, or place in their Telegram.
---

# Telegram search

Uses the local `tgsearch` tool (adjust the path to where it is installed).

1. If `TG_API_ID`/`TG_API_HASH` are set, refresh first: `python /path/to/tgsearch.py sync`.
   Otherwise run `python /path/to/tgsearch.py stats` and tell the user how old the newest message is;
   if stale, ask them to re-export from Telegram Desktop and run `import`.
2. Search: `python /path/to/tgsearch.py search "<words>" --json --limit 30`
   - Typos and spacing ("8gb"/"8 gb") are handled by the tool.
   - For the other-language or alternative spelling, run a second search with the Arabic/English
     equivalent (e.g. Jeddah / جدة), or add it to `aliases.txt`.
   - Use `--any` when several words are alternatives, `--chat NAME` and `--since YYYY-MM-DD` to narrow.
3. Present results grouped by chat with date, sender and the relevant text. Say if nothing matched
   and which variants were tried. Never send, edit or delete Telegram messages.
