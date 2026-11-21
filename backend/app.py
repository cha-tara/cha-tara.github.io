import hashlib
import json
import os
import re
import secrets
import time
import urllib.request
import urllib.error
from collections import OrderedDict
import sqlite3
from contextlib import asynccontextmanager, closing, contextmanager
from datetime import UTC, datetime
from pathlib import Path
from threading import BoundedSemaphore, Lock
from typing import Annotated

from fastapi import FastAPI, Header, HTTPException, Query, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from starlette.responses import JSONResponse
from pydantic import BaseModel, Field, StringConstraints

database = Path(os.getenv("CHA_TARA_DB", "cha-tara.sqlite3"))


@contextmanager
def connect():
    with closing(sqlite3.connect(database)) as db, db:
        db.row_factory = sqlite3.Row
        yield db


@asynccontextmanager
async def lifespan(_app):
    database.parent.mkdir(parents=True, exist_ok=True)
    with connect() as db:
        db.execute("PRAGMA journal_mode=WAL")
        db.executescript("""
            CREATE TABLE IF NOT EXISTS accounts (
                id TEXT PRIMARY KEY,
                login TEXT NOT NULL UNIQUE,
                name TEXT NOT NULL,
                salt BLOB NOT NULL,
                password_hash BLOB NOT NULL
            );
            CREATE TABLE IF NOT EXISTS sessions (
                token_hash TEXT PRIMARY KEY,
                account_id TEXT NOT NULL,
                expires_at INTEGER NOT NULL
            );
            CREATE INDEX IF NOT EXISTS sessions_expiry ON sessions(expires_at);
            CREATE TABLE IF NOT EXISTS posts (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                author_id TEXT NOT NULL,
                request_id TEXT NOT NULL,
                name TEXT NOT NULL,
                tea TEXT NOT NULL,
                notes TEXT NOT NULL,
                descriptors TEXT NOT NULL,
                created_at TEXT NOT NULL,
                UNIQUE(author_id, request_id)
            );
            CREATE INDEX IF NOT EXISTS posts_author ON posts(author_id, id);
            CREATE TABLE IF NOT EXISTS follows (
                reader TEXT NOT NULL,
                author TEXT NOT NULL,
                PRIMARY KEY (reader, author)
            );
        """)
    yield


class LimitRequestBody:
    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http" or scope["method"] not in ("POST", "PUT"):
            await self.app(scope, receive, send)
            return
        limit = 2048 if scope["path"].startswith("/v1/auth/") else 256 * 1024
        body = bytearray()
        while True:
            message = await receive()
            if message["type"] == "http.disconnect":
                return
            chunk = message.get("body", b"")
            if len(body) + len(chunk) > limit:
                await JSONResponse({"detail": "Request too large"}, status_code=413)(
                    scope, receive, send
                )
                return
            body.extend(chunk)
            if not message.get("more_body", False):
                break

        async def receive_body():
            return {"type": "http.request", "body": bytes(body), "more_body": False}

        await self.app(scope, receive_body, send)


app = FastAPI(title="Cha Tara", lifespan=lifespan, docs_url=None, redoc_url=None)
app.add_middleware(LimitRequestBody)
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("CHA_TARA_ORIGINS", "https://cha-tara.github.io").split(","),
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)


class Post(BaseModel):
    request_id: Annotated[str, StringConstraints(pattern=r"^[0-9a-f]{32}$")]
    tea: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)]
    notes: Annotated[str, StringConstraints(strip_whitespace=True, max_length=2000)] = ""
    descriptors: list[Annotated[str, StringConstraints(max_length=140)]] = Field(
        default_factory=list, max_length=1800
    )


Authorization = Annotated[str | None, Header()]


class Credentials(BaseModel):
    login: Annotated[str, StringConstraints(strip_whitespace=True, to_lower=True, pattern=r"^[a-z0-9_]{3,32}$")]
    password: Annotated[str, StringConstraints(min_length=10, max_length=128)]


class Registration(Credentials):
    name: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=40)]


class MasterQuestion(BaseModel):
    question: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=1200)]


