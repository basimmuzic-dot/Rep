# Saudi Laws Knowledge Base (الأنظمة واللوائح)

A token-efficient legal reference for Claude and Claude Code. It needs only Python 3.9+ and has no dependencies.

## Setup (one time, on a PC that can open laws.boe.gov.sa)
```bash
cd saudi-laws
python3 scrape.py                    # laws in urls.txt + their linked regulations (اللوائح)
# python3 scrape.py --crawl-folders  # optional: discover every law from /Laws/Folders/*
python3 kb.py build                  # builds data/laws.db (SQLite FTS5)
python3 kb.py search "فسخ عقد العمل"   # test it
```
Then open Claude Code in the repo root. `.mcp.json` registers the `saudi-laws` MCP server automatically.

## Output
- `data/laws/<id>.md`: one clean Markdown file per law, with each article under its own `## المادة …` heading. Use these to read, check differences, or upload to a Claude Project.
- `data/articles.jsonl`: one article per line.
- `data/laws.db`: the search index.

## Why it's cheap to run
Claude never loads the laws. It calls `search_saudi_laws` and gets about 5 article snippets (around 350 characters each, roughly 1–2k tokens in total). It calls `get_saudi_law_article` only when it needs the full text of one article. Searching runs on your machine and costs no tokens. There are no embedding API calls.

## Expired / non-valid law
Each law carries the site's `الحالة` field (front matter `status:`, plus `published:` and `retrieved:` dates).
- `ساري` (in force): returned normally.
- `لاغي` (repealed) and individual articles that say "ألغيت هذه المادة": hidden from search by default.
- `ساري بعد مدة N يوم من تاريخ النشر`: hidden until the computed effective date, then valid automatically.
- `جاري العمل على النظام` (no publication date on the site): shown with a ⚠️ warning, validity unconfirmed.
- Amended articles are tagged `article_status`: the text includes the amendment history, the latest amendment governs.
Pass `include_inactive=true` to see hidden items (each carries a ⚠️ warning). Statuses are a snapshot from `retrieved:`; re-run `scrape.py` periodically.

## Maintenance
- `python scrape.py --resplit` re-parses the saved `.md` files offline (no network) and rebuilds `articles.jsonl`.
- `python kb.py build` writes a new timestamped `laws-*.db` and points `laws.current` at it (a running server never blocks a rebuild).
- `python eval.py` (ranking check) and `python verify.py` (spot-check articles against the live pages).
