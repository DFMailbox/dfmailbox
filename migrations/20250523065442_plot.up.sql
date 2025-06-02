SET timezone TO 'UTC';
CREATE TABLE plot (
    id INTEGER PRIMARY KEY NOT NULL, -- DF plot id
    owner UUID NOT NULL,
    instance BYTEA REFERENCES known_instance(public_key)
);

