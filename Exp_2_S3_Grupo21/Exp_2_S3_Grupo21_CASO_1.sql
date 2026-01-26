-- S3 - Clinica Ketekura - grupo 21

---------------------------------------------------
--Caso 1: Pagos Morosos
---------------------------------------------------

--truncar tabla PAGO_MOROSO
TRUNCATE TABLE PAGO_MOROSO;

SET SERVEROUTPUT ON;

DECLARE
    --cursor para pagos
    CURSOR cur_pago_moroso IS
        SELECT 
            PAC_RUN,
            p.DV_RUN  AS "PAC_DV_RUN",
            p.PNOMBRE || ' ' || p.SNOMBRE || ' ' || p.APATERNO || ' ' || p.AMATERNO AS "PAC_NOMBRE",
            p.FECHA_NACIMIENTO,
            ATE_ID,
            pa.FECHA_VENC_PAGO,
            pa.FECHA_PAGO,
            ESP_ID,
            e.NOMBRE  AS "ESPECIALIDAD_ATENCION"

        FROM PAGO_ATENCION pa
        LEFT JOIN ATENCION a             USING(ATE_ID)
        LEFT JOIN PACIENTE p             USING(PAC_RUN)
        LEFT JOIN ESPECIALIDAD_MEDICO em USING(MED_RUN,ESP_ID)
        LEFT JOIN ESPECIALIDAD e         USING(ESP_ID)
        WHERE 
            pa.FECHA_PAGO > pa.FECHA_VENC_PAGO AND 
            EXTRACT(YEAR FROM a.FECHA_ATENCION) = EXTRACT(YEAR FROM SYSDATE) - 1
        ORDER BY 
            pa.FECHA_VENC_PAGO ASC, 
            p.APATERNO DESC
    ;

    --registro de pago atencion
    TYPE pago_atencion_tipo IS RECORD (
        PAC_RUN               PACIENTE.PAC_RUN%TYPE,
        PAC_DV_RUN            PACIENTE.DV_RUN%TYPE,
        PAC_NOMBRE            VARCHAR2(200),
        FECHA_NACIMIENTO      PACIENTE.FECHA_NACIMIENTO%TYPE,
        ATE_ID                PAGO_ATENCION.ATE_ID%TYPE,
        FECHA_VENC_PAGO       PAGO_ATENCION.FECHA_VENC_PAGO%TYPE,
        FECHA_PAGO            PAGO_ATENCION.FECHA_PAGO%TYPE,
        ESP_ID                NUMBER(4),
        ESPECIALIDAD_ATENCION VARCHAR2(40)
    );
    reg_pago                  pago_atencion_tipo;

    ---------------------------------------------
    --variables para calcular multa

    -- multas por dia segun especialidad
    -- VARRAY para multas y especialidades
    TYPE t_multas          IS VARRAY(7)  OF NUMBER(5);
    TYPE t_id_especialidad IS VARRAY(12) OF NUMBER(4);

    va_multas t_multas := t_multas(
        1200,   -- 1: Cirugía General y Dermatología 
        1300,   -- 2: Ortopedia y Traumatología
        1700,   -- 3: Inmunología y Otorrinolaringología
        1900,   -- 4: Fisiatría y Medicina Interna
        1100,   -- 5: Medicina General
        2000,   -- 6: Psiquiatría Adultos
        2300    -- 7: Cirugía Digestiva y Reumatología
    );

    va_id_especialidad t_id_especialidad := t_id_especialidad(
        100,300,
        200,
        400,900,
        500,600,
        700,
        1100,
        1400,1800
    );

    v_dias_morosidad NUMBER(4);
    v_multa_dia      NUMBER(5);
    v_monto_multa    NUMBER(6);

    -----------------------------------------------
    -- contadores para la cantidad total de pagos / las inserciones correctas
    v_count_pago     NUMBER(5) := 0;
    v_count_insert   NUMBER(5) := 0;

    ----------------------------------------------
    --variables para calculos de descuentos tercera edad

    --con cursor / registro para la tabla de Descuentos
    CURSOR cur_desc IS
        SELECT 
            ANNO_INI,
            ANNO_TER,
            PORCENTAJE_DESCTO
        FROM PORC_DESCTO_3RA_EDAD
    ;
    TYPE desc_tipo IS RECORD (
        ANNO_INI            PORC_DESCTO_3RA_EDAD.ANNO_INI%TYPE,
        ANNO_TER            PORC_DESCTO_3RA_EDAD.ANNO_TER%TYPE,
        PORCENTAJE_DESCTO   PORC_DESCTO_3RA_EDAD.PORCENTAJE_DESCTO%TYPE
    );
    reg_desc                desc_tipo;

    -- edad / porcentaje descuento 0 por defecto
    v_edad           NUMBER(3);
    v_porc_desc      NUMBER(2) := 0;

