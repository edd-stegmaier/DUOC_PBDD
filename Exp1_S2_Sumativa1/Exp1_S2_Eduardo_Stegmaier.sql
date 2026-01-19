--Sumativa 1 - S2 TRUCK RENTAL
--Eduardo Stegmaier


--------------------------------------
--Generar  Usuarios / Claves para empleados
--------------------------------------
/*
datos de empleados para Usuario:  | datos de empleados para clave:
-primer nombre                    |   -run                - id empleado
-estado civil                     |   -año nacimiento
-sueldo base                      |   -sueldo base
-run dv                           |   -apellido paterno
-años trabajados                  |   - estado civil
                                       
ingresar en tabla USUARIO_CLAVE
*/


---------------------------------------
-- Selects de prueba
SELECT 
    e.ID_EMP,
    e.NUMRUN_EMP,
    e.DVRUN_EMP,
    e.PNOMBRE_EMP,
    e.APPATERNO_EMP,
    e.FECHA_NAC,
    e.FECHA_CONTRATO,
    e.SUELDO_BASE,
    ec.NOMBRE_ESTADO_CIVIL
FROM EMPLEADO e
LEFT JOIN ESTADO_CIVIL ec USING(ID_ESTADO_CIVIL)
;

SELECT 
        MAX(ID_EMP),
        MIN(ID_EMP),
        (MAX(ID_EMP) - MIN(ID_EMP)) / ( COUNT(ID_EMP) - 1)
FROM EMPLEADO;
---------------------------------------

---------------------------------------
--Solucion del Caso

--limpiar tabla
TRUNCATE TABLE USUARIO_CLAVE;

--variable de fecha de proceso
VARIABLE fecha_proceso DATE;
EXEC :fecha_proceso := SYSDATE;

SET SERVEROUTPUT ON;

--inicia bloque PL/SQL
DECLARE
    --variables que necesitamos leer de la tabla EMPLEADO
    v_id_emp EMPLEADO.ID_EMP%TYPE;
    v_numrun_emp EMPLEADO.NUMRUN_EMP%TYPE;
    v_dvrun_emp EMPLEADO.DVRUN_EMP%TYPE;
    v_pnombre_emp EMPLEADO.PNOMBRE_EMP%TYPE;
    v_snombre_emp EMPLEADO.SNOMBRE_EMP%TYPE;
    v_appaterno_emp EMPLEADO.APPATERNO_EMP%TYPE;
    v_apmaterno_emp EMPLEADO.APMATERNO_EMP%TYPE;
    v_fecha_nac EMPLEADO.FECHA_NAC%TYPE;
    v_fecha_contrato EMPLEADO.FECHA_CONTRATO%TYPE;
    v_sueldo_base EMPLEADO.SUELDO_BASE%TYPE;
    v_nombre_estado_civil ESTADO_CIVIL.NOMBRE_ESTADO_CIVIL%TYPE;

    --variables necesarias para llenar USUARIO_CLAVE
    v_nombre_usuario USUARIO_CLAVE.NOMBRE_USUARIO%TYPE;
    v_clave_usuario USUARIO_CLAVE.CLAVE_USUARIO%TYPE;
    v_nombre_empleado USUARIO_CLAVE.NOMBRE_EMPLEADO%TYPE;
    v_anios_trabajados NUMBER(2);

    --Variables para ejecutar loop(maximo, count e intervalos de ID EMPLEADOS)
    v_id_emp_max EMPLEADO.ID_EMP%TYPE;
    v_count_emp NUMBER(5);
    v_intervalo_id_emp NUMBER(5);

    --contador de iteraciones
    v_count_iteracion NUMBER(5) := 0;

    --ingresamos la variable bind ( no la usamos directamente)
    v_fecha_proceso DATE := :fecha_proceso;
