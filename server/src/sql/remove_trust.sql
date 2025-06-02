DELETE FROM trust
WHERE plot = $1 AND trusted = $2;
