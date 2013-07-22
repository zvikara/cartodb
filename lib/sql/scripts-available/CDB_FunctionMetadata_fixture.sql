-- write the new values
WITH n(i,p,r,w) AS ( VALUES
(
  1, -- CDB_DigitSeparator
  $REG$cdb_digitseparator\s*\((?:[ '"]*|\$[^$]*\$)([^ '",$]*)$REG$,
  '$1',
  NULL
),
(
  2, -- CDB_UserTables
  'CDB_UserTables',
  'pg_class',
  NULL
),
(
  3, -- CDB_ColumnNames
  'CDB_ColumnNames',
  'pg_attribute',
  NULL
),
(
  4, -- CDB_ColumnType
  'CDB_ColumnType',
  'pg_attribute',
  NULL
),
(
  1000, -- sentinel for end of system rows
  '^CUSTOM_ENTRIES_ABOVE_THIS_ID',
  '',
  NULL
)
),
upsert AS (
    UPDATE public.CDB_FunctionMetadata o
    SET pattern=n.p, read=n.r, write=n.w
    FROM n WHERE o.id = n.i
    RETURNING o.id
)
-- insert missing rows
INSERT INTO public.CDB_FunctionMetadata(id,pattern,read,write)
SELECT n.i, n.p, n.r, n.w FROM n
WHERE n.i NOT IN (
  SELECT id FROM upsert
);

 
-- Reset sequence
SELECT setval('public.cdb_functionmetadata_id_seq',
  (SELECT max(id) FROM public.CDB_FunctionMetadata), true);
