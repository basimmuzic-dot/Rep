#!/usr/bin/env python3
"""Saudi laws knowledge base: SQLite FTS5 index + a token-frugal MCP server.

    python3 kb.py build              # data/articles.jsonl -> data/laws.db
    python3 kb.py search "فسخ العقد"  # quick CLI test
    python3 kb.py serve              # MCP stdio server (Claude Code launches this via .mcp.json)

Why this design: retrieval runs locally (BM25 over Arabic-normalized text), so it costs
zero tokens. Claude only receives the few matching articles, trimmed to a snippet,
and fetches a full article only when it needs one.
"""
import datetime, json, re, sqlite3, sys, threading, time
from pathlib import Path

DATA = Path(__file__).parent / "data"
CURRENT = DATA / "laws.current"  # names the live index file; build() writes a fresh one each time so a
                                 # running server that still has the old file open (Windows lock) never blocks a rebuild


def db_path():
    try:
        return DATA / CURRENT.read_text(encoding="utf-8").strip()
    except OSError:
        return DATA / "laws.db"
TITLE_W = 0.3  # bm25 weight of the law title column (body and article label are 1.0)
DIACRITICS = re.compile(r"[ؐ-ًؚ-ٰٟۖ-ۭـ]")


def norm(s):
    """Arabic normalization so 'المادة' / 'المادّة' / 'إدارة' / 'ادارة' all match."""
    s = DIACRITICS.sub("", s)
    s = re.sub("[إأآٱ]", "ا", s).replace("ى", "ي").replace("ة", "ه").replace("ؤ", "و").replace("ئ", "ي")
    return re.sub(r"(?<!\w)(?:لل|[وفبك]ال|ال)(?=\w{3,})", "", s)  # drop the article/clitic so 'العمل', 'للعمل', 'بالعمل' match 'عمل'



REPEALED_RE = re.compile(r"(?:ألغيت|أُلغيت|ألغي|ألغاة)\s+هذه\s+المادة")
AMENDED_RE = re.compile(r"عدلت|عُدلت|تم تعديل|أضيفت|أُضيفت")


def status_code(status):
    """law status text from the site -> in_force | repealed | not_yet | unverified"""
    if status == "ساري":
        return "in_force"
    if status.startswith("لاغ"):
        return "repealed"
    if status.startswith("ساري بعد"):
        return "not_yet"  # 'ساري بعد مدة 180 يوم من تاريخ النشر': becomes valid on a computed date
    return "unverified"  # e.g. 'جاري العمل على النظام' (no publication date on the site): shown, with a warning


def effective_from(status, published):
    """ISO date a 'ساري بعد مدة N يوم من تاريخ النشر' law takes effect ('' if it cannot be computed)"""
    m = re.search(r"(\d+)\s*يوم", status)
    if not (m and published):
        return ""
    return (datetime.date.fromisoformat(published) + datetime.timedelta(days=int(m.group(1)))).isoformat()


# valid today: in force, unverified (shown with a warning), or past its computed effective date
ACTIVE = ("(a.status_code IN ('in_force','unverified') OR "
          "(a.status_code='not_yet' AND a.effective_from!='' AND a.effective_from<=date('now')))")


def article_flag(text):
    head = text[:300]
    return "repealed" if REPEALED_RE.search(head) else "amended" if AMENDED_RE.search(head) else ""


def build():
    new = DATA / f"laws-{int(time.time())}.db"
    c = sqlite3.connect(new)
    c.executescript("""
      CREATE TABLE articles(id INTEGER PRIMARY KEY, law_id, title, type, url, article, text,
                            status, status_code, retrieved, published, effective_from, flag);
      CREATE VIRTUAL TABLE fts USING fts5(title, article, body, tokenize='unicode61 remove_diacritics 2');
    """)
    n = 0
    for line in open(DATA / "articles.jsonl", encoding="utf-8"):
        r = json.loads(line)
        st = r.get("status", "")
        pub = r.get("published", "")
        cur = c.execute("INSERT INTO articles(law_id,title,type,url,article,text,status,status_code,retrieved,"
                        "published,effective_from,flag) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)",
                        (r["law_id"], r["title"], r["type"], r["url"], r["article"], r["text"],
                         st, status_code(st), r.get("retrieved", ""), pub, effective_from(st, pub),
                         article_flag(r["text"])))
        c.execute("INSERT INTO fts(rowid,title,article,body) VALUES(?,?,?,?)",
                  (cur.lastrowid, norm(r["title"]), norm(r["article"]), norm(r["text"])))
        n += 1
    c.commit()
    c.close()
    CURRENT.write_text(new.name, encoding="utf-8")
    for old in DATA.glob("laws*.db"):  # best effort: a file still open in another process stays until it exits
        if old != new:
            try:
                old.unlink()
            except OSError:
                pass
    print(f"indexed {n} articles → {new}")


