"""Build semantic (dense) vectors for every article passage.  Run with the venv python:

    .venv/Scripts/python embed.py            # resumable; checkpoints in data/emb/
    .venv/Scripts/python embed.py --limit 500   # quick test

Output: data/embeddings.npy (float16, L2-normalised) + data/embeddings.keys.json ([law_id, article, part] per row).
Runs once (and again only after the laws change). Queries are embedded at search time by kb.py.
"""
import argparse, json, os, sys, time
from pathlib import Path

import numpy as np

DATA = Path(__file__).parent / "data"
MODEL = "intfloat/multilingual-e5-large"
WINDOW = 1200  # characters per passage (about 300-400 tokens)


def passages():
    """[(key, text)] — long articles are split on line boundaries; every passage carries the law + article name."""
    out = []
    for line in open(DATA / "articles.jsonl", encoding="utf-8"):
        r = json.loads(line)
        head = f"{r['title']} | {r.get('section', '')} | {r['article']}\n"
        parts, cur = [], ""
        for para in r["text"].split("\n"):
            if cur and len(cur) + len(para) > WINDOW:
                parts.append(cur)
                cur = ""
            cur += ("\n" if cur else "") + para
            while len(cur) > WINDOW * 1.5:  # one huge paragraph
                parts.append(cur[:WINDOW])
                cur = cur[WINDOW:]
        parts.append(cur)
        for i, p in enumerate(parts):
            out.append(([r["law_id"], r["article"], i], "passage: " + head + p))
    return out


def cards():
    """One short 'card' per law for routing a question to the right law: title + the official summary + chapter headings."""
    laws = {}
    for line in open(DATA / "articles.jsonl", encoding="utf-8"):
        r = json.loads(line)
        c = laws.setdefault(r["law_id"], {"title": r["title"], "pre": "", "secs": []})
        if r["article"] == "الديباجة":
            c["pre"] = r["text"][:700]
        if r.get("section"):
            for s in r["section"].split(" › "):
                if s not in c["secs"] and len(c["secs"]) < 14:
                    c["secs"].append(s)
    return [(lid, "passage: " + c["title"] + "\n" + c["pre"] + "\n" + " | ".join(c["secs"])) for lid, c in laws.items()]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--batch", type=int, default=16)
    ap.add_argument("--cards", action="store_true", help="embed one routing card per law (fast, ~5 min)")
    a = ap.parse_args()
    from fastembed import TextEmbedding

    if a.cards:
        cs = cards()
        model = TextEmbedding(MODEL, threads=os.cpu_count())
        vec = np.array(list(model.embed([t for _, t in cs], batch_size=a.batch)), dtype=np.float32)
        vec = (vec / np.linalg.norm(vec, axis=1, keepdims=True)).astype(np.float16)
        np.save(DATA / "lawcards.npy", vec)
        (DATA / "lawcards.keys.json").write_text(json.dumps([k for k, _ in cs]), encoding="utf-8")
        print("saved", vec.shape, flush=True)
        return

    items = passages()
    if a.limit:
        items = items[: a.limit]
    order = sorted(range(len(items)), key=lambda i: len(items[i][1]))  # similar lengths per batch = little padding
    ck = DATA / "emb"
    ck.mkdir(exist_ok=True)
    done = {}
    for f in sorted(ck.glob("part-*.npz")):
        z = np.load(f)
        for i, v in zip(z["idx"], z["vec"]):
            done[int(i)] = v
    todo = [i for i in order if i not in done]
    print(f"{len(items)} passages, {len(done)} already done, {len(todo)} to go", flush=True)
    model = TextEmbedding(MODEL, threads=os.cpu_count())
    t0, n, CH = time.time(), 0, 512
    for s in range(0, len(todo), CH):
        idx = todo[s : s + CH]
        vec = np.array(list(model.embed([items[i][1] for i in idx], batch_size=a.batch)), dtype=np.float16)
        np.savez(ck / f"part-{len(done) + n:06d}.npz", idx=np.array(idx), vec=vec)
        for i, v in zip(idx, vec):
            done[i] = v
        n += len(idx)
        rate = n / (time.time() - t0)
        print(f"{len(done)}/{len(items)}  {rate:.1f}/s  eta {int((len(todo) - n) / rate / 60)} min", flush=True)
    mat = np.stack([done[i] for i in range(len(items))])
    mat = (mat / np.linalg.norm(mat.astype(np.float32), axis=1, keepdims=True)).astype(np.float16)
    np.save(DATA / "embeddings.npy", mat)
    (DATA / "embeddings.keys.json").write_text(json.dumps([k for k, _ in items], ensure_ascii=False), encoding="utf-8")
    print("saved", mat.shape, flush=True)


if __name__ == "__main__":
    main()