@app.post("/v1/master")
def master_question(data: MasterQuestion, request: Request, authorization: Authorization = None):
    actor(authorization, required=True)
    check_auth_rate(request)
    key = os.getenv("GROQ_API_KEY")
    if not key:
        raise HTTPException(503, "Assistant unavailable")
    payload = {
        "model": "qwen/qwen3.8-27b",
        "messages": [
            {"role": "system", "content": "Ты Мастер Чи, дружелюбный чайный консультант Cha Tara. Отвечай кратко на русском. При нехватке данных уточняй. Не обещай лечебных эффектов. Доступные чаи: Бай Хао Инь Чжэнь, Бай Му Дань, Шоу Мэй, Лунцзин, Билочунь, Маофэн, Цзюнь Шань Инь Чжэнь, Хошань Хуан Я, Да Хун Пао, Те Гуань Инь, Дун Дин, Цзинь Цзюнь Мэй, Дянь Хун, Цимэнь Хун Ча, Шэн пуэр, Шу пуэр, Лю Бао, Фу Чжуань, GABA улун, GABA красный. Если советуешь чай, отвечай JSON: answer (строка), tea (название или пустая строка), grams, water, temperature, seconds (числа или null). Не выдумывай факты."},
            {"role": "user", "content": data.question},
        ],
        "response_format": {"type": "json_object"},
        "max_completion_tokens": 800,
        "temperature": 0.5,
    }
    req = urllib.request.Request(
        "https://api.groq.com/openai/v1/chat/completions",
        data=json.dumps(payload).encode(),
        headers={"Authorization": "Bearer " + key, "Content-Type": "application/json",
                 "User-Agent": "ChaTara/1.0"},
    )
    try:
        with urllib.request.urlopen(req, timeout=35) as upstream:
            result = json.loads(upstream.read(100000))
        answer = json.loads(result["choices"][0]["message"]["content"])
        if not isinstance(answer.get("answer"), str):
            raise ValueError("Invalid response")
        return answer
    except urllib.error.HTTPError as exc:
        raise HTTPException(429 if exc.code == 429 else 502, "Assistant unavailable") from exc
    except (OSError, ValueError, KeyError, IndexError, TypeError) as exc:
        raise HTTPException(502, "Assistant unavailable") from exc


auth_slots = BoundedSemaphore(1)
auth_lock = Lock()
attempts = OrderedDict()


def check_auth_rate(request: Request):
    ip = request.client.host if request.client else "unknown"
    now = time.monotonic()
    with auth_lock:
        count, reset = attempts.pop(ip, (0, now + 60))
        if now >= reset:
            count, reset = 0, now + 60
        attempts[ip] = (count + 1, reset)
        if len(attempts) > 2048:
            attempts.popitem(last=False)
    if count >= 8:
        raise HTTPException(429, "Too many requests")


def password_hash(password, salt):
    if not auth_slots.acquire(blocking=False):
        raise HTTPException(429, "Try again")
    try:
        return hashlib.scrypt(password.encode(), salt=salt, n=32768, r=8, p=1,
                              maxmem=64 * 1024 * 1024)
    finally:
        auth_slots.release()


def token_hash(authorization):
    if not authorization or not re.fullmatch(r"Bearer [0-9a-f]{64}", authorization):
        raise HTTPException(401, "Sign in required")
    return hashlib.sha256(bytes.fromhex(authorization[7:])).hexdigest()


def actor(authorization, required=False):
    if authorization is None and not required:
        return None
    with connect() as db:
        account = db.execute("""
            SELECT a.id, a.name FROM accounts a JOIN sessions s ON s.account_id=a.id
            WHERE s.token_hash=? AND s.expires_at > ?
        """, (token_hash(authorization), int(time.time()))).fetchone()
    if account is None:
        raise HTTPException(401, "Sign in required")
    return account


def create_session(db, account_id, name, response):
    token = secrets.token_hex(32)
    now = int(time.time())
    db.execute("DELETE FROM sessions WHERE expires_at <= ?", (now,))
    db.execute("INSERT INTO sessions VALUES (?, ?, ?)",
               (token_hash("Bearer " + token), account_id, now + 7 * 86400))
    response.headers["Cache-Control"] = "no-store"
    return {"token": token, "name": name}


@app.post("/v1/auth/register", status_code=201)
def register(data: Registration, request: Request, response: Response):
    check_auth_rate(request)
    account_id, salt = secrets.token_hex(16), secrets.token_bytes(16)
    digest = password_hash(data.password, salt)
    with connect() as db:
        result = db.execute("""
            INSERT INTO accounts VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(login) DO NOTHING
        """, (account_id, data.login, data.name, salt, digest))
        if not result.rowcount:
            raise HTTPException(409, "Login already exists")
        return create_session(db, account_id, data.name, response)


