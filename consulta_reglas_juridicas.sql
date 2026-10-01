-- SUPER CONSULTA recortada: solo las columnas BASE del Excel (SUPER_CONSULTA_REGLAS_CONSISTENCIA.xlsx,
-- hoja CONSULTA_MAESTRA), SIN ninguna de las 41 columnas de reglas. Termina en
-- suma_participacion_agrupacion (columna Y en tu Excel).
-- Esquema real de la base: [esquema]
--
-- Mapeo de columnas (igual orden que en el Excel):
--  A predio_t_id            G fuente_ilicode          M formal                   S sexo_ilicode
--  B numero_predial_nacional H ente_emisor            N zona_rural               T grupo_etnico_ilicode
--  C tipo_de_predio          I numero_fuente          O interesado_tipo_ilicode  U tipo_agrupacion
--  D fmi                     J fecha_documento_fuente P documento_tipo_ilicode   V total_interesados
--  E derecho_tipo            K fecha_inicio_tenencia  Q documento_identidad      W total_agrupados
--  F condicion_predio        L fecha_visita_predial   R nombre_completo          Y suma_participacion_agrupacion

with tb1 as (
    select
        cr.rrr,
        cm.interesado_ilc_interesado as interesado_ilc_interesado,
        cm.agrupacion as agrupacion_id,
        ci.ilicode as ci_ilicode,
        cd.ilicode as cd_ilicode,
        gt.ilicode as tipo_agrupacion
    from [esquema].col_rrrinteresado cr
    inner join [esquema].col_miembros cm
        on cm.agrupacion = cr.interesado_cr_agrupacioninteresados
    inner join [esquema].ilc_interesado ii
        on ii.t_id = cm.interesado_ilc_interesado
    inner join [esquema].cr_documentotipo cd
        on cd.t_id = ii.tipo_documento
    inner join [esquema].cr_interesadotipo ci
        on ci.t_id = ii.tipo
    inner join [esquema].cr_agrupacioninteresados ag
        on ag.t_id = cm.agrupacion
    left join [esquema].col_grupointeresadotipo gt
        on gt.t_id = ag.tipo
    UNION
    select
        cr.rrr,
        cr.interesado_ilc_interesado,
        null as agrupacion_id,
        ci.ilicode as ci_ilicode,
        cd.ilicode as cd_ilicode,
        null as tipo_agrupacion
    from [esquema].col_rrrinteresado cr
    inner join [esquema].ilc_interesado ii
        on ii.t_id = cr.interesado_ilc_interesado
    inner join [esquema].cr_documentotipo cd
        on cd.t_id = ii.tipo_documento
    inner join [esquema].cr_interesadotipo ci
        on ci.t_id = ii.tipo
    where not exists (
        select 1
        from [esquema].col_rrrinteresado cr2
        where cr2.rrr = cr.rrr
          and cr2.interesado_cr_agrupacioninteresados is not null
    )
),
validacion_agrupacion as (
    select rrr, count(*) as total_interesados, count(tipo_agrupacion) as total_agrupados
    from tb1
    group by rrr
),
participacion_agrupacion as (
    select agrupacion, sum(participacion) as suma_participacion,
           count(*) as total_miembros, count(participacion) as miembros_con_participacion
    from [esquema].col_miembros
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
    from [esquema].ilc_derecho pd
    left join tb1 on tb1.rrr = pd.t_id
    left join [esquema].ilc_interesado ii2
        on ii2.t_id = tb1.interesado_ilc_interesado
    group by pd.unidad
),
-- Fuentes agrupadas por derecho: en el cargue cada interesado trae su propia copia de la
-- fuente (misma escritura, mismo numero y fecha), por eso un derecho con N interesados
-- tiene N fuentes. Si se unen sin agrupar, cada interesado se repite N veces.
fuentes_por_derecho as (
    select
        crf.rrr as derecho_t_id,
        count(distinct fa.t_id) as cantidad_fuentes,
        string_agg(distinct cf.ilicode, ' | ') as fuente_ilicode,
        string_agg(distinct fa.ente_emisor, ' | ') as ente_emisor,
        string_agg(distinct fa.numero_fuente, ' | ') as numero_fuente,
        string_agg(distinct fa.fecha_documento_fuente::text, ' | ') as fecha_documento_fuente
    from [esquema].col_rrrfuente crf
    inner join [esquema].ilc_fuenteadministrativa fa
        on fa.t_id = crf.fuente_administrativa
    left join [esquema].col_fuenteadministrativatipo cf
        on cf.t_id = fa.tipo
    group by crf.rrr
),
-- Informalidad agrupada por predio informal: una mejora puede estar sobre DOS o mas
-- predios formales; sin agrupar, cada interesado de la mejora sale repetido.
informalidad_por_predio as (
    select
        pi.igc_predio_informal as predio_t_id,
        count(distinct pi.igc_predio_formal) as cantidad_predios_formales,
        string_agg(distinct ipf.interesados_concat, ' | ') as interesado_predio_formal
    from [esquema].ilc_predio_informalidad pi
    left join interesados_por_predio ipf
        on ipf.predio_t_id = pi.igc_predio_formal
    group by pi.igc_predio_informal
),
tb2 as (
    select
        pc.t_id as predio_t_id,
        pc.numero_predial_nacional,
        ip.ilicode as tipo_de_predio,
        pc.matricula_inmobiliaria as fmi,
        id.ilicode as derecho_tipo,
        cp.ilicode as condicion_predio,
        fd.fuente_ilicode,
        fd.ente_emisor,
        fd.numero_fuente,
        fd.fecha_documento_fuente,
        fd.cantidad_fuentes,
        pd.t_id as derecho_t_id,
        pd.fecha_inicio_tenencia,
        dalc.fecha_visita_predial,
        case when inf.predio_t_id is not null then 'INFORMAL' end as condicion_informalidad_registro,
        inf.cantidad_predios_formales,
        inf.interesado_predio_formal,
        case
            when length(pc.numero_predial_nacional) >= 22
                then (substring(pc.numero_predial_nacional, 22, 1) <> '2')
            else null
        end as formal,
        case
            when length(pc.numero_predial_nacional) >= 7
                then (substring(pc.numero_predial_nacional, 6, 2) = '00')
            else null
        end as zona_rural
    from [esquema].ilc_predio pc
    left join [esquema].ilc_derecho pd
        on pd.unidad = pc.t_id
    left join [esquema].ilc_derechocatastraltipo id
        on id.t_id = pd.tipo
    left join fuentes_por_derecho fd
        on fd.derecho_t_id = pd.t_id
    left join [esquema].ilc_prediotipo ip
        on ip.t_id = pc.tipo
    left join [esquema].ilc_condicionprediotipo cp
        on cp.t_id = pc.condicion_predio
    -- una sola fila de visita por predio (la mas reciente): si el predio tiene varios
    -- registros de datos adicionales, antes se duplicaban todos sus interesados
    left join (
        select ilc_predio, max(fecha_visita_predial) as fecha_visita_predial
        from [esquema].ilc_datosadicionaleslevantamientocatastral
        group by ilc_predio
    ) dalc
        on dalc.ilc_predio = pc.t_id
    left join informalidad_por_predio inf
        on inf.predio_t_id = pc.t_id
),
calc as (
    select
        tb2.*,
        tb1.agrupacion_id,
        tb1.tipo_agrupacion,
        va.total_interesados,
        va.total_agrupados,
        pa.suma_participacion as suma_participacion_agrupacion,
        ii.t_id as interesado_t_id,
        tb1.ci_ilicode as interesado_tipo_ilicode,
        tb1.cd_ilicode as documento_tipo_ilicode,
        ii.documento_identidad,
        ii.razon_social,
        ii.primer_nombre, ii.segundo_nombre, ii.primer_apellido, ii.segundo_apellido,
        cs.ilicode as sexo_ilicode,
        ge.ilicode as grupo_etnico_ilicode,
        coalesce(
            nullif(trim(ii.razon_social), ''),
            nullif(trim(concat_ws(' ', ii.primer_nombre, ii.segundo_nombre, ii.primer_apellido, ii.segundo_apellido)), '')
        ) as nombre_completo
    from tb2
    left join tb1 on tb1.rrr = tb2.derecho_t_id
    left join [esquema].ilc_interesado ii
        on ii.t_id = tb1.interesado_ilc_interesado
    left join [esquema].cr_sexotipo cs
        on cs.t_id = ii.sexo
    left join [esquema].ilc_autorreconocimientoetnicotipo ge
        on ge.t_id = ii.grupo_etnico
    left join validacion_agrupacion va on va.rrr = tb2.derecho_t_id
    left join participacion_agrupacion pa on pa.agrupacion = tb1.agrupacion_id
),
resultado as (
select
    predio_t_id,                     -- A
    interesado_t_id,
    numero_predial_nacional,         -- B
    tipo_de_predio,                  -- C
    fmi,                             -- D
    derecho_tipo,                    -- E
    condicion_predio,                -- F
    fuente_ilicode,                  -- G
    ente_emisor,                     -- H
    numero_fuente,                   -- I
    fecha_documento_fuente,          -- J
    fecha_inicio_tenencia,           -- K
    fecha_visita_predial,            -- L
    formal,                          -- M
    zona_rural,                      -- N
    interesado_tipo_ilicode,         -- O
    documento_tipo_ilicode,          -- P
    documento_identidad,             -- Q
    nombre_completo,                 -- R
    sexo_ilicode,                    -- S
    grupo_etnico_ilicode,            -- T
    tipo_agrupacion,                 -- U
    total_interesados,               -- V
    total_agrupados,                 -- W
    suma_participacion_agrupacion    -- X (columna Y en tu Excel)

from calc
)
-- ============================================================================
-- FILTRO: descomenta (quita el -- del inicio) UNA o varias de las lineas de abajo
-- para simular un filtro de Excel. Deja las demas comentadas. Si no descomentas
-- nada, ves todo el detalle: una fila por predio + interesado.
-- ============================================================================
select *
from resultado
where 1=1
    -- and predio_t_id = 12345                                -- un predio puntual
    -- and tipo_de_predio = 'Predio.Publico.Presunto_Baldio'   -- filtrar por tipo de predio
    -- and derecho_tipo = 'Dominio'                            -- filtrar por tipo de derecho
    -- and condicion_predio = 'Informal'                       -- filtrar por condicion del predio
    -- and fuente_ilicode = 'Sin_Documento'                    -- filtrar por tipo de fuente
    -- and formal is true                                      -- solo predios formales
    -- and formal is false                                     -- solo predios informales
    -- and zona_rural is true                                  -- solo zona rural
    -- and zona_rural is false                                 -- solo zona urbana
    -- and fmi is not null                                     -- solo predios CON folio de matricula
    -- and fmi is null                                         -- solo predios SIN folio de matricula
    -- and interesado_tipo_ilicode = 'Persona_Juridica'        -- solo personas juridicas
    -- and interesado_tipo_ilicode = 'Persona_Natural'         -- solo personas naturales
    -- and documento_tipo_ilicode = 'NIT'                      -- filtrar por tipo de documento
    -- and grupo_etnico_ilicode = 'Etnico.Indigena'            -- solo interesados indigenas
    -- and tipo_agrupacion is not null                         -- solo interesados en agrupacion
    -- and total_interesados > 1                               -- predios con mas de un interesado
order by predio_t_id, interesado_t_id;
