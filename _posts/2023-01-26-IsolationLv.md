---
layout: post
title:  "Isolation Level"
date:   2023-01-26 12:20:57 +0900
categories: [SQL , LOCK]
tags: [sql, db, lock]
---

## 선착순 이벤트를 한다? 100명까지
위와 같은 이벤트를 진행한다고 가정했을 떄, 99번째때 참가자가 0.01초까지 같다고 가정했을 때, 누구를 선택할것인가?   
필자같은 경우는 wiselife 프로젝트에서 챌린지 인증시각이 10:00시~ 10:10분까지인데 10:09:59 인 사람이 인증을 했을 때, 서버 응답시간으로 인해 인증을 못한다면? 서비스 센터에 바로 전화가 올 것이다.  
이렇게 엄격하게 ACID특성을 지키면 동시성(Concurrency)를 해결 할 수 없을 것이다. 이 점을 해결할 수 있는 부분이 Transaction의 격리 레벨인 Isolation LV이다.   
격리성을 덜 지키는 대신 더 좋은 동시성을 얻을 수 있다.  

## 일관성=정합성 ∝ 동시성 

`동시성 제어`란 동시에 실행되는 트랜잭션의 수를 최대화 하는 것과 데이터 CRUD 시 데이터의 무결성을 유지하는 것이다. 이것은 트레이드 오프 관계인지라 동시성이 증가하면 일관성은 감소할 수 밖에 없는 반비례 관계이다.
<img src="https://dataonair.or.kr/images/know/tech/090709_vds1.jpg"> 

또한 동시성은 '낙관적 동시성 제어'와 '비관적 동시성 제어'로 나뉘는데,

`낙관적 동시성 제어`  
**같은 데이터를 동시에 수정하지 않을 것으로 가정**하고 데이터를 읽는 시점에 락을 걸진 않지만 수정하는 시점에서 기존에 읽어온 데이터가 다른 사용자에 의해 변경되었는지 재검사가 필요한 경우  

`비관적 동시성 제어`  
**같은 데이터를 동시에 수정할 것으로 가정**하고 데이터를 읽는 시점에서 락을 걸고 조회, 갱신 완료 시까지 락을 유지하는 경우  
   
## InnoDB LOCK  
 LOCK은 트랜잭션 처리의 절차를 보장하기 위한 방법이다. 격리단계에 따라 더 느슨하게 더 강하게 lock을 거는 것이다. 또한, DBMS별로 구현방식과 세부적인 방법이 제각각이기에 사용법을 알고 사용해한다. 필자는 MySQL의 InnoDB의 LOCK을 말할 예정이다.  

### Row-level lock
가장 기본적인 Lock은 테이블의 row마다 걸리는 락이있다.   
이것은 공유락(shared lock, read lock), 배타락 (Exclusive lock, write lock) 두종류로 나뉜다.   

> `S lock = Read lock` S LOCK을 사용하는 쿼리끼는 같은 row에 접근이 가능하다.  
> `X lock = Write lock` X LOCK이 걸린 row는 어떠한 쿼리도 접근 불가능
{: .prompt-tip}  

### Record lock  
해당 레코드 락은 row가 아닌 DB의 인덱스 레코드에 걸리는 락이다. 여기서 s lock, x lock이 있다. 예시를 보자  
```sql
트랜잭션 A
SELECT s1 FROM studnet WHERE s1 = 1 FOR UPDATE; 

트랜잭션 B
DELETE FROM student where s1 = 1;
```
트랜잭션 A쿼리가 실행되었을떄 student.s1의 값이 1인 인덱스에 X lock이 걸린다. 이 경우에 트랜잭션 B의 쿼리를 실행하려고하면, student.s1의 값이 1인 인덱스에 똑같이 X lock을 걸려고 시도하지만 이미 선점되어있는 상태이기 떄문에 트랜잭션A가 실행완료되기 전까지는 해당 s1 학생을 삭제할 수 없다.  

