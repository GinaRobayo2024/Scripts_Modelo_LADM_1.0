-- Modelo de datos completo (atributos + llaves primarias + relaciones) en una sola consulta,
-- lista para exportar a CSV. Filtrada al esquema o_70523_00_20250627_l3_h5_r3.

WITH atributos AS (
    SELECT
        n.nspname                                      AS esquema,
        c.relname                                       AS tabla,
        c.oid                                            AS tabla_oid,
        a.attname                                       AS atributo,
        a.attnum,
        pg_catalog.format_type(a.atttypid, a.atttypmod) AS tipo_dato,
        NOT a.attnotnull                                AS permite_nulo
    FROM pg_catalog.pg_attribute a
    JOIN pg_catalog.pg_class c ON c.oid = a.attrelid
    JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    WHERE c.relkind IN ('r', 'p')
      AND n.nspname = 'o_70523_00_20250627_l3_h5_r3'
      AND a.attnum > 0
      AND NOT a.attisdropped
),
llaves_primarias AS (
    SELECT con.conrelid AS tabla_oid, unnest(con.conkey) AS attnum
    FROM pg_catalog.pg_constraint con
    WHERE con.contype = 'p'
),
llaves_foraneas AS (
    SELECT
        con.conrelid       AS tabla_oid,
        cols.attnum,
        fn.nspname         AS esquema_referenciado,
        fc.relname         AS tabla_referenciada,
        fa.attname         AS atributo_referenciado
    FROM pg_catalog.pg_constraint con
    JOIN LATERAL unnest(con.conkey, con.confkey) AS cols(attnum, confattnum) ON true
    JOIN pg_catalog.pg_class fc ON fc.oid = con.confrelid
    JOIN pg_catalog.pg_namespace fn ON fn.oid = fc.relnamespace
    JOIN pg_catalog.pg_attribute fa
        ON fa.attrelid = con.confrelid
       AND fa.attnum = cols.confattnum
    WHERE con.contype = 'f'
)
SELECT
    at.esquema,
    at.tabla,
    at.atributo,
    at.tipo_dato,
    at.permite_nulo,
    CASE WHEN pk.attnum IS NOT NULL THEN 'PK' END AS llave_primaria,
    fk.esquema_referenciado,
    fk.tabla_referenciada,
    fk.atributo_referenciado
FROM atributos at
LEFT JOIN llaves_primarias pk ON pk.tabla_oid = at.tabla_oid AND pk.attnum = at.attnum
LEFT JOIN llaves_foraneas fk ON fk.tabla_oid = at.tabla_oid AND fk.attnum = at.attnum
ORDER BY at.esquema, at.tabla, at.attnum;
