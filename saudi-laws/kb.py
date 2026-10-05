#!/usr/bin/env python3
"""Saudi laws knowledge base: SQLite FTS5 index + a token-frugal MCP server.

    python3 kb.py build              # data/articles.jsonl -> data/laws.db
    python3 kb.py search "فسخ العقد"  # quick CLI test
    python3 kb.py serve              # MCP stdio server (Claude Code launches this via .mcp.json)

Why this design: retrieval runs locally (BM25 over Arabic-normalized text), so it costs
zero tokens. Claude only receives the few matching articles, trimmed to a snippet,
and fetches a full article only when it needs one.
"""
import json, re, sqlite3, sys
from pathlib import Path

DATA = Path(__file__).parent / "data"
DB = DATA / "laws.db"
TITLE_W = 0.3  # bm25 weight of the law title column (body and article label are 1.0)
DIACRITICS = re.compile(r"[ؐ-ًؚ-ٰٟۖ-ۭـ]")


def norm(s):
    """Arabic normalization so 'المادة' / 'المادّة' / 'إدارة' / 'ادارة' all match."""
    s = DIACRITICS.sub("", s)
    s = re.sub("[إأآٱ]", "ا", s).replace("ى", "ي").replace("ة", "ه").replace("ؤ", "و").replace("ئ", "ي")
    return re.sub(r"(?<!\w)(?:لل|[وفبك]ال|ال)(?=\w{3,})", "", s)  # drop the article/clitic so 'العمل', 'للعمل', 'بالعمل' match 'عمل'



def build():
    DB.unlink(missing_ok=True)
    c = sqlite3.connect(DB)
    c.executescript("""
      CREATE TABLE articles(id INTEGER PRIMARY KEY, law_id, title, type, url, article, text);
      CREATE VIRTUAL TABLE fts USING fts5(title, article, body, tokenize='unicode61 remove_diacritics 2');
    """)
    n = 0
    for line in open(DATA / "articles.jsonl", encoding="utf-8"):
        r = json.loads(line)
        cur = c.execute("INSERT INTO articles(law_id,title,type,url,article,text) VALUES(?,?,?,?,?,?)",
                        (r["law_id"], r["title"], r["type"], r["url"], r["article"], r["text"]))
        c.execute("INSERT INTO fts(rowid,title,article,body) VALUES(?,?,?,?)",
                  (cur.lastrowid, norm(r["title"]), norm(r["article"]), norm(r["text"])))
        n += 1
    c.commit()
    print(f"indexed {n} articles → {DB}")


def _db():
    c = sqlite3.connect(DB)
    c.row_factory = sqlite3.Row
    return c


def search(query, k=5, law=None, snippet_chars=350):
    terms = [t for t in re.findall(r"\w+", norm(query)) if len(t) > 1]
    if not terms:
        return []
    # OR-match with prefix (Arabic has many affixes); BM25 ranks docs with more terms higher.
    # Title hits weighted 3x, article label 1x, body 1x.
    q = " OR ".join(f'"{t}"*' for t in terms)
    if len(terms) > 1:  # reward the exact phrase and adjacent words
        q += ' OR "' + " ".join(terms) + '"' + "".join(f' OR "{a} {b}"' for a, b in zip(terms, terms[1:]))
    sql = """SELECT a.id,a.title,a.type,a.article,a.text,a.url FROM fts JOIN articles a ON a.id=fts.rowid
             WHERE fts MATCH ? {} ORDER BY bm25(fts,{tw},1.0,1.0) LIMIT ?"""
    args = [q]
    if law:
        sql = sql.format("AND a.title LIKE ?", tw=TITLE_W)
        args.append(f"%{law}%")
    else:
        sql = sql.format("", tw=TITLE_W)
    rows = _db().execute(sql, args + [k]).fetchall()
    out = []
    for r in rows:
        t = r["text"]
        cut = t if len(t) <= snippet_chars else t[:snippet_chars] + "…"
        out.append({"id": r["id"], "law": r["title"], "type": r["type"], "article": r["article"],
                    "text": cut, "truncated": len(t) > snippet_chars})
    return out


