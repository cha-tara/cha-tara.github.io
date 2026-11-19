import hashlib
import json
import os
import re
import sqlite3
from contextlib import asynccontextmanager, closing, contextmanager
from datetime import UTC, datetime
from pathlib import Path
from typing import Annotated

from fastapi import FastAPI, Header, HTTPException, Query, Response
from fastapi.middleware.cors import CORSMiddleware
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


app = FastAPI(title="Cha Tara", lifespan=lifespan, docs_url=None, redoc_url=None)
app.add_middleware(
    CORSMiddleware,
    allow_origins=os.getenv("CHA_TARA_ORIGINS", "https://cha-tara.github.io").split(","),
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
)


class Post(BaseModel):
    request_id: Annotated[str, StringConstraints(pattern=r"^[0-9a-f]{32}$")]
    name: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=40)]
    tea: Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)]
    notes: Annotated[str, StringConstraints(strip_whitespace=True, max_length=2000)] = ""
    descriptors: list[Annotated[str, StringConstraints(max_length=140)]] = Field(
        default_factory=list, max_length=1800
    )


Authorization = Annotated[str | None, Header()]


def actor(authorization, required=False):
    if not authorization and not required:
        return None
    if not authorization or not re.fullmatch(r"Bearer [0-9a-f]{64}", authorization):
        raise HTTPException(401, "Invalid browser credential")
    return hashlib.sha256(bytes.fromhex(authorization[7:])).hexdigest()


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
    reader = actor(authorization)
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
    owner = actor(authorization, required=True)
    with connect() as db:
        db.execute("""
            INSERT INTO posts (author_id, request_id, name, tea, notes, descriptors, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(author_id, request_id) DO NOTHING
        """, (
            owner, post.request_id, post.name, post.tea, post.notes,
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
    owner = actor(authorization, required=True)
    with connect() as db:
        result = db.execute("DELETE FROM posts WHERE id=? AND author_id=?", (post_id, owner))
        if not result.rowcount:
            raise HTTPException(404, "Post not found")


@app.put("/v1/follows/{author}", status_code=204)
def follow(author: str, authorization: Authorization = None):
    reader = actor(authorization, required=True)
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
    reader = actor(authorization, required=True)
    with connect() as db:
        db.execute("DELETE FROM follows WHERE reader=? AND author=?", (reader, author))
