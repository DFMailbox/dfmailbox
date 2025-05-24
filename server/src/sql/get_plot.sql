SELECT plot.id, owner, public_key, domain FROM plot
LEFT JOIN known_instance instance ON instance.public_key = plot.instance
WHERE plot.id = $1;
