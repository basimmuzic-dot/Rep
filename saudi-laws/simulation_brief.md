# Brief: act as the lawyer-assistant (instruction-following test)

## 1. Objective
You are the Saudi-law assistant described in `C:\AI-Work\Rep\CLAUDE.md`. Read it first and follow it exactly.
Answer the 4 questions below for a human lawyer who will review your work.

## 2. Tools
The MCP tools are not available in this test; use the identical functions through the shell (working dir `C:\AI-Work\Rep`):

    python saudi-laws/kb.py call search_saudi_laws '{"query": "...", "queries": ["...", "..."], "k": 8}'
    python saudi-laws/kb.py call get_saudi_law_article '{"id": 123}'
    python saudi-laws/kb.py call get_saudi_law_article '{"law": "نظام العمل", "article": "المادة الأولى"}'
    python saudi-laws/kb.py call list_saudi_laws '{"title_contains": "..."}'

Optional fields: `law` (title filter), `include_inactive` (true/false). Output is JSON (Arabic, UTF-8).
Run each command with Bash. On Windows quote the JSON with single quotes as shown. If Arabic output looks garbled, run
with `PYTHONIOENCODING=utf-8` set.

## 3. Questions (answer each separately)
1. موظف في شركة خاصة فصلوه بدون إنذار ولا مكافأة، وش حقوقه؟
2. هل يجوز لصاحب العمل إنهاء عقد العامل لأنه بلغ سن التقاعد؟ وما سن التقاعد المعتمد؟
3. كيف يتم بيع الأموال المحجوزة للمدين في المزاد حتى يسدد الدين؟
4. ما المبدأ القضائي المستقر لمحاكم الاستئناف في تقدير التعويض عن الضرر المعنوي؟

## 4. Output
Write your final report to `C:\AI-Work\Rep\saudi-laws\simulation_report.md` containing, per question:
(a) the answer exactly as you would give it to the lawyer, following the CLAUDE.md answer rules;
(b) an audit list: every tool call you made (tool + arguments) in order.
Max ~1000 words total. Do not modify any other file.

## 5. Boundaries
Read-only except the report. Use only the knowledge base for legal content; if something is not in it, say so.

## 6. Done criteria
All 4 questions answered with citations per CLAUDE.md, plus the audit list.
