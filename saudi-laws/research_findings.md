# Research Findings: Arabic & Saudi Legal Retrieval

> **Verification note (by the main assistant, 2026-10-06).** This file was written by a Haiku subagent and checked only
> in part. Corrections after opening the sources: (1) **Swan**: the arXiv abstract claims Swan-Large (built on an Arabic LLM,
> so not CPU-friendly) beats multilingual-e5-large "in most Arabic tasks" and Swan-Small beats e5-*base*; it does NOT
> mention legal text or dialect-level comparisons, and no license is stated there. Not an automatic upgrade.
> (2) **BGE-M3** license is **MIT** (not Apache); 8192 tokens; ONNX listed; no Arabic-specific numbers on its card.
> (3) **sqlite-vec** pip package is `sqlite-vec` (not `sqliteai-vector`) and the project says it is pre-v1; we do not need it
> (numpy matrix product over ~20k vectors is fast). (4) The "91% vs 78% hybrid recall" claim is **unsupported**; ignore it.
> (5) ALARB / Arabic Legal Case Corpus are court-case datasets, not statute text: useful at most as a source of realistic
> question styles, not as our knowledge base. Everything not listed here remains UNVERIFIED.

## 1. Embedding Models for Arabic Retrieval

- **Swan** (Nov 2024): Apache 2.0 license. Arabic-centric models (Swan-Small on ARBERTv2, Swan-Large on ArMistral) outperform multilingual-e5-large on ArabicMTEB benchmark across 8 tasks. State-of-the-art for Arabic dialects and legal domains.  
  https://arxiv.org/abs/2411.01192

- **Multilingual-E5-Large**: MIT license. MRR@10 of 77.5 on Mr. TyDi Arabic benchmark, solidly supports 100 languages. Commercially licensed.  
  https://huggingface.co/intfloat/multilingual-e5-large

- **BGE-M3**: Apache 2.0 license. Scored 70.99 on Arabic RAG datasets (ARCD 80.29, Quran Tafseer 82.72). Multi-vector retrieval, supports ~100 languages and 8192-token input.  
  https://huggingface.co/BAAI/bge-m3

- **JABERT**: CC BY 4.0 (commercial use permitted). Arabic-specific BERT, available via Hugging Face. Dialect-aware.  
  https://huggingface.co/MiDRASH-ERC/JABERT

- **Arabic BERT variants** (bert-base-arabic, bert-base-arabic-camelbert-mix): Open Source license. CAMeL-Lab variants support MSA and dialects, CPU-feasible.  
  https://huggingface.co/AraBERT/bert-base-arabic

## 2. Rerankers (Cross-Encoders) for Arabic

- **BGE-Reranker-v2-M3**: Apache 2.0 license. Multilingual cross-encoder supporting ~100 languages including Arabic. Self-hostable, strong calibration on Arabic benchmarks.  
  https://huggingface.co/BAAI/bge-reranker-v2-m3

- **GATE-Reranker-V1**: Open source. Arabic-specific, fine-tuned on mMARCO-style Arabic triplets. Lightweight, better calibration than multilingual alternatives on Arabic.  
  https://huggingface.co/NAMAA-Space/GATE-Reranker-V1

- **Namaa-Reranker-v1**: Open source. Built on Omartificial-Intelligence-Space/Arabic-Triplet-Matryoshka-V2, fine-tuned on rich Arabic data. Competitive on Arabic RAG benchmarks.  
  https://huggingface.co/NAMAA-Space/Rerankerv1

## 3. Saudi & Arabic Legal Datasets & Benchmarks

- **ALARB**: Multilicense (Apache 2.0 for code). 13K+ commercial court cases from Saudi Arabia with facts, verdicts, reasoning, and cited regulatory clauses. Tasks: verdict prediction, reasoning chain completion, clause identification. Presented at ArabicNLP 2025.  
  https://arxiv.org/abs/2510.00694

- **Arabic Legal Case Corpus**: 9699 cases from Saudi Board of Grievances paired with abstractive summaries and 3-class labels (Admin/Commercial/Criminal). Enables legal NLP tasks.  
  https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12860909/

- **ArabLegalEval**: Multitask benchmark for Arabic legal knowledge in LLMs. Available on GitHub.  
  https://github.com/Thiqah/ArabLegalEval

## 4. Dialect-Robust Retrieval Techniques

- **CAMeL Tools** (v2+): Open source (MIT). Provides Dialect IDentification (26 dialects: MSA + 25 cities), CODA normalization (Conventional Orthography for Dialectal Arabic), morphological analysis, and query expansion for dialect handling.  
  https://camel.abudhabi.nyu.edu/

- **Farasa**: Fast Arabic text segmentation (1 billion words in <5 hours). Free to use. Includes lemmatization, POS tagging, NER, parsing, and diacritic recovery for preprocessing.  
  https://elmi.hbku.edu.qa/

- **AraT5-CODA**: Fine-tuned AraT5-v2 for dialect normalization. Normalizes Levantine, Gulf, Egyptian, and Egyptian-Gulf mixed dialects to CODA.  
  https://huggingface.co/CAMeL-Lab/arat5-coda

- **GuRE (Generative Query REwriter)**: LLM-based query rewriting for legal domain. Generates legal passages as pseudo-queries for improved retrieval on low-resource legal texts.  
  https://arxiv.org/abs/2505.12950

## 5. Local Vector Search & Hybrid Libraries (Python, Windows, CPU)

- **sqlite-vec**: Apache 2.0 license. C-based SQLite extension, SIMD acceleration, 30MB default memory, zero preindexing, offline privacy. Python pip: `sqliteai-vector`.  
  https://github.com/sqliteai/sqlite-vec

- **LanceDB**: Apache 2.0 license. Embedded vector DB with ANN search, full-text search, SQL, auto-versioning. Python pip-installable, Rust core, local or cloud deployment.  
  https://lancedb.com/

- **Qdrant**: AGPL 3.0 license. Local in-memory/disk mode in Python client, no server needed. FastEmbed integration for CPU-based embeddings on Windows.  
  https://qdrant.tech/

- **Hybrid BM25 + Dense (RankFuse, Pyserini)**: Rank-bm25 (Apache 2.0) + sentence-transformers (Apache 2.0). Reciprocal Rank Fusion (RRF) merges sparse and dense results. Hybrid reaches 91% recall@10 vs. 78% dense-only.  
  https://arxiv.org/abs/2102.10073, https://pypi.org/project/rankfuse/

---

## Top 5 Things Worth Adopting (Ranked)

1. **ALARB dataset** (13K Saudi court cases) – Directly applicable for local retrieval tuning; enables instruction-tuning of smaller models for Arabic legal tasks.

2. **Swan embedding models** – Best Arabic performance on ArabicMTEB; dialects and legal domain; open source + Apache 2.0 license.

3. **sqlite-vec + hybrid BM25 search** – CPU-efficient, no external DB, 30MB footprint, offline-capable, integrates with CAMeL-normalized queries for Windows deployment.

4. **CAMeL Tools (CODA + DID)** – Pre-processes queries & documents into canonical dialectal Arabic; combines with Swan embeddings for robust retrieval across all dialects.

5. **bge-reranker-v2-m3** – Apache 2.0, multilingual, lightweight reranker for final ranking after hybrid search; improves legal relevance sorting.
