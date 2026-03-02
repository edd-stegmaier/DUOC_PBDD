--S8 - Sumativa 3 - hotel “La Última Oportunidad”
--Eduardo Stegmaier


SET SERVEROUTPUT ON;

--funcion que regitra errores / usada en consumos , agencias
CREATE OR REPLACE PROCEDURE sp_reg_error(
    p_subprog   IN REG_ERRORES.NOMSUBPROGRAMA%TYPE, 
    p_msg_error IN REG_ERRORES.MSG_ERROR%TYPE
    )
IS 
BEGIN
    INSERT INTO REG_ERRORES VALUES(sq_error.NEXTVAL, p_subprog, p_msg_error);
    IF SQL%ROWCOUNT>0 THEN
        DBMS_OUTPUT.PUT_LINE('--');
        DBMS_OUTPUT.PUT_LINE('Error registrado en REG_ERRORES: ' || p_msg_error);
    END IF;

EXCEPTION 
    WHEN OTHERS THEN
    NULL;
END;
/
------------------------------------------
--   CASO 1: Actualizar total consumos
------------------------------------------

-- funcion obtiene total consumos huesped
CREATE OR REPLACE FUNCTION fn_get_total_consumo(p_id_huesped IN NUMBER)
RETURN NUMBER IS
    v_total_consumo NUMBER;
BEGIN
    SELECT MONTO_CONSUMOS
    INTO   v_total_consumo
    FROM   TOTAL_CONSUMOS
    WHERE  ID_HUESPED = p_id_huesped;

    RETURN v_total_consumo;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        sp_reg_error('Error en funcion fn_get_total_consumos al recuperar consumo cliente ID ' || p_id_huesped,SQLERRM);
        RETURN 0;
END;
/

-- funcion que ejecuta UPDATE en TOTAL_CONSUMOS
CREATE OR REPLACE FUNCTION fn_update_total_consumos(p_id_huesped IN NUMBER, p_total_consumo IN NUMBER)
RETURN BOOLEAN IS
BEGIN
    UPDATE TOTAL_CONSUMOS
    SET    MONTO_CONSUMOS = p_total_consumo
    WHERE  ID_HUESPED = p_id_huesped;

    RETURN TRUE;
EXCEPTION
    WHEN OTHERS THEN
        RETURN FALSE;
END;
/

-- sp para calcular / actualizar total consumos 
CREATE OR REPLACE PROCEDURE sp_actualizar_total(
    p_id_huesped   IN NUMBER, 
    p_old_consumo  IN NUMBER, 
    p_new_consumo  IN NUMBER)
IS
    v_total_consumo          NUMBER;
    v_total_consumo_anterior NUMBER;
    v_update                 BOOLEAN;
BEGIN
    --obtenemos total consumo actual para el huesped
    v_total_consumo_anterior := fn_get_total_consumo(p_id_huesped);

    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Huésped ID: ' || p_id_huesped);
    DBMS_OUTPUT.PUT_LINE('Total consumo anterior: ' || v_total_consumo_anterior);

    IF p_old_consumo IS NULL THEN --INSERT
        v_total_consumo := v_total_consumo_anterior + p_new_consumo;
        DBMS_OUTPUT.PUT_LINE('Operación: INSERT - Nuevo consumo: ' || p_new_consumo);

    ELSIF p_new_consumo IS NULL THEN  --DELETE
        v_total_consumo := v_total_consumo_anterior - p_old_consumo;
        DBMS_OUTPUT.PUT_LINE('Operación: DELETE - Consumo eliminado: ' || p_old_consumo);

    ELSE --UPDATE
        v_total_consumo := v_total_consumo_anterior + (p_new_consumo - p_old_consumo);
        DBMS_OUTPUT.PUT_LINE('Operación: UPDATE - Cambio consumo: ' || (p_new_consumo - p_old_consumo));

    END IF;

    DBMS_OUTPUT.PUT_LINE('Total consumo nuevo: ' || v_total_consumo);

    -- ejecutamos actualización del total consumo en tabla TOTAL_CONSUMOS
    v_update := fn_update_total_consumos(p_id_huesped, v_total_consumo);

    --comprobamos resultado de la actualización
    IF v_update THEN
        DBMS_OUTPUT.PUT_LINE('Total consumo actualizado correctamente.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Error al actualizar total consumo.');
    END IF;

