-- SUPER CONSULTA: Reglas de consistencia juridicas 2.1 a 2.41 (LADM_COL 1.0)
-- Esquema real de la base: o_70523_00_01_20250627_l3_h5_r3
--
-- Convencion de marca por regla (columnas r2_1 .. r2_41):
--   0    = la regla APLICA a esta fila y SE CUMPLE
--   1    = la regla APLICA a esta fila y NO SE CUMPLE (error)
--   NULL = la regla NO APLICA a esta fila (no cumple las condiciones de entrada de la regla)
--
-- SUPUESTOS / LIMITACIONES:
--  - "La Nacion", "INCORA", "INCODER", "ANT", "Municipio", EDP: se detectan por texto libre
--    (razon_social / nombre del interesado) via expresiones regulares, NO por catalogo
--    estructurado (no existe FK de interesado a un catalogo de entidades).
--  - "EDP" para 2.4, 2.5, 2.8: heuristica ampliada (nacion, municipio, departamento/
--    gobernacion, alcaldia, instituto, superintendencia, agencia, unidad administrativa
--    especial). Revisar contra el listado oficial de EDP si existe.
--  - Formal/informal: posicion 22 del numero_predial_nacional = '2' => informal (mismo
--    criterio de tus scripts existentes).
--  - Zona rural/urbana: substring(numero_predial_nacional,6,2) = '00' => rural.
--  - 2.28/2.29: no se valida mecanicamente la excepcion "Secuencial solo cuando no fue
--    posible identificar el documento"; se acepta Secuencial siempre como valido.
--  - 2.31: solo valida formato (digitos + guion opcional de 1 digito); NO detecta
--    secuencias consecutivas tipo 12345678-9 ni digito de verificacion modulo 11.
--  - 2.24: comparacion de nombre_completo tal cual esta escrito (sin normalizar mayusculas/
--    tildes). Ver validacion_mismo_interesado_diferente_documento.sql para version normalizada.

