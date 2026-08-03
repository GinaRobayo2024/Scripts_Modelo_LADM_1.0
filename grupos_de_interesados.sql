-- Datos juridicos con grupo de interesados - modelo LADM_COL 1.0
-- Esquema: o_70523_00_20250627_l3_h5_r3
-- Predio + interesados (agrupaciones, participacion, etnia, novedad numero predial, informalidad)

with tb1 as(
    select
        cr.rrr,
        cm.interesado_ilc_interesado as interesado_ilc_interesado,
        cm.agrupacion as agrupacion_id,
        ci.ilicode as ci_ilicode,
        cd.ilicode as cd_ilicode,
        gt.ilicode as tipo_agrupacion
    from o_70523_00_20250627_l3_h5_r3.col_rrrinteresado cr
    inner join o_70523_00_20250627_l3_h5_r3.col_miembros cm
        on cm.agrupacion = cr.interesado_cr_agrupacioninteresados
    inner join o_70523_00_20250627_l3_h5_r3.ilc_interesado ii
        on ii.t_id = cm.interesado_ilc_interesado
    inner join o_70523_00_20250627_l3_h5_r3.cr_documentotipo cd
        on cd.t_id = ii.tipo_documento
    inner join o_70523_00_20250627_l3_h5_r3.cr_interesadotipo ci
        on ci.t_id = ii.tipo
    inner join o_70523_00_20250627_l3_h5_r3.cr_agrupacioninteresados ag
        on ag.t_id = cm.agrupacion
    left join o_70523_00_20250627_l3_h5_r3.col_grupointeresadotipo gt
        on gt.t_id = ag.tipo
    UNION
    select
        cr.rrr,
        cr.interesado_ilc_interesado,
        null as agrupacion_id,
        ci.ilicode as ci_ilicode,
        cd.ilicode as cd_ilicode,
        null as tipo_agrupacion
    from o_70523_00_20250627_l3_h5_r3.col_rrrinteresado cr
    inner join o_70523_00_20250627_l3_h5_r3.ilc_interesado ii
        on ii.t_id = cr.interesado_ilc_interesado
    inner join o_70523_00_20250627_l3_h5_r3.cr_documentotipo cd
        on cd.t_id = ii.tipo_documento
    inner join o_70523_00_20250627_l3_h5_r3.cr_interesadotipo ci
        on ci.t_id = ii.tipo
    where not exists (
        select 1
        from o_70523_00_20250627_l3_h5_r3.col_rrrinteresado cr2
        where cr2.rrr = cr.rrr
          and cr2.interesado_cr_agrupacioninteresados is not null
    )
),
validacion_agrupacion as (
    select
        rrr,
        count(*) as total_interesados,
        count(tipo_agrupacion) as total_agrupados
    from tb1
    group by rrr
),
participacion_agrupacion as (
    select
        agrupacion,
        sum(participacion) as suma_participacion
    from o_70523_00_20250627_l3_h5_r3.col_miembros
    group by agrupacion
),
interesados_por_predio as (
    select
        pd.unidad as predio_t_id,
        string_agg(
            distinct coalesce(
                ii2.razon_social,
                trim(concat_ws(' ', ii2.primer_nombre, ii2.segundo_nombre, ii2.primer_apellido, ii2.segundo_apellido))
            ),
            '; '
        ) as interesados_concat
    from o_70523_00_20250627_l3_h5_r3.ilc_derecho pd
    left join tb1 on tb1.rrr = pd.t_id
    left join o_70523_00_20250627_l3_h5_r3.ilc_interesado ii2
        on ii2.t_id = tb1.interesado_ilc_interesado
    group by pd.unidad
),
tb2 as (
    select
        pc.t_id as predio_t_id,
        pc.numero_predial_nacional,
        ip.ilicode as tipo_de_predio,
        pc.matricula_inmobiliaria as fmi,
        id.ilicode as derecho_tipo,
        cp.ilicode as condicion_predio,
        fa.tipo as fuente_tipo_id,
        cf.ilicode as fuente_ilicode,
        fa.ente_emisor,
        fa.numero_fuente,
        fa.fecha_documento_fuente,
        pd.t_id as derecho_t_id,
        dalc.fecha_visita_predial,
        enp.numero_predial as estructura_numero_novedad,
        tn.ilicode as tipo_novedad_ilicode,
        case when pi.igc_predio_formal is not null then 'INFORMAL' end as condicion_informalidad_registro,
        ipf.interesados_concat as interesado_predio_formal
    from o_70523_00_20250627_l3_h5_r3.ilc_predio pc
    left join o_70523_00_20250627_l3_h5_r3.ilc_derecho pd
        on pd.unidad = pc.t_id
    left join o_70523_00_20250627_l3_h5_r3.ilc_derechocatastraltipo id
        on id.t_id = pd.tipo
    left join o_70523_00_20250627_l3_h5_r3.col_rrrfuente cr
        on cr.rrr = pd.t_id
    left join o_70523_00_20250627_l3_h5_r3.ilc_fuenteadministrativa fa
        on fa.t_id = cr.fuente_administrativa
    left join o_70523_00_20250627_l3_h5_r3.col_fuenteadministrativatipo cf
        on fa.tipo = cf.t_id
    left join o_70523_00_20250627_l3_h5_r3.ilc_prediotipo ip
        on ip.t_id = pc.tipo
    left join o_70523_00_20250627_l3_h5_r3.ilc_condicionprediotipo cp
        on cp.t_id = pc.condicion_predio
    left join o_70523_00_20250627_l3_h5_r3.ilc_datosadicionaleslevantamientocatastral dalc
        on dalc.ilc_predio = pc.t_id
    left join o_70523_00_20250627_l3_h5_r3.ilc_estructuranovedadnumeropredial enp
        on enp.ilc_dtsdcnltmntctstral_novedad_numeros_prediales = dalc.t_id
    left join o_70523_00_20250627_l3_h5_r3.ilc_estructuranovedadnumeropredial_tipo_novedad tn
        on tn.t_id = enp.tipo_novedad
    left join o_70523_00_20250627_l3_h5_r3.ilc_predio_informalidad pi
        on pi.igc_predio_informal = pc.t_id
    left join interesados_por_predio ipf
        on ipf.predio_t_id = pi.igc_predio_formal
)
select
    tb2.predio_t_id,
    tb2.numero_predial_nacional,
    case
        when length(tb2.numero_predial_nacional) >= 7
            then substring(tb2.numero_predial_nacional, 6, 2)
        else null
    end as zona,
    case
        when length(tb2.numero_predial_nacional) >= 22
            then substring(tb2.numero_predial_nacional, 22, 1)
        else null
    end as posicion_22,
    case
        when length(tb2.numero_predial_nacional) >= 22
             and substring(tb2.numero_predial_nacional, 22, 1) = '2'
            then 'INFORMAL'
        when length(tb2.numero_predial_nacional) >= 22
            then 'FORMAL'
        else null
    end as condicion_informal,
    tb2.condicion_informalidad_registro,
    tb2.interesado_predio_formal,
    tb2.tipo_de_predio,
    tb2.fmi,
    tb2.derecho_tipo,
    tb2.condicion_predio,
    tb2.fuente_tipo_id,
    tb2.fuente_ilicode,
    tb2.ente_emisor,
    tb2.numero_fuente,
    tb2.fecha_documento_fuente,
    tb2.fecha_visita_predial,
    tb2.estructura_numero_novedad,
    tb2.tipo_novedad_ilicode,
    ii.tipo_documento,
    tb1.cd_ilicode as documento_tipo_ilicode,
    tb1.ci_ilicode as interesado_tipo_ilicode,
    tb1.tipo_agrupacion,
    va.total_interesados,
    va.total_agrupados,
    case
        when va.total_interesados > 1 and va.total_agrupados = 0
            then 'No cumple'
        else 'Cumple'
    end as estado_agrupacion_interesados,
    pa.suma_participacion as suma_participacion_agrupacion,
    ii.tipo as interesado_tipo_id,
    ii.documento_identidad,
    cs.ilicode as sexo_ilicode,
    ii.primer_nombre,
    ii.segundo_nombre,
    ii.primer_apellido,
    ii.segundo_apellido,
    ii.razon_social,
    npi.ilicode as pueblo_indigena_ilicode,
    ie.nombre_comunidad
from tb2
left join tb1 on tb1.rrr = tb2.derecho_t_id
left join validacion_agrupacion va on va.rrr = tb2.derecho_t_id
left join participacion_agrupacion pa on pa.agrupacion = tb1.agrupacion_id
left join o_70523_00_20250627_l3_h5_r3.ilc_interesado ii
    on ii.t_id = tb1.interesado_ilc_interesado
left join o_70523_00_20250627_l3_h5_r3.cr_sexotipo cs
    on cs.t_id = ii.sexo
left join o_70523_00_20250627_l3_h5_r3.ilc_identificacionetnica ie
    on ie.lc_identificacionetnica = ii.t_id
left join o_70523_00_20250627_l3_h5_r3.ilc_nombrepueblosindigenastipo npi
    on npi.t_id = ie.nombre_pueblo;
