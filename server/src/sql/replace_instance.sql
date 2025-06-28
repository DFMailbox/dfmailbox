UPDATE known_instance
SET address = $2
WHERE public_key = $1;