with tb1 as (
    select
        cr.rrr,
        cm.interesado_ilc_interesado as interesado_ilc_interesado,
        cm.agrupacion as agrupacion_id,
        ci.ilicode as ci_ilicode,
        cd.ilicode as cd_ilicode,
        gt.ilicode as tipo_agrupacion
    from o_70523_00_01_20250627_l3_h5_r3.col_rrrinteresado cr
    inner join o_70523_00_01_20250627_l3_h5_r3.col_miembros cm
        on cm.agrupacion = cr.interesado_cr_agrupacioninteresados
    inner join o_70523_00_01_20250627_l3_h5_r3.ilc_interesado ii
        on ii.t_id = cm.interesado_ilc_interesado
    inner join o_70523_00_01_20250627_l3_h5_r3.cr_documentotipo cd
        on cd.t_id = ii.tipo_documento
    inner join o_70523_00_01_20250627_l3_h5_r3.cr_interesadotipo ci
        on ci.t_id = ii.tipo
    inner join o_70523_00_01_20250627_l3_h5_r3.cr_agrupacioninteresados ag
        on ag.t_id = cm.agrupacion
    left join o_70523_00_01_20250627_l3_h5_r3.col_grupointeresadotipo gt
        on gt.t_id = ag.tipo
    UNION
    select
        cr.rrr,
        cr.interesado_ilc_interesado,
        null as agrupacion_id,
        ci.ilicode as ci_ilicode,
        cd.ilicode as cd_ilicode,
        null as tipo_agrupacion
    from o_70523_00_01_20250627_l3_h5_r3.col_rrrinteresado cr
    inner join o_70523_00_01_20250627_l3_h5_r3.ilc_interesado ii
        on ii.t_id = cr.interesado_ilc_interesado
    inner join o_70523_00_01_20250627_l3_h5_r3.cr_documentotipo cd
        on cd.t_id = ii.tipo_documento
    inner join o_70523_00_01_20250627_l3_h5_r3.cr_interesadotipo ci
        on ci.t_id = ii.tipo
    where not exists (
        select 1
        from o_70523_00_01_20250627_l3_h5_r3.col_rrrinteresado cr2
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
    from o_70523_00_01_20250627_l3_h5_r3.col_miembros
    group by agrupacion
),
tipos_por_agrupacion as (
    select
        cm.agrupacion,
        bool_or(ci.ilicode = 'Persona_Natural') as tiene_natural,
        bool_or(ci.ilicode = 'Persona_Juridica') as tiene_juridica
    from o_70523_00_01_20250627_l3_h5_r3.col_miembros cm
    inner join o_70523_00_01_20250627_l3_h5_r3.ilc_interesado ii
        on ii.t_id = cm.interesado_ilc_interesado
    inner join o_70523_00_01_20250627_l3_h5_r3.cr_interesadotipo ci
        on ci.t_id = ii.tipo
    group by cm.agrupacion
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
    from o_70523_00_01_20250627_l3_h5_r3.ilc_derecho pd
    left join tb1 on tb1.rrr = pd.t_id
    left join o_70523_00_01_20250627_l3_h5_r3.ilc_interesado ii2
        on ii2.t_id = tb1.interesado_ilc_interesado
    group by pd.unidad
),
novedades_por_predio as (
    select
        dalc.ilc_predio as predio_t_id,
        string_agg(distinct tn.ilicode, '; ' order by tn.ilicode) as novedades
    from o_70523_00_01_20250627_l3_h5_r3.ilc_datosadicionaleslevantamientocatastral dalc
    inner join o_70523_00_01_20250627_l3_h5_r3.ilc_estructuranovedadnumeropredial enp
        on enp.ilc_dtsdcnltmntctstral_novedad_numeros_prediales = dalc.t_id
    inner join o_70523_00_01_20250627_l3_h5_r3.ilc_estructuranovedadnumeropredial_tipo_novedad tn
        on tn.t_id = enp.tipo_novedad
    group by dalc.ilc_predio
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
        pd.fecha_inicio_tenencia,
        dalc.fecha_visita_predial,
        case when pi.igc_predio_formal is not null then 'INFORMAL' end as condicion_informalidad_registro,
        ipf.interesados_concat as interesado_predio_formal,
        np.novedades,
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
    from o_70523_00_01_20250627_l3_h5_r3.ilc_predio pc
    left join o_70523_00_01_20250627_l3_h5_r3.ilc_derecho pd
        on pd.unidad = pc.t_id
    left join o_70523_00_01_20250627_l3_h5_r3.ilc_derechocatastraltipo id
        on id.t_id = pd.tipo
    left join o_70523_00_01_20250627_l3_h5_r3.col_rrrfuente cr
        on cr.rrr = pd.t_id
    left join o_70523_00_01_20250627_l3_h5_r3.ilc_fuenteadministrativa fa
        on fa.t_id = cr.fuente_administrativa
    left join o_70523_00_01_20250627_l3_h5_r3.col_fuenteadministrativatipo cf
        on fa.tipo = cf.t_id
    left join o_70523_00_01_20250627_l3_h5_r3.ilc_prediotipo ip
        on ip.t_id = pc.tipo
    left join o_70523_00_01_20250627_l3_h5_r3.ilc_condicionprediotipo cp
        on cp.t_id = pc.condicion_predio
    left join o_70523_00_01_20250627_l3_h5_r3.ilc_datosadicionaleslevantamientocatastral dalc
        on dalc.ilc_predio = pc.t_id
    left join o_70523_00_01_20250627_l3_h5_r3.ilc_predio_informalidad pi
        on pi.igc_predio_informal = pc.t_id
    left join interesados_por_predio ipf
        on ipf.predio_t_id = pi.igc_predio_formal
    left join novedades_por_predio np
        on np.predio_t_id = pc.t_id
),
calc as (
    select
        tb2.*,
        tb1.agrupacion_id,
        tb1.tipo_agrupacion,
        va.total_interesados,
        va.total_agrupados,
        pa.suma_participacion as suma_participacion_agrupacion,
        pa.miembros_con_participacion as pa_miembros_con_participacion,
        tpa.tiene_natural as agrup_tiene_natural,
        tpa.tiene_juridica as agrup_tiene_juridica,
        ii.t_id as interesado_t_id,
        tb1.ci_ilicode as interesado_tipo_ilicode,
        tb1.cd_ilicode as documento_tipo_ilicode,
        ii.documento_identidad,
        ii.razon_social,
        ii.primer_nombre, ii.segundo_nombre, ii.primer_apellido, ii.segundo_apellido,
        cs.ilicode as sexo_ilicode,
        ge.ilicode as grupo_etnico_ilicode,
        ie.t_id as identificacion_etnica_t_id,
        coalesce(
            nullif(trim(ii.razon_social), ''),
            nullif(trim(concat_ws(' ', ii.primer_nombre, ii.segundo_nombre, ii.primer_apellido, ii.segundo_apellido)), '')
        ) as nombre_completo,
        (tb2.fmi is not null) as tiene_fmi,
        (tb2.tipo_de_predio ilike 'Predio.Publico.%') as es_publico,
        (tb2.tipo_de_predio ilike 'Predio.Privado.%') as es_privado
    from tb2
    left join tb1 on tb1.rrr = tb2.derecho_t_id
    left join o_70523_00_01_20250627_l3_h5_r3.ilc_interesado ii
        on ii.t_id = tb1.interesado_ilc_interesado
    left join o_70523_00_01_20250627_l3_h5_r3.cr_sexotipo cs
        on cs.t_id = ii.sexo
    left join o_70523_00_01_20250627_l3_h5_r3.ilc_autorreconocimientoetnicotipo ge
        on ge.t_id = ii.grupo_etnico
    left join o_70523_00_01_20250627_l3_h5_r3.ilc_identificacionetnica ie
        on ie.lc_identificacionetnica = ii.t_id
    left join validacion_agrupacion va on va.rrr = tb2.derecho_t_id
    left join participacion_agrupacion pa on pa.agrupacion = tb1.agrupacion_id
    left join tipos_por_agrupacion tpa on tpa.agrupacion = tb1.agrupacion_id
),
final as (
    select
        calc.*,
        (coalesce(nombre_completo,'') ~* '\y(LA NACION|NACION)\y') as es_nacion,
        (coalesce(nombre_completo,'') ~* '\yINCORA\y') as es_incora,
        (coalesce(nombre_completo,'') ~* '\yINCODER\y') as es_incoder,
        (coalesce(nombre_completo,'') ~* '(\yANT\y|AGENCIA NACIONAL DE TIERRAS)') as es_ant,
        (coalesce(nombre_completo,'') ~* '\yMUNICIPIO\y') as es_municipio,
        (coalesce(nombre_completo,'') ~* '\y(DEPARTAMENTO|GOBERNACION)\y') as es_departamento_gobernacion,
        (fuente_ilicode in ('Documento_Fuente.Acto_Administrativo','Documento_Fuente.Escritura_Publica','Documento_Fuente.Sentencia_Judicial')) as fuente_acto_escritura_sentencia,
        (fuente_ilicode in ('Documento_Fuente.Documento_Privado','Sin_Documento')) as fuente_privado_o_sin_doc
    from calc
),
dup_nombre_documento as (
    select nombre_completo, documento_identidad, count(distinct interesado_t_id) as n
    from final
    where nombre_completo is not null and nullif(trim(documento_identidad),'') is not null
    group by nombre_completo, documento_identidad
),
dup_documento as (
    select documento_identidad, count(distinct interesado_t_id) as n
    from final
    where nullif(trim(documento_identidad),'') is not null
    group by documento_identidad
)
select
    f.predio_t_id,
    f.numero_predial_nacional,
    f.tipo_de_predio,
    f.fmi,
    f.derecho_tipo,
    f.condicion_predio,
    f.fuente_ilicode,
    f.ente_emisor,
    f.numero_fuente,
    f.fecha_documento_fuente,
    f.fecha_inicio_tenencia,
    f.fecha_visita_predial,
    f.novedades,
    f.formal,
    f.zona_rural,
    f.interesado_tipo_ilicode,
    f.documento_tipo_ilicode,
    f.documento_identidad,
    f.nombre_completo,
    f.sexo_ilicode,
    f.grupo_etnico_ilicode,
    f.tipo_agrupacion,
    f.total_interesados,
    f.total_agrupados,
    f.suma_participacion_agrupacion,

    -- 2.1
    case when f.derecho_tipo in ('Ocupacion','Posesion') then
        case when (f.derecho_tipo='Ocupacion' and f.es_publico) or (f.derecho_tipo='Posesion' and f.es_privado)
             then 0 else 1 end
    end as r2_1,

    -- 2.2
    case when f.tipo_de_predio='Predio.Publico.Baldio.Baldio' and f.zona_rural is true and f.formal is true then
        case when f.derecho_tipo='Dominio' and f.tiene_fmi and (f.es_nacion or f.es_incora or f.es_incoder or f.es_ant)
                  and f.fuente_ilicode='Documento_Fuente.Acto_Administrativo'
                  and nullif(trim(f.ente_emisor),'') is not null
             then 0 else 1 end
    end as r2_2,

    -- 2.3
    case when f.tipo_de_predio='Predio.Publico.Baldio.Baldio' and f.zona_rural is true and f.formal is false then
        case when f.derecho_tipo='Ocupacion' and not f.tiene_fmi
                  and not (f.es_nacion or f.es_incora or f.es_incoder or f.es_ant)
                  and f.fuente_privado_o_sin_doc
             then 0 else 1 end
    end as r2_3,

    -- 2.4
    case when f.tipo_de_predio='Predio.Publico.Uso_Publico' and f.formal is true and f.tiene_fmi then
        case when f.derecho_tipo='Dominio'
                  and (f.es_nacion or f.es_municipio or f.es_departamento_gobernacion
                       or coalesce(f.nombre_completo,'') ~* '\y(ALCALDIA|INSTITUTO|SUPERINTENDENCIA|AGENCIA|UNIDAD ADMINISTRATIVA ESPECIAL|ENTIDAD PUBLICA|CENTRO EDUCATIVO|INSTITUCION EDUCATIVA|COLEGIO|ESCUELA|SOCIEDAD DE ACTIVOS ESPECIALES)\y')
                  and f.fuente_acto_escritura_sentencia
             then 0 else 1 end
    end as r2_4,

    -- 2.5
    case when f.tipo_de_predio='Predio.Publico.Uso_Publico' and f.formal is true and not f.tiene_fmi then
        case when f.derecho_tipo='Dominio'
                  and (f.es_nacion or f.es_municipio or f.es_departamento_gobernacion
                       or coalesce(f.nombre_completo,'') ~* '\y(ALCALDIA|INSTITUTO|SUPERINTENDENCIA|AGENCIA|UNIDAD ADMINISTRATIVA ESPECIAL|ENTIDAD PUBLICA|CENTRO EDUCATIVO|INSTITUCION EDUCATIVA|COLEGIO|ESCUELA|SOCIEDAD DE ACTIVOS ESPECIALES)\y')
                  and f.fuente_ilicode='Sin_Documento'
             then 0 else 1 end
    end as r2_5,

    -- 2.6
    case when f.tipo_de_predio='Predio.Publico.Uso_Publico' and f.formal is false then
        case when f.derecho_tipo='Ocupacion' and not f.tiene_fmi
                  and (f.interesado_predio_formal is null or f.nombre_completo is distinct from f.interesado_predio_formal)
                  and f.fuente_privado_o_sin_doc
             then 0 else 1 end
    end as r2_6,

    -- 2.7
    case when f.tipo_de_predio='Predio.Publico.Fiscal_Patrimonial' and f.formal is true then
        case when f.derecho_tipo='Dominio' and f.tiene_fmi and f.fuente_acto_escritura_sentencia
             then 0 else 1 end
    end as r2_7,

    -- 2.8
    case when f.tipo_de_predio='Predio.Publico.Fiscal_Patrimonial' and f.formal is true then
        case when f.interesado_tipo_ilicode='Persona_Juridica'
                  and (f.es_nacion or f.es_municipio or f.es_departamento_gobernacion or f.es_incora or f.es_incoder or f.es_ant
                       or coalesce(f.nombre_completo,'') ~* '\y(ALCALDIA|INSTITUTO|SUPERINTENDENCIA|AGENCIA|UNIDAD ADMINISTRATIVA ESPECIAL|ENTIDAD PUBLICA|CENTRO EDUCATIVO|INSTITUCION EDUCATIVA|COLEGIO|ESCUELA|SOCIEDAD DE ACTIVOS ESPECIALES)\y')
             then 0 else 1 end
    end as r2_8,

    -- 2.9
    case when f.tipo_de_predio='Predio.Publico.Fiscal_Patrimonial' and f.formal is false then
        case when f.derecho_tipo='Ocupacion' and not f.tiene_fmi and f.fuente_privado_o_sin_doc
             then 0 else 1 end
    end as r2_9,

    -- 2.10
    case when f.tipo_de_predio='Predio.Publico.Fiscal_Patrimonial' and f.formal is false then
        case when f.interesado_predio_formal is null or f.nombre_completo is distinct from f.interesado_predio_formal
             then 0 else 1 end
    end as r2_10,

    -- 2.11
    case when f.tipo_de_predio='Predio.Publico.Presunto_Baldio' and f.formal is true and f.tiene_fmi then
        case when f.derecho_tipo='Dominio' and (f.es_nacion or f.es_municipio) and f.fuente_acto_escritura_sentencia
             then 0 else 1 end
    end as r2_11,

    -- 2.12
    case when f.tipo_de_predio='Predio.Publico.Presunto_Baldio' and f.formal is true and not f.tiene_fmi then
        case when f.derecho_tipo='Dominio'
                  and ((f.zona_rural is true and f.es_nacion) or (f.zona_rural is false and f.es_municipio))
                  and f.fuente_ilicode='Sin_Documento'
             then 0 else 1 end
    end as r2_12,

    -- 2.13
    case when f.tipo_de_predio='Predio.Publico.Presunto_Baldio' and f.formal is false and f.tiene_fmi then
        case when f.derecho_tipo='Ocupacion' and not (f.es_nacion or f.es_municipio) and f.fuente_acto_escritura_sentencia
             then 0 else 1 end
    end as r2_13,

    -- 2.14
    case when f.tipo_de_predio='Predio.Publico.Presunto_Baldio' and f.formal is false and not f.tiene_fmi then
        case when f.derecho_tipo='Ocupacion' and not (f.es_nacion or f.es_municipio) and f.fuente_privado_o_sin_doc
             then 0 else 1 end
    end as r2_14,

    -- 2.15
    case when f.tipo_de_predio='Predio.Privado.Privado' and f.formal is true then
        case when f.derecho_tipo='Dominio' and f.tiene_fmi and f.fuente_acto_escritura_sentencia
             then 0 else 1 end
    end as r2_15,

    -- 2.16
    case when f.tipo_de_predio='Predio.Privado.Privado' and f.formal is false then
        case when f.derecho_tipo='Posesion'
                  and ((f.tiene_fmi and f.fuente_acto_escritura_sentencia) or (not f.tiene_fmi and f.fuente_privado_o_sin_doc))
             then 0 else 1 end
    end as r2_16,

    -- 2.17
    case when f.derecho_t_id is not null then
        case when f.fecha_inicio_tenencia is not null
                  and (f.fecha_visita_predial is null or f.fecha_inicio_tenencia < f.fecha_visita_predial)
             then 0 else 1 end
    end as r2_17,

    -- 2.18
    case when f.tiene_fmi and f.fecha_inicio_tenencia is not null and f.fecha_documento_fuente is not null then
        case when f.fecha_inicio_tenencia >= f.fecha_documento_fuente then 0 else 1 end
    end as r2_18,

    -- 2.19
    case when f.derecho_tipo='Dominio' and f.tipo_de_predio in ('Predio.Publico.Uso_Publico','Predio.Publico.Presunto_Baldio') and not f.tiene_fmi then
        case when f.fecha_inicio_tenencia = (case when f.zona_rural is true then date '1936-12-04' else date '1959-12-31' end)
             then 0 else 1 end
    end as r2_19,

    -- 2.20
    case when f.tiene_fmi then
        case when f.fecha_documento_fuente is not null and f.fuente_ilicode is not null
                  and nullif(trim(f.numero_fuente),'') is not null and nullif(trim(f.ente_emisor),'') is not null
                  and (f.fecha_visita_predial is null or f.fecha_documento_fuente <= f.fecha_visita_predial)
             then 0 else 1 end
    end as r2_20,

    -- 2.21
    case when f.fuente_ilicode is not null then
        case
            when f.fuente_ilicode <> 'Sin_Documento'
                 and (nullif(trim(f.ente_emisor),'') is null or nullif(trim(f.numero_fuente),'') is null or f.fecha_documento_fuente is null)
                then 1
            when f.fuente_ilicode = 'Sin_Documento'
                 and (nullif(trim(f.ente_emisor),'') is not null or nullif(trim(f.numero_fuente),'') is not null or f.fecha_documento_fuente is not null)
                then 1
            else 0
        end
    end as r2_21,

    -- 2.22
    case when f.fuente_ilicode is not null and f.fuente_ilicode <> 'Sin_Documento' then
        case
            when f.fuente_ilicode in ('Documento_Fuente.Escritura_Publica','Fuente_Informativa_Intercultural.Protocolizacion_Notarial')
                then case when nullif(trim(f.ente_emisor),'') is not null and f.ente_emisor ~* 'notar' then 0 else 1 end
            when f.fuente_ilicode = 'Documento_Fuente.Sentencia_Judicial'
                then case when nullif(trim(f.ente_emisor),'') is not null and f.ente_emisor ~* '(juzgado|tribunal|corte)' then 0 else 1 end
            when f.fuente_ilicode = 'Fuente_Informativa_Intercultural.Mandato_Propio_Indigena'
                then case when nullif(trim(f.ente_emisor),'') is not null and f.ente_emisor ~* '(cabildo|resguardo|autoridad ind[ií]gena)' then 0 else 1 end
            else case when nullif(trim(f.ente_emisor),'') is not null then 0 else 1 end
        end
    end as r2_22,

    -- 2.23
    case when f.total_interesados is null or f.total_interesados = 0 then 1 else 0 end as r2_23,

    -- 2.24
    case when f.interesado_t_id is not null and f.nombre_completo is not null and nullif(trim(f.documento_identidad),'') is not null then
        case when dnd.n > 1 then 1 else 0 end
    end as r2_24,

    -- 2.25
    case when f.interesado_t_id is not null and nullif(trim(f.documento_identidad),'') is not null then
        case when dd.n > 1 then 1 else 0 end
    end as r2_25,

    -- 2.26
    case when f.tipo_de_predio='Predio.Privado.Colectivo' then
        case when f.grupo_etnico_ilicode is not null and f.grupo_etnico_ilicode <> 'Ninguno' then 0 else 1 end
    end as r2_26,

    -- 2.27
    case when f.condicion_predio in ('Via','Bien_Uso_Publico') then
        case when f.tipo_de_predio='Predio.Publico.Uso_Publico' and f.derecho_tipo='Dominio' then 0 else 1 end
    end as r2_27,

    -- 2.28
    case when f.interesado_tipo_ilicode='Persona_Juridica' then
        case when f.documento_tipo_ilicode in ('NIT','Secuencial') then 0 else 1 end
    end as r2_28,

    -- 2.29
    case when f.interesado_tipo_ilicode='Persona_Natural' then
        case when f.documento_tipo_ilicode in ('Cedula_Ciudadania','Pasaporte','Cedula_Extranjeria','Tarjeta_Identidad','Registro_Civil','Secuencial')
             then 0 else 1 end
    end as r2_29,

    -- 2.30
    case when f.documento_tipo_ilicode in ('Cedula_Ciudadania','Cedula_Extranjeria','Tarjeta_Identidad','Registro_Civil') then
        case when nullif(trim(f.documento_identidad),'') is not null and trim(f.documento_identidad) <> '0' then 0 else 1 end
    end as r2_30,

    -- 2.31
    case when f.documento_tipo_ilicode = 'NIT' then
        case when nullif(trim(f.documento_identidad),'') is not null
                  and trim(f.documento_identidad) <> '0'
                  and f.documento_identidad ~ '^[0-9]+(-[0-9])?$'
             then 0 else 1 end
    end as r2_31,

    -- 2.32
    case
        when f.interesado_tipo_ilicode='Persona_Natural' then
            case when nullif(trim(f.primer_nombre),'') is not null
                      and nullif(trim(f.primer_apellido),'') is not null
                      and f.primer_nombre ~ '^[A-Za-zÁÉÍÓÚÑÜáéíóúñü ]+$'
                      and f.primer_apellido ~ '^[A-Za-zÁÉÍÓÚÑÜáéíóúñü ]+$'
                      and nullif(trim(f.razon_social),'') is null
                 then 0 else 1 end
        when f.interesado_tipo_ilicode='Persona_Juridica' then
            case when nullif(trim(f.primer_nombre),'') is null
                      and nullif(trim(f.segundo_nombre),'') is null
                      and nullif(trim(f.primer_apellido),'') is null
                      and nullif(trim(f.segundo_apellido),'') is null
                      and nullif(trim(f.razon_social),'') is not null
                 then 0 else 1 end
    end as r2_32,

    -- 2.33
    case when f.interesado_tipo_ilicode='Persona_Natural' then
        case when coalesce(f.primer_nombre,'') ~* '\ySUC\y' or coalesce(f.segundo_nombre,'') ~* '\ySUC\y'
                  or coalesce(f.primer_apellido,'') ~* '\ySUC\y' or coalesce(f.segundo_apellido,'') ~* '\ySUC\y'
             then 1 else 0 end
    end as r2_33,

    -- 2.34
    case when f.interesado_t_id is not null then
        case
            when f.interesado_tipo_ilicode='Persona_Natural' and f.sexo_ilicode is null then 1
            when f.interesado_tipo_ilicode='Persona_Juridica' and f.sexo_ilicode is not null then 1
            else 0
        end
    end as r2_34,

    -- 2.35
    case when f.interesado_tipo_ilicode='Persona_Natural' then
        case when coalesce(f.primer_nombre,'') ~* '\y(SAS|LTDA|SOCIEDAD|EMPRESA|FUNDACION|CORPORACION|COOPERATIVA|ASOCIACION|SUCESION|SUC|CIA|COMPA[NÑ]IA|LIMITADA|ANONIMA|UNIPERSONAL|CONSORCIO|ESAL|ONG|NIT)\y'
                  or coalesce(f.segundo_nombre,'') ~* '\y(SAS|LTDA|SOCIEDAD|EMPRESA|FUNDACION|CORPORACION|COOPERATIVA|ASOCIACION|SUCESION|SUC|CIA|COMPA[NÑ]IA|LIMITADA|ANONIMA|UNIPERSONAL|CONSORCIO|ESAL|ONG|NIT)\y'
                  or coalesce(f.primer_apellido,'') ~* '\y(SAS|LTDA|SOCIEDAD|EMPRESA|FUNDACION|CORPORACION|COOPERATIVA|ASOCIACION|SUCESION|SUC|CIA|COMPA[NÑ]IA|LIMITADA|ANONIMA|UNIPERSONAL|CONSORCIO|ESAL|ONG|NIT)\y'
                  or coalesce(f.segundo_apellido,'') ~* '\y(SAS|LTDA|SOCIEDAD|EMPRESA|FUNDACION|CORPORACION|COOPERATIVA|ASOCIACION|SUCESION|SUC|CIA|COMPA[NÑ]IA|LIMITADA|ANONIMA|UNIPERSONAL|CONSORCIO|ESAL|ONG|NIT)\y'
             then 1 else 0 end
    end as r2_35,

    -- 2.36
    case when f.agrupacion_id is not null then
        case when f.agrup_tiene_natural and f.agrup_tiene_juridica then
            case when f.tipo_agrupacion is distinct from 'Grupo_Mixto' then 1 else 0 end
        end
    end as r2_36,

    -- 2.37
    case when f.agrupacion_id is not null then
        case when f.agrup_tiene_natural and not f.agrup_tiene_juridica then
            case when f.tipo_agrupacion is distinct from 'Grupo_Civil' then 1 else 0 end
        end
    end as r2_37,

    -- 2.38
    case when f.agrupacion_id is not null then
        case when f.agrup_tiene_juridica and not f.agrup_tiene_natural then
            case when f.tipo_agrupacion is distinct from 'Grupo_Empresarial' then 1 else 0 end
        end
    end as r2_38,

    -- 2.39
    case when f.grupo_etnico_ilicode = 'Etnico.Indigena' then
        case when f.identificacion_etnica_t_id is not null then 0 else 1 end
    end as r2_39,

    -- 2.40
    case when f.total_interesados > 1 then
        case when f.total_agrupados > 0 then 0 else 1 end
    end as r2_40,

    -- 2.41 (version original: exige sum=1 solo si ademas la participacion esta detallada)
    case when f.agrupacion_id is not null then
        case
            when f.tiene_fmi and f.pa_miembros_con_participacion > 0 then
                case when f.suma_participacion_agrupacion is distinct from 1 then 1 else 0 end
            else
                case when coalesce(f.suma_participacion_agrupacion,0) <> 0 then 1 else 0 end
        end
    end as r2_41,

    -- 2.41 (version estricta: para predios CON FMI exige sum=1 sin importar si la
    -- participacion fue diligenciada o no -- si esta vacia (NULL), se marca como error).
    -- Ver conversacion: de 156 agrupaciones, 87 estan ligadas a predios con FMI y NINGUNA
    -- tiene participacion diligenciada hoy, por eso esta version muestra 87 errores.
    case when f.agrupacion_id is not null then
        case
            when f.tiene_fmi then
                case when f.suma_participacion_agrupacion is distinct from 1 then 1 else 0 end
            else
                case when coalesce(f.suma_participacion_agrupacion,0) <> 0 then 1 else 0 end
        end
    end as r2_41_estricta

from final f
left join dup_nombre_documento dnd
    on dnd.nombre_completo = f.nombre_completo and dnd.documento_identidad = f.documento_identidad
left join dup_documento dd
    on dd.documento_identidad = f.documento_identidad
order by f.predio_t_id, f.interesado_t_id;
