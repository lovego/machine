#!/bin/bash

echo "CREATE USER readonly WITH PASSWORD 'password';" | psql -X postgres

grant_readonly_to_database() {
  local greenColor='\033[0;32m'
  local noColor='\033[0m'
  local db=$1
  echo -e "\nDatabase: ${greenColor}$db${noColor}"

  echo "GRANT CONNECT ON DATABASE $db TO readonly;" | psql -X postgres
  echo '
ALTER DEFAULT PRIVILEGES FOR USER xxx GRANT SELECT ON TABLES TO readonly;

DO $do$
DECLARE
  sch text;
BEGIN
  FOR sch IN SELECT nspname FROM pg_namespace
  LOOP
    EXECUTE format($$ GRANT USAGE ON SCHEMA %I TO readonly $$, sch);
    EXECUTE format($$ GRANT SELECT ON ALL TABLES IN SCHEMA %I TO readonly $$, sch);
  END LOOP;
END;
$do$;
' | psql -X $db
}

for db in "$@"; do
  grant_readonly_to_database "$db"
done
