create or replace package pack_mante
is 
procedure mant_agregar(dep_id DEPARTMENTS.DEPARTMENT_ID%type,
dep_nom DEPARTMENTS.DEPARTMENT_NAME%TYPE, man_id DEPARTMENTS.MANAGER_ID%TYPE,loc_id DEPARTMENTS.LOCATION_ID%TYPE);
PROCEDURE mant_eliminar (DEP_ID DEPARTMENTS.DEPARTMENT_ID%TYPE);
PROCEDURE mant_modificar (dep_id DEPARTMENTS.DEPARTMENT_ID%TYPE,
dep_nom DEPARTMENTS.DEPARTMENT_NAME%TYPE, man_id DEPARTMENTS.MANAGER_ID%TYPE,loc_id DEPARTMENTS.LOCATION_ID%TYPE);
PROCEDURE mant_consulta (dep_nom DEPARTMENTS.DEPARTMENT_NAME%TYPE);

END pack_mante;

--- CUERPO ------

create or replace package body pack_mante
is
    --Insertar nuevo departamento
    procedure mant_agregar(dep_id DEPARTMENTS.DEPARTMENT_ID%type,
dep_nom DEPARTMENTS.DEPARTMENT_NAME%TYPE, man_id DEPARTMENTS.MANAGER_ID%TYPE,loc_id DEPARTMENTS.LOCATION_ID%TYPE,p_mensaje out varchar2)
    is
        v_department_id departments.department_id%type;
        v_department_dup exception;
        v_existe int;
    begin
        
        select count(1)
        into v_existe
        from departments
        where upper (department_name, manager_id, location_id) = upper (dep_id,dep_nom,loc_id);
        
        if v_existe >= 1 then
            raise v_department_dup;
        else
            
            select max(department_id)+1 into v_department_id from departments;
            
            insert into departments values(dep_id,dep_nom,man_id,loc_id);
            commit;
            p_mensaje := 'Departamento ingresado . ID: '||v_department_id;
        end if;
    exception
        when v_depa_dup then
            p_mensaje := ('Existe el departamento ingresado : '||dep_nom);
        when DUP_VAL_ON_INDEX then
            p_mensaje := ('ERROR - Primary key repetido');
        when others then
            p_mensaje := ('Error encontrado: '||SQLCODE||' Mensaje: '||SQLERRM);    
    end;
    
    /*Actualizar los datos del departamento*/
    procedure mant_actualizar(dep_id DEPARTMENTS.DEPARTMENT_ID%TYPE,
    dep_nom DEPARTMENTS.DEPARTMENT_NAME%TYPE, man_id DEPARTMENTS.MANAGER_ID%TYPE,loc_id DEPARTMENTS.LOCATION_ID%TYPE,p_mensaje out varchar2)
    as
        v_err_nombre exception;
        v_err_manag exception;
        v_err_loc exception;
        v_num_depa int;
    begin
        
        select count(*) into v_num_depa from departments where upper(department_name,manager_id,location_id) = upper(dep_nom,man_id,loc_id);
        
        if v_num_depa > 0 then
            raise v_err_nombre;  
            raise v_err_manag ;
            raise v_err_loc;
        end if;
        
        update departments
        set department_name = initcap(dep_nom), manager_id = man_id, location_id = loc_id
        where department_id = dep_id;
        commit;
        p_mensaje := 'El departamento se actualizó correctamente: '||dep_id||'-'||initcap(dep_nom)||'-'||man_id||'-'||loc_id;
    exception
        when NO_DATA_FOUND then
            p_mensaje := ('Departamento no existente.');
        when v_err_nombre then
            p_mensaje := ('Nombre de departamento ya existente');
        when v_err_manag then
            p_mensaje := (' ID del manager ya existe');
        when v_err_loc then
            p_mensaje := (' ID de la locación ya existe');
        when others then
            p_mensaje := ('Error encontrado: '||SQLCODE||' Mensaje: '||SQLERRM);
    end;
    
    /*Eliminar un departamento*/
    procedure mant_eliminar (DEP_ID DEPARTMENTS.DEPARTMENT_ID%TYPE,p_mensaje out varchar2)
    as
        v_exs_locations exception;
        v_num_locations number;
    begin
    
        select count(*) into v_num_locations from locations where department_id = dep_id;
        
        if v_num_locations > 0 then
            raise v_exs_locations;
        end if;
        
        delete from departments
        where department_id = dep_id;
        
        if sql%notfound then
            p_mensaje := 'Código solicitado no existe: '||dep_id;
        else
            commit;
            p_mensaje := 'Departamento se eliminó corectamente: '||dep_id;
        end if;
    exception
        when v_exs_locations then
            p_mensaje := 'Locación  la cual impide ejecutar la eliminación.';
        when others then
            p_mensaje := 'Error encontrado : '||SQLCODE||' Mensaje: '||SQLERRM;
    end;
