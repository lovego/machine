--查看btree索引膨胀
SELECT schemaname, tblname, idxname,
  pg_size_pretty(real_size::bigint) as real_size,
  pg_size_pretty(bloat_size::bigint) as bloat_size,
  bloat_ratio || '%' as bloat_ratio,
  pg_size_pretty(extra_size::bigint) as extra_size,
  fillfactor, is_na
FROM (
  SELECT nspname AS schemaname, tblname, idxname, bs*(relpages)::bigint AS real_size,
    bs*(relpages-est_pages_ff) AS bloat_size,
    CASE WHEN relpages > est_pages_ff THEN
      round((100.0 * (relpages-est_pages_ff) / relpages)::numeric, 2)
    END  AS bloat_ratio,
    bs*(relpages-est_pages)::bigint AS extra_size,
    CASE WHEN relpages > est_pages THEN
      round((100.0 * (relpages-est_pages) / relpages)::numeric, 2)
    END AS extra_ratio,
    fillfactor, is_na
    -- , 100-(s3.pst).avg_leaf_density, est_pages, index_tuple_hdr_bm, maxalign, pagehdr, nulldatawidth, nulldatahdrwidth, s3.reltuples, s3.relpages -- (DEBUG INFO)
  FROM (
    SELECT coalesce(1 +
         ceil(reltuples/floor((bs-pageopqdata-pagehdr)/(4+nulldatahdrwidth)::float)), 0 -- ItemIdData size + computed avg size of a tuple (nulldatahdrwidth)
      ) AS est_pages,
      coalesce(1 +
         ceil(reltuples/floor((bs-pageopqdata-pagehdr)*fillfactor/(100*(4+nulldatahdrwidth)::float))), 0
      ) AS est_pages_ff,
      bs, nspname, table_oid, tblname, idxname, relpages, fillfactor, is_na
      -- , stattuple.pgstatindex(quote_ident(nspname)||'.'||quote_ident(idxname)) AS pst, index_tuple_hdr_bm, maxalign, pagehdr, nulldatawidth, nulldatahdrwidth, reltuples -- (DEBUG INFO)
    FROM (
      SELECT maxalign, bs, nspname, tblname, idxname, reltuples, relpages, relam, table_oid, fillfactor,
        ( index_tuple_hdr_bm +
            maxalign - CASE -- Add padding to the index tuple header to align on MAXALIGN
              WHEN index_tuple_hdr_bm%maxalign = 0 THEN maxalign
              ELSE index_tuple_hdr_bm%maxalign
            END
          + nulldatawidth + maxalign - CASE -- Add padding to the data to align on MAXALIGN
              WHEN nulldatawidth = 0 THEN 0
              WHEN nulldatawidth::integer%maxalign = 0 THEN maxalign
              ELSE nulldatawidth::integer%maxalign
            END
        )::numeric AS nulldatahdrwidth, pagehdr, pageopqdata, is_na
        -- , index_tuple_hdr_bm, nulldatawidth -- (DEBUG INFO)
      FROM (
        SELECT
          i.nspname, i.tblname, i.idxname, i.reltuples, i.relpages, i.relam, a.attrelid AS table_oid,
          current_setting('block_size')::numeric AS bs, fillfactor,
          CASE -- MAXALIGN: 4 on 32bits, 8 on 64bits (and mingw32 ?)
            WHEN version() ~ 'mingw32' OR version() ~ '64-bit|x86_64|ppc64|ia64|amd64' THEN 8
            ELSE 4
          END AS maxalign,
          /* per page header, fixed size: 20 for 7.X, 24 for others */
          24 AS pagehdr,
          /* per page btree opaque data */
          16 AS pageopqdata,
          /* per tuple header: add IndexAttributeBitMapData if some cols are null-able */
          CASE WHEN max(coalesce(s.null_frac,0)) = 0
            THEN 2 -- IndexTupleData size
            ELSE 2 + (( 32 + 8 - 1 ) / 8) -- IndexTupleData size + IndexAttributeBitMapData size ( max num filed per index + 8 - 1 /8)
          END AS index_tuple_hdr_bm,
          /* data len: we remove null values save space using it fractionnal part from stats */
          sum( (1-coalesce(s.null_frac, 0)) * coalesce(s.avg_width, 1024)) AS nulldatawidth,
          max( CASE WHEN a.atttypid = 'pg_catalog.name'::regtype THEN 1 ELSE 0 END ) > 0 AS is_na
        FROM pg_attribute AS a
          JOIN (
            SELECT nspname, tbl.relname AS tblname, idx.relname AS idxname, idx.reltuples, idx.relpages, idx.relam,
              indrelid, indexrelid, indkey::smallint[] AS attnum,
              coalesce(substring(
                array_to_string(idx.reloptions, ' ')
                 from 'fillfactor=([0-9]+)')::smallint, 90) AS fillfactor
            FROM pg_index
              JOIN pg_class idx ON idx.oid=pg_index.indexrelid
              JOIN pg_class tbl ON tbl.oid=pg_index.indrelid
              JOIN pg_namespace ON pg_namespace.oid = idx.relnamespace
            WHERE pg_index.indisvalid AND tbl.relkind = 'r' AND idx.relpages > 0
          ) AS i ON a.attrelid = i.indexrelid
          JOIN pg_stats AS s ON s.schemaname = i.nspname
            AND ((s.tablename = i.tblname AND s.attname = pg_catalog.pg_get_indexdef(a.attrelid, a.attnum, TRUE)) -- stats from tbl
            OR   (s.tablename = i.idxname AND s.attname = a.attname))-- stats from functionnal cols
          JOIN pg_type AS t ON a.atttypid = t.oid
        WHERE a.attnum > 0
        GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
      ) AS s1
    ) AS s2
      JOIN pg_am am ON s2.relam = am.oid WHERE am.amname = 'btree'
  ) AS s3
  WHERE NOT is_na
) AS s4
ORDER BY coalesce(bloat_ratio, 0) DESC, schemaname DESC, tblname;

