DELETE FROM trust
WHERE plot = $1 OR trusted = $1;
