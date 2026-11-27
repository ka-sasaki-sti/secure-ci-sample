from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_healthz():
    res = client.get("/healthz")
    assert res.status_code == 200
    assert res.json() == {"status": "ok"}


def test_crud():
    created = client.post("/todos", json={"title": "write blog"})
    assert created.status_code == 201
    todo_id = created.json()["id"]

    assert client.get(f"/todos/{todo_id}").json()["title"] == "write blog"

    updated = client.put(
        f"/todos/{todo_id}", json={"title": "write blog", "done": True}
    )
    assert updated.json()["done"] is True

    assert client.delete(f"/todos/{todo_id}").status_code == 204
    assert client.get(f"/todos/{todo_id}").status_code == 404


def test_rejects_unknown_fields():
    # 想定外のフィールドを黙って受け取らない
    res = client.post("/todos", json={"title": "x", "is_admin": True})
    assert res.status_code == 422


def test_rejects_too_long_title():
    res = client.post("/todos", json={"title": "a" * 201})
    assert res.status_code == 422


def test_docs_are_disabled_by_default():
    for path in ("/docs", "/redoc", "/openapi.json"):
        assert client.get(path).status_code == 404


def test_security_headers():
    res = client.get("/healthz")
    assert res.headers["X-Content-Type-Options"] == "nosniff"
    assert res.headers["X-Frame-Options"] == "DENY"
    assert "default-src 'none'" in res.headers["Content-Security-Policy"]
