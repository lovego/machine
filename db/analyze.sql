select relname, n_live_tup, n_dead_tup, case
    when n_live_tup > 0 then (n_dead_tup * 100 / n_live_tup)::text || '%'
  end as dead_ratio,
  to_char(last_vacuum, 'YYYY-MM-DD HH:MI') as last_vacuum,
  to_char(last_autovacuum, 'YYYY-MM-DD HH:MI') as last_autovacuum,
  to_char(last_analyze, 'YYYY-MM-DD HH:MI') as last_analyze,
  to_char(last_autoanalyze, 'YYYY-MM-DD HH:MI') as last_autoanalyze
from pg_stat_user_tables
order by last_autovacuum;
