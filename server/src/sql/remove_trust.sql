DELETE FROM trust
WHERE plot = $1 AND trusted = ANY($2::INTEGER[]);
