CREATE TABLE plot (
    id INTEGER PRIMARY KEY NOT NULL, -- DF plot id
    owner UUID NOT NULL,
    instance INTEGER REFERENCES known_instance(id)
);

