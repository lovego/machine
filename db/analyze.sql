select relname, n_live_tup, n_dead_tup, case
    when n_live_tup > 0 then (n_dead_tup * 100 / n_live_tup)::text || '%'
  end as dead_ratio,
  date(last_vacuum) as last_vacuum,
  date(last_autovacuum) as last_autovacuum,
  date(last_analyze) as last_analyze,
  date(last_autoanalyze) as last_autoanalyze
from pg_stat_user_tables
where relname='company_parts' order by last_autoanalyze;
