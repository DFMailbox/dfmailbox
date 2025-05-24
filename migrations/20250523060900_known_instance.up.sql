CREATE TABLE known_instance (
    public_key bytea PRIMARY KEY,
    domain TEXT NOT NULL UNIQUE
);