def get_article(id=None, law=None, article=None):
    c = _db()
    if id is not None:
        r = c.execute("SELECT * FROM articles WHERE id=?", (id,)).fetchone()
    else:
        r = c.execute("SELECT * FROM articles WHERE title LIKE ? AND article LIKE ? LIMIT 1",
                      (f"%{law}%", f"%{article}%")).fetchone()
    return dict(r) if r else {"error": "not found"}


def list_laws():
    return [dict(r) for r in _db().execute(
        "SELECT title, type, COUNT(*) AS articles FROM articles GROUP BY law_id ORDER BY type, title")]


# ---------------- minimal MCP (JSON-RPC over stdio), no SDK needed ----------------
TOOLS = [
    {"name": "search_saudi_laws",
     "description": "Search Saudi laws and implementing regulations (الأنظمة واللوائح) article by article. "
                    "Returns the top-k matching articles as short snippets. Query in Arabic for best results; the match is lexical, so if results look off, retry with the law's own wording (e.g. 'ينتهي عقد العمل' rather than 'فسخ') or several short queries. "
                    "Use get_saudi_law_article(id) for full text only if a snippet is truncated and needed.",
     "inputSchema": {"type": "object", "properties": {
         "query": {"type": "string"}, "k": {"type": "integer", "default": 5, "maximum": 20},
         "law": {"type": "string", "description": "optional: restrict to laws whose title contains this"}},
         "required": ["query"]}},
    {"name": "get_saudi_law_article",
     "description": "Full text of one article, by id from search results, or by law title + article label.",
     "inputSchema": {"type": "object", "properties": {
         "id": {"type": "integer"}, "law": {"type": "string"}, "article": {"type": "string"}}}},
    {"name": "list_saudi_laws", "description": "List indexed laws/regulations with article counts.",
     "inputSchema": {"type": "object", "properties": {}}},
]


def call(name, a):
    if name == "search_saudi_laws":
        return search(a["query"], min(int(a.get("k", 5)), 20), a.get("law"))
    if name == "get_saudi_law_article":
        return get_article(a.get("id"), a.get("law"), a.get("article"))
    if name == "list_saudi_laws":
        return list_laws()
    raise ValueError(name)


def serve():
    sys.stdin.reconfigure(encoding="utf-8")  # Windows defaults to cp1252, which breaks Arabic
    sys.stdout.reconfigure(encoding="utf-8")
    for line in sys.stdin:
        msg = json.loads(line)
        mid, method = msg.get("id"), msg.get("method")
        if mid is None:
            continue  # notification
        try:
            if method == "initialize":
                res = {"protocolVersion": msg["params"].get("protocolVersion", "2024-11-05"),
                       "capabilities": {"tools": {}}, "serverInfo": {"name": "saudi-laws", "version": "1.0"}}
            elif method == "tools/list":
                res = {"tools": TOOLS}
            elif method == "tools/call":
                p = msg["params"]
                data = call(p["name"], p.get("arguments") or {})
                res = {"content": [{"type": "text", "text": json.dumps(data, ensure_ascii=False, separators=(",", ":"))}]}
            elif method == "ping":
                res = {}
            else:
                raise ValueError(f"unknown method {method}")
            out = {"jsonrpc": "2.0", "id": mid, "result": res}
        except Exception as e:  # noqa: BLE001
            out = {"jsonrpc": "2.0", "id": mid, "error": {"code": -32000, "message": str(e)}}
        sys.stdout.write(json.dumps(out, ensure_ascii=False) + "\n")
        sys.stdout.flush()


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "serve"
    if cmd == "build":
        build()
    elif cmd == "search":
        print(json.dumps(search(" ".join(sys.argv[2:])), ensure_ascii=False, indent=1))
    else:
        serve()