### Gap lock
Gap lock은 DB index record의 gap에 걸리는 lock이다. 여기서 gap이란 index 중 DB에 실제 record가 없는 부분이다.   
이게 무슨말이냐 하면..아래와 같은 테이블이 있고 현재 ID 칼럼에 인덱스가 걸려있는 상황이다.  

|ID|NAME|
|:---:|:---:|
|2||
|3|홍길동|
|4||
|5|아무개|

현재 2와 4는 인덱스 레코드가 없다. 이 부분을 index record의 gap이라한다.  

 위처럼 `gap lock은 해당 gap에 접근하려는 다른 쿼리의 접근을 막는다`. 이는 Record lock이 해당 index를 탈 때, 다른 쿼리의 접근을 막는 것과 동일하다.   
 둘의 차이점은 record lock이 이미 존재하는 row가 변경되지 않도록 보호하는   
 반면, gap lock은 조건에 해당하는 새로운 row가 추가되는 것을 방지하기 위함이다.

## 격리단계  
`Read Uncommitted`   
가장 낮은 격리 수준, 커밋되지 않은 데이터를 읽을 수 있다.  
ROLLBACK이 될 데이터도 읽어올 수 있으므로 주의가 필요하다.  
LOCK이 발생하지 않는다.  
`Read Committed`      
커밋된 데이터만 읽을 수 있다.  
read operation마다 스냅샷을 저장한다.   
구현 방식이 차이 때문에 Query를 수행한 시점의 데이터와 정확하게 일치하지 않을 수 있다.    
LOCK이 발생하지 않는다.    
**MySQL에서 많은 양의 데이터를 복제하거나 이동할 때 이 LEVEL을 추천한다.**  
`Repetable Read`    
1. MySQL Default Level이고, 한 번 조회한 데이터를 반복해서 조회해도 같은 데이터가 조회된다.  

```sql
mysql 디폴트 설정

mysql> SHOW VARIABLES WHERE VARIABLE_NAME='tx_isolation';
+---------------+-----------------+
| Variable_name | Value           |
+---------------+-----------------+
| tx_isolation  | REPEATABLE-READ |
+---------------+-----------------+
1 row in set (0.00 sec)
```

2. SELECT시 현재 시점의 스냅샷을 만들고 스냅샷을 조회한다. 즉, 처음으로 read operation (SELECT)을 수행한 시간을 기록한다. 그리고 모든 read operation마다 해당 시점을 기준으로 consistent read를 수행한다. 그러므로 트랜잭션 도중에 다른 트랜잭션이 커밋되더라도 새로 커밋된 데이터는 조회되지 않는다. 이유는 첫 read시의 스냅샷이 보이기 떄문이다.
3. record lock과 gap lock이 발생      

 `Serializable`   
 가장 엄격한 격리 수준이다.   
 SELECT 문에 사용하는 모든 테이블에 shared lock이 발생한다.  
 ```sql
(A) SELECT state FROM account WHERE id = 1; 
(B) SELECT state FROM account WHERE id = 1;
(B) UPDATE account SET state = ‘rich’, money = money * 1000 WHERE id = 1; 
(B) COMMIT;
(A) UPDATE account SET state = ‘rich’, money = money * 1000 WHERE id = 1;
(A) COMMIT;
 ```
 
|트랜잭션 A	|트랜잭션 B|
|---|---|
|BEGIN|	|
|SELECT state FROM account WHERE id = 1	`S lock 발동`||
||BEGIN|
||SELECT state FROM account WHERE id = 1  `S lock 발동`|
|`X lock실패`|UPDATE account SET state = 'rich', money = money * 1000 WHERE id = 1|
||COMMIT|
|UPDATE account SET state = 'rich', money = money * 1000 WHERE id = 1	|`X lock실패`|
|COMMIT	||

row에 S lock이 걸려있으므로 데드락 상태로 전환되고 두 개의 트랜잭션은 모두 timeout된다. 즉, 돈은 원금 그대로 남아있게 된다.   
이처럼 데이터는 보호되지만 쉽게 데드락이 될 수 있으므로 무차별적으로 사용하면 안된다.

