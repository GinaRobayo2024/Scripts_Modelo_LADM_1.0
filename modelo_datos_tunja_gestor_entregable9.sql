-- Modelo de datos del esquema tunja_gestor_entregable9_28092026.
-- Mismo formato que "MODELO 1.0.csv": una fila por atributo, con PK y la referencia de la FK.
-- Si el esquema tiene otro nombre, cambiarlo en el CTE "params".

WITH params AS (
    SELECT 'tunja_gestor_entregable9_28092026'::name AS esquema
),
pk AS (
    SELECT con.conrelid, unnest(con.conkey) AS attnum
    FROM pg_catalog.pg_constraint con
    JOIN pg_catalog.pg_namespace n ON n.oid = con.connamespace
    WHERE con.contype = 'p'
      AND n.nspname = (SELECT esquema FROM params)
),
fk AS (
    SELECT con.conrelid,
           k.attnum,
           fn.nspname AS esquema_referenciado,
           fc.relname AS tabla_referenciada,
           fa.attname AS atributo_referenciado
    FROM pg_catalog.pg_constraint con
    JOIN pg_catalog.pg_namespace n ON n.oid = con.connamespace
    CROSS JOIN LATERAL unnest(con.conkey, con.confkey) AS k(attnum, fattnum)
    JOIN pg_catalog.pg_class fc ON fc.oid = con.confrelid
    JOIN pg_catalog.pg_namespace fn ON fn.oid = fc.relnamespace
    JOIN pg_catalog.pg_attribute fa ON fa.attrelid = con.confrelid AND fa.attnum = k.fattnum
    WHERE con.contype = 'f'
      AND n.nspname = (SELECT esquema FROM params)
)
SELECT
    n.nspname                                       AS esquema,
    c.relname                                       AS tabla,
    a.attname                                       AS atributo,
    pg_catalog.format_type(a.atttypid, a.atttypmod) AS tipo_dato,
    NOT a.attnotnull                                AS permite_nulo,
    CASE WHEN pk.attnum IS NOT NULL THEN 'PK' END   AS llave_primaria,
    fk.esquema_referenciado,
    fk.tabla_referenciada,
    fk.atributo_referenciado
FROM pg_catalog.pg_attribute a
JOIN pg_catalog.pg_class c     ON c.oid = a.attrelid
JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
LEFT JOIN pk ON pk.conrelid = c.oid AND pk.attnum = a.attnum
LEFT JOIN fk ON fk.conrelid = c.oid AND fk.attnum = a.attnum
WHERE c.relkind IN ('r', 'p')
  AND n.nspname = (SELECT esquema FROM params)
  AND a.attnum > 0
  AND NOT a.attisdropped
ORDER BY c.relname, a.attnum;
