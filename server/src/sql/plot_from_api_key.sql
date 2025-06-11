SELECT plot.id, owner, public_key, address, mailbox_msg_id FROM api_key
JOIN plot ON plot.id = api_key.plot
LEFT JOIN known_instance instance ON instance.public_key = plot.instance
WHERE hashed_key = sha256($1);
