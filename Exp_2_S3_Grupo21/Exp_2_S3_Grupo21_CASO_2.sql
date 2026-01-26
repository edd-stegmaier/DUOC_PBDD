-- S3 - Clinica Ketekura - grupo 21

----------------------------------
--Caso 2:  medicos servicio comunidad
----------------------------------

--truncar tabla MEDICO_SERVICIO_COMUNIDAD
TRUNCATE TABLE  MEDICO_SERVICIO_COMUNIDAD;

--resetear secuencia IDENTITY a 1 para reintentar el proceso / puede aumentar aun si falla el insert 
ALTER TABLE MEDICO_SERVICIO_COMUNIDAD MODIFY id_med_scomun GENERATED ALWAYS AS IDENTITY (START WITH 1);

----------------------------------
SET SERVEROUTPUT ON;

DECLARE
    --cursor para medicos y registro
    CURSOR cur_medico IS
        SELECT 
            UNI_ID,
            TRIM(u.NOMBRE)                                                                          AS "UNIDAD", 
            m.MED_RUN,
            LPAD(REPLACE(TO_CHAR(m.MED_RUN ,'FM99G999G999'), ',','.'), 10, '0' ) || '-' || m.DV_RUN AS "RUN_MEDICO",
            SUBSTR(m.PNOMBRE || ' ' || m.SNOMBRE || ' ' || m.APATERNO || ' ' || m.AMATERNO, 1, 50)  AS "NOMBRE_MEDICO",
            SUBSTR( TRIM( u.NOMBRE), 1, 2 ) 
                || SUBSTR( TRIM( m.APATERNO ), -3, 2 ) 
                || SUBSTR( TRIM(TO_CHAR( m.MED_RUN )), -3, 3 )
                || '@medicocktk.cl'                                            AS "CORREO_INSTITUCIONAL"
        FROM      MEDICO m
        LEFT JOIN UNIDAD u USING(UNI_ID)
        ORDER BY 
            u.NOMBRE   ASC, 
            m.APATERNO ASC
    ;
    TYPE medico_tipo IS RECORD (
        UNI_ID               NUMBER(4),--UNIDAD.UNI_ID%TYPE,
        UNIDAD               VARCHAR2(50),-- UNIDAD.NOMBRE%TYPE,
        MED_RUN              MEDICO.MED_RUN%TYPE,
        RUN_MEDICO           MEDICO_SERVICIO_COMUNIDAD.RUN_MEDICO%TYPE,
        NOMBRE_MEDICO        VARCHAR2(50),
        CORREO_INSTITUCIONAL MEDICO_SERVICIO_COMUNIDAD.CORREO_INSTITUCIONAL%TYPE
    );
    reg_medico               medico_tipo;

    -- variables a calcular 
    v_total_aten_medicas     MEDICO_SERVICIO_COMUNIDAD.TOTAL_ATEN_MEDICAS%TYPE := 0;
    v_destinacion            MEDICO_SERVICIO_COMUNIDAD.DESTINACION%TYPE;
    v_max_atenciones NUMBER(3); 

    -- destinos en VARRAY
    TYPE destinos_t IS VARRAY(3) OF MEDICO_SERVICIO_COMUNIDAD.DESTINACION%TYPE;
    va_destinos destinos_t := destinos_t(
        'Servicio de Atencion Primaria de Urgencia (SAPU)',
        'Hospitales del area de la Salud Publica',
        'Centros de Salud Familiar (CESFAM)'
    );
    
    --contadores para iteraciones
    v_count_insert NUMBER(5) := 0;
    v_count_medico NUMBER(5) := 0;

