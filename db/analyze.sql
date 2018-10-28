select relname, n_live_tup, n_dead_tup,
  case when n_live_tup > 0 and n_dead_tup >= boot_val::int then
    round((n_dead_tup - boot_val::int) * 100.0 / n_live_tup, 2) || '%'
  end as dead_ratio,
  case when last_autovacuum > last_vacuum or last_vacuum is null then
    to_char(last_autovacuum, 'YYYY-MM-DD HH24:MI')
  end as last_autovacuum,
  case when last_vacuum > last_autovacuum or last_autovacuum is null then
    to_char(last_vacuum, 'YYYY-MM-DD HH24:MI')
  end as last_vacuum
from pg_stat_user_tables, pg_settings
where pg_settings.name='autovacuum_vacuum_threshold'
order by coalesce(last_autovacuum, '0001-01-01') desc,
         coalesce(last_vacuum, '0001-01-01') desc;

select relname, n_live_tup, n_mod_since_analyze,
  case when n_live_tup > 0 and n_mod_since_analyze >= boot_val::int then
    round((n_mod_since_analyze - boot_val::int) * 100.0 / n_live_tup, 2) || '%'
  end as mod_ratio,
  case when last_autoanalyze > last_analyze or last_analyze is null then
    to_char(last_autoanalyze, 'YYYY-MM-DD HH24:MI')
  end as last_autoanalyze,
  case when last_analyze > last_autoanalyze or last_autoanalyze is null then
    to_char(last_analyze, 'YYYY-MM-DD HH24:MI')
  end as last_analyze
from pg_stat_user_tables, pg_settings
where pg_settings.name='autovacuum_analyze_threshold'
order by coalesce(last_autoanalyze, '0001-01-01') desc,
         coalesce(last_analyze, '0001-01-01') desc;
