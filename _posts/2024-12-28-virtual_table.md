---
layout: post


title: "가상테이블"


date: 2024-12-28 09:40:00 +0900


categories: [virtual_table]


tags: [mysql,virtual_table]
---
MySQL에서 가상 테이블은 실제 데이터를 저장하지 않고 쿼리 결과를 임시로 저장하는 객체아다.     
가상 테이블의 주요 형태로는 View, 파생 테이블(Derived Table), CTE(Common Table Expression), Temporary Table이 있다.

## 1. 뷰(View)
뷰는 하나 이상의 테이블에서 원하는 데이터를 선택하여 만든 가상 테이블이다.     
뷰는 데이터베이스에 저장되며, 재사용이 가능하다.

### 특징:
- 실제 데이터를 저장하지 않고, 쿼리 정의만 저장한다.    
- 기본 테이블의 데이터가 변경되면 뷰의 데이터도 자동으로 변경된다.      
- 복잡한 쿼리를 단순화할 수 있다.     

### 예시:
```sql
-- 뷰 생성
CREATE VIEW high_salary_employees AS
SELECT employee_id, first_name, last_name, salary
FROM employees
WHERE salary > 5000;

-- 뷰 테이블 조회
SELECT * FROM high_salary_employees;
```

이 예시에서는 급여가 5000 이상인 직원들의 정보를 보여주는 뷰를 생성했다. 이 뷰는 마치 실제 테이블처럼 사용할 수 있다. 또한 별도의 수동 삭제가 필요하다. 
~~~sql
DROP VIEW {테이블 명}
~~~

## 2. 파생 테이블(Derived Table)

파생 테이블은 FROM 절에서 서브쿼리로 만들어지는 임시 테이블이다. 쿼리 실행 중에만 존재하며, 쿼리가 끝나면 사라진다.

### 특징:
- 복잡한 조인이나 집계 연산을 단순화할 수 있다.
- 메인 쿼리의 가독성을 높일 수 있다.
- 일회성으로 사용된다.

### 예시:

```sql
SELECT dept_name, avg_salary
FROM (
    SELECT department_id, AVG(salary) as avg_salary
    FROM employees
    GROUP BY department_id
) AS dept_salaries
JOIN departments d ON dept_salaries.department_id = d.department_id;
```

이 예시에서는 각 부서의 평균 급여를 계산하는 서브쿼리를 파생 테이블로 사용했다.

## 3. CTE(Common Table Expression)
CTE는 WITH 절을 사용하여 이름이 부여된 임시 결과 집합을 정의한다. 복잡한 쿼리를 더 읽기 쉽고 관리하기 쉽게 만들어준다.

### 특징:
- 쿼리 내에서 여러 번 참조할 수 있다.
- 재귀적 쿼리를 작성할 수 있다.
- 쿼리의 가독성과 유지보수성을 향상시킨다.

### 예시:

```sql
WITH RECURSIVE employee_hierarchy AS (
    -- 기준 행 (최상위 관리자)
    SELECT employee_id, first_name, last_name, manager_id, 0 AS level
    FROM employees
    WHERE manager_id IS NULL
    
    UNION ALL
    
    -- 재귀 부분
    SELECT e.employee_id, e.first_name, e.last_name, e.manager_id, eh.level + 1
    FROM employees e
    JOIN employee_hierarchy eh ON e.manager_id = eh.employee_id
)
SELECT * FROM employee_hierarchy;
```

이 예시는 재귀적 CTE를 사용하여 직원들의 계층 구조를 표현했다. 최상위 관리자부터 시작해서 모든 하위 직원들을 레벨별로 보여준다.

## 4. 임시 테이블 TEMPORARY TABLE
임시 테이블은 CREATE TEMPORARY TABLE 명령으로 생성되며, 세션이 종료될 때까지 존재한다.    
~~~sql
-- 임시 테이블 생성
CREATE TEMPORARY TABLE temp_sales (
    id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(100),
    total_sales DECIMAL(10,2)
);

-- 데이터 삽입
INSERT INTO temp_sales (product_name, total_sales)
SELECT p.name, SUM(o.quantity * o.price)
FROM products p
JOIN orders o ON p.id = o.product_id
GROUP BY p.id;

-- 임시 테이블 사용
SELECT * FROM temp_sales WHERE total_sales > 10000;
~~~
세션이 종료되는 시점은 명시적으로 연결 종료를 하던지, DB 커낵션이 끊킨다던가,       
타임아웃, 임시테이블 자동삭제 마지막으로 새로운 세션시작 (동알한 테이블 생성 쿼리)시 종료된다고 보면된다.

## 정리

| 특성 | View | 파생 테이블 | CTE | 임시 테이블 |
|------|------|------------|-----|------------|
| 정의 | 저장된 쿼리 결과를 가상 테이블로 표현 | FROM 절의 서브쿼리로 생성되는 임시 결과셋 | WITH 절을 사용해 정의되는 명명된 임시 결과셋 | CREATE TEMPORARY TABLE로 생성되는 실제 테이블 |
| 지속성 | 데이터베이스에 영구 저장 | 쿼리 실행 중에만 존재 | 쿼리 실행 중에만 존재 | 세션 종료 시까지 존재 |
| 재사용성 | 여러 쿼리에서 재사용 가능 | 단일 쿼리 내에서만 사용 | 단일 쿼리 내에서 여러 번 참조 가능 | 세션 내에서 여러 쿼리에서 재사용 가능 |
| 데이터 수정 | 일부 경우 가능 | 불가능 | 불가능 | 가능 (INSERT, UPDATE, DELETE) |
| 인덱싱 | 일부 DBMS에서 가능 | 불가능 | 불가능 | 가능 |
| 복잡성 처리 | 복잡한 쿼리 단순화 | 중간 결과 생성으로 복잡한 연산 단순화 | 복잡한 쿼리를 논리적 부분으로 분해 | 복잡한 중간 결과 저장 및 처리 |
| 성능 | 자주 사용 시 성능 향상 가능 | 대규모 데이터에서 성능 저하 가능 | 복잡한 쿼리에서 성능 향상 가능 | 대량 데이터 처리 시 유리 |
| 재귀 쿼리 | 지원하지 않음 | 지원하지 않음 | 지원 | 지원하지 않음 |
| 생성 방법 | CREATE VIEW | 서브쿼리 | WITH 절 | CREATE TEMPORARY TABLE |