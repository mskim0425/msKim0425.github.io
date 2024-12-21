---
layout: post


title: "INDEX에 관하여"


date: 2024-12-21 13:40:00 +0900


categories: [index, single, multi]


tags: [index, single, multi]
---

전에 클러스터인덱스와 넌클러스터 인덱스에 대해 다뤄봤었는데 복습겸 다시 한번 적자면    
`클러스터 인덱스`는 기본키나 빈번하게 검색이나 정렬이 필요한 열에 사용하고(자동으로 기본키가 됨)    
`넌클러스터 인덱스`는 WHERE 절에 자주 사용되고 여러조합에 쿼리 성능을 뽑아낼때 쓴다고 한다.    
그래서 이참에 인덱스에 대해 정리해볼까 하고 글을 쓴다.   


단순한 회원테이블이 있다고 가정해보자.
```sql
CREATE TABLE members (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL,
    birthdate DATE,
    age INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id)
);
```   
### 단일 인덱스
단일 인덱스는 하나의 컬럼에 대해서만 생성된 인덱스이다.

```sql
CREATE INDEX idx_name ON members (name);
CREATE INDEX idx_email ON members (email);
```

### 복합 인덱스
복합 인덱스는 두 개 이상의 컬럼을 조합해 생성된 인덱스이다.

```sql
CREATE INDEX idx_name_email ON members (name, email);
```

## 성능 비교 및 최적화

### 예시 1: 단일 컬럼 검색
```sql
SELECT * FROM members WHERE name = 'John Kim';
```

이 경우, 단일 인덱스 `idx_name`이 복합 인덱스 `idx_name_email`보다 약간 더 효율적일 수 있다.     
이유는 단일 인덱스가 더 작고 검색해야 할 데이터가 적기 떄문이다.   

### 예시 2: 복수 컬럼 검색
```sql
SELECT * FROM members WHERE name = 'John Doe' AND email = 'john@example.com';
```
이 경우, 복합 인덱스 `idx_name_email`이 단일 인덱스들보다 훨씬 효율적이다.    
복합 인덱스는 두 컬럼을 모두 커버하므로 테이블 액세스 없이 인덱스만으로 결과를 반환하기 떄문이다.   

### 예시 3: 부분 일치 검색
```sql
SELECT * FROM members WHERE name = 'John Doe';
```
복합 인덱스 `idx_name_email`만 있는 경우에도 이 쿼리도 효율적으로 처리할 수 있다.    
복합 인덱스의 왼쪽 끝 컬럼(이 경우 'name')만 사용하는 쿼리도 해당 인덱스를 활용할 수 있기 때문.   

### 예시 4: ORDER BY에서 활용
```sql
SELECT * FROM members ORDER BY name, email;
```
복합 인덱스 `idx_name_email`가 이미 정렬된 순서로 데이터를 저장하고 있기 때문에 추가적인 정렬 작업이 필요 없다.  

---   

`카디널리티`를 고려해서 복합 인덱스를 만들 때는 카디널리티(고유값의 수)가 높은 컬럼을 먼저 배치하는 것이 좋고. (한국은 이름이 같은 케이스가 있기에 `(email, name)`이 `(name, email)` 보다 효율적)      
`인덱스 컬럼 순서` WHERE 절에서 자주 사용되는 컬럼을 복합 인덱스의 왼쪽에 배치하고    
`범위 조건 주의` 범위 조건(>,< BETWEEN 등)이 사용되는 컬럼은 복합 인덱스의 마지막에 배치하도록 설게    
`커버링 인덱스 활용` SELECT 절에서 요청하는 모든 컬럼이 인덱스에 포함되도록 테이블 액세스를 줄이고        
`불필요한 인덱스 제거` 너무 많은 인덱스는 INSERT, UPDATE, DELETE 작업의 성능을 저하시킬 수 있으므로 필요한 것만 인덱스를 만드는걸로 하면 성능이 좋아진다.    
    
### 커버링 인덱스 (Covering Index)

커버링 인덱스는 쿼리에 필요한 모든 컬럼을 포함하는 인덱스이다.    
```sql
CREATE INDEX idx_covering_name ON Customer(first_name, last_name);
```
이 인덱스를 사용하면 `first_name`과 `last_name`만 필요한 쿼리의 경우 테이블에 접근하지 않고도 결과를 반환한다.    


### 접두사 인덱스 (Prefix Index)
긴 문자열에서 컬럼에 대해 전체가 아닌 앞부분만 인덱싱하는 기법. 인덱스 크기를 줄이면서도 효과적인 검색유도.    

```sql
CREATE INDEX idx_email ON tb_user(email(5));
```
email 필드의 앞 5자만 인덱싱해서 뒤에 불필요한 @gmail.com 같은 @뒤의 데이터를 저장하지않아도 됨.    

```sql
SELECT * FROM tb_user USE INDEX(idx_user_pro) WHERE professor='Software Engineering';
SELECT * FROM tb_user IGNORE INDEX(idx_user_pro) WHERE professor='Software Engineering';
SELECT * FROM tb_user FORCE INDEX(idx_user_pro) WHERE professor='Software Engineering';
```
위처럼 옵티마이저의 선택을 오버라이드하거나 특정 인덱스 사용을 강제할 수도 있다.    

### 인덱스 갱신기능
```sql
ANALYZE TABLE table_name;
```
ANALYZE를 통해 인덱스를 재생성해서 성능을 최적화하고 키를 재분배한다는데 알아서 innoDB가 해준다고 한다. 데이터 삽입이 20억행이상 갱신된 경우에 수동으로 해주면 좋다고한다.      

### 적응형 해시 인덱스 (Adaptive Hash Index)
InnoDB 엔진은 자주 접근되는 데이터에 대해 자동으로 해시 인덱스를 생성해서 B-Tree의 한계를(자주 사용되는 데이터 탐색인데 동일하게 트리의 경로를 쫓아야하는점) 보완해주는 기능이다.    
    
특히 단일 랜덤 키 접근이 빈도있게 발생하는 경우, B-Tree 를 통하지 않고 데이터에 접근/처리가 가능하기에 좋은 퍼포먼스를 보여준다.   
BUT, 옵티마이저가 판단하여 해시 키로 만들기 때문에 제어가 어렵고 테이블 Drop 시, 기존 해시 자료구조에 데이터가 남아있어서 영향을 준다.    
해시 인덱스에 의존하여 트래픽이 주로 처리되는 서비스인 경우 고려해볼법하다. 금융거래시스템에서 계좌번호로 누군가에게 송금할떄? 검색하는 기능이나 인기많은 상품에대해 쓸만할지도...?   



