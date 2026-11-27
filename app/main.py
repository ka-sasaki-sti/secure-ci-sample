"""小さな ToDo API。

セキュリティ CI のデモ用なので、アプリ自体は最小限にしている。
ただし「入力をそのまま信じない」「外に出す必要のないものは出さない」は守る。
"""

import os
from itertools import count
from threading import Lock

from fastapi import FastAPI, HTTPException, Request, Response
from pydantic import BaseModel, ConfigDict, Field

# API ドキュメント（/docs, /redoc, /openapi.json）は既定で無効。
# 本番で内部情報を露出させないため、明示的に有効化したときだけ出す。
_docs_enabled = os.getenv("ENABLE_DOCS") == "1"

app = FastAPI(
    title="secure-ci-sample",
    docs_url="/docs" if _docs_enabled else None,
    redoc_url="/redoc" if _docs_enabled else None,
    openapi_url="/openapi.json" if _docs_enabled else None,
)


@app.middleware("http")
async def security_headers(request: Request, call_next) -> Response:
    response = await call_next(request)
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["Referrer-Policy"] = "no-referrer"
    response.headers["Content-Security-Policy"] = (
        "default-src 'none'; frame-ancestors 'none'"
    )
    response.headers["Cache-Control"] = "no-store"
    response.headers["Cross-Origin-Resource-Policy"] = "same-origin"
    response.headers["Permissions-Policy"] = "geolocation=(), camera=(), microphone=()"
    return response


class TodoIn(BaseModel):
    # 未知のフィールドは受け付けない。型・長さもスキーマで固定する
    model_config = ConfigDict(extra="forbid")

    title: str = Field(min_length=1, max_length=200)
    done: bool = False


class Todo(TodoIn):
    id: int


_todos: dict[int, Todo] = {}
_ids = count(1)
_lock = Lock()
MAX_TODOS = 1000


@app.get("/healthz")
def healthz() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/todos")
def list_todos() -> list[Todo]:
    return list(_todos.values())


@app.post("/todos", status_code=201)
def create_todo(todo: TodoIn) -> Todo:
    with _lock:
        if len(_todos) >= MAX_TODOS:
            raise HTTPException(status_code=429, detail="too many todos")
        created = Todo(id=next(_ids), **todo.model_dump())
        _todos[created.id] = created
    return created


@app.get("/todos/{todo_id}")
def get_todo(todo_id: int) -> Todo:
    if todo_id not in _todos:
        raise HTTPException(status_code=404, detail="not found")
    return _todos[todo_id]


@app.put("/todos/{todo_id}")
def update_todo(todo_id: int, todo: TodoIn) -> Todo:
    with _lock:
        if todo_id not in _todos:
            raise HTTPException(status_code=404, detail="not found")
        updated = Todo(id=todo_id, **todo.model_dump())
        _todos[todo_id] = updated
    return updated


@app.delete("/todos/{todo_id}", status_code=204)
def delete_todo(todo_id: int) -> None:
    with _lock:
        if _todos.pop(todo_id, None) is None:
            raise HTTPException(status_code=404, detail="not found")


# --- デモ: CI に止められるべきコード（マージしない） ---
import pickle

import yaml


@app.post("/import")
async def import_todos(request: Request) -> dict[str, int]:
    body = await request.body()
    if request.headers.get("content-type") == "application/yaml":
        data = yaml.load(body)  # 任意オブジェクトを復元できる
    else:
        data = pickle.loads(
            body
        )  # 外部入力をそのまま復元する（Apache Axis / Puppet と同じ型の事故）
    return {"imported": len(data)}
