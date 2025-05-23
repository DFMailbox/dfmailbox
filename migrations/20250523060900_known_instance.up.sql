CREATE TABLE known_instance (
    id SERIAL PRIMARY KEY,
    public_key bytea NOT NULL UNIQUE,
    domain TEXT NOT NULL UNIQUE
);