end;




create or replace package MANT_CALCULAR
is
    function f_obtener_fecha(p_fecha_cont employees.hire_date%type)return varchar2;
    function f_bono(p_codemp employees.employee_id%type)return numeric;
    function f_descto(p_codjob jobs.job_id%type) return numeric;
end;

create or replace package body MANT_CALCULAR
as

    --	Función que calcule la cantidad de años, enviando como parámetro una fecha.
    function f_obtener_fecha(p_fecha_cont employees.hire_date%type)return varchar2
    is
        id_emp employees.employee_id%type;
        v_en_texto varchar2(100);
    begin
        select trunc(years_between(sysdate,hire_date)/12) 
        from employees
        where employee_id = id_emp;
    exception
        when others then
            v_en_texto := ('Ha ocurrido un error: '||SQLERRM);
            return v_en_texto;
    end;
    
    -- Función que calcule un bono enviando como parámetro el salario. La formula es la siguiente: 
    -- BONO_UTIL = (((SALARIO*7) + 15% SALARIO)/5 )+ 35 SOLES POR CADA AÑO TRABAJADO(use la función creada anteriormente)
    function f_bono(p_codemp employees.employee_id%type)return numeric
    is
        sal employees.salary%type;
        bono employees.salary%type;
    begin 
        select salary
        into sal
        from employees
        where employee_id = p_codemp;
        
        bono := (((sal*7)+0.15*sal)/5)+35*(fn_obtener_fecha);
        return bono;
    exception
        when others then
        return -1;
    end;
    
    -- Función que calcule un descuento en base al JOB_ID y SALARIO enviados como parámetros:
    -- DESCUENTO = (SALARIO – (SALARIO MINIMO DEL JOB_ID))
    function f_descto(p_codjob jobs.job_id%type) return numeric
    is
        sal employees.salary%type;
        dscto employees.salary%type;
    begin
        select e.salary, j.min_salary 
        into sal
        from employees e
        inner join jobs j on j.job_id = e.job_id
        where j.job_id = p_codjob;
    
        dscto := (sal - (j.min_salary));
        return dscto;
    exception
        when others then
            return -1;
    end;
end;

procedure sp_reporte(p_id_emp employees.employee_id%type)
is
    cursor c_empleado is (SELECT e.employee_id,e.first_name,e.last_name,e.hire_date,e.salary, j.job_title FROM employees e 
    inner join jobs j on j.job_id = e.job_id where department_id = p_id_emp);
begin
    
    DBMS_OUTPUT.PUT_LINE('REPORTE-DEPARTAMENTO: TI');
    DBMS_OUTPUT.PUT_LINE('====================================');
    for reg_emp in c_empleado loop
    DBMS_OUTPUT.PUT_LINE('Empleado: '||reg_emp.first_name||' '||reg_emp.last_name);
    DBMS_OUTPUT.PUT_LINE('Fecha de contrato: '||reg_emp.hire_date);
    DBMS_OUTPUT.PUT_LINE('Trabajo: '||reg_emp.job_id||'-'||reg_emp.job_title);
    DBMS_OUTPUT.PUT_LINE('Salario: '||to_char(salary,'L999,999.99'));
    DBMS_OUTPUT.PUT_LINE('************************************');
    DBMS_OUTPUT.PUT_LINE('BONO UTIL         '||fn_bono(reg_emp.employee_id));
    DBMS_OUTPUT.PUT_LINE('DESCUENTO         '||fn_dscto(reg_emp.employee_id));
    DBMS_OUTPUT.PUT_LINE('************************************');
    end loop;
end;