@app.post("/v1/auth/login")
def login(data: Credentials, request: Request, response: Response):
    check_auth_rate(request)
    with connect() as db:
        account = db.execute("SELECT * FROM accounts WHERE login=?", (data.login,)).fetchone()
    digest = password_hash(data.password, account["salt"] if account else bytes(16))
    if account is None or not secrets.compare_digest(account["password_hash"], digest):
        raise HTTPException(401, "Invalid login or password")
    with connect() as db:
        return create_session(db, account["id"], account["name"], response)


@app.delete("/v1/auth/session", status_code=204)
def logout(authorization: Authorization = None):
    with connect() as db:
        db.execute("DELETE FROM sessions WHERE token_hash=?", (token_hash(authorization),))


@app.get("/health")
def health():
    with connect() as db:
        db.execute("SELECT 1 FROM posts").fetchone()
    return {"ok": True}


@app.get("/v1/feed")
def feed(
    response: Response,
    following: bool = False,
    before: Annotated[int | None, Query(gt=0)] = None,
    authorization: Authorization = None,
):
    account = actor(authorization)
    reader = account["id"] if account else None
    response.headers["Cache-Control"] = "no-store"
    with connect() as db:
        rows = db.execute("""
            SELECT p.id, p.author_id, p.name, p.tea, p.notes, p.descriptors, p.created_at,
                   f.author IS NOT NULL AS followed
            FROM posts p LEFT JOIN follows f
                ON f.author = p.author_id AND f.reader = :reader
            WHERE (:before IS NULL OR p.id < :before)
              AND (NOT :following OR f.author IS NOT NULL)
            ORDER BY p.id DESC LIMIT 31
        """, {"reader": reader, "before": before, "following": following}).fetchall()
    return {
        "posts": [
            dict(row) | {
                "mine": row["author_id"] == reader,
                "followed": bool(row["followed"]),
                "descriptors": json.loads(row["descriptors"]),
            }
            for row in rows[:30]
        ],
        "next_before": rows[29]["id"] if len(rows) > 30 else None,
    }


@app.post("/v1/posts", status_code=201)
def publish(post: Post, authorization: Authorization = None):
    account = actor(authorization, required=True)
    owner = account["id"]
    with connect() as db:
        db.execute("""
            INSERT INTO posts (author_id, request_id, name, tea, notes, descriptors, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(author_id, request_id) DO NOTHING
        """, (
            owner, post.request_id, account["name"], post.tea, post.notes,
            json.dumps(post.descriptors, ensure_ascii=False),
            datetime.now(UTC).isoformat(),
        ))
        row = db.execute(
            "SELECT id FROM posts WHERE author_id=? AND request_id=?",
            (owner, post.request_id),
        ).fetchone()
        return {"id": row["id"]}


@app.delete("/v1/posts/{post_id}", status_code=204)
def delete_post(post_id: int, authorization: Authorization = None):
    account = actor(authorization, required=True)
    owner = account["id"]
    with connect() as db:
        result = db.execute("DELETE FROM posts WHERE id=? AND author_id=?", (post_id, owner))
        if not result.rowcount:
            raise HTTPException(404, "Post not found")


@app.put("/v1/follows/{author}", status_code=204)
def follow(author: str, authorization: Authorization = None):
    reader = actor(authorization, required=True)["id"]
    if author == reader:
        raise HTTPException(400, "Cannot follow yourself")
    with connect() as db:
        result = db.execute("""
            INSERT OR IGNORE INTO follows (reader, author)
            SELECT ?, ? WHERE EXISTS (SELECT 1 FROM posts WHERE author_id=?)
        """, (reader, author, author))
        if not result.rowcount and not db.execute(
            "SELECT 1 FROM posts WHERE author_id=?", (author,)
        ).fetchone():
            raise HTTPException(404, "Author not found")


@app.delete("/v1/follows/{author}", status_code=204)
def unfollow(author: str, authorization: Authorization = None):
    reader = actor(authorization, required=True)["id"]
    with connect() as db:
        db.execute("DELETE FROM follows WHERE reader=? AND author=?", (reader, author))
