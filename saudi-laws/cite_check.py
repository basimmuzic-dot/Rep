"""Citation checker: every «quoted passage» in an answer must appear in the knowledge base.   python cite_check.py report.md
Quotes are matched after Arabic normalization, ignoring spaces/punctuation, and may be split by '…' (each piece is checked)."""
import re, sqlite3, sys
import kb


def flat(s):
    return re.sub(r"[\s\W_]+", "", kb.norm(s))


def main(path):
    db = sqlite3.connect(kb.db_path())
    corpus = "".join(flat(t) for (t,) in db.execute("SELECT text FROM articles"))
    text = open(path, encoding="utf-8").read()
    ok = bad = 0
    for q in re.findall(r"«([^»]{12,})»", text):
        for piece in (p for p in re.split(r"…|\.\.\.", q) if len(flat(p)) >= 10):
            if flat(piece) in corpus:
                ok += 1
            else:
                bad += 1
                print("NOT FOUND:", piece.strip()[:90])
    print(f"{ok} quoted passages found in the knowledge base, {bad} not found")


if __name__ == "__main__":
    main(sys.argv[1])
