import json

import pytest

import tgsearch as t


@pytest.fixture
def db(tmp_path):
    export = {"chats": {"list": [
        {"name": "Deals KSA", "type": "public_supergroup", "id": 1, "messages": [
            {"id": 1, "type": "message", "date": "2026-03-01T10:00:00", "from": "Ali",
             "text": "Big Jiddah outlet discount this weekend"},
            {"id": 2, "type": "message", "date": "2026-03-02T10:00:00", "from": "Sara",
             "text": ["Laptop ", {"type": "bold", "text": "8GB"}, " RAM 256 SSD"]},
            {"id": 3, "type": "message", "date": "2026-03-03T10:00:00", "from": "Omar",
             "text": "خصم كبير في جدّة على الاوتلت"},
            {"id": 4, "type": "message", "date": "2026-03-04T10:00:00", "from": "Ali",
             "text": "Phone 8 gb ram, storage 128"},
            {"id": 5, "type": "message", "date": "2026-03-05T10:00:00", "from": "Ali",
             "text": "Riyadh warehouse sale, 16 gb only"},
            {"id": 6, "type": "service", "text": "pinned"},
        ]},
    ]}}
    path = tmp_path / "result.json"
    path.write_text(json.dumps(export, ensure_ascii=False), encoding="utf-8")
    conn = t.connect(tmp_path / "m.db")
    t.import_export(conn, path)
    return conn


def ids(res):
    return sorted(r[5] for _, r in res)


def test_import_skips_service_messages_and_flattens_rich_text(db):
    assert db.execute("SELECT COUNT(*) FROM messages").fetchone()[0] == 5
    assert "8GB" in db.execute("SELECT text FROM messages WHERE msg_id=2").fetchone()[0]


def test_reimport_is_idempotent(db, tmp_path):
    before = db.execute("SELECT COUNT(*), (SELECT COUNT(*) FROM tokens) FROM messages").fetchone()
    t.import_export(db, tmp_path / "result.json")
    assert db.execute("SELECT COUNT(*), (SELECT COUNT(*) FROM tokens) FROM messages").fetchone() == before


def test_spelling_variant_jeddah_finds_jiddah(db):
    assert 1 in ids(t.search(db, "jeddah"))


def test_space_insensitive_units(db):
    assert {2, 4} <= set(ids(t.search(db, "8gb")))
    assert {2, 4} <= set(ids(t.search(db, "8 gb")))
    assert 5 not in ids(t.search(db, "8 gb"))  # 16 gb must not match


def test_arabic_normalization_and_diacritics(db):
    assert 3 in ids(t.search(db, "جده"))  # jeddah without shadda/ta marbuta
    assert 3 in ids(t.search(db, "الأوتلت"))


def test_aliases_cross_language(db, tmp_path):
    aliases = t.load_aliases(t.DEFAULT_ALIASES)
    assert {1, 3} <= set(ids(t.search(db, "jeddah", aliases=aliases)))


def test_all_terms_required_by_default_any_widens(db):
    assert ids(t.search(db, "discount laptop")) == []
    assert {1, 2} <= set(ids(t.search(db, "discount laptop", any_term=True)))


def test_short_terms_are_not_fuzzy(db):
    assert 4 not in ids(t.search(db, "9 gb"))


def test_exact_flag_disables_typos(db):
    assert ids(t.search(db, "jeddah", exact=True)) == []


def test_chat_and_date_filters(db):
    assert ids(t.search(db, "sale", chat="nope")) == []
    assert ids(t.search(db, "gb", since="2026-03-05")) == [5]