END;
/

--trigger en Consumo
CREATE OR REPLACE TRIGGER trg_actualizar_consumo
AFTER INSERT OR DELETE OR UPDATE ON CONSUMO
FOR EACH ROW
BEGIN
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Trigger activado por ' || CASE 
        WHEN INSERTING THEN 'INSERT'
        WHEN DELETING THEN 'DELETE'
        WHEN UPDATING THEN 'UPDATE'
    END || ' en tabla CONSUMO.');

    IF INSERTING THEN
        sp_actualizar_total(:NEW.ID_HUESPED, :OLD.MONTO, :NEW.MONTO);
    ELSE
        sp_actualizar_total(:OLD.ID_HUESPED, :OLD.MONTO, :NEW.MONTO);
    END IF;
    
END;
/


--bloque anonimo principal para pruebas de trigger en tabla CONSUMO
DECLARE 
    --insertar
    v_id_consumo_insert CONSUMO.ID_CONSUMO%TYPE := 0;
    v_id_huesped_insert CONSUMO.ID_HUESPED%TYPE := 340006;
    v_id_reserva_insert CONSUMO.ID_RESERVA%TYPE := 1587;
    v_monto_insert      CONSUMO.MONTO%TYPE      := 150;

    --eliminar
    v_id_consumo_delete CONSUMO.ID_CONSUMO%TYPE := 11473;

    --actualizar
    v_id_consumo_update CONSUMO.ID_CONSUMO%TYPE := 10688;
    v_monto_update      CONSUMO.MONTO%TYPE      := 95;

