CREATE TABLE trust (
    id SERIAL PRIMARY KEY,
    plot INTEGER NOT NULL REFERENCES plot(id),
    trusted INTEGER NOT NULL REFERENCES plot(id),
    UNIQUE (plot, trusted)
);

