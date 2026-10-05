"""Spot-check the index against the live pages (independent HTML->text, no scraper code).  python3 verify.py [N]"""
import html, random, re, sqlite3, sys, time
import kb, scrape

def live_text(url):
    h = scrape.fetch(url)
    h = re.sub(r"(?is)<(script|style)\b.*?</\1>", " ", h)
    t = html.unescape(re.sub(r"<[^>]+>", " ", h)).replace("\xa0", " ")
    return re.sub(r"\s+", " ", kb.norm(t))

def squash(s):
    return re.sub(r"\s+", " ", kb.norm(s)).strip()

def main(n=30, seed=7):
    random.seed(seed)
    c = sqlite3.connect(kb.db_path())
    laws = c.execute("SELECT law_id, url, title FROM articles GROUP BY law_id").fetchall()
    laws = random.sample(laws, min(n, len(laws)))
    bad = ok = 0
    for lid, url, title in laws:
        arts = c.execute("SELECT article, text FROM articles WHERE law_id=? AND length(text)>150", (lid,)).fetchall()
        if not arts:
            continue
        page = live_text(url)
        for label, text in random.sample(arts, min(2, len(arts))):
            t = squash(text)
            head, tail = t[:100], t[-60:]
            good = head in page and tail in page
            ok += good
            bad += not good
            if not good:
                print(f"MISMATCH {title[:40]} | {label[:30]} | head_ok={head in page} tail_ok={tail in page}")
        time.sleep(0.5)
    print(f"verified {ok}/{ok + bad} sampled articles ({len(laws)} laws) against the live pages")

if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else 30)