BEGIN 
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE(' Ejecutando bloque anónimo para probar trigger...');

    --siguiente ID_CONSUMO para insert
    SELECT MAX(ID_CONSUMO) + 1 
    INTO   v_id_consumo_insert
    FROM   CONSUMO
    ;

    --prueba de insert
    INSERT INTO CONSUMO VALUES(v_id_consumo_insert, v_id_reserva_insert, v_id_huesped_insert, v_monto_insert);
        IF SQL%ROWCOUNT > 0 THEN
            DBMS_OUTPUT.PUT_LINE('1. Consumo insertado correctamente.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('1. Error al insertar consumo.');
        END IF;

    --prueba de delete
    DELETE FROM CONSUMO WHERE ID_CONSUMO = v_id_consumo_delete;
        IF SQL%ROWCOUNT > 0 THEN
            DBMS_OUTPUT.PUT_LINE('2. Consumo eliminado correctamente.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('2. Error al eliminar consumo.');
        END IF;

    --prueba de update
    UPDATE CONSUMO
    SET    MONTO = v_monto_update
    WHERE  ID_CONSUMO = v_id_consumo_update;
        IF SQL%ROWCOUNT > 0 THEN
            DBMS_OUTPUT.PUT_LINE('3. Consumo actualizado correctamente.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('3. Error al actualizar consumo.');
        END IF;

    ROLLBACK; -- para no afectar la base de datos con los cambios de prueba
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error al ejecutar bloque de prueba del trigger: ' || SQLERRM);
END;
/


-------------------------------------------
--   CASO 2: Gestion cobranza
-------------------------------------------

--varibles bind para fecha de proceso y valor del dolar
VAR p_fecha_proceso VARCHAR2(20);
VAR p_valor_dolar NUMBER;

EXEC :p_fecha_proceso := '2021-08-18';
EXEC :p_valor_dolar := 915;



-- crear package con variables y función para monto tours
CREATE OR REPLACE PACKAGE pkg_pago_tours IS
  -- Variables públicas
  v_monto_tours NUMBER;

  -- Función pública
  FUNCTION fn_monto_tours( p_id_huesped NUMBER) RETURN NUMBER;
END pkg_pago_tours;
/

CREATE OR REPLACE PACKAGE BODY pkg_pago_tours IS
    FUNCTION fn_monto_tours( p_id_huesped NUMBER) RETURN NUMBER IS
        v_monto_tours NUMBER;
    BEGIN
        SELECT NVL(SUM(VALOR_TOUR), 0)
        INTO   v_monto_tours
        FROM   TOUR
        JOIN HUESPED_TOUR USING(ID_TOUR)
        JOIN HUESPED USING(ID_HUESPED)
        WHERE  ID_HUESPED = p_id_huesped;
    
        RETURN v_monto_tours;
    END fn_monto_tours;
END pkg_pago_tours;
/

--funcion retorna agencia del huesped / NO REGISTRA AGENCIA
-- errores registrados en REG_ERRORES
CREATE OR REPLACE FUNCTION fn_agencia_huesped(p_id_huesped IN NUMBER)
RETURN VARCHAR2 IS
    v_nom_agencia AGENCIA.NOM_AGENCIA%TYPE;
BEGIN 
    SELECT NOM_AGENCIA
    INTO v_nom_agencia
    FROM AGENCIA
    JOIN HUESPED USING(ID_AGENCIA)
    WHERE ID_HUESPED = p_id_huesped;

    RETURN v_nom_agencia;
EXCEPTION
    WHEN OTHERS THEN 
        sp_reg_error('Error en funcion fn_agencia_huesped al recuperar agencia cliente ID ' || p_id_huesped,SQLERRM);
        RETURN 'NO REGISTRA AGENCIA';
END;
/

--funcion retorna pocentaje descuento segun tramo de consumos
CREATE OR REPLACE FUNCTION fn_pct_desc_consumos(p_id_huesped IN NUMBER)
RETURN NUMBER IS
    TYPE t_tramos IS VARRAY(30) OF TRAMOS_CONSUMOS%ROWTYPE;
    v_tramos t_tramos;

    v_consumo  NUMBER := 0;
    v_pct      NUMBER := 0;

BEGIN 
    --obtenemos consumo
    v_consumo := fn_get_total_consumo(p_id_huesped);

    --cargar tramos desde tabla
    SELECT *
    BULK COLLECT INTO v_tramos
    FROM     TRAMOS_CONSUMOS
    ORDER BY VMIN_TRAMO;

    --obtener porcentaje segun tramo de consumo
    FOR tramo IN 1..v_tramos.count LOOP
        IF v_consumo BETWEEN v_tramos(tramo).VMIN_TRAMO AND v_tramos(tramo).VMAX_TRAMO THEN
            v_pct := v_tramos(tramo).PCT;
        END IF;
    END LOOP; 

    RETURN v_pct;
EXCEPTION
    WHEN OTHERS THEN 
        RETURN 0;
END;
/

--funcion que calcura el coste por persona
CREATE OR REPLACE FUNCTION fn_costo_personas(p_id_huesped IN NUMBER, p_fecha_proceso IN DATE, p_valor_dolar IN NUMBER)
RETURN NUMBER
IS 
    CURSOR cur_habitacion IS
        SELECT TIPO_HABITACION
        FROM HABITACION 
        INNER JOIN DETALLE_RESERVA USING(ID_HABITACION)
        INNER JOIN RESERVA         USING(ID_RESERVA)
        WHERE ID_HUESPED = p_id_huesped
            AND INGRESO + ESTADIA = TO_DATE('2021-08-18', 'YYYY-MM-DD')
        ;
    v_total_personas NUMBER := 0;
BEGIN 
    FOR reg_hab IN cur_habitacion LOOP
        CASE reg_hab.TIPO_HABITACION
            WHEN 'S' THEN v_total_personas := v_total_personas + 1;
            WHEN 'D' THEN v_total_personas := v_total_personas + 2;
            WHEN 'T' THEN v_total_personas := v_total_personas + 3;
            WHEN 'C' THEN v_total_personas := v_total_personas + 4;
            WHEN 'SE' THEN v_total_personas := v_total_personas + 1; --suponemos 1 persona
            WHEN 'SP' THEN v_total_personas := v_total_personas + 1;
            ELSE NULL; -- otros tipos, no suma
        END CASE;
    END LOOP;

    RETURN ROUND(v_total_personas * (35000/p_valor_dolar));
END;
/

--procedimiento almacenado principal
-- guarda resultado en DETALLE_DIARIO_HUESPEDES
CREATE OR REPLACE PROCEDURE sp_procesar_pagos(p_fecha_proceso IN DATE, p_valor_dolar IN NUMBER)
IS 

    -- NOTA: para los  huéspedes (340494, 340542) que tienen fecha salida 18/08/21 reservas (1830, 1990)
    -- pero faltan en DETALLE_RESERVA que vincula las reservas con una habitación.
    -- se descartan con INNER JOIN
    CURSOR cur_alojamiento IS
        SELECT
            ID_HUESPED,
            APPAT_HUESPED || ' ' || APMAT_HUESPED || ' ' || NOM_HUESPED AS "NOMBRE",
            SUM(VALOR_HABITACION) AS "VALOR_HABITACION",
            SUM(VALOR_MINIBAR)    AS "VALOR_MINIBAR",
            ESTADIA
        FROM HUESPED
        INNER JOIN RESERVA         USING(ID_HUESPED)
        INNER JOIN DETALLE_RESERVA USING(ID_RESERVA)
        INNER JOIN HABITACION      USING(ID_HABITACION)
        WHERE INGRESO + ESTADIA =  TO_DATE('2021-08-18', 'YYYY-MM-DD')
        GROUP BY ID_HUESPED, APPAT_HUESPED || ' ' || APMAT_HUESPED || ' ' || NOM_HUESPED, ESTADIA
        ORDER BY ID_HUESPED
    ;

    --ID_HUESPED, NOMBRE, AGENCIA, ALOJAMIENTO, CONSUMOS, TOURS, SUBTOTAL_PAGO, DESCUENTO_CONSUMOS, DESCUENTOS_AGENCIA, TOTAL
    reg_pago DETALLE_DIARIO_HUESPEDES%ROWTYPE;

    --coste por persona
    v_valor_persona          NUMBER := 0;
    --contadores
    v_count_huespedes        NUMBER := 0;
    v_count_huespedes_insert NUMBER := 0;
BEGIN

    EXECUTE IMMEDIATE 'TRUNCATE TABLE DETALLE_DIARIO_HUESPEDES';
    EXECUTE IMMEDIATE 'TRUNCATE TABLE REG_ERRORES';

    -- loop para calculo de detalle diario huespedes
    FOR reg_alojamiento IN cur_alojamiento LOOP

        --contador
        v_count_huespedes := v_count_huespedes + 1;

        reg_pago.ID_HUESPED := reg_alojamiento.ID_HUESPED;
        reg_pago.NOMBRE := reg_alojamiento.NOMBRE;

        --obtenemos nombre de agencia
        reg_pago.AGENCIA := fn_agencia_huesped(reg_pago.ID_HUESPED);

        --calculo valor alojamiento (costo habitacion + minibar por los dias de estadia)
        reg_pago.ALOJAMIENTO := (reg_alojamiento.VALOR_HABITACION + reg_alojamiento.VALOR_MINIBAR)*reg_alojamiento.ESTADIA*p_valor_dolar ;

        --obtenemos total consumos y de tours con las funciones
        reg_pago.CONSUMOS := fn_get_total_consumo(reg_pago.ID_HUESPED)*p_valor_dolar;
        reg_pago.TOURS := pkg_pago_tours.fn_monto_tours(reg_pago.ID_HUESPED)*p_valor_dolar;

        --calculo coste por persona de $35.000 (en dolares) segun el tipo de habitacion
        v_valor_persona := fn_costo_personas(reg_pago.ID_HUESPED,p_fecha_proceso, p_valor_dolar)* p_valor_dolar;

        --calculo subtotal
        reg_pago.SUBTOTAL_PAGO := reg_pago.ALOJAMIENTO + reg_pago.CONSUMOS + reg_pago.TOURS +v_valor_persona;

        --obtenemos descuento por consumos
        IF reg_pago.CONSUMOS > 0 THEN -- para no registrar error de consumo dos veces
            reg_pago.DESCUENTO_CONSUMOS := fn_pct_desc_consumos(reg_pago.ID_HUESPED)*reg_pago.SUBTOTAL_PAGO;
        ELSE
            reg_pago.DESCUENTO_CONSUMOS := 0;
        END IF;
        --descuento de agencia 
        reg_pago.DESCUENTOS_AGENCIA := 0;

        IF reg_pago.AGENCIA = 'VIAJES ALBERTI' THEN
            reg_pago.DESCUENTOS_AGENCIA := 0.12*reg_pago.SUBTOTAL_PAGO;
        END IF;

        --calculo total
        reg_pago.TOTAL := reg_pago.SUBTOTAL_PAGO - reg_pago.DESCUENTO_CONSUMOS - reg_pago.DESCUENTOS_AGENCIA;

        DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
        DBMS_OUTPUT.PUT_LINE(RPAD('Huésped ID:',20) || reg_pago.ID_HUESPED);
        DBMS_OUTPUT.PUT_LINE(RPAD('Nombre:',20) || reg_pago.NOMBRE);
        DBMS_OUTPUT.PUT_LINE(RPAD('Agencia:',20) || reg_pago.AGENCIA);
        DBMS_OUTPUT.PUT_LINE(RPAD('Valor alojamiento:',20) || TO_CHAR(reg_pago.ALOJAMIENTO,'999,999,990'));
        DBMS_OUTPUT.PUT_LINE(RPAD('Valor consumos:',20) || TO_CHAR(reg_pago.CONSUMOS,'999,999,990'));
        DBMS_OUTPUT.PUT_LINE(RPAD('Valor tours:',20) || TO_CHAR(reg_pago.TOURS,'999,999,990'));
        DBMS_OUTPUT.PUT_LINE(RPAD('Valor por persona:',20) || TO_CHAR(v_valor_persona,'999,999,990'));
        DBMS_OUTPUT.PUT_LINE(RPAD('Subtotal pago:',20) || TO_CHAR(reg_pago.SUBTOTAL_PAGO,'999,999,990'));
        DBMS_OUTPUT.PUT_LINE(RPAD('Desc. consumos:',20) || TO_CHAR(reg_pago.DESCUENTO_CONSUMOS,'999,999,990'));
        DBMS_OUTPUT.PUT_LINE(RPAD('Desc. agencia:',20) || TO_CHAR(reg_pago.DESCUENTOS_AGENCIA,'999,999,990'));
        DBMS_OUTPUT.PUT_LINE(RPAD('Total a pagar:',20) || TO_CHAR(reg_pago.TOTAL,'999,999,990'));
        
        --guardar resultado en tabla DETALLE_DIARIO_HUESPEDES / continua en caso de fallo
        BEGIN
            INSERT INTO DETALLE_DIARIO_HUESPEDES VALUES reg_pago;
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Error al insertar detalle diario del huésped: ' || SQLERRM);
        END;

        --registro de insert exitoso en contador o fallo
        IF SQL%ROWCOUNT > 0 THEN
            DBMS_OUTPUT.PUT_LINE('Detalle diario del huésped registrado correctamente.');
            v_count_huespedes_insert := v_count_huespedes_insert + 1;
        ELSE
            DBMS_OUTPUT.PUT_LINE('Error al registrar detalle diario del huésped.');
        END IF;

    END LOOP;

    -- control fin del proceso
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('Proceso de pagos finalizado. Total huéspedes procesados: ' || v_count_huespedes_insert || '/' || v_count_huespedes);
    
    IF v_count_huespedes_insert = v_count_huespedes THEN
        DBMS_OUTPUT.PUT_LINE('Todos los detalles diarios de huéspedes se registraron correctamente.');
        COMMIT;
    ELSE
        DBMS_OUTPUT.PUT_LINE('Hubo errores en el registro de algunos detalles diarios de huéspedes.');
        ROLLBACK;
    END IF;


EXCEPTION 
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error en el proceso de pagos: ' || SQLERRM);
END; 
/

-- bloque pl/sql para ejecutar procedimiento de pagos
BEGIN 
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE(' Ejecutando bloque anónimo para probar proceso de pagos...');

    sp_procesar_pagos(TO_DATE(:p_fecha_proceso, 'YYYY-MM-DD'), :p_valor_dolar);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error al ejecutar proceso de pagos: ' || SQLERRM);
END;
/



---------------------------------------------------
---------------------------------------------------

--Select de prueba para cursor
/*
SELECT
    ID_HUESPED, ID_RESERVA, ID_HABITACION, INGRESO, ESTADIA, INGRESO + ESTADIA 
FROM HUESPED
left JOIN RESERVA USING(ID_HUESPED)
left JOIN DETALLE_RESERVA USING(ID_RESERVA)
LEFT JOIN HABITACION USING(ID_HABITACION)
WHERE INGRESO + ESTADIA = TO_DATE('2021-08-18', 'YYYY-MM-DD')
;
*/
-- reservas sin habitacion
--SELECT * FROM DETALLE_RESERVA WHERE ID_RESERVA IN(1830,1990);

-- revisar tabla de detalle diario de huespedes
--SELECT * FROM DETALLE_DIARIO_HUESPEDES;

-- revisar tabla registro de errores
--SELECT * FROM REG_ERRORES;
