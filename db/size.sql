SELECT pg_database.datname, pg_size_pretty(pg_database_size(pg_database.datname))
FROM pg_database
ORDER by pg_database_size(pg_database.datname) DESC;

SELECT table_schema, table_name, pg_size_pretty(pg_relation_size(
    '"' || table_schema || '"."' || table_name || '"'
))
FROM information_schema.tables
ORDER BY pg_relation_size('"' || table_schema || '"."' || table_name || '"') DESC;


