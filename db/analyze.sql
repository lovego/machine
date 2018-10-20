select relname, n_live_tup, n_dead_tup, case
    when n_live_tup > 0 then (n_dead_tup * 100 / n_live_tup)::text || '%'
  end as dead_ratio,
  last_vacuum, last_autovacuum, last_analyze, last_autoanalyze
from pg_stat_user_tables
where relname='company_parts' order by last_autoanalyze;
