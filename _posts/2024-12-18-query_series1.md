---
layout: post


title: "mysql 쿼리 기능"


date: 2024-12-18 22:00:00 +0900


categories: [LEAD, LAG, OVER, PARTITION]


tags: [LEAD, LAG, OVER, PARTITION]
---

## **윈도우 함수란?**
> 행과 행 간의 관계를 정의하거나 계산할때 씀. 데이터를 그룹화하지 않고도 각 행을 유지하면서 추가적인 계산을 수행
> 특징으로는 GROUP BY와 다르게 행이 유지되고 OVER절을 써야하고 행간 순위, 누적합계 비교가 가능함.
{: .prompt-tip }

## **LEAD**
- **LEAD** 함수는 현재 행을 기준으로 이후 행의 데이터를 가져오는 데 사용.
- 주로 다음 행의 값과 현재 행의 값을 비교하거나, 다음 데이터의 예측값을 계산할 때 활용.

```sql
LEAD(<expression>[, offset[, default_value]]) OVER (PARTITION BY <expr> ORDER BY <expr>)
```
- **expression**: 반환할 열(column) 값.
- **offset**: 기준 행으로부터 몇 번째 이후 값을 가져올지 지정. 기본값은 1.
- **default_value**: 이후 행이 없을 경우 반환할 기본값. 기본값은 `NULL`.
- **PARTITION BY**: 데이터를 그룹화하여 각 그룹 내에서 별도로 계산.
- **ORDER BY**: 행의 순서를 지정.

![image](https://github.com/mskim0425/msKim0425.github.io/blob/main/images/sql/lead_examp.jpg?raw=true)

```sql
SELECT 
    customerName,
    orderDate,
    LEAD(orderDate, 1) OVER (PARTITION BY customerNumber ORDER BY orderDate) AS nextOrderDate
FROM orders
INNER JOIN customers USING (customerNumber);
```
- 위의 이미지 처럼 각각의 고객별로 주문 날짜를 기준으로 정렬하고, 다음 주문 날짜를 조회가 필요할 때 사용

---

## **LAG**
- **LAG** 함수는 현재 행을 기준으로 이전 행의 데이터를 가져오는 데 사용
- 주로 이전 값과 현재 값을 비교하거나 변화 추이를 계산할 때 활용

```sql
LAG(<expression>[, offset[, default_value]]) OVER (PARTITION BY <expr> ORDER BY <expr>)
```
- 구문은 LEAD와 동일하지만 전 상태를 비교할때 씀

| productline | order_year | order_value | prev_year_order_value |
|-------------|------------|-------------|------------------------|
| Classic Cars | 2022 | 1500000 | NULL |
| Classic Cars | 2023 | 1650000 | 1500000 |
| Classic Cars | 2024 | 1800000 | 1650000 |
| Vintage Cars | 2022 | 800000 | NULL |
| Vintage Cars | 2023 | 850000 | 800000 |
| Vintage Cars | 2024 | 900000 | 850000 |
| Motorcycles | 2022 | 600000 | NULL |
| Motorcycles | 2023 | 650000 | 600000 |
| Motorcycles | 2024 | 700000 | 650000 |

```sql
WITH productline_sales AS (
    SELECT 
        productline,
        YEAR(orderDate) AS order_year,
        ROUND(SUM(quantityOrdered * priceEach), 0) AS order_value
    FROM orders
    INNER JOIN orderdetails USING (orderNumber)
    INNER JOIN products USING (productCode)
    GROUP BY productline, order_year
)
SELECT 
    productline,
    order_year,
    order_value,
    LAG(order_value, 1) OVER (PARTITION BY productline ORDER BY order_year) AS prev_year_order_value
FROM productline_sales;
```
- 각 제품군(productline)의 연도별 매출액을 계산하고, 전년도 매출액(prev_year_order_value)을 비교할떄 씀


| 기능                  | LEAD                                | LAG                                |
|-----------------------|-------------------------------------|-------------------------------------|
| 반환값               | 현재 행 기준 이후 값               | 현재 행 기준 이전 값               |
| 주요 목적            | 미래 데이터 참조                   | 과거 데이터 참조                   |
| 기본값               | NULL                               | NULL                               |
| 활용 예시            | 다음 주문 날짜 조회                | 전년도 매출액 비교                 |

---

## **OVER**
- 윈도우 함수에서 **반드시 사용되는 구문**으로, 특정 범위를 정의해야함
- `ORDER BY`를 통해 행의 순서를 지정하거나, `PARTITION BY`를 통해 그룹화된 데이터 내에서 연산을 수행할 수 있음.

## **PARTITION BY**
- 데이터를 특정 그룹으로 나누어 각 그룹 내에서 독립적으로 연산을 수행
- `PARTITION BY`를 생략하면 전체 데이터셋에 대해 연산이 수행

| employeeName | department | salary | rank_in_department |
|--------------|------------|--------|---------------------|
| John Smith   | IT         | 95000  | 1                   |
| Jane Doe     | IT         | 92000  | 2                   |
| Mike Johnson | IT         | 88000  | 3                   |
| Emily Brown  | IT         | 85000  | 4                   |
| Sarah Lee    | Sales      | 110000 | 1                   |
| Tom Wilson   | Sales      | 105000 | 2                   |
| Lisa Chen    | Sales      | 98000  | 3                   |
| David Kim    | Sales      | 95000  | 4                   |
| Mary Taylor  | HR         | 88000  | 1                   |
| Robert White | HR         | 85000  | 2                   |
| Anna Garcia  | HR         | 82000  | 3                   |

```sql
SELECT 
    employeeName,
    department,
    salary,
    RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS rank_in_department
FROM employees;
```
- 각 부서별로 직원들의 급여 순위를 계산 `rank_in_department 구하기`

---