BEGIN
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('          CASO 2: MEDICOS SERVICIO COMUNIDAD ');
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------');


    --maximo de atenciones el año anterior
    SELECT 
        MAX(cnt)
    INTO 
        v_max_atenciones
    FROM (
        SELECT COUNT(*) cnt
        FROM   ATENCION
        WHERE  EXTRACT(YEAR FROM FECHA_ATENCION) = EXTRACT(YEAR FROM SYSDATE) - 1
        GROUP BY MED_RUN
        );

    --recorremos cursor de medicos
    FOR reg_medico IN cur_medico LOOP

        -- total de atenciones medicas por medico año anterior
        SELECT 
            COUNT(*) 
        INTO 
            v_total_aten_medicas
        FROM ATENCION
        WHERE 
            MED_RUN = reg_medico.MED_RUN 
            AND EXTRACT(YEAR FROM FECHA_ATENCION) = EXTRACT(YEAR FROM SYSDATE) - 1
        ;

        --realizamos el proceso para la atenciones totales menor al maximo
        IF v_total_aten_medicas < v_max_atenciones THEN
            --contador de medicos procesados
            v_count_medico := v_count_medico + 1;

            v_destinacion := 
                CASE
                    WHEN reg_medico.UNI_ID IN(100, 400)                                            THEN va_destinos(1)
                    WHEN reg_medico.UNI_ID = 200        AND (v_total_aten_medicas BETWEEN 0 AND 3) THEN va_destinos(1)
                    WHEN reg_medico.UNI_ID IN(700, 800) AND (v_total_aten_medicas BETWEEN 0 AND 3) THEN va_destinos(1)
                    WHEN reg_medico.UNI_ID = 1000       AND (v_total_aten_medicas BETWEEN 0 AND 3) THEN va_destinos(1)
                    
                    WHEN reg_medico.UNI_ID = 200        AND (v_total_aten_medicas > 3)             THEN va_destinos(2)
                    WHEN reg_medico.UNI_ID IN(700, 800) AND (v_total_aten_medicas > 3)             THEN va_destinos(2)
                    WHEN reg_medico.UNI_ID = 1000       AND (v_total_aten_medicas > 3)             THEN va_destinos(2)
                    WHEN reg_medico.UNI_ID IN(900, 500)                                            THEN va_destinos(2)
                    WHEN reg_medico.UNI_ID = 300                                                   THEN va_destinos(2)

                    WHEN reg_medico.UNI_ID = 600                                                   THEN va_destinos(3)
                    ELSE ' OTRO'
                END;

            -- insert en tabla de medico_servicio_comunidad
            INSERT INTO MEDICO_SERVICIO_COMUNIDAD
            (
                UNIDAD,
                RUN_MEDICO,
                NOMBRE_MEDICO,
                CORREO_INSTITUCIONAL,
                TOTAL_ATEN_MEDICAS,
                DESTINACION
            )
            VALUES
            (
                reg_medico.UNIDAD,
                reg_medico.RUN_MEDICO,
                reg_medico.NOMBRE_MEDICO,
                reg_medico.CORREO_INSTITUCIONAL,
                v_total_aten_medicas,
                v_destinacion
            );
            
            -- control de insercion con contador
            IF SQL%FOUND THEN
                v_count_insert := v_count_insert + 1;
                DBMS_OUTPUT.PUT_LINE(' MEDICO PROCESADO: ' || reg_medico.NOMBRE_MEDICO 
                                || ' | TOTAL ATENCIONES AÑO ANTERIOR: ' || v_total_aten_medicas
                                || ' | DESTINACION: ' || v_destinacion);
            END IF;
        END IF;

    END LOOP;
    
    DBMS_OUTPUT.PUT_LINE('INSERTADO ' || v_count_insert || ' MEDICOS DE '  || v_count_medico );

    -- control de transaccion
    IF v_count_insert = v_count_medico THEN
        DBMS_OUTPUT.PUT_LINE('PROCESO EXITOSO, CONFIRMANDO');
        COMMIT;
    ELSE 
        DBMS_OUTPUT.PUT_LINE('PROCESO CON ERRORES, EJECUTANDO ROLLBACK ');
        ROLLBACK;
    END IF;

EXCEPTION
    -- manejo de errores
    WHEN OTHERS THEN 
        DBMS_OUTPUT.PUT_LINE('ERROR CONTROLADO: ' || SQLERRM);
        ROLLBACK;
END;
/

/*
-- select de prueba
SELECT 
    TRIM(u.NOMBRE) AS "UNIDAD", 
    REPLACE(TO_CHAR(m.MED_RUN ,'FM99G999G999'), ',','.') || '-' || m.DV_RUN AS "RUN_MEDICO",
    m.PNOMBRE || ' ' || m.SNOMBRE || ' ' || m.APATERNO || ' ' || m.AMATERNO AS "NOMBRE_MEDICO",
    SUBSTR( TRIM( u.NOMBRE), 1, 2 ) 
     || SUBSTR( TRIM( m.APATERNO ), -2, 2 ) 
     || SUBSTR( TO_CHAR( m.MED_RUN ), -1, 3 ) 
    AS "CORREO_INSTITUCIONAL"
FROM MEDICO m
LEFT JOIN UNIDAD u USING(UNI_ID)
ORDER BY 
    u.NOMBRE ASC, 
    m.APATERNO ASC
;

SELECT MAX(COUNT(*))
FROM   ATENCION
WHERE 
    EXTRACT(YEAR FROM FECHA_ATENCION) = EXTRACT(YEAR FROM SYSDATE) - 1
GROUP BY MED_RUN
;
*/