```java
  // 별도로 정의하지 않으면 DB의 Isolation Level을 따름
  @Transactional(isolation = Isolation.DEFAULT)
  @Transactional(isolation = Isolation.READ_UNCOMMITTED)
  @Transactional(isolation = Isolation.READ_COMMITTED)
  @Transactional(isolation = Isolation.REPEATABLE_READ)
  @Transactional(isolation = Isolation.SERIALIZABLE)
  
```
#### 계속해서 언급된 Consistent read이란?
read(=SELECT) operation을 수행할 때 현재 DB의 값이 아닌 특정 시점의 DB snapshot을 읽어오는 것이다. snapshot은 commit 된 변화만이 적용된 상태를 의미한다.  
   
row에 lock을 걸어 다른 transaction이 할 수 없도록 하는 방법이 가장 단순한 방법이지만 InnoDB 엔진은 동시성이 매우 떨어지기 때문에 consistent read를 하기 위해 lock을 사용하지 않는다.

InnoDB 엔진은 실행했던 `쿼리의 log를 통해 consistent read를 지원`한다. InnoDB 엔진은 각 쿼리를 실행할 때마다 실행한 쿼리의 log를 차곡차곡 저장한다. 그리고 나중에 consistent read를 할 때 이 log를 통해 특정 시점의 DB snapshot을 복구하여 가져온다. 이 방식은 비록 복구하는 비용이 발생하긴 하지만, lock을 활용하는 방식보다 높은 동시성을 얻을 수 있다.

한가지 주의해야하는 점은 Update나 Delete같은 DML 쿼리에서는 해당 Consistent read를 적용받지 않는다. where 조건을 사용해도 내가 수정하려고 한 select쿼리로 읽어온 row와 해당 row들을 수정하기 위해서 update 쿼리를 날렸을때 수정되는 row가 다를수 있다는 것이다.    

아래는 두 트랜잭션이 REPEATABLE READ가 아래와 같이 일어났을때를 나타낸 것이다.
```sql
트랜잭션 A - isolation: READ COMMITTED
SELECT COUNT(name) FROM STUDENT WHERE name = 'TOM';
DELETE FROM STUDENT WHERE name = 'TOM';
COMMIT;

트랜잭션 B - isolation: READ COMMITTED
INSERT INTO STUDENT(name,score) VALUES ('TOM',100),('TOM',95),('TOM',90);
COMMIT;

두 트랜잭션이 아래와같이 일어났을떄
(A) SELECT COUNT(name) FROM STUDENT WHERE name = 'TOM'; // 데이터가 없는 상황이므로 실행결과는 0 
(B) INSERT INTO STUDENT(name,score) VALUES ('TOM',100),('TOM',95),('TOM',90);  //non lock 상태이므로 해당 쿼리 실행
(B) COMMIT;
(A) DELETE FROM STUDENT WHERE name = 'TOM'; // 3 rows 삭제
(A) COMMIT;
```
위처럼 consistent read에는 보이지 않는 row에 DML 쿼리가 영향을 준 경우, 그 시점 이후로는 해당 row가 transaction에 보이기 시작한다.  
위와같은 상황을 회피하기 위해 SERIALIZABLE을 써야한다는 것이다.  

## 격리 수준이 낮을때 발생되는 문제점  

### Dirty read
커밋이 완료되지 않은 데이터를 다른 트랜잭션이 읽는 케이스. 이로인해 최종 결과가 비일관적으로 저장될 수 있다.    
>Transaction A에서 row를 삽입했다.  
>READ UNCOMMITTED transaction B가 해당 row를 읽는다.  
>Transaction A가 rollback 된다.  
>B는 존재하지않은 데이터를 읽은 케이스르 Dirty read라고 한다.   
  
이것이 가능한 이유는 InnoDB 엔진이 transaction을 commit 하는 방법 때문이다. InnoDB 엔진은 커밋이 적용됐던 안됐던 일단 실행된 모든 쿼리를 DB에 적용한다.   
즉, 특정 log를 보고 특정 시점의 snapshot을 복구하는 consistent read를 하지 않고 그냥 해당 시점의 DB를 읽으면 dirty read가 된다. 아래는 해당 내용을 언급한 MySQL reference의 내용이다.  

