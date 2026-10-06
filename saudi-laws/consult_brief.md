# Consultation brief: reliable meaning-based retrieval for Saudi laws (read-only advice)

## 1. Objective
Basem is building a **lawyer-assistant AI** to be sold to a law firm. A human lawyer will review its output, but retrieval
must be **watertight**: the assistant must find the right article of the right Saudi law/regulation even when the user's
wording does not match the statute (dialects, colloquial speech, typos, formal/classical/Quranic-style fiqh vocabulary).
Give concrete, prioritized advice. Do not write code into the repo; reply with advice only.

## 2. Inputs (read these)
- `C:\AI-Work\Rep\saudi-laws\README.md` : architecture summary
- `C:\AI-Work\Rep\saudi-laws\kb.py` : search (SQLite FTS5 BM25 + thesaurus + multi-query + e5 dense fusion), MCP server
- `C:\AI-Work\Rep\saudi-laws\scrape.py` : scraper (laws.boe.gov.sa) and article splitting
- `C:\AI-Work\Rep\saudi-laws\thesaurus.json` : everyday -> statutory term expansion (query side)
- `C:\AI-Work\Rep\saudi-laws\eval2.py`, `eval3.py` : colloquial/typo test questions (eval3 = holdout)
- `C:\AI-Work\Rep\CLAUDE.md` : rules the AI follows when answering
- Facts: 515 documents (laws + regulations), 16,896 articles, 19.6k passages. Local CPU only (12 threads, no GPU).
  Dense model: `intfloat/multilingual-e5-large` via fastembed/onnx (embedding of all passages in progress, ~hours, one-time).
  Query-time cost must stay low (tokens and latency). Python stdlib + venv with fastembed/numpy is acceptable.
  Current measured recall in top 5: keyword+thesaurus only = 25/34 (eval2, partly tuned) and 10/25 (eval3 holdout).

## 3. Questions
A. **Dialects.** Saudi users speak Najdi, Hijazi, Gulf, southern (and some Egyptian/Levantine), plus formal MSA and
   classical/Quranic fiqh vocabulary (personal status). Recommend the most effective ways to bridge dialect -> statute
   vocabulary in a retrieval system (e.g. query rewriting by the LLM, dialect-normalization rules, dialect->MSA
   lexicons, which embedding models handle Arabic dialects best, fine-tuning/synthetic query generation). Give specific
   dialect words/patterns I should cover and what to avoid.
B. **Retrieval architecture.** Is dense + BM25 + RRF + multi-query the right design? What else gives the biggest gain for
   Arabic legal text: reranker (which model, CPU-feasible?), better chunking (article-level vs passage, include law title,
   regulation <-> law linking, cross-references), doc2query / synthetic questions per article (HyDE), Arabic stemming/
   root matching, bge-m3 or jina-v3 instead of e5-large, etc. Rank by impact vs effort.
C. **Evaluation.** How should I build a trustworthy evaluation set (size, how to label, metrics like recall@k / MRR,
   avoiding tuning on the test set) so I can claim reliability to a law firm?
D. **Failure modes and safeguards.** What can still go wrong (wrong amended version, superseded law, article numbering,
   missing regulation, truncation, hallucinated citations) and what guardrails/checks should the system and the answering
   prompt (`CLAUDE.md`) include? Anything in `kb.py` / `scrape.py` that looks wrong or risky?
E. **Anything else** you would do differently for a product sold to a law firm (audit trail, citation verification,
   update process, Arabic/English, confidentiality).

## 4. Output format
A single Markdown reply: (1) top 10 recommendations ranked by impact/effort with a one-line "why", (2) answers to A-E
(brief, specific), (3) a list of concrete bugs/risks you spotted in the files with file:line. Max ~900 words.

## 5. Allowed sources
The files above, plus public web sources if useful (cite URLs; do not invent facts or model benchmarks).

## 6. Boundaries
Read-only. Do not modify files. Do not contact anything except public web pages. No credentials involved.

## 7. Done criteria
Advice is concrete (names models/techniques/dialect examples), prioritized, and flags uncertainty where you are unsure.
