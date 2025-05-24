CREATE TABLE known_instance (
    public_key bytea PRIMARY KEY,
    domain TEXT UNIQUE -- Null means compromised key
);