BEGIN

    --Buscamos el rango del id y calculamos el intervalo para recorrer el loop
    -- usamos el maximo, minimo y cantidad de ids
    SELECT MAX(ID_EMP),  MIN(ID_EMP), COUNT(ID_EMP)
    INTO   v_id_emp_max, v_id_emp,    v_count_emp   FROM EMPLEADO;

    v_intervalo_id_emp := (v_id_emp_max - v_id_emp) / (v_count_emp - 1);
    
    DBMS_OUTPUT.PUT_LINE('-------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE('       GENERANDO USUARIO Y CLAVE PARA EMPLEADOS');
    DBMS_OUTPUT.PUT_LINE('INICIANDO BLOQUE PL/SQL CON IDS: ' || v_id_emp || ' A ' || v_id_emp_max || ' INTERVALO: ' || v_intervalo_id_emp);
    DBMS_OUTPUT.PUT_LINE('-------------------------------------------------------------');

    --loop por empleado
    LOOP
        
        --obtenemos datos del Empleado
        SELECT 
            --e.ID_EMP, usamos el que obtuvimos arriba
            e.NUMRUN_EMP,
            e.DVRUN_EMP,
            TRIM(e.PNOMBRE_EMP),
            TRIM(e.SNOMBRE_EMP),
            TRIM(e.APPATERNO_EMP),
            TRIM(e.APMATERNO_EMP),
            e.PNOMBRE_EMP || ' ' || e.SNOMBRE_EMP || ' ' || e.APPATERNO_EMP || ' ' || e.APMATERNO_EMP,
            e.FECHA_NAC,
            e.FECHA_CONTRATO,
            ROUND(e.SUELDO_BASE),
            TRIM(ec.NOMBRE_ESTADO_CIVIL)
        INTO 
            --v_id_emp,
            v_numrun_emp,
            v_dvrun_emp,
            v_pnombre_emp,
            v_snombre_emp,
            v_appaterno_emp,
            v_apmaterno_emp,
            v_nombre_empleado,
            v_fecha_nac,
            v_fecha_contrato,
            v_sueldo_base,
            v_nombre_estado_civil
        FROM EMPLEADO e
        LEFT JOIN ESTADO_CIVIL ec USING(ID_ESTADO_CIVIL)
        WHERE e.ID_EMP = v_id_emp 
        ;

        DBMS_OUTPUT.PUT_LINE(' GENERANDO USUARIO PARA : ' || v_pnombre_emp || ' ' || v_appaterno_emp || ' ID: ' || v_id_emp);
        
        --calculamos años trabajados
        v_anios_trabajados := (EXTRACT(YEAR FROM v_fecha_proceso) - EXTRACT(YEAR FROM v_fecha_contrato));

        --------------------------------
        -- Creamos nombre de Usuario (usamos estado civil, primer nombre, sueldo base, rut dv y años trabajados)
        v_nombre_usuario :=
            LOWER(SUBSTR(v_nombre_estado_civil, 1, 1)) 
            || UPPER(SUBSTR(v_pnombre_emp,1,3)) 
            || LENGTH(v_pnombre_emp) 
            || '*' 
            || SUBSTR(TO_CHAR(v_sueldo_base),-1,1) 
            || v_dvrun_emp 
            || v_anios_trabajados
        ;

        -- agrega 'X' si trabajo menos de 10 años
        IF v_anios_trabajados < 10 THEN
            v_nombre_usuario := v_nombre_usuario || 'X';
        END IF;

        --------------------------------
        --creamos clave de Usuario (usamos rut, año de nacimiento, sueldo base)
        v_clave_usuario :=
            SUBSTR(TO_CHAR(v_numrun_emp), 3, 1)
            || EXTRACT(YEAR FROM v_fecha_nac) + 2
            || SUBSTR(TO_CHAR(v_sueldo_base), -3, 3) - 1
        ;

        --agregamos 2 letras de su apellido segun su estado civil
        IF v_nombre_estado_civil = 'CASADO' OR v_nombre_estado_civil = 'ACUERDO DE UNION CIVIL' THEN
            v_clave_usuario := v_clave_usuario || LOWER(SUBSTR(v_appaterno_emp, 1, 2));
        ELSIF v_nombre_estado_civil = 'DIVORCIADO' OR v_nombre_estado_civil = 'SOLTERO' THEN
            v_clave_usuario := v_clave_usuario || LOWER(SUBSTR(v_appaterno_emp, 1, 1)) || LOWER(SUBSTR(v_appaterno_emp, -1, 1));
        ELSIF v_nombre_estado_civil = 'VIUDO' THEN
            v_clave_usuario := v_clave_usuario || LOWER(SUBSTR(v_appaterno_emp, -3, 1)) || LOWER(SUBSTR(v_appaterno_emp, -2, 1));
        ELSIF v_nombre_estado_civil = 'SEPARADO' THEN
            v_clave_usuario := v_clave_usuario || LOWER(SUBSTR(v_appaterno_emp, -2, 2));
        END IF;

        --agregamos los ultimos parametros(id, mes y año base de datos)
        v_clave_usuario := 
            v_clave_usuario 
            || v_id_emp 
            || EXTRACT(MONTH FROM v_fecha_proceso) 
            || EXTRACT(YEAR FROM v_fecha_proceso);
        --------------------------------
        
        --ingresar en tabla USUARIO_CLAVE
        INSERT INTO USUARIO_CLAVE
        VALUES (v_id_emp, v_numrun_emp, v_dvrun_emp, v_nombre_empleado, v_nombre_usuario, v_clave_usuario);

        --contador de interaciones si fue correcto el INSERT
        IF SQL%FOUND THEN
            v_count_iteracion := v_count_iteracion + 1;
        END IF;

        --actualizamos el id para el proximo loop
        v_id_emp := v_id_emp + v_intervalo_id_emp;

        --control termino proceso
        EXIT WHEN v_id_emp > v_id_emp_max;   
    END LOOP;

    --control de transaccion 
    DBMS_OUTPUT.PUT_LINE('USUARIOS GENERADOS: ' || v_count_iteracion || ' DE ' || v_count_emp || ' EMPLEADOS.');

    IF v_count_iteracion = v_count_emp THEN
        DBMS_OUTPUT.PUT_LINE('PROCESO FINALIZADO EXITOSAMENTE');
        COMMIT;
    ELSE
        DBMS_OUTPUT.PUT_LINE('ERROR, EJECUTANDO ROLLBACK');
        ROLLBACK;
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('PROCESO CON ERRORES');
        ROLLBACK;
END
;

--revisar tabla USUARIO_CLAVE
SELECT * FROM USUARIO_CLAVE;
