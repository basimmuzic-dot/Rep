#!/usr/bin/env python3
"""Scrape Saudi laws (الأنظمة) and regulations (اللوائح) from laws.boe.gov.sa.

Standard library only. Run it on a machine that can reach laws.boe.gov.sa:

    python3 scrape.py                      # the laws in urls.txt
    python3 scrape.py --crawl-folders      # also discover laws from /Laws/Folders/1..N
    python3 scrape.py URL [URL ...]        # specific pages

Output:
    data/laws/<id>.md        one clean Markdown file per law/regulation (good for humans & AI)
    data/articles.jsonl      one JSON object per article (input for build_index.py)
"""
import argparse, gzip, html, json, re, sys, time, urllib.request
from html.parser import HTMLParser
from pathlib import Path

BASE = "https://laws.boe.gov.sa"
OUT = Path(__file__).parent / "data"
UA = {"User-Agent": "Mozilla/5.0 (law-kb research scraper)", "Accept-Language": "ar"}
DETAIL_RE = re.compile(r"/BoeLaws/Laws/LawDetails/([0-9a-f-]{36})/\d+", re.I)
# "المادة الأولى" / "المادة 12" / "المادة الحادية عشرة" ...
ARTICLE_RE = re.compile(r"^[ \t]*((?:ال)?مادة[ \t]*[^\n:：]{1,40}?)[ \t]*[:：]?[ \t]*$|^[ \t]*((?:ال)?مادة[ \t]*\S+(?:[ \t]+\S+){0,3})[ \t]*[:：]", re.M)


def fetch(url, tries=4):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=60) as r:
                return r.read().decode("utf-8", "replace")
        except Exception as e:  # noqa: BLE001
            if i == tries - 1:
                raise
            print(f"  retry {url}: {e}", file=sys.stderr)
            time.sleep(2 ** (i + 1))
# site widgets that leak into the text (visit counter, notify button, per-article buttons)
NOISE_RE = re.compile(r"^(عدد مرات التصفح\s*\d*|طلب اشعار|تعديلات المادة|نبذة عن النظام"
                      r"|مادة معدلة|مادة ملغية|اصل الوثيقة|طباعة|الملاحظات والتعليقات|الإصدارات|اللغات)$")
_folder_index = None
STATUS_RE = re.compile(r"^\s*الحالة\s*\n+\s*(\S[^\n]*)", re.M)


PUBLISHED_RE = re.compile(r"تاريخ النشر\s*\n+[^\n]*?(\d{1,2})/(\d{1,2})/(\d{4})\s*مـ")


def extract_published(text):
    """Gregorian publication date (ISO) from the page header, empty if the site has none."""
    m = PUBLISHED_RE.search(text)
    return f"{m.group(3)}-{int(m.group(2)):02d}-{int(m.group(1)):02d}" if m else ""


def extract_status(text):
    """The law page's 'الحالة' field: ساري / لاغي / جاري العمل على النظام / ساري بعد مدة ..."""
    m = STATUS_RE.search(text)
    return m.group(1).strip() if m else ""


def regulation_links(title):
    """The law pages do not link to their regulations; find them by title in the folder index."""
    global _folder_index
    if _folder_index is None:
        page = fetch(f"{BASE}/BoeLaws/Laws/Folders/1")
        _folder_index = [(m.group(1), re.sub(r"\s+", " ", re.sub(r"<[^>]+>", "", m.group(2))).strip())
                         for m in re.finditer(r'<a [^>]*href="[^"]*LawDetails/([0-9a-f-]{36})/\d+[^"]*"[^>]*>(.*?)</a>', page, re.S)]
    if "لائح" in title:
        return []
    return [f"{BASE}/BoeLaws/Laws/LawDetails/{i}/1" for i, t in _folder_index if "لائح" in t and title in t]


