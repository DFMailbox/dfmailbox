SELECT id, plot, hashed_key, created_at FROM api_key
WHERE plot = $1;