def _db():
    c = sqlite3.connect(db_path())
    c.row_factory = sqlite3.Row
    return c


def _tags(r):
    """warnings that must travel with any result that is not plain current law"""
    t = {}
    code, today = r["status_code"], datetime.date.today().isoformat()
    if code == "repealed":
        t["warning"] = f"⚠️ نظام لاغٍ (حالة الموقع «{r['status']}») — لا يُعتمد عليه"
    elif code == "not_yet" and not (r["effective_from"] and r["effective_from"] <= today):
        when = f"يسري من {r['effective_from']}" if r["effective_from"] else "تاريخ السريان غير محدد"
        t["warning"] = f"⚠️ لم يبدأ سريانه بعد ({when}) — لا يُعتمد عليه الآن"
    elif code == "unverified":
        t["warning"] = (f"⚠️ حالة النظام على الموقع «{r['status'] or 'غير معروفة'}» وتاريخ النشر غير محدد — "
                        "سريانه غير مؤكد؛ تحقق من المصدر الرسمي")
    if r["flag"] == "repealed":
        t["article_status"] = "⚠️ مادة ملغاة — لا يُعتمد عليها"
    elif r["flag"] == "amended":
        t["article_status"] = "معدلة: النص يتضمن سجل التعديلات، والمعتمد أحدث تعديل؛ تحقق من المصدر"
    return t


STOP = {norm(w) for w in """هل ما ماذا من في عن على الى إلى الذي التي اللي الذين هذا هذه ذلك تلك كان يكون كيف متى اين أين لماذا
هو هي هم انا أنا انت نحن او أو ام ثم لكن عند اذا إذا حتى عشان علشان ليش ليه وش ايش شنو مين كم يعني
اللي يلزم يحق يجوز هناك ايضا أيضا فقط قد لا لم لن ان إن أن كي لو بس""".split()}
_THES = None


def _thesaurus():
    global _THES
    if _THES is None:
        try:
            raw = json.loads((Path(__file__).parent / "thesaurus.json").read_text(encoding="utf-8"))
        except OSError:
            raw = {}
        _THES = {norm(k): [norm(x) for x in v] for k, v in raw.items() if not k.startswith("_")}
    return _THES


def _terms(query):
    return [t for t in re.findall(r"\w+", norm(query)) if len(t) > 1 and t not in STOP]


def _fts_query(query):
    """OR of the question's words (prefix match) + thesaurus expansions + exact phrase / adjacent pairs."""
    terms = _terms(query)
    if not terms:
        return None
    th, extra = _thesaurus(), []
    for t in terms:
        extra += th.get(t, [])
    extra += [e for k, v in th.items() if " " in k and k in " ".join(terms) for e in v]  # multi-word keys
    parts = [f'"{t}"*' for t in dict.fromkeys(terms)]
    parts += [f'"{e}"' if " " in e else f'"{e}"*' for e in dict.fromkeys(extra) if e not in terms]
    if len(terms) > 1:
        parts.append('"' + " ".join(terms) + '"')
        parts += [f'"{a} {b}"' for a, b in zip(terms, terms[1:])]
    return " OR ".join(parts)


def _fts_ids(q, cond, args, n):
    sql = f"""SELECT a.id FROM fts JOIN articles a ON a.id=fts.rowid WHERE fts MATCH ?{cond}
              ORDER BY bm25(fts,{TITLE_W},1.0,1.0) LIMIT ?"""
    return [r[0] for r in _db().execute(sql, [q] + args + [n]).fetchall()]


RRF_K = 60


def _fuse(rankings, weights=None):
    """Reciprocal-rank fusion: an article ranked high by several retrievers / phrasings wins."""
    score = {}
    for i, ranking in enumerate(rankings):
        w = weights[i] if weights else 1.0
        for pos, aid in enumerate(ranking):
            score[aid] = score.get(aid, 0.0) + w / (RRF_K + pos + 1)
    return sorted(score, key=score.get, reverse=True)


