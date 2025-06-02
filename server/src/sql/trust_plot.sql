INSERT INTO trust (plot, trusted)
VALUES ($1, $2)
ON CONFLICT (plot, trusted) DO NOTHING;