class TextExtractor(HTMLParser):
    """HTML -> text with line breaks at block elements; drops nav/script/style."""
    SKIP = {"script", "style", "noscript", "header", "footer", "nav", "svg", "button", "form"}
    BLOCK = {"p", "div", "br", "li", "tr", "h1", "h2", "h3", "h4", "h5", "h6", "section", "article", "table"}

    def __init__(self):
        super().__init__()
        self.parts, self.skip, self.links, self.title = [], 0, [], ""
        self._in_title = False

    def handle_starttag(self, tag, attrs):
        if tag in self.SKIP:
            self.skip += 1
        if tag in self.BLOCK:
            self.parts.append("\n")
        if tag == "title":
            self._in_title = True
        if tag == "a":
            href = dict(attrs).get("href") or ""
            self._href = href if DETAIL_RE.search(href) else None
            self._atext = ""

    def handle_endtag(self, tag):
        if tag in self.SKIP and self.skip:
            self.skip -= 1
        if tag in self.BLOCK:
            self.parts.append("\n")
        if tag == "title":
            self._in_title = False
        if tag == "a" and getattr(self, "_href", None):
            if "لائح" in self._atext:  # only follow regulation links, not every related law
                self.links.append(self._href)
            self._href = None

    def handle_data(self, data):
        if getattr(self, "_href", None):
            self._atext += data
        if self._in_title:
            self.title += data
        elif not self.skip:
            self.parts.append(data)

    def text(self):
        t = html.unescape("".join(self.parts)).replace("\xa0", " ")
        t = re.sub(r"[ \t]+", " ", t)
        t = "\n".join(l for l in t.split("\n") if not NOISE_RE.match(l.strip()))
        return re.sub(r"\n\s*\n+", "\n\n", t).strip()


def law_id(url):
    m = DETAIL_RE.search(url)
    return m.group(1) if m else re.sub(r"\W+", "_", url)[-60:]


def chunk_text(text, size=1500):
    """No articles (regulations, rules): chunk by paragraph so search returns small pieces."""
    chunks, cur = [], ""
    for para in (p for p in text.split("\n") if p.strip()):
        if cur and len(cur) + len(para) > size:
            chunks.append(cur)
            cur = ""
        cur += ("\n" if cur else "") + para
    if cur:
        chunks.append(cur)
    return [(f"النص ({i})", c) for i, c in enumerate(chunks, 1)] if len(chunks) > 1 else [("النص", text)]


def split_articles(text):
    """Fallback for pages without article blocks: [(label, body)] from heading lines in plain text."""
    hits = [(m.start(), (m.group(1) or m.group(2)).strip()) for m in ARTICLE_RE.finditer(text)]
    if not hits:
        return chunk_text(text)
    out = []
    if hits[0][0] > 0:
        out.append(("الديباجة", text[: hits[0][0]].strip()))
    for i, (pos, label) in enumerate(hits):
        end = hits[i + 1][0] if i + 1 < len(hits) else len(text)
        body = text[pos:end].strip()
        body = body[len(label):].lstrip(" :：\n") if body.startswith(label) else body
        out.append((label, body))
    merged = {}
    for l, b in out:
        if b:
            merged[l] = merged[l] + "\n\n" + b if l in merged else b
    return list(merged.items())


# ---- structured parsing of the law page: every article is an <div class="article_item"> block ----
H3_RE = re.compile(r'<h3 class="center">(.*?)</h3>', re.S)
ITEM_RE = re.compile(r'<div class="article_item[ "]')
POPUP_RE = re.compile(r'<div class="article_item_popup">.*?<div class="HTMLContainer">(.*?)</div>\s*(?:<a [^>]*></a>\s*)?</div>', re.S)
MAIN_RE = re.compile(r'<div class="HTMLContainer">(.*?)</div>', re.S)
LEVELS = (("باب", 1), ("كتاب", 1), ("جزء", 1), ("فصل", 2), ("قسم", 2), ("فرع", 3))
REPEALED_RE = re.compile(r"(?:ألغيت|أُلغيت|ألغي|أُلغي|ألغاة)\s+هذه\s+المادة|\bمادة ملغاة\b")
ORIG, AMEND = "【النص الأصلي — قبل التعديلات】", "【التعديلات كما وردت في الموقع — المعتمد أحدثها بحسب تاريخ المرسوم؛ وما لم يُعدَّل يبقى من النص الأصلي】"


def html_text(fragment):
    p = TextExtractor()
    p.feed(fragment)
    return p.text()


