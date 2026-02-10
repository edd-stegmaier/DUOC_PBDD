-- S5 - Sumativa 2 - ALL THE BEST
-- Eduardo Stegmaier

/*
SELECTS DE PRUEBA

SELECT 
    NUMRUN,
    DVRUN,
    NRO_TARJETA,
    NRO_TRANSACCION,
    FECHA_TRANSACCION,
    NOMBRE_TPTRAN_TARJETA,
    MONTO_TOTAL_TRANSACCION
FROM 
    TRANSACCION_TARJETA_CLIENTE
LEFT JOIN
    TARJETA_CLIENTE USING(NRO_TARJETA)
LEFT JOIN
    CLIENTE USING(NUMRUN)
LEFT JOIN 
    TIPO_TRANSACCION_TARJETA USING(COD_TPTRAN_TARJETA)
WHERE 
    COD_TPTRAN_TARJETA IN (102,103)
    AND EXTRACT(YEAR FROM FECHA_TRANSACCION) = EXTRACT(YEAR FROM SYSDATE)
ORDER BY 
    FECHA_TRANSACCION ASC,
    NUMRUN 
;
*/

/*
SELECT
    EXTRACT(MONTH FROM FECHA_TRANSACCION),
    TIPO_TRANSACCION,
    SUM(MONTO_TRANSACCION),
    SUM(APORTE_SBIF)
FROM DETALLE_APORTE_SBIF
GROUP BY EXTRACT(MONTH FROM FECHA_TRANSACCION), TIPO_TRANSACCION;
*/

--solucion del caso

-- truncar tablas
TRUNCATE TABLE DETALLE_APORTE_SBIF;
TRUNCATE TABLE RESUMEN_APORTE_SBIF;

--fecha de ejecucion del proceso
VARIABLE fecha_ejecucion VARCHAR2(20);
EXECUTE :fecha_ejecucion := TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS');

SET SERVEROUTPUT ON;

DECLARE
    --definimos un arreglo para almacenar los tipos de transaccion a procesar
    TYPE t_tran IS VARRAY(3) OF TIPO_TRANSACCION_TARJETA.COD_TPTRAN_TARJETA%TYPE;
    v_tipo_tran t_tran := t_tran(102,103); -- usamos transacciones de avances y super avances (codigo 102, 103)

    -- definimos cursor explicito para avances (102, 103)
    CURSOR cur_avance IS
        SELECT 
            NUMRUN,
            DVRUN,
            NRO_TARJETA,
            NRO_TRANSACCION,
            FECHA_TRANSACCION,
            NOMBRE_TPTRAN_TARJETA   AS "TIPO_TRANSACCION",
            MONTO_TOTAL_TRANSACCION AS "MONTO_TRANSACCION"
        FROM 
            TRANSACCION_TARJETA_CLIENTE
        LEFT JOIN
            TARJETA_CLIENTE          USING(NRO_TARJETA)
        LEFT JOIN
            CLIENTE                  USING(NUMRUN)
        LEFT JOIN 
            TIPO_TRANSACCION_TARJETA USING(COD_TPTRAN_TARJETA)
        WHERE 
            COD_TPTRAN_TARJETA IN (v_tipo_tran(1), v_tipo_tran(2)) -- codigo avance
            AND EXTRACT(YEAR FROM FECHA_TRANSACCION) = EXTRACT(YEAR FROM TO_DATE(:fecha_ejecucion, 'YYYY-MM-DD HH24:MI:SS')) 
            --transacciones año actual
        ORDER BY 
            FECHA_TRANSACCION ASC,
            NUMRUN 
    ;

    --definimos cursor para resumen de aporte por mes y tipo de transaccion
    CURSOR cur_resumen (p_tipo_tran NUMBER)IS
        SELECT
            EXTRACT (MONTH FROM d.FECHA_TRANSACCION) AS "MES",
            MAX(d.TIPO_TRANSACCION)                  AS "TIPO_TRANSACCION",
            SUM(d.MONTO_TRANSACCION)                 AS "MONTO_TOTAL_TRANSACCIONES",
            SUM(d.APORTE_SBIF)                       AS "APORTE_TOTAL_ABIF"
        FROM      DETALLE_APORTE_SBIF d
        LEFT JOIN TRANSACCION_TARJETA_CLIENTE t
               ON t.NRO_TARJETA = d.NRO_TARJETA
              AND t.NRO_TRANSACCION = d.NRO_TRANSACCION
        WHERE     t.COD_TPTRAN_TARJETA = p_tipo_tran
          AND     EXTRACT(YEAR FROM d.FECHA_TRANSACCION) = EXTRACT(YEAR FROM TO_DATE(:fecha_ejecucion, 'YYYY-MM-DD HH24:MI:SS'))
        GROUP BY  EXTRACT (MONTH FROM d.FECHA_TRANSACCION)
    ;

    --variables detalle aporte 
    v_aporte_sbif               DETALLE_APORTE_SBIF.APORTE_SBIF%TYPE    := 0;
    v_porc_aporte               TRAMO_APORTE_SBIF.PORC_APORTE_SBIF%TYPE := 0; 

    --variables resumen aporte
    v_mes_anno                  RESUMEN_APORTE_SBIF.MES_ANNO%TYPE;

    --creamos un arreglo para almacenar los valores de los tramos
    TYPE t_tramo IS RECORD(
        tramo_inf   TRAMO_APORTE_SBIF.TRAMO_INF_AV_SAV%TYPE,
        tramo_sup   TRAMO_APORTE_SBIF.TRAMO_SUP_AV_SAV%TYPE,
        porc_aporte TRAMO_APORTE_SBIF.PORC_APORTE_SBIF%TYPE
    );
    TYPE t_tramos IS VARRAY(25) OF t_tramo;
    v_tramos t_tramos;

    --excepciones definidas por el usuario
    e_sin_aporte    EXCEPTION;
    e_no_completado EXCEPTION;

    --excepciones no predefinidas
    -- error de integridad referencial al insertar detalle
    e_fk_invalida EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_fk_invalida, -2291);

    --contador del proceso
    v_count_avance NUMBER(5) := 0;
    v_count_insert NUMBER(5) := 0;

    v_count_resumen NUMBER(5) := 0;
    v_count_resumen_insert NUMBER(5) := 0;

