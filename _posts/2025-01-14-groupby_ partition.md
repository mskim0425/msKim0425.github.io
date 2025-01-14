---
layout: post


title: "비슷하면서 다른 SQL 정리"


date: 2025-01-14 19:40:00 +0900


categories: [PARTITION, GROUP]


tags: [mysql, PARTITION, GROUPBY]
---
### GROUP BY와 PARTITION BY
GROUP BY와 PARTITION BY는 SQL에서 데이터를 그룹화하는 데 사용되는 중요한 구문이다.        
두 구문은 유사한 기능을 하지만, 결과 데이터의 구조와 사용 목적에 차이가 있다.

#### 주요 차이점

| 특성 | GROUP BY | PARTITION BY |
|------|----------|--------------|
| 결과 행의 수 | 그룹화된 결과만 반환하여 감소 | 모든 원본 행 유지 |
| 데이터 집계 방식 | 그룹별로 집계하여 하나의 결과 행 생성 | 각 행에 그룹의 집계 결과 추가 |
| 사용 위치 | SELECT 문의 마지막 부분 | 윈도우 함수와 함께 OVER 절 내에서 사용 |

#### GROUP BY

```sql
SELECT department, AVG(salary) as avg_salary
FROM employees
GROUP BY department;

| department | avg_salary |
|------------|------------|
| IT         | 75000      |
| Sales      | 65000      |
| HR         | 55000      |
```

이 쿼리는 부서별 평균 급여를 계산하며, 결과는 부서 수만큼의 행을 반환한다.   
주로 총매출 계산이나 제품 카테고별 평균 가격 산출에 용이하다.

#### PARTITION BY

```sql
SELECT 
    employee_name,
    department,
    salary,
    AVG(salary) OVER (PARTITION BY department) as dept_avg_salary
FROM employees;

| employee_name | department | salary | dept_avg_salary |
|---------------|------------|--------|-----------------|
| 도비           | IT         | 80000  | 75000           |
| 헤르미온느       | IT         | 70000  | 75000           |
| 해리포터        | Sales      | 60000  | 65000           |
| 존시나          | Sales      | 70000  | 65000           |
| 다비드          | HR         | 55000  | 55000           |
```

이 쿼리는 모든 직원의 정보를 유지하면서 각 부서의 평균 급여를 함께 표시한다.   
각각의 지원급여와 해당 부서평균 급여나 월별 매출과 연각 누적 매출을 동시에 보고 싶을떄 사용

#### 결론

GROUP BY는 데이터를 요약하고 집계할 때 유용하며, PARTITION BY는 원본 데이터를 유지하면서 그룹별 계산 결과를 함께 보여주고자 할 때 효과적이다. 분석 목적과 필요한 결과 형태에 따라 적절한 구문을 선택하여 사용하면 된다.


 < 정리중 >
### UNION vs. UNION ALL

| 특성 | UNION | UNION ALL |
|------|-------|-----------|
| 중복 제거 | 중복 행 제거 | 중복 행 유지 |
| 성능 | 중복 검사로 인해 상대적으로 느림 | 중복 검사 없어 빠름 |
| 결과 정렬 | 자동으로 결과 정렬 | 정렬하지 않음 |

### JOIN vs. SUBQUERY

| 특성 | JOIN | SUBQUERY |
|------|------|----------|
| 데이터 결합 방식 | 테이블 간 직접 결합 | 쿼리 내 다른 쿼리 포함 |
| 성능 | 대체로 빠름 | 복잡한 경우 느릴 수 있음 |
| 가독성 | 복잡한 조인에서 가독성 떨어질 수 있음 | 간단한 경우 가독성 좋음 |
| 유연성 | 다중 테이블 조인 가능 | 단일 값 또는 행 집합 반환 |

### WHERE vs. HAVING

| 특성 | WHERE | HAVING |
|------|-------|--------|
| 필터링 시점 | 그룹화 전 행 필터링 | 그룹화 후 결과 필터링 |
| 집계 함수 사용 | 사용 불가 | 사용 가능 |
| 성능 | 일반적으로 더 빠름 | WHERE로 먼저 필터링한 후 사용 시 효율적 |
| 사용 위치 | GROUP BY 이전 | GROUP BY 이후 |

### INNER JOIN vs. OUTER JOIN

| 특성 | INNER JOIN | OUTER JOIN |
|------|------------|------------|
| 결과 행 | 양쪽 테이블에서 일치하는 행만 | 한쪽 또는 양쪽 테이블의 모든 행 포함 가능 |
| NULL 처리 | NULL 값 제외 | NULL 값 포함 가능 |
| 사용 사례 | 두 테이블 간 공통 데이터 필요 시 | 한 테이블의 모든 데이터와 매칭 정보 필요 시 |