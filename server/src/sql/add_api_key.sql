INSERT INTO api_key (plot, hashed_key) 
VALUES ($1, sha256($2))