BEGIN

    DBMS_OUTPUT.PUT_LINE('---------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('               APORTE SBIF ');
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------');

    --cargar tramos desde tabla
    SELECT 
        TRAMO_INF_AV_SAV, 
        TRAMO_SUP_AV_SAV,
        PORC_APORTE_SBIF
    BULK COLLECT INTO v_tramos
    FROM     TRAMO_APORTE_SBIF
    ORDER BY TRAMO_INF_AV_SAV;

    --loop para procesar cada avance y calcular su aporte correspondiente
    FOR reg_avance IN cur_avance LOOP

        BEGIN
            DBMS_OUTPUT.PUT_LINE(' NUMERO TARJETA: ' || reg_avance.NRO_TARJETA || ' monto: ' || reg_avance.MONTO_TRANSACCION);

            --seleccionamos el porcentaje de aporte de acuerdo a los tramos que obtuvimos en la tabla
            FOR t IN 1..v_tramos.count LOOP
                IF  reg_avance.MONTO_TRANSACCION BETWEEN v_tramos(t).tramo_inf AND v_tramos(t).tramo_sup THEN
                    v_porc_aporte := v_tramos(t).porc_aporte;
                END IF;
            END LOOP;

            --en caso de no aplicar aporte, se registra la excepcion y se continua con el siguiente registro
            IF v_porc_aporte = 0 THEN
                RAISE e_sin_aporte;
            END IF;

            -- avance con aporte
            v_count_avance := v_count_avance + 1;

            -- calculo de aporte
            v_aporte_sbif := reg_avance.MONTO_TRANSACCION * (v_porc_aporte/100);

            -- insertamos detalle aporte
            INSERT INTO DETALLE_APORTE_SBIF (
                NUMRUN,
                DVRUN,
                NRO_TARJETA,
                NRO_TRANSACCION,
                FECHA_TRANSACCION,
                TIPO_TRANSACCION,
                MONTO_TRANSACCION,
                APORTE_SBIF
            ) VALUES (
                reg_avance.NUMRUN,
                reg_avance.DVRUN,
                reg_avance.NRO_TARJETA,
                reg_avance.NRO_TRANSACCION, 
                reg_avance.FECHA_TRANSACCION,
                reg_avance.TIPO_TRANSACCION,   
                reg_avance.MONTO_TRANSACCION,
                v_aporte_sbif
            );

            --verificamos que el insert se haya realizado
            IF SQL%FOUND THEN
                v_count_insert := v_count_insert + 1;
                DBMS_OUTPUT.PUT_LINE('  -APORTE: $' || v_aporte_sbif || '  -APORTE REGISTRADO');
            END IF;

        EXCEPTION
            -- no aplica aporte para este avance, se registra y continua el proceso
            WHEN e_sin_aporte THEN
                DBMS_OUTPUT.PUT_LINE('  -NO APLICA APORTE PARA: ' || reg_avance.NRO_TARJETA || ' monto: $' || reg_avance.MONTO_TRANSACCION);
        END;

    END LOOP;

    DBMS_OUTPUT.PUT_LINE('---------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('TOTAL AVANCES CON APORTE: ' || v_count_avance);
    DBMS_OUTPUT.PUT_LINE('TOTAL AVANCES PROCESADOS: ' || v_count_insert);

    --control de transaccion 
    IF v_count_avance = v_count_insert THEN
        DBMS_OUTPUT.PUT_LINE('PROCESO EXITOSO, CONFIRMANDO');
        COMMIT;
    ELSE
        --excepcion de proceso incompleto
        DBMS_OUTPUT.PUT_LINE('NO SE HAN PROCESADO TODOS LOS AVANCES');
        RAISE e_no_completado;
    END IF;


    --resumen 
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('               RESUMEN APORTE SBIF');
    DBMS_OUTPUT.PUT_LINE('---------------------------------------------');

    --procesamos el resumen por mes y tipo de transaccion
    FOR i IN 1..v_tipo_tran.count LOOP
        FOR reg_resumen IN cur_resumen(v_tipo_tran(i)) LOOP

            -- formateo mes-anno para el resumen
            v_mes_anno := LPAD(TO_CHAR(reg_resumen.MES), 2, '0') || TO_CHAR(EXTRACT(YEAR FROM TO_DATE(:fecha_ejecucion, 'YYYY-MM-DD HH24:MI:SS')));
            DBMS_OUTPUT.PUT_LINE('REGISTRANDO:  MES_ANNO: ' || v_mes_anno || ' MONTO TOTAL: ' || reg_resumen.MONTO_TOTAL_TRANSACCIONES || ' APORTE TOTAL:  ' || reg_resumen.APORTE_TOTAL_ABIF);
            
            --contador para control de transaccion del resumen
            v_count_resumen := v_count_resumen + 1;

            INSERT INTO RESUMEN_APORTE_SBIF (
                MES_ANNO,
                TIPO_TRANSACCION,
                MONTO_TOTAL_TRANSACCIONES,
                APORTE_TOTAL_ABIF 
            ) VALUES (
                v_mes_anno,
                reg_resumen.TIPO_TRANSACCION,
                reg_resumen.MONTO_TOTAL_TRANSACCIONES,
                reg_resumen.APORTE_TOTAL_ABIF
            );

            --verificamos que el insert se haya realizado
            IF SQL%FOUND THEN
                DBMS_OUTPUT.PUT_LINE('  -RESUMEN REGISTRADO');
                v_count_resumen_insert := v_count_resumen_insert + 1;
            END IF;

        END LOOP;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('---------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('TOTAL RESUMENES A PROCESAR: ' || v_count_resumen);
    DBMS_OUTPUT.PUT_LINE('TOTAL RESUMENES PROCESADOS: ' || v_count_resumen_insert);

    --control de transaccion del resumen
    IF v_count_resumen = v_count_resumen_insert THEN
        DBMS_OUTPUT.PUT_LINE('RESUMEN COMPLETO, CONFIRMANDO');
        COMMIT;
    ELSE
        --excepcion de proceso incompleto
        DBMS_OUTPUT.PUT_LINE('NO SE HAN PROCESADO TODOS LOS RESUMENES');
        RAISE e_no_completado;
    END IF;



EXCEPTION
    --excepcion de proceso incompleto
    WHEN e_no_completado THEN
        DBMS_OUTPUT.PUT_LINE('ERROR : PROCESO NO COMPLETADO');
        ROLLBACK;
    -- excepciones de arreglo
    WHEN COLLECTION_IS_NULL OR SUBSCRIPT_OUTSIDE_LIMIT THEN
        DBMS_OUTPUT.PUT_LINE('ERROR : NO SE HAN DEFINIDO LOS TRAMOS DE APORTE');
        ROLLBACK;
    -- excepcion de fk invalida al insertar detalle
    WHEN e_fk_invalida THEN
        DBMS_OUTPUT.PUT_LINE('ERROR : REGISTRO RELACIONADO NO EXISTE (FK)');
        ROLLBACK;

    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('PROCESO CON ERRORES: ' || SQLERRM);
        ROLLBACK;
END;

/