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
ARTICLE_RE = re.compile(r"^\s*(المادة\s+[^\n:：]{1,40}?)\s*[:：]?\s*$|^\s*(المادة\s+\S+(?:\s+\S+){0,3})\s*[:：]", re.M)


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
        return re.sub(r"\n\s*\n+", "\n\n", t).strip()


def law_id(url):
    m = DETAIL_RE.search(url)
    return m.group(1) if m else re.sub(r"\W+", "_", url)[-60:]


def split_articles(text):
    """Return [(article_label, body)]; preamble (decree, title) is article '0'."""
    hits = [(m.start(), (m.group(1) or m.group(2)).strip()) for m in ARTICLE_RE.finditer(text)]
    if not hits:
        return [("النص", text)]
    out = []
    if hits[0][0] > 0:
        out.append(("الديباجة", text[: hits[0][0]].strip()))
    for i, (pos, label) in enumerate(hits):
        end = hits[i + 1][0] if i + 1 < len(hits) else len(text)
        body = text[pos:end].strip()
        body = body[len(label):].lstrip(" :：\n") if body.startswith(label) else body
        out.append((label, body))
    return [(l, b) for l, b in out if b]


def scrape(url, seen, queue, follow_related):
    lid = law_id(url)
    if lid in seen:
        return []
    seen.add(lid)
    print(f"→ {url}")
    p = TextExtractor()
    p.feed(fetch(url))
    text = p.text()
    title = (p.title.split("|")[0].strip() or text.split("\n", 1)[0])[:200]
    kind = "لائحة" if re.search(r"لائح", title) else "نظام"
    if follow_related:  # implementing regulations etc. are linked from the law page
        for href in p.links:
            full = href if href.startswith("http") else BASE + href
            if law_id(full) not in seen:
                queue.append(full)
    arts = split_articles(text)
    (OUT / "laws").mkdir(parents=True, exist_ok=True)
    md = [f"---\nid: {lid}\ntitle: {title}\ntype: {kind}\nsource: {url}\n---\n", f"# {title}\n"]
    md += [f"## {label}\n\n{body}\n" for label, body in arts]
    (OUT / "laws" / f"{lid}.md").write_text("\n".join(md), encoding="utf-8")
    return [{"law_id": lid, "title": title, "type": kind, "url": url, "article": label, "text": body}
            for label, body in arts]


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
    a = ap.parse_args()
    queue = a.urls or [l.strip() for l in open(Path(__file__).parent / "urls.txt") if l.strip() and not l.startswith("#")]
    if a.crawl_folders:
        queue += folder_links(a.crawl_folders)
    seen, rows = set(), []
    while queue:
        url = queue.pop(0)
        try:
            rows += scrape(url, seen, queue, not a.no_related)
        except Exception as e:  # noqa: BLE001
            print(f"FAILED {url}: {e}", file=sys.stderr)
        time.sleep(a.delay)
    OUT.mkdir(exist_ok=True)
    with open(OUT / "articles.jsonl", "w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    print(f"done: {len(seen)} documents, {len(rows)} articles → {OUT}")


if __name__ == "__main__":
    main()
