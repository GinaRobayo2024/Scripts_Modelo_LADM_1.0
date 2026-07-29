-- Metadatos del esquema SNC_CICA en Oracle: atributos, llaves primarias y relaciones.
-- Ajustar 'SNC_CICA' si se requiere otro esquema.

SELECT
    c.owner       AS esquema,
    c.table_name  AS tabla,
    c.column_name AS atributo,
    c.data_type ||
        CASE
            WHEN c.data_type IN ('VARCHAR2', 'CHAR', 'NVARCHAR2', 'NCHAR')
                THEN '(' || c.char_length || ')'
            WHEN c.data_type = 'NUMBER' AND c.data_precision IS NOT NULL
                THEN '(' || c.data_precision || ',' || NVL(c.data_scale, 0) || ')'
            ELSE ''
        END AS tipo_dato,
    c.nullable AS permite_nulo,
    CASE WHEN pk.column_name IS NOT NULL THEN 'PK' END AS llave_primaria,
    fk.r_owner      AS esquema_referenciado,
    fk.r_table_name AS tabla_referenciada,
    fk.r_column_name AS atributo_referenciado
FROM all_tab_columns c
LEFT JOIN (
    SELECT acc.owner, acc.table_name, acc.column_name
    FROM all_constraints ac
    JOIN all_cons_columns acc
        ON ac.constraint_name = acc.constraint_name
       AND ac.owner = acc.owner
    WHERE ac.constraint_type = 'P'
      AND ac.owner = 'SNC_CICA'
) pk
    ON c.owner = pk.owner
   AND c.table_name = pk.table_name
   AND c.column_name = pk.column_name
LEFT JOIN (
    SELECT
        acc.owner,
        acc.table_name,
        acc.column_name,
        rc.owner        AS r_owner,
        rcc.table_name  AS r_table_name,
        rcc.column_name AS r_column_name
    FROM all_constraints ac
    JOIN all_cons_columns acc
        ON ac.constraint_name = acc.constraint_name
       AND ac.owner = acc.owner
    JOIN all_constraints rc
        ON ac.r_constraint_name = rc.constraint_name
       AND ac.r_owner = rc.owner
    JOIN all_cons_columns rcc
        ON rc.constraint_name = rcc.constraint_name
       AND rc.owner = rcc.owner
       AND acc.position = rcc.position
    WHERE ac.constraint_type = 'R'
      AND ac.owner = 'SNC_CICA'
) fk
    ON c.owner = fk.owner
   AND c.table_name = fk.table_name
   AND c.column_name = fk.column_name
WHERE c.owner = 'SNC_CICA'
ORDER BY c.table_name, c.column_id;