def parse_articles(page):
    """-> [dict(label, section, body, flag)] from article blocks; [] when the page has none.
    flag: '' | 'amended' (the site marks the block `changed-article`) | 'repealed' (latest amendment repeals it)."""
    heads = [(m.start(), m.end(), html_text(m.group(1)).strip(" :：\n")) for m in H3_RE.finditer(page)]
    items = [m.start() for m in ITEM_RE.finditer(page)]
    out, section, seen = [], {}, {}
    for n, (s, e, label) in enumerate(heads):
        if not re.match(r"^(?:ال)?مادة", label):
            for word, lvl in LEVELS:
                if re.match(rf"^(?:ال)?{word}\b", label):
                    section = {k: v for k, v in section.items() if k < lvl}
                    section[lvl] = label
                    break
            continue
        nxt = [x for x in items if x > e] + ([heads[n + 1][0]] if n + 1 < len(heads) else [len(page)])
        span = page[e:min(nxt)]
        amends = [t for t in (html_text(m.group(1)) for m in POPUP_RE.finditer(span)) if t]
        mm = MAIN_RE.search(POPUP_RE.sub("", span))
        main = html_text(mm.group(1)) if mm else ""
        start = max([x for x in items if x < s] or [0])
        changed = "changed-article" in page[start:start + 120]
        flag = "repealed" if (amends and REPEALED_RE.search(amends[-1][:300])) or REPEALED_RE.search(main[:200]) \
            else "amended" if (changed or amends) else ""
        body = main
        if amends:
            body = (f"{ORIG}\n{main}\n\n" if main else "") + f"{AMEND}\n" + "\n---\n".join(amends)
        sec = " › ".join(section[k] for k in sorted(section))
        if label in seen:  # numbering restarts (e.g. per chapter): keep labels unique
            seen[label] += 1
            label = f"{label} ({sec or seen[label]})"
        else:
            seen[label] = 1
        if body:
            out.append({"label": label, "section": sec, "body": body, "flag": flag})
    return out


def build_articles(page, text):
    """Preamble from the plain text + structured articles; falls back to text splitting if the page has no blocks."""
    arts = parse_articles(page)
    if not arts:
        return [{"label": l, "section": "", "body": b, "flag": ""} for l, b in split_articles(text)]
    pre = split_articles(text)
    head = [{"label": "الديباجة", "section": "", "body": pre[0][1], "flag": ""}] if pre and pre[0][0] == "الديباجة" else []
    return head + arts


def scrape(url, seen, queue, follow_related, raw_html=None, fetched=None):
    lid = law_id(url)
    if lid in seen:
        return []
    seen.add(lid)
    print(f"→ {url}")
    page = raw_html if raw_html is not None else fetch(url)
    p = TextExtractor()
    p.feed(page)
    text = p.text()
    if len(text) < 200:  # site error / empty detail page ("عذراً، لقد حدث خطأ", "التفاصيل")
        seen.discard(lid)
        raise RuntimeError(f"empty or error page ({len(text)} chars)")
    if raw_html is None:  # cache the raw page so parser improvements never need a re-download
        (OUT / "raw").mkdir(parents=True, exist_ok=True)
        (OUT / "raw" / f"{lid}.html.gz").write_bytes(gzip.compress(page.encode("utf-8")))
    status, published = extract_status(text), extract_published(text)
    title = (p.title.split("|")[0].strip() or text.split("\n", 1)[0])[:200]
    kind = "لائحة" if re.search(r"لائح", title) else "نظام"
    if follow_related and raw_html is None:  # implementing regulations etc. are linked from the law page
        for full in [h if h.startswith("http") else BASE + h for h in p.links] + regulation_links(title):
            if law_id(full) not in seen and full not in queue:
                queue.append(full)
    text = re.sub(r"\A(?:\s*" + re.escape(title) + r"\s*\n)+", "", text)  # page repeats the title
    write_md({"id": lid, "title": title, "type": kind, "source": url, "status": status, "published": published,
              "retrieved": fetched or time.strftime("%Y-%m-%d")}, build_articles(page, text))


def write_md(meta, arts):
    status = meta.get("status", "")
    md = [f"---\nid: {meta['id']}\ntitle: {meta['title']}\ntype: {meta['type']}\nsource: {meta['source']}\n"
          f"status: {status}\npublished: {meta.get('published', '')}\nretrieved: {meta.get('retrieved', '')}\n---\n",
          f"# {meta['title']}\n"]
    if status != "ساري":  # make non-binding texts impossible to miss
        md.append(f"> ⚠️ الحالة: {status or 'غير معروفة'} — ليس نظامًا ساريًا؛ لا يُعتمد عليه دون التحقق من المصدر.\n")
    for a in arts:
        head = f"## {a['label']}\n" + (f"§ {a['section']}\n" if a["section"] else "") + (f"⚑ {a['flag']}\n" if a["flag"] else "")
        md.append(f"{head}\n{a['body']}\n")
    (OUT / "laws").mkdir(parents=True, exist_ok=True)
    (OUT / "laws" / f"{meta['id']}.md").write_text("\n".join(md), encoding="utf-8")


