#!/usr/bin/env python3
"""tgsearch - typo-tolerant, Arabic-aware search over your Telegram messages.

Messages live in a local SQLite file (default ~/.tgsearch/messages.db).
They get there in one of two ways:

  import  - read a Telegram Desktop "Export Telegram data" JSON export
  sync    - optional: incrementally pull new messages with your own Telegram
            login (read-only, needs `pip install telethon`)

Then:  tgsearch.py search "jeddah outlet"
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sqlite3
import sys
import unicodedata
from pathlib import Path

DEFAULT_DB = Path(os.environ.get("TGSEARCH_DB", Path.home() / ".tgsearch" / "messages.db"))
DEFAULT_ALIASES = Path(__file__).with_name("aliases.txt")

# ---------------------------------------------------------------- normalising

_ARABIC_DIACRITICS = re.compile("[ً-ٰٟۖ-ۭـ]")  # harakat + tatweel
_CHAR_MAP = str.maketrans({
    "أ": "ا", "إ": "ا", "آ": "ا", "ٱ": "ا",
    "ى": "ي", "ی": "ي", "ې": "ي", "ئ": "ي",
    "ة": "ه", "ؤ": "و", "ک": "ك", "گ": "ك",
    "‌": " ", "‏": "", "‎": "",
})
_DIGITS = str.maketrans(
    "٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹", "01234567890123456789")
_TOKEN = re.compile(r"\d+|[^\W\d_]+")


def normalize(text: str) -> str:
    text = unicodedata.normalize("NFKC", text).casefold()
    text = _ARABIC_DIACRITICS.sub("", text)
    return text.translate(_CHAR_MAP).translate(_DIGITS)


def tokenize(text: str) -> list[str]:
    """Word tokens; digits and letters are split, so '8gb' == '8 gb'."""
    return _TOKEN.findall(normalize(text))


def max_edits(term: str) -> int:
    n = len(term)
    return 0 if n <= 3 else 1 if n <= 5 else 2


# ------------------------------------------------------------------ database

SCHEMA = """
CREATE TABLE IF NOT EXISTS messages (
  id INTEGER PRIMARY KEY,
  chat_id INTEGER NOT NULL,
  msg_id INTEGER NOT NULL,
  chat_name TEXT,
  chat_type TEXT,
  sender TEXT,
  date TEXT,
  text TEXT,
  UNIQUE(chat_id, msg_id)
);
CREATE TABLE IF NOT EXISTS tokens (
  word TEXT NOT NULL,
  mid INTEGER NOT NULL,
  pos INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS tokens_word ON tokens(word);
CREATE INDEX IF NOT EXISTS tokens_mid ON tokens(mid);
CREATE INDEX IF NOT EXISTS messages_chat ON messages(chat_id, msg_id);
"""


def connect(path: Path = DEFAULT_DB) -> sqlite3.Connection:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    db = sqlite3.connect(path)
    db.executescript(SCHEMA)
    return db


def upsert(db: sqlite3.Connection, chat_id: int, msg_id: int, chat_name: str,
           chat_type: str, sender: str, date: str, text: str) -> bool:
    """Insert or update one message. Returns True if the row was new."""
    row = db.execute("SELECT id FROM messages WHERE chat_id=? AND msg_id=?",
                     (chat_id, msg_id)).fetchone()
    if row:
        mid, new = row[0], False
        db.execute("UPDATE messages SET chat_name=?, chat_type=?, sender=?, date=?, text=? WHERE id=?",
                   (chat_name, chat_type, sender, date, text, mid))
        db.execute("DELETE FROM tokens WHERE mid=?", (mid,))
    else:
        cur = db.execute(
            "INSERT INTO messages(chat_id,msg_id,chat_name,chat_type,sender,date,text) VALUES(?,?,?,?,?,?,?)",
            (chat_id, msg_id, chat_name, chat_type, sender, date, text))
        mid, new = cur.lastrowid, True
    db.executemany("INSERT INTO tokens(word,mid,pos) VALUES(?,?,?)",
                   [(w, mid, i) for i, w in enumerate(tokenize(text))])
    return new


# ------------------------------------------------------------------- import

def _flatten(text) -> str:
    """Telegram exports text as a string or a list of strings/{type,text} dicts."""
    if isinstance(text, str):
        return text
    if isinstance(text, list):
        return "".join(p if isinstance(p, str) else p.get("text", "") for p in text)
    return ""


def import_export(db: sqlite3.Connection, path: Path) -> tuple[int, int]:
    """Import a Telegram Desktop JSON export (full account or a single chat)."""
    path = Path(path)
    files = sorted(path.rglob("result.json")) if path.is_dir() else [path]
    if not files:
        raise SystemExit(f"No result.json found under {path}")
    added = seen = 0
    for f in files:
        data = json.loads(f.read_text(encoding="utf-8"))
        chats = data["chats"]["list"] if "chats" in data else [data]
        for chat in chats:
            cid = chat.get("id")
            if cid is None or "messages" not in chat:
                continue
            name = chat.get("name") or "(unnamed)"
            ctype = chat.get("type", "")
            for m in chat["messages"]:
                if m.get("type") != "message":
                    continue
                text = _flatten(m.get("text")).strip()
                if not text:
                    continue
                seen += 1
                added += upsert(db, cid, m["id"], name, ctype,
                                m.get("from") or "", m.get("date", ""), text)
        db.commit()
    return added, seen


# --------------------------------------------------------------------- sync

def sync(db: sqlite3.Connection, only: list[str] | None, limit_per_chat: int | None) -> int:
    """Pull messages newer than what we already have. Read-only: never sends or marks read."""
    try:
        from telethon.sync import TelegramClient
        from telethon.tl.types import Channel, Chat, User
    except ImportError:
        raise SystemExit("sync needs Telethon:  pip install telethon")
    api_id, api_hash = os.environ.get("TG_API_ID"), os.environ.get("TG_API_HASH")
    if not (api_id and api_hash):
        raise SystemExit("Set TG_API_ID and TG_API_HASH (from https://my.telegram.org -> API development tools).")
    session = str(DEFAULT_DB.parent / "session")
    total = 0
    with TelegramClient(session, int(api_id), api_hash) as client:
        for dlg in client.iter_dialogs():
            ent = dlg.entity
            name = dlg.name or "(unnamed)"
            if only and not any(o.casefold() in name.casefold() for o in only):
                continue
            ctype = ("private_chat" if isinstance(ent, User)
                     else "private_channel" if isinstance(ent, Channel) and not getattr(ent, "username", None)
                     else "channel" if isinstance(ent, Channel)
                     else "private_group" if isinstance(ent, Chat) else "")
            last = db.execute("SELECT COALESCE(MAX(msg_id),0) FROM messages WHERE chat_id=?",
                              (ent.id,)).fetchone()[0]
            n = 0
            for m in client.iter_messages(ent, min_id=last, reverse=True, limit=limit_per_chat):
                if not m.message:
                    continue
                sender = ""
                try:
                    s = m.sender
                    sender = getattr(s, "title", None) or " ".join(
                        filter(None, [getattr(s, "first_name", None), getattr(s, "last_name", None)]))
                except Exception:
                    pass
                upsert(db, ent.id, m.id, name, ctype, sender, m.date.isoformat(), m.message)
                n += 1
            db.commit()
            if n:
                print(f"  {name}: +{n}", file=sys.stderr)
            total += n
    return total


# ------------------------------------------------------------------- search

def load_aliases(path: Path | None) -> dict[str, set[str]]:
    """aliases.txt: one group per line, comma separated. Every member expands to the whole group."""
    groups: dict[str, set[str]] = {}
    if not path or not Path(path).exists():
        return groups
    for line in Path(path).read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        members = {t for part in line.split(",") for t in tokenize(part)}
        for t in members:
            groups.setdefault(t, set()).update(members)
    return groups


def expand_term(term: str, aliases: dict[str, set[str]]) -> set[str]:
    return aliases.get(term, set()) | {term}


def search(db: sqlite3.Connection, query: str, *, aliases: dict[str, set[str]] | None = None,
           exact: bool = False, any_term: bool = False, chat: str | None = None,
           since: str | None = None, limit: int = 30):
    """Return [(score, row)] best first. Row = (chat_name, date, sender, text, chat_id, msg_id)."""
    from rapidfuzz import process
    from rapidfuzz.distance import Levenshtein

    terms = tokenize(query)
    if not terms:
        return []
    aliases = aliases or {}
    vocab = [r[0] for r in db.execute("SELECT DISTINCT word FROM tokens")]
    known = set(vocab)

    # term -> {matched vocabulary word: edit distance}
    per_term: list[dict[str, int]] = []
    for t in terms:
        hits: dict[str, int] = {}
        for variant in expand_term(t, aliases):
            k = 0 if exact else max_edits(variant)
            if k == 0:
                if variant in known:
                    hits[variant] = 0
                continue
            for w, d, _ in process.extract(variant, vocab, scorer=Levenshtein.distance,
                                           score_cutoff=k, limit=None):
                hits[w] = min(d, hits.get(w, d))
        per_term.append(hits)

    # message id -> per-term list of (position, distance)
    found: list[dict[int, list[tuple[int, int]]]] = []
    for hits in per_term:
        by_msg: dict[int, list[tuple[int, int]]] = {}
        words = list(hits)
        for i in range(0, len(words), 500):
            chunk = words[i:i + 500]
            q = ",".join("?" * len(chunk))
            for w, mid, pos in db.execute(f"SELECT word,mid,pos FROM tokens WHERE word IN ({q})", chunk):
                by_msg.setdefault(mid, []).append((pos, hits[w]))
        found.append(by_msg)

    if any_term:
        candidates = set().union(*(f.keys() for f in found))
    else:
        candidates = set(found[0]).intersection(*found[1:]) if found else set()

    scored = []
    for mid in candidates:
        dist = 0
        for f in found:
            if mid in f:
                dist += min(d for _, d in f[mid])
        covered = sum(1 for f in found if mid in f)
        score = covered * 10 - dist * 2
        # reward the terms appearing next to each other, in order ("8 gb")
        if covered == len(found) and len(found) > 1:
            starts = [p for p, _ in found[0].get(mid, [])]
            for p0 in starts:
                if all(any(p == p0 + i for p, _ in found[i][mid]) for i in range(1, len(found))):
                    score += 5
                    break
        scored.append((score, mid))
    scored.sort(key=lambda s: -s[0])

    results = []
    for score, mid in scored:
        row = db.execute("SELECT chat_name,date,sender,text,chat_id,msg_id FROM messages WHERE id=?",
                         (mid,)).fetchone()
        if chat and chat.casefold() not in (row[0] or "").casefold():
            continue
        if since and (row[1] or "") < since:
            continue
        results.append((score, row))
    # best score first, newest first within ties
    results.sort(key=lambda r: (r[0], r[1][1]), reverse=True)
    return results[:limit]


# ---------------------------------------------------------------------- CLI

def main(argv: list[str] | None = None) -> None:
    p = argparse.ArgumentParser(prog="tgsearch", description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--db", type=Path, default=DEFAULT_DB, help="SQLite file (default %(default)s)")
    sub = p.add_subparsers(dest="cmd", required=True)

    s = sub.add_parser("import", help="import a Telegram Desktop JSON export (file or folder)")
    s.add_argument("path", type=Path)

    s = sub.add_parser("sync", help="fetch new messages with your own login (read-only; needs telethon)")
    s.add_argument("--chat", action="append", help="only chats whose name contains this (repeatable)")
    s.add_argument("--limit-per-chat", type=int, help="cap per chat per run, useful for the first run")

    s = sub.add_parser("search", help="fuzzy search")
    s.add_argument("query")
    s.add_argument("--exact", action="store_true", help="no typo tolerance (aliases still apply)")
    s.add_argument("--any", action="store_true", dest="any_term", help="match ANY word instead of all")
    s.add_argument("--chat", help="only chats whose name contains this")
    s.add_argument("--since", help="only messages on/after this date, e.g. 2026-01-01")
    s.add_argument("--limit", type=int, default=30)
    s.add_argument("--aliases", type=Path, default=DEFAULT_ALIASES)
    s.add_argument("--json", action="store_true", help="machine-readable output (for AI use)")

    sub.add_parser("stats", help="how much is indexed, and how fresh")

    a = p.parse_args(argv)
    db = connect(a.db)

    if a.cmd == "import":
        added, seen = import_export(db, a.path)
        print(f"Imported {seen} messages ({added} new).")
    elif a.cmd == "sync":
        print(f"Synced {sync(db, a.chat, a.limit_per_chat)} new messages.")
    elif a.cmd == "stats":
        n, chats, newest = db.execute(
            "SELECT COUNT(*), COUNT(DISTINCT chat_id), MAX(date) FROM messages").fetchone()
        print(f"{n} messages in {chats} chats; newest message: {newest}")
    else:
        res = search(db, a.query, aliases=load_aliases(a.aliases), exact=a.exact,
                     any_term=a.any_term, chat=a.chat, since=a.since, limit=a.limit)
        if a.json:
            print(json.dumps([{"score": s, "chat": r[0], "date": r[1], "from": r[2],
                               "text": r[3], "chat_id": r[4], "msg_id": r[5]} for s, r in res],
                             ensure_ascii=False, indent=1))
        elif not res:
            print("No matches. Try --any, or add spelling variants to aliases.txt.")
        for s, r in res:
            if not a.json:
                text = " ".join(r[3].split())
                print(f"[{r[1][:16].replace('T', ' ')}] {r[0]} · {r[2]}\n  {text[:300]}{'…' if len(text) > 300 else ''}\n")


if __name__ == "__main__":
    main()
