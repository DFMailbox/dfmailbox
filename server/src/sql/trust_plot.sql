INSERT INTO trust (plot, trusted)
SELECT $1, unnest($2::int[])
ON CONFLICT (plot, trusted) DO NOTHING;

