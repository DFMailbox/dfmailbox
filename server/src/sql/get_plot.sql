SELECT plot.id, owner, public_key, domain, mailbox_msg_id FROM plot
LEFT JOIN known_instance instance ON instance.public_key = plot.instance
WHERE plot.id = $1;
