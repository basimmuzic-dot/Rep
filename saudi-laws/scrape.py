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
import argparse, html, json, re, sys, time, urllib.request
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


def split_articles(text):
    """Return [(article_label, body)]; preamble (decree, title) is article '0'."""
    hits = [(m.start(), (m.group(1) or m.group(2)).strip()) for m in ARTICLE_RE.finditer(text)]
    if not hits:  # no articles (regulations, rules): chunk by paragraph so search returns small pieces
        chunks, cur = [], ""
        for para in (p for p in text.split("\n") if p.strip()):
            if cur and len(cur) + len(para) > 1500:
                chunks.append(cur)
                cur = ""
            cur += ("\n" if cur else "") + para
        if cur:
            chunks.append(cur)
        return [(f"النص ({i})", c) for i, c in enumerate(chunks, 1)] if len(chunks) > 1 else [("النص", text)]
    out = []
    if hits[0][0] > 0:
        out.append(("الديباجة", text[: hits[0][0]].strip()))
    for i, (pos, label) in enumerate(hits):
        end = hits[i + 1][0] if i + 1 < len(hits) else len(text)
        body = text[pos:end].strip()
        body = body[len(label):].lstrip(" :：\n") if body.startswith(label) else body
        out.append((label, body))
    merged = {}  # amendment history repeats the article heading: keep one heading per article
    for l, b in out:
        if b:
            merged[l] = merged[l] + "\n\n" + b if l in merged else b
    return list(merged.items())


def scrape(url, seen, queue, follow_related):
    lid = law_id(url)
    if lid in seen:
        return []
    seen.add(lid)
    print(f"→ {url}")
    p = TextExtractor()
    p.feed(fetch(url))
    text = p.text()
    if len(text) < 200:  # site error / empty detail page ("عذراً، لقد حدث خطأ", "التفاصيل")
        seen.discard(lid)
        raise RuntimeError(f"empty or error page ({len(text)} chars)")
    status = extract_status(text)
    title = (p.title.split("|")[0].strip() or text.split("\n", 1)[0])[:200]
    kind = "لائحة" if re.search(r"لائح", title) else "نظام"
    if follow_related:  # implementing regulations etc. are linked from the law page
        for full in [h if h.startswith("http") else BASE + h for h in p.links] + regulation_links(title):
            if law_id(full) not in seen and full not in queue:
                queue.append(full)
    text = re.sub(r"\A(?:\s*" + re.escape(title) + r"\s*\n)+", "", text)  # page repeats the title
    arts = split_articles(text)
    (OUT / "laws").mkdir(parents=True, exist_ok=True)
    write_md({"id": lid, "title": title, "type": kind, "source": url, "status": status,
              "retrieved": time.strftime("%Y-%m-%d")}, arts)


def write_md(meta, arts):
    status = meta.get("status", "")
    md = [f"---\nid: {meta['id']}\ntitle: {meta['title']}\ntype: {meta['type']}\nsource: {meta['source']}\n"
          f"status: {status}\nretrieved: {meta.get('retrieved', '')}\n---\n", f"# {meta['title']}\n"]
    if status != "ساري":  # make non-binding texts impossible to miss
        md.append(f"> ⚠️ الحالة: {status or 'غير معروفة'} — ليس نظامًا ساريًا؛ لا يُعتمد عليه دون التحقق من المصدر.\n")
    md += [f"## {label}\n\n{body}\n" for label, body in arts]
    (OUT / "laws").mkdir(parents=True, exist_ok=True)
    (OUT / "laws" / f"{meta['id']}.md").write_text("\n".join(md), encoding="utf-8")


def read_md(path):
    """-> (front-matter dict, text after the '# title' line)"""
    _, fm, rest = path.read_text(encoding="utf-8").split("---\n", 2)
    meta = dict(l.split(": ", 1) for l in fm.strip().splitlines() if ": " in l)
    rest = rest.strip().split("\n", 1)[1] if "\n" in rest.strip() else ""
    return meta, re.sub(r"\A\s*> ⚠️[^\n]*\n", "", rest)  # drop the status banner


def resplit():
    """Offline: re-run article splitting over the saved .md files (no network)."""
    for path in sorted((OUT / "laws").glob("*.md")):
        meta, rest = read_md(path)
        if not meta.get("status"):  # files saved before status was captured: it is in the page header text
            meta["status"] = extract_status(rest)
            meta["retrieved"] = time.strftime("%Y-%m-%d", time.localtime(path.stat().st_mtime))
        rest = re.sub(r"^## (?:النص(?: \(\d+\))?|الديباجة)[ \t]*$", "", rest, flags=re.M)  # synthetic headings
        rest = re.sub(r"^## ", "", rest, flags=re.M)  # real article headings become heading lines again
        rest = "\n".join(l for l in rest.split("\n") if not NOISE_RE.match(l.strip()))
        write_md(meta, split_articles(rest.strip()))


def rebuild_jsonl():
    """articles.jsonl is always derived from data/laws/*.md, so partial runs never drop other laws."""
    n = 0
    with open(OUT / "articles.jsonl", "w", encoding="utf-8") as f:
        for path in sorted((OUT / "laws").glob("*.md")):
            meta, rest = read_md(path)
            for blk in re.split(r"^## ", rest, flags=re.M)[1:]:
                label, _, body = blk.partition("\n")
                f.write(json.dumps({"law_id": meta["id"], "title": meta["title"], "type": meta["type"],
                                    "url": meta["source"], "status": meta.get("status", ""),
                                    "retrieved": meta.get("retrieved", ""),
                                    "article": label.strip(), "text": body.strip()},
                                   ensure_ascii=False) + "\n")
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
    ap.add_argument("--resplit", action="store_true", help="offline: re-split saved .md files, rebuild articles.jsonl")
    a = ap.parse_args()
    if a.resplit:
        resplit()
        print(f"resplit done: {rebuild_jsonl()} articles")
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
