-- Unidades de construccion: numero predial, identificador, uso y estado de conservacion,
-- diferenciando construcciones CONVENCIONALES de NO CONVENCIONALES.
-- La clasificacion convencional se toma de cuc_tipologiaconstruccion (no de
-- cuc_calificacionconvencional, que en esta base esta vacia).
-- La conservacion se trae tal cual esta en la tabla de catalogo (sin normalizar).
-- Modelo LADM_COL 1.0. Esquema: p_iza_h6_e1

with base as (
    select
        ic.t_id                                                  as unidad_construccion_id,
        pr.numero_predial_nacional,
        ic.identificador,
        uc.ilicode                                                as uso_ilicode,
        uc.dispname                                                as uso_nombre,
        cal.cuc_clfccnndcnstrccion_cuc_tipologiaconstruccion      as tipologia_id,
        cal.cuc_clfccnndcnstrccion_cuc_tipologianoconvencional    as no_convencional_id
    from p_iza_h6_e1.ilc_caracteristicasunidadconstruccion ic
    left join p_iza_h6_e1.cr_unidadconstruccion cr
        on cr.cr_caracteristicasunidadconstruccion = ic.t_id
    left join p_iza_h6_e1.col_uebaunit ueb
        on ueb.ue_cr_unidadconstruccion = cr.t_id
    left join p_iza_h6_e1.ilc_predio pr
        on pr.t_id = ueb.baunit
    left join p_iza_h6_e1.cr_usouconstipo uc
        on uc.t_id = ic.uso
    left join p_iza_h6_e1.cuc_calificacion_unidadconstruccion cal
        on cal.ilc_caracteristicasunidadconstruccion = ic.t_id
)
-- CONVENCIONALES (tabla cuc_tipologiaconstruccion)
select
    b.unidad_construccion_id,
    b.numero_predial_nacional,
    b.identificador,
    b.uso_ilicode,
    b.uso_nombre,
    'CONVENCIONAL'                      as tipo_construccion,
    tt.ilicode                          as tipologia_ilicode,
    tt.dispname                         as tipologia_nombre,
    ect.ilicode                         as conservacion_ilicode,
    ect.dispname                        as conservacion_nombre
from base b
inner join p_iza_h6_e1.cuc_tipologiaconstruccion tc
    on tc.t_id = b.tipologia_id
left join p_iza_h6_e1.cuc_tipologiatipo tt
    on tt.t_id = tc.tipo_tipologia
left join p_iza_h6_e1.cuc_estadoconservaciontipologiatipo ect
    on ect.t_id = tc.conservacion

union all

-- NO CONVENCIONALES (tabla cuc_tipologianoconvencional)
select
    b.unidad_construccion_id,
    b.numero_predial_nacional,
    b.identificador,
    b.uso_ilicode,
    b.uso_nombre,
    'NO CONVENCIONAL'                   as tipo_construccion,
    at.ilicode                          as tipologia_ilicode,
    at.dispname                         as tipologia_nombre,
    ecn.ilicode                         as conservacion_ilicode,
    ecn.dispname                        as conservacion_nombre
from base b
inner join p_iza_h6_e1.cuc_tipologianoconvencional tnc
    on tnc.t_id = b.no_convencional_id
left join p_iza_h6_e1.cuc_anexotipo at
    on at.t_id = tnc.tipo_anexo
left join p_iza_h6_e1.cuc_estadoconservaciontipologiatipo ecn
    on ecn.t_id = tnc.conservacion_anexo

order by numero_predial_nacional, unidad_construccion_id, tipo_construccion;