BEGIN
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('              CASO 1: PAGO MOROSO');
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------------');
    

    --FOR cursor de pagos
    FOR reg_pago IN cur_pago_moroso LOOP
    
        --contador de pagos procesados
        v_count_pago := v_count_pago + 1;
        
        --dias de atraso
        v_dias_morosidad := (reg_pago.FECHA_PAGO - reg_pago.FECHA_VENC_PAGO);

        v_multa_dia :=
            CASE
                WHEN reg_pago.ESP_ID IN (va_id_especialidad(1), va_id_especialidad(2))   THEN va_multas(1)
                WHEN reg_pago.ESP_ID =   va_id_especialidad(3)                           THEN va_multas(2)
                WHEN reg_pago.ESP_ID IN (va_id_especialidad(4), va_id_especialidad(5))   THEN va_multas(3)
                WHEN reg_pago.ESP_ID IN (va_id_especialidad(6), va_id_especialidad(7))   THEN va_multas(4)
                WHEN reg_pago.ESP_ID =   va_id_especialidad(8)                           THEN va_multas(5)
                WHEN reg_pago.ESP_ID =   va_id_especialidad(9)                           THEN va_multas(6)
                WHEN reg_pago.ESP_ID IN (va_id_especialidad(10), va_id_especialidad(11)) THEN va_multas(7)
                ELSE 0
            END;
        
        --calculamos monto total multa
        v_monto_multa := v_dias_morosidad * v_multa_dia;

        --edad
        v_edad := EXTRACT(YEAR FROM SYSDATE) - EXTRACT(YEAR FROM reg_pago.FECHA_NACIMIENTO);

        --encontramos el porcentaje descuento tercera edad si aplica
        FOR reg_desc IN cur_desc LOOP
            IF v_edad BETWEEN reg_desc.ANNO_INI AND reg_desc.ANNO_TER THEN 
                v_porc_desc := reg_desc.PORCENTAJE_DESCTO;
            END IF; --si no aplica queda en 0
        END LOOP;

        --total multa con descuento aplicado
        v_monto_multa := v_monto_multa * (1 - (v_porc_desc/100) );


        --insertar datos
        INSERT INTO PAGO_MOROSO
        VALUES(
            reg_pago.PAC_RUN,  
            reg_pago.PAC_DV_RUN, 
            reg_pago.PAC_NOMBRE, 
            reg_pago.ATE_ID, 
            reg_pago.FECHA_VENC_PAGO, 
            reg_pago.FECHA_PAGO, 
            v_dias_morosidad, 
            reg_pago.ESPECIALIDAD_ATENCION, 
            v_monto_multa 
        );

        -- control de insercion con contador
        IF SQL%FOUND THEN
            DBMS_OUTPUT.PUT_LINE('  PAGO PACIENTE INGRESADO RUT: ' || reg_pago.PAC_RUN || '-'|| reg_pago.PAC_DV_RUN 
                ||   ' | DIAS MORA: '|| v_dias_morosidad 
                ||   ' | MONTO MULTA TOTAL: ' || v_monto_multa);
            v_count_insert := v_count_insert + 1;
        END IF;


    END LOOP;

    DBMS_OUTPUT.PUT_LINE('INSERTADO ' || v_count_insert || ' PAGOS DE '  || v_count_pago );

    -- control de transaccion
    IF v_count_insert = v_count_pago THEN
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


/*select prueba

SELECT 
    PAC_RUN,
    p.DV_RUN AS "PAC_DV_RUN",
    p.PNOMBRE || ' ' || p.SNOMBRE || ' ' || p.APATERNO || ' ' || p.AMATERNO AS "PAC_NOMBRE",
    ATE_ID,
    pa.FECHA_VENC_PAGO,
    pa.FECHA_PAGO,
    e.NOMBRE AS "ESPECIALIDAD ATENCION"
FROM PAGO_ATENCION pa
LEFT JOIN ATENCION a USING(ATE_ID)
LEFT JOIN PACIENTE p USING(PAC_RUN)
LEFT JOIN ESPECIALIDAD_MEDICO em USING(MED_RUN,ESP_ID)
LEFT JOIN ESPECIALIDAD e USING(ESP_ID)
WHERE pa.FECHA_PAGO > pa.FECHA_VENC_PAGO
AND EXTRACT(YEAR FROM pa.FECHA_PAGO) = EXTRACT(YEAR FROM SYSDATE) - 1
ORDER BY pa.FECHA_VENC_PAGO ASC, p.APATERNO DESC;

SELECT * FROM PORC_DESCTO_3RA_EDAD;

*/