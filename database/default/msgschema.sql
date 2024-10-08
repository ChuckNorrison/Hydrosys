DROP TABLE IF EXISTS posts;

CREATE TABLE posts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created TEXT NOT NULL,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    color TEXT
);
