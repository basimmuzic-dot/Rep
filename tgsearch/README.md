# tgsearch

Typo-tolerant, Arabic-aware search over your own Telegram messages, plus optional automatic refresh.
Everything stays on your computer in one SQLite file (`~/.tgsearch/messages.db`).

What it handles:
- Spelling variants: `jeddah` finds `Jiddah` / `Jedda` (edit distance scales with word length; words of 3 letters or fewer must match exactly).
- Spacing: `8gb` = `8 gb` = `8GB`, but `16 gb` does not match `8 gb`.
- Arabic: diacritics, tatweel, alef/yeh/teh-marbuta variants, Arabic-Indic digits are normalised on both sides.
- Cross-language / odd spellings: add groups to `aliases.txt` (`jeddah, jiddah, جدة`).

## Setup (once)

```
cd tgsearch
pip install -r requirements.txt      # telethon only needed for `sync`
```

### 1. First load: Telegram Desktop export (no login needed)
Telegram Desktop → Settings → Advanced → **Export Telegram data**.
Tick the chats/groups/channels you want, untick media, format **JSON**, then Export.
```
python tgsearch.py import "C:\path\to\Telegram Desktop\DataExport_2026-10-14"
```

### 2. Search
```
python tgsearch.py search "jeddah outlet"
python tgsearch.py search "8gb" --since 2026-09-01
python tgsearch.py search "خصم جدة" --chat Deals
python tgsearch.py search "discount outlet" --any     # either word
python tgsearch.py search "jeddah" --exact            # no typo tolerance
```

## Automatic refresh (optional)

Telegram Desktop cannot be told to export from a script, so unattended refresh needs
its own login via the API. `sync` does that **read-only** (it never sends, deletes or marks
messages read) and only fetches messages newer than what you already have.

1. https://my.telegram.org → API development tools → create an app → copy `api_id`, `api_hash`.
2. Set them and run once; it asks for your phone and the login code:
   ```
   export TG_API_ID=123456 TG_API_HASH=abcdef...      # Windows: setx / $env:
   python tgsearch.py sync --limit-per-chat 2000      # first run, modest
   ```
3. Schedule it.
   - macOS/Linux: `crontab -e` → `0 */3 * * * TG_API_ID=... TG_API_HASH=... python /path/tgsearch.py sync`
   - Windows: Task Scheduler → run `python C:\path\tgsearch.py sync` every few hours.

Cautions:
- This logs in as a second session of your account (Settings → Devices). Keep the session file
  `~/.tgsearch/session.session` private: whoever has it has your account.
- Telegram can rate-limit heavy scraping. Keep `--limit-per-chat` modest at first and don't run it every minute.
- Edits and deletions made after a message was synced are not picked up. Re-importing an export updates edits.
- Not tested against live Telegram from the cloud sandbox where this was written; test on a couple of chats first with `--chat`.

## Using it from Claude Code

Copy `SKILL.md` to `~/.claude/skills/telegram-search/SKILL.md`. Then ask Claude things like
"find Jeddah outlet discounts in my Telegram" and it will refresh (if configured), expand
spelling variants and run `tgsearch search --json`.

## Tests
```
python -m pytest
```