def search(query=None, k=5, law=None, snippet_chars=350, include_inactive=False, queries=None):
    """Hybrid search. `queries` = several paraphrases / legal-term variants of the same question (fused)."""
    qs = [q for q in ([query] if query else []) + list(queries or []) if q and q.strip()]
    if not qs:
        return []
    args, cond = [], ""
    if law:
        cond += " AND a.title LIKE ?"
        args.append(f"%{law}%")
    db = _db()
    hidden = 0
    if not include_inactive:  # expired law must never look valid
        first = _fts_query(qs[0])
        if first:
            hidden = db.execute(f"SELECT COUNT(*) FROM fts JOIN articles a ON a.id=fts.rowid WHERE fts MATCH ?{cond}"
                                f" AND NOT ({ACTIVE} AND a.flag!='repealed')", [first] + args).fetchone()[0]
        cond += f" AND {ACTIVE} AND a.flag!='repealed'"
    rankings, weights = [], []
    for q in qs:
        fq = _fts_query(q)
        if fq:
            rankings.append(_fts_ids(fq, cond, args, 60))
            weights.append(1.0)
    for ranking, w in _dense_rankings(qs, cond, args):
        rankings.append(ranking)
        weights.append(w)
    ids = _fuse(rankings, weights)[:k]
    rows = {r["id"]: r for r in db.execute(
        "SELECT a.id,a.title,a.type,a.article,a.text,a.url,a.status,a.status_code,a.effective_from,a.flag "
        f"FROM articles a WHERE a.id IN ({','.join('?' * len(ids))})", ids).fetchall()} if ids else {}
    out = []
    for i in ids:
        r = rows[i]
        t = r["text"]
        cut = t if len(t) <= snippet_chars else t[:snippet_chars] + "…"
        out.append({"id": r["id"], "law": r["title"], "type": r["type"], "article": r["article"],
                    "text": cut, "truncated": len(t) > snippet_chars, **_tags(r)})
    if hidden:
        out.append({"note": f"{hidden} matching articles were hidden because they are repealed, repealed articles, "
                            "or in laws not yet in force; pass include_inactive=true to see them (not valid law)."})
    return out


DENSE_MODEL = "intfloat/multilingual-e5-large"
_dense = {"state": "unloaded"}  # unloaded | loading | ready | off
_dense_lock = threading.Lock()


def dense_load():
    """Load the embedding model + vectors once (needs the venv: numpy + fastembed). Safe to call repeatedly."""
    with _dense_lock:
        if _dense["state"] != "unloaded":
            return
        _dense["state"] = "loading"
    try:
        import numpy as np
        from fastembed import TextEmbedding
        keys = json.loads((DATA / "embeddings.keys.json").read_text(encoding="utf-8"))
        mat = np.load(DATA / "embeddings.npy").astype(np.float32)
        ids = {(l, a): i for i, l, a in _db().execute("SELECT id, law_id, article FROM articles")}
        aid = np.array([ids.get((k[0], k[1]), -1) for k in keys])
        _dense.update(np=np, mat=mat, aid=aid, model=TextEmbedding(DENSE_MODEL), state="ready")
    except Exception as e:  # noqa: BLE001  keyword search still works without the semantic layer
        _dense.update(state="off", why=repr(e))


def _dense_rankings(qs, cond, args):
    """Semantic retriever: rank articles by meaning (cosine similarity of multilingual-e5 vectors)."""
    if _dense["state"] == "unloaded":
        dense_load()
    if _dense["state"] != "ready":
        return []
    np, mat, aid = _dense["np"], _dense["mat"], _dense["aid"]
    out = []
    for q in qs:
        v = np.array(list(_dense["model"].embed(["query: " + q]))[0], dtype=np.float32)
        sims = mat @ (v / np.linalg.norm(v))
        top = np.argpartition(-sims, 400)[:400]
        seen = []
        for i in top[np.argsort(-sims[top])]:
            a = int(aid[i])
            if a >= 0 and a not in seen:
                seen.append(a)
        ok = {r[0] for r in _db().execute(
            f"SELECT a.id FROM articles a WHERE a.id IN ({','.join('?' * len(seen))}){cond}", seen + args)}
        out.append(([a for a in seen if a in ok][:60], 1.0))
    return out


