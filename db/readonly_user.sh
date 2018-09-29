#!/bin/bash

databases='accounts, goods, orders, manage'

echo "
  CREATE USER readonly WITH PASSWORD 'password';
  GRANT CONNECT ON DATABASE $databases TO readonly;
" | psql -X

greenColor='\033[0;32m'
noColor='\033[0m'

for db in ${databases//,/ }; do
  echo -e "\ndatabase: ${greenColor}$db${noColor}"
  echo '
    GRANT USAGE ON SCHEMA public TO READONLY;
    GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO readonly;
  ' | psql -X $db
done

