-- Predios con visita / sin visita (lista con IN)
-- Modelo LADM_COL 1.0
--
-- IMPORTANTE: reemplazar [esquema] por el esquema real de la base
-- (ej: o_XXXXX_XX_AAAAMMDD_l1_h5_...).
--
-- tiene_visita = 'SI' cuando el predio tiene registro en
-- ilc_datosadicionaleslevantamientocatastral con fecha_visita_predial.

SET search_path TO [esquema];

SELECT
    pc.numero_predial_nacional,
    pc.t_id                                   AS predio_t_id,
    CASE WHEN max(dalc.fecha_visita_predial) IS NOT NULL
         THEN 'SI' ELSE 'NO' END              AS tiene_visita,
    max(dalc.fecha_visita_predial)            AS fecha_visita_predial,
    string_agg(DISTINCT rv.ilicode, ' | ')    AS resultado_visita
FROM ilc_predio pc
LEFT JOIN ilc_datosadicionaleslevantamientocatastral dalc
    ON dalc.ilc_predio = pc.t_id
LEFT JOIN ilc_resultadovisitatipo rv
    ON rv.t_id = dalc.resultado_visita
WHERE pc.numero_predial_nacional IN (
    -- Pegar aqui los numeros prediales, uno por linea, separados por coma
    '000000000000000000000000000001',
    '000000000000000000000000000002',
    '000000000000000000000000000003'   -- el ultimo SIN coma
)
GROUP BY pc.numero_predial_nacional, pc.t_id
ORDER BY tiene_visita, pc.numero_predial_nacional;