def get_article(id=None, law=None, article=None):
    c = _db()
    if id is not None:
        r = c.execute("SELECT * FROM articles WHERE id=?", (id,)).fetchone()
    else:
        r = c.execute("SELECT * FROM articles WHERE title LIKE ? AND article LIKE ? LIMIT 1",
                      (f"%{law}%", f"%{article}%")).fetchone()
    return {**dict(r), **_tags(r)} if r else {"error": "not found"}


def list_laws(title_contains=None, include_inactive=False):
    cond = "" if include_inactive else f"WHERE {ACTIVE}"
    if title_contains:
        cond += (" AND " if cond else "WHERE ") + "a.title LIKE ?"
    rows = _db().execute(
        "SELECT a.title, a.type, a.status, a.published, a.retrieved, COUNT(*) AS articles FROM articles a "
        f"{cond} GROUP BY a.law_id ORDER BY a.type, a.title", (f"%{title_contains}%",) if title_contains else ()).fetchall()
    return [{k: v for k, v in dict(r).items() if not (k == "status" and v == "ساري")} for r in rows]


# ---------------- minimal MCP (JSON-RPC over stdio), no SDK needed ----------------
TOOLS = [
    {"name": "search_saudi_laws",
     "description": "Search Saudi laws and implementing regulations (الأنظمة واللوائح) article by article. "
                    "Returns the top-k matching articles as short snippets. Matching is by keywords AND meaning, but always pass `queries` with 3-5 phrasings of the same question "
                    "(everyday wording + the statute's likely wording + synonyms, e.g. فصل / إنهاء العقد / سبب غير مشروع) for reliable recall; if the best result still looks off, search again with different wording or a `law` filter. "
                    "By default only laws and articles IN FORCE are returned; anything carrying a warning/article_status field is not plain current law, so flag it to the user. "
                    "Use get_saudi_law_article(id) for full text only if a snippet is truncated and needed.",
     "inputSchema": {"type": "object", "properties": {
         "query": {"type": "string", "description": "the question or key terms, in Arabic"},
         "queries": {"type": "array", "items": {"type": "string"},
                     "description": "3-5 alternative phrasings of the SAME question (everyday wording, statutory wording, "
                                    "synonyms); results are fused, so recall improves a lot"},
         "k": {"type": "integer", "default": 5, "maximum": 20},
         "law": {"type": "string", "description": "optional: restrict to laws whose title contains this"},
         "include_inactive": {"type": "boolean", "default": False,
                              "description": "also return repealed/pending laws and repealed articles (NOT valid law; for history only)"}},
         "required": ["query"]}},
    {"name": "get_saudi_law_article",
     "description": "Full text of one article, by id from search results, or by law title + article label.",
     "inputSchema": {"type": "object", "properties": {
         "id": {"type": "integer"}, "law": {"type": "string"}, "article": {"type": "string"}}}},
    {"name": "list_saudi_laws", "description": "List indexed laws/regulations (in force by default) with article counts. Optionally filter by title.",
     "inputSchema": {"type": "object", "properties": {
         "title_contains": {"type": "string"}, "include_inactive": {"type": "boolean", "default": False}}}},
]


def call(name, a):
    if name == "search_saudi_laws":
        return search(a.get("query"), min(int(a.get("k", 5)), 20), a.get("law"),
                      include_inactive=bool(a.get("include_inactive")), queries=a.get("queries"))
    if name == "get_saudi_law_article":
        return get_article(a.get("id"), a.get("law"), a.get("article"))
    if name == "list_saudi_laws":
        return list_laws(a.get("title_contains"), bool(a.get("include_inactive")))
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


def _venv_python():
    py = Path(__file__).parent / ".venv" / ("Scripts/python.exe" if sys.platform == "win32" else "bin/python")
    return py if py.exists() and Path(sys.executable).resolve() != py.resolve() else None


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "serve"
    py = _venv_python()
    if py and cmd in ("serve", "search"):  # semantic search needs numpy + fastembed, which live in the venv
        import subprocess
        sys.exit(subprocess.call([str(py), __file__] + sys.argv[1:]))
    if cmd == "build":
        build()
    elif cmd == "search":
        dense_load()
        print(json.dumps(search(" ".join(sys.argv[2:])), ensure_ascii=False, indent=1))
    else:
        threading.Thread(target=dense_load, daemon=True).start()  # load the model without delaying the MCP handshake
        serve()
