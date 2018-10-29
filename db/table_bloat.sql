-- 查看表膨胀
SELECT schemaname, tblname,
  pg_size_pretty(real_size::bigint) as real_size,
  pg_size_pretty(bloat_size::bigint) as bloat_size,
  bloat_ratio || '%' as bloat_ratio,
  pg_size_pretty(extra_size::bigint) as extra_size,
  extra_ratio || '%' as extra_ratio,
  fillfactor, is_na
FROM (
  SELECT schemaname, tblname, bs*tblpages AS real_size,
    (tblpages-est_tblpages_ff)*bs AS bloat_size,
    CASE WHEN tblpages - est_tblpages_ff > 0
      THEN round((100.0 * (tblpages - est_tblpages_ff)/tblpages)::numeric, 2)
    END AS bloat_ratio,
    (tblpages-est_tblpages)*bs AS extra_size,
    CASE WHEN tblpages - est_tblpages > 0
      THEN round((100.0 * (tblpages - est_tblpages)/tblpages)::numeric, 2)
    END AS extra_ratio,
    fillfactor, is_na
  FROM (
    SELECT
      ceil( reltuples / ( (bs-page_hdr)/tpl_size ) ) + ceil( toasttuples / 4 ) AS est_tblpages,
      ceil( reltuples / ( (bs-page_hdr)*fillfactor/(tpl_size*100) ) ) + ceil( toasttuples / 4 ) AS est_tblpages_ff,
      tblpages, fillfactor, bs, schemaname, tblname, heappages, toastpages, is_na
    FROM (
      SELECT
        ( 4 + tpl_hdr_size + tpl_data_size + (2*ma)
          - CASE WHEN tpl_hdr_size%ma = 0 THEN ma ELSE tpl_hdr_size%ma END
          - CASE WHEN ceil(tpl_data_size)::int%ma = 0 THEN ma ELSE ceil(tpl_data_size)::int%ma END
        ) AS tpl_size, bs - page_hdr AS size_per_block, (heappages + toastpages) AS tblpages, heappages,
        toastpages, reltuples, toasttuples, bs, page_hdr, schemaname, tblname, fillfactor, is_na
      FROM (
        SELECT
          ns.nspname AS schemaname, tbl.relname AS tblname, tbl.reltuples,
          tbl.relpages AS heappages, coalesce(toast.relpages, 0) AS toastpages,
          coalesce(toast.reltuples, 0) AS toasttuples,
          coalesce(substring(
            array_to_string(tbl.reloptions, ' ')
            FROM 'fillfactor=([0-9]+)')::smallint, 100) AS fillfactor,
          current_setting('block_size')::numeric AS bs,
          CASE WHEN version()~'mingw32' OR version()~'64-bit|x86_64|ppc64|ia64|amd64' THEN 8 ELSE 4 END AS ma,
          24 AS page_hdr,
          23 + CASE WHEN MAX(coalesce(null_frac,0)) > 0 THEN ( 7 + count(*) ) / 8 ELSE 0::int END
            + CASE WHEN tbl.relhasoids THEN 4 ELSE 0 END AS tpl_hdr_size,
          sum( (1-coalesce(s.null_frac, 0)) * coalesce(s.avg_width, 1024) ) AS tpl_data_size,
          bool_or(att.atttypid = 'pg_catalog.name'::regtype)
            OR count(att.attname) <> count(s.attname) AS is_na
        FROM pg_attribute AS att
          JOIN pg_class AS tbl ON att.attrelid = tbl.oid
          JOIN pg_namespace AS ns ON ns.oid = tbl.relnamespace
          LEFT JOIN pg_stats AS s ON s.schemaname=ns.nspname
            AND s.tablename = tbl.relname AND s.inherited=false AND s.attname=att.attname
          LEFT JOIN pg_class AS toast ON tbl.reltoastrelid = toast.oid
        WHERE att.attnum > 0 AND NOT att.attisdropped
          AND tbl.relkind = 'r'
        GROUP BY 1,2,3,4,5,6,7,8,9,10, tbl.relhasoids
      ) AS s
    ) AS s2
  ) AS s3
  WHERE NOT is_na
) AS s4
ORDER BY coalesce(bloat_ratio, 0) DESC, schemaname DESC, tblname;