def read_md(path):
    """-> (front-matter dict, text after the '# title' line, without the status banner)"""
    _, fm, rest = path.read_text(encoding="utf-8").split("---\n", 2)
    meta = dict(l.split(": ", 1) for l in fm.strip().splitlines() if ": " in l)
    rest = rest.strip().split("\n", 1)[1] if "\n" in rest.strip() else ""
    return meta, re.sub(r"\A\s*> ⚠️[^\n]*\n", "", rest)


def reparse():
    """Offline: rebuild every .md from the cached raw pages (data/raw), no network."""
    n = 0
    for f in sorted((OUT / "raw").glob("*.html.gz")):
        lid = f.name[: -len(".html.gz")]
        fetched = time.strftime("%Y-%m-%d", time.localtime(f.stat().st_mtime))  # when the page was downloaded
        scrape(f"{BASE}/BoeLaws/Laws/LawDetails/{lid}/1", set(), [], False,
               gzip.decompress(f.read_bytes()).decode("utf-8"), fetched)
        n += 1
    return n


def rebuild_jsonl():
    """articles.jsonl is always derived from data/laws/*.md, so partial runs never drop other laws."""
    n = 0
    with open(OUT / "articles.jsonl", "w", encoding="utf-8") as f:
        for path in sorted((OUT / "laws").glob("*.md")):
            meta, rest = read_md(path)
            for blk in re.split(r"^## ", rest, flags=re.M)[1:]:
                label, _, body = blk.partition("\n")
                section = flag = ""
                while body.startswith(("§ ", "⚑ ")):
                    line, _, body = body.partition("\n")
                    if line.startswith("§ "):
                        section = line[2:].strip()
                    else:
                        flag = line[2:].strip()
                f.write(json.dumps({"law_id": meta["id"], "title": meta["title"], "type": meta["type"],
                                    "url": meta["source"], "status": meta.get("status", ""),
                                    "retrieved": meta.get("retrieved", ""), "published": meta.get("published", ""),
                                    "article": label.strip(), "section": section, "flag": flag,
                                    "text": body.strip()}, ensure_ascii=False) + "\n")
                n += 1
    return n


def folder_links(max_folders):
    links = []
    for n in range(1, max_folders + 1):
        try:
            page = fetch(f"{BASE}/BoeLaws/Laws/Folders/{n}")
        except Exception as e:  # noqa: BLE001
            print(f"folder {n}: {e}", file=sys.stderr)
            continue
        links += [BASE + m.group(0) for m in DETAIL_RE.finditer(page)]
    return links


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("urls", nargs="*")
    ap.add_argument("--crawl-folders", type=int, nargs="?", const=30, default=0,
                    help="also scan /Laws/Folders/1..N for law links (default N=30)")
    ap.add_argument("--no-related", action="store_true", help="don't follow linked regulations")
    ap.add_argument("--delay", type=float, default=1.0)
    ap.add_argument("--reparse", action="store_true", help="offline: rebuild .md files from the cached raw pages (data/raw)")
    a = ap.parse_args()
    if a.reparse:
        print(f"reparsed {reparse()} pages; {rebuild_jsonl()} articles")
        return
    queue = a.urls or [l.strip() for l in open(Path(__file__).parent / "urls.txt") if l.strip() and not l.startswith("#")]
    if a.crawl_folders:
        queue += folder_links(a.crawl_folders)
    seen = set()
    while queue:
        url = queue.pop(0)
        try:
            scrape(url, seen, queue, not a.no_related)
        except Exception as e:  # noqa: BLE001
            print(f"FAILED {url}: {e}", file=sys.stderr)
        time.sleep(a.delay)
    OUT.mkdir(exist_ok=True)
    print(f"done: {len(seen)} documents scraped, {rebuild_jsonl()} articles in total → {OUT}")


if __name__ == "__main__":
    main()