>InnoDB는 커밋에 낙관적 메커니즘을 사용하므로 커밋이 실제로 발생하기 전에 데이터 파일에 변경 사항을 기록할 수 있습니다. 이 기술은 롤백의 경우 더 많은 작업이 필요하다는 단점과 함께 커밋 자체를 더 빠르게 만듭니다.

### Non Repeatable Read  
반복해서 같은 데이터를 읽을 수 없게 되는 케이스. 한 트랜잭션에서 같은 쿼리를 두 번 수행할 때 그 사이에 다른 트랜잭션이 값을 수정/삭제하므로 두 쿼리의 결과가 상이하게 나타나는 비 일관성의 문제가 발생한다.  

### Phantom Read
반복 조회 시, 결과 집합이 달라지는 케이스. 한 트랜잭션 안에서 일정 범위의 레코드를 두 번 읽을 때, 처음 결과에 없던 레코드가 두 번째에서는 나타나는 문제

이렇게 총 4가지 케이스가 있는데 격리수준을 낮게 했을 때, 발생되는 문제점은 아래와 같다.   

||Dirty read|Non Repeatable Read|Phantom Read|
|---|:---:|:---:|:---:|
|Read Uncommitted|0|0|0|
|Read Committed||0|0|
|Repetable Read|||0|
|Serializable||||  

<!-- 트랜잭션 전파(Transaction Propagation)
트랜잭션 전파란 트랜잭션의 경계에서 진행 중인 트랜잭션이 존재할 때 또는 존재하지 않을 때, 어떻게 동작할 것인지 결정하는 방식을 의미합니다.

트랜잭션 전파는 propagation 애트리뷰트를 통해서 설정할 수 있으며, 대표적으로 아래와 같은 propagation 유형을 사용할 수 있습니다.

Propagation.REQUIRED
우리가 앞에서 @Transactional 애너테이션의 propagation 애트리뷰트에 지정한 Propagation.REQUIRED 는 일반적으로 가장 많이 사용되는 propagation 유형의 디폴트 값입니다.
진행 중인 트랜잭션이 없으면 새로 시작하고, 진행 중인 트랜잭션이 있으면 해당 트랜잭션에 참여합니다.

Propagation.REQUIRES_NEW
이미 진행중인 트랜잭션과 무관하게 새로운 트랜잭션이 시작됩니다. 기존에 진행중이던 트랜잭션은 새로 시작된 트랜잭션이 종료할 때까지 중지됩니다.

Propagation.MANDATORY
Propagation.REQUIRED는 진행 중인 트랜잭션이 없으면 새로운 트랜잭션이 시작되는 반면, Propagation.MANDATORY는 진행 중인 트랜잭션이 없으면 예외를 발생시킵니다.

Propagation.*NOT_SUPPORTED*
트랜잭션을 필요로 하지 않음을 의미합니다. 진행 중인 트랜잭션이 있으면 메서드 실행이 종료될 때 까지 진행중인 트랜잭션은 중지되며, 메서드 실행이 종료되면 트랜잭션을 계속 진행합니다.

Propagation.*NEVER*
트랜잭션을 필요로 하지 않음을 의미하며, 진행 중인 트랜잭션이 존재할 경우에는 예외를 발생시킵니다 -->

## what I learn  
row를 읽을떄는 디폴트 설정인 Repetable Read, CRUD를 진행할떄는 Serializable을 사용해서 진행했는데, 이젠 적절하게 isolation을 낮추면서 동시성을 높일수 있는 여러 LV을 고려하여 선택해야겠다.  

## 출처
https://dev.mysql.com/doc/refman/5.6/en/innodb-transaction-isolation-levels.html) 
https://dev.mysql.com/doc/refman/5.6/en/innodb-locking.html  
https://dev.mysql.com/doc/refman/8.0/en/innodb-locking-transaction-model.html
https://blog.sapzil.org/2017/04/01/do-not-trust-sql-transaction  
https://jupiny.com/2018/11/30/mysql-transaction-isolation-levels