# Research brief: existing solutions for Arabic / Saudi legal retrieval (web research, report only)

## 1. Objective
We are building a local, token-efficient knowledge base of Saudi laws (from laws.boe.gov.sa) for a lawyer-assistant AI.
Before we build more ourselves, find what ALREADY exists so we do not reinvent the wheel. We need retrieval that works by
meaning (dialects, typos, formal/classical Arabic), runs locally on CPU (12 threads, no GPU), Python, license must allow
commercial use.

## 2. What to find (answer each with 2-5 concrete items; each with URL + license + one line on why it matters)
1. Best open **embedding models for Arabic retrieval** and their benchmark evidence (MTEB Arabic / ArabicMTEB, MIRACL-ar,
   any Arabic legal retrieval benchmark). Compare: multilingual-e5-large (what we use), bge-m3, any Arabic-specific models
   (e.g. Arabic-trained BERT/sentence models, GATE-AraBERT, Arabic Matryoshka embeddings, etc.). Which are CPU-feasible and
   commercially licensed?
2. Open **rerankers** (cross-encoders) good for Arabic, CPU-feasible, commercial license (e.g. bge-reranker-v2-m3 and others).
3. Existing **Saudi / Arabic legal datasets, corpora, benchmarks or RAG projects** on GitHub / Hugging Face (e.g. Saudi law
   datasets, Arabic legal QA, "SaudiLaws", legal RAG repos, MCP servers for Saudi/Arabic law). Note license and whether
   we could reuse data/ideas, and any known pitfalls.
4. Known techniques/papers for **dialect-robust retrieval** in Arabic: dialect to MSA normalization tools (CAMeL Tools,
   Farasa, etc.), query rewriting, doc2query/synthetic queries for Arabic legal text. What worked, with evidence.
5. Libraries that already implement what we hand-wrote: hybrid BM25 + dense with fusion, Arabic stemming/normalization
   (e.g. CAMeL Tools, qalsadi, pyarabic), local vector search (e.g. sqlite-vec, LanceDB, Qdrant local). Which are simple to
   install on Windows / Python 3.14 (or 3.12) and reliable?

## 3. Output
Markdown at `C:\AI-Work\Rep\saudi-laws\research_findings.md`, max ~700 words: one section per question, bullets with
URL + license + one-line takeaway, then a final "Top 5 things worth adopting, ranked" list. Mark anything you could not
verify as UNVERIFIED. Quote nothing long; summarize.

## 4. Sources and boundaries
Public web only (Hugging Face model cards, GitHub READMEs, arXiv, official docs). Do not invent benchmark numbers: only
report numbers you actually saw on a page, with the URL. Read-only except writing the findings file. No downloads or installs.

## 5. Done criteria
Every item has a working URL you opened; license stated; uncertain claims labeled UNVERIFIED.
