---
title: "DAG · Airflow · StarRocks 총정리 — SQL/Java/Ruby 개발자를 위한 데이터 파이프라인 입문 (RAG 인덱싱 자동화 실습)"
date: 2026-09-10 10:00:00 +0900
categories: [Dev, Data]
tags: [airflow, dag, starrocks, data-pipeline, olap, etl, orchestration, rag]
description: "DAG를 '순환 없는 작업 순서도'로, Airflow를 'cron + 의존성 + 재시도 + 대시보드'로, StarRocks를 '집계 전용 MySQL 호환 DB'로 이해한다. 이전 글의 RAG 인덱싱 파이프라인을 Airflow DAG로 옮기고 검색 로그를 StarRocks에 쌓아 Recall@5를 집계하는 실습, 그리고 데이터 파이프라인 용어 사전까지."
---

## 한 줄 요약

> **DAG**는 "순환 없는 작업 순서도", **Airflow**는 "그 순서도를 cron처럼 돌리되 의존성·재시도·부분 재실행·대시보드까지 챙겨주는 스케줄러", **StarRocks**는 "`GROUP BY`를 억 단위 행에서도 초 단위로 끝내는, MySQL 프로토콜 호환 집계 전용 DB"다.
{: .prompt-tip }

[이전 글](/posts/rag-vector-db-frontmatter-for-sql-java-ruby-developers/)에서 블로그 글을 pgvector에 넣는 RAG 인덱싱 파이프라인을 만들었다. `파일 읽기 → Frontmatter 파싱 → 청킹 → 임베딩 → INSERT`. 이걸 매일 자동으로 돌리고, 검색이 얼마나 잘 되는지 숫자로 보고 싶다는 게 이 글의 출발점이다. 그러려면 두 가지가 필요하다 — **작업을 순서대로 안정적으로 돌리는 것**(DAG, Airflow)과 **쌓인 로그를 빠르게 집계하는 것**(StarRocks).

---

## 1. 문제: cron으로 파이프라인을 돌리면 생기는 일

처음엔 다들 cron으로 시작한다.

```
0 3 * * *  cd /srv/blog && git pull && ruby index_posts.rb >> /var/log/rag.log 2>&1
```

몇 주 지나면 이런 일이 생긴다.

| 상황 | cron에서 벌어지는 일 |
|---|---|
| 임베딩 API가 한 번 타임아웃 | 스크립트 전체 실패. 재시도는 내가 `while` 루프로 직접 짜야 함 |
| `git pull`은 됐는데 임베딩만 실패 | 어디까지 성공했는지 로그를 `grep` 해서 찾고, 그 지점부터 수동 재실행 |
| 임베딩 완료 후 StarRocks 적재도 추가하고 싶음 | 스크립트 하나에 계속 이어 붙임 → 500줄짜리 `run.rb` |
| 지난주 데이터를 다시 돌려야 함 | 날짜 인자 받도록 스크립트 고치고, 7번 수동 실행 |
| 어젯밤 잘 돌았나? | 서버 접속해서 로그 파일 열어봄 |
| 두 작업을 병렬로 돌리고 셋째 작업은 둘 다 끝난 뒤에 | cron으론 표현 불가. `&`와 `wait`로 셸 스크립트 곡예 |

cron은 "언제 실행할지"만 안다. **"무엇을 어떤 순서로, 실패하면 어떻게"**는 전부 내 몫이다. 이 빈칸을 채우는 게 오케스트레이터(orchestrator)고, Airflow가 그 대표다. 그리고 오케스트레이터가 작업 순서를 표현하는 데 쓰는 자료구조가 DAG다.

---

## 2. DAG: 순환 없는 작업 순서도

**DAG = Directed Acyclic Graph.** 단어를 뜯으면 끝이다.

- **Graph**: 점(노드)과 선(엣지)
- **Directed**: 선에 방향이 있다 → "A 다음에 B"
- **Acyclic**: 순환이 없다 → A→B→C→A 같은 고리 금지

RAG 인덱싱 파이프라인을 그리면 이렇게 된다.

```
git_pull ──▶ changed_posts ──▶ chunk ──▶ embed ──▶ upsert_pgvector ──▶ report
                                  │                                        ▲
                                  └──────────▶ validate_frontmatter ───────┘
```

`chunk`가 끝나면 `embed`와 `validate_frontmatter`가 **병렬**로 돌고, `report`는 둘 다 끝나야 시작한다. cron으론 못 쓰는 문장을 그림 하나로 표현했다.

**왜 순환이 없어야 하나.** 순환이 있으면 "어디서 시작해서 언제 끝나는지"를 정할 수 없다. A가 B를 기다리고 B가 A를 기다리면 데드락이다. 순환이 없으면 **위상 정렬(topological sort)**이 가능해서, "의존성을 만족하는 실행 순서"가 항상 하나 이상 존재한다. 오케스트레이터는 이 순서대로 노드를 실행하고, 의존성이 없는 노드들은 동시에 돌린다.

이미 아는 것들이 전부 DAG다.

| 익숙한 것 | 노드 | 엣지 |
|---|---|---|
| Git 커밋 히스토리 | 커밋 | parent 포인터 (merge 커밋은 부모 2개) |
| Maven / Gradle / Bundler 의존성 | 라이브러리 | `depends on` (순환 의존은 빌드 실패) |
| Spring Bean 초기화 순서 | Bean | `@DependsOn`, 생성자 주입 (순환이면 `BeanCurrentlyInCreationException`) |
| `EXPLAIN` 실행 계획 | 스캔·조인·정렬 연산자 | 데이터 흐름 (트리 = DAG의 특수 형태) |
| Rails `before_action` 체인 | 필터 | 선언 순서 |
| DB 외래키 관계도 (순환 없을 때) | 테이블 | FK |

**DAG는 자료구조이지 도구가 아니다.** Airflow, Prefect, Dagster, Argo Workflows, GitHub Actions의 `needs:` 전부 DAG로 작업을 표현한다. 이름이 비슷한 **RAG**(Retrieval-Augmented Generation)는 LLM 답변 패턴이고 전혀 다른 개념이다 — 다만 RAG의 인덱싱 파이프라인은 그 자체로 DAG라서, 이 글에서 둘이 만난다.

---

## 3. Airflow: cron + 의존성 + 재시도 + 대시보드

Apache Airflow는 **"Python 코드로 DAG를 정의하면, 스케줄에 맞춰 실행하고 상태를 관리해주는 서버"**다. 2014년 Airbnb에서 만들었고, 지금은 데이터 파이프라인 오케스트레이터의 사실상 표준이다.

### 3-1. 핵심 용어 6개

| 용어 | 뜻 | 익숙한 것에 대응하면 |
|---|---|---|
| **DAG** | 파이프라인 하나. 스케줄·시작일·재시도 정책을 가짐 | Jenkins의 Pipeline / Job |
| **Task** | DAG 안의 노드 하나. 실제로 실행되는 단위 | Jenkins의 Stage / Step |
| **Operator** | Task를 만드는 템플릿. `BashOperator`, `PythonOperator`, `SqlOperator`, `DockerOperator`… | 라이브러리의 Client 클래스 |
| **Scheduler** | 시계를 보며 "지금 돌릴 DAG 있나?" 체크하고 Task를 큐에 넣는 데몬 | cron 데몬 + 큐 프로듀서 |
| **Executor / Worker** | 큐에서 Task를 꺼내 실제로 실행. Local, Celery, Kubernetes 등 | Sidekiq 워커 / Spring `@Async` 스레드풀 |
| **XCom** | Task 사이에 작은 값을 주고받는 통로 (DB에 저장됨) | 메서드 리턴값. 단, **작은 값만** — 파일·DataFrame은 S3 경로를 넘길 것 |

### 3-2. 알아두면 삽질을 줄이는 용어

- **schedule / start_date / catchup**: `schedule="@daily"`와 `start_date=2026-09-01`을 주고 오늘이 9월 10일이면, Airflow는 기본적으로 **9/1~9/9 분을 전부 소급 실행**한다(catchup). 처음엔 거의 항상 `catchup=False`.
- **Backfill**: 과거 기간을 의도적으로 다시 돌리는 것. `airflow dags backfill -s 2026-09-01 -e 2026-09-07 rag_index_blog`. cron 시절 "날짜 인자 받게 고쳐서 7번 실행"이 명령어 하나가 된다.
- **Idempotent(멱등)**: 같은 날짜로 두 번 돌려도 결과가 같아야 한다. Backfill과 재시도가 안전하려면 필수. SQL로 치면 `INSERT` 대신 `INSERT … ON CONFLICT DO UPDATE`, `DELETE WHERE dt = ? 후 INSERT`.
- **Sensor**: "파일이 생길 때까지 / 다른 DAG가 끝날 때까지" 기다리는 Task. `FileSensor`, `ExternalTaskSensor`.
- **Retry / retry_delay**: Task 단위 재시도. cron 시절의 `while` 루프가 인자 두 개로 끝난다.
- **SLA**: "이 Task는 03:30까지 끝나야 함". 넘기면 알림.
- **Pool**: 동시 실행 개수 제한. 임베딩 API 레이트 리밋이 있으면 `pool="openai", pool_slots=1`.
- **Connection / Variable**: DB 접속 정보·API 키를 코드 밖(UI 또는 환경변수)에 두는 곳. `.env`의 Airflow 버전.
- **TaskFlow API**: `@task` 데코레이터로 함수를 Task로 만드는 문법. 리턴값이 자동으로 XCom을 탄다. 2.x 이후 표준.

> **Airflow는 Python이지만 Task는 아무 언어나 된다.** `BashOperator`로 `ruby index_posts.rb`나 `java -jar indexer.jar`를 부르면 되고, 컨테이너로 격리하고 싶으면 `DockerOperator`/`KubernetesPodOperator`를 쓴다. Airflow는 **지휘자**지 연주자가 아니다. Java/Ruby 코드를 Python으로 다시 쓸 필요가 없다.
{: .prompt-info }

### 3-3. RAG 인덱싱 DAG

이전 글의 Ruby 인덱서(`index_posts.rb`)를 그대로 재사용한다. 바뀐 글만 골라 임베딩하고, 실행 결과를 StarRocks에 남긴다.

```python
# dags/rag_index_blog.py
from datetime import datetime, timedelta
from airflow.decorators import dag, task
from airflow.operators.bash import BashOperator

BLOG = "/srv/blog"

@dag(
    dag_id="rag_index_blog",
    schedule="0 3 * * *",                 # 매일 03:00 KST (cron 문법 그대로)
    start_date=datetime(2026, 9, 1),
    catchup=False,                        # 과거분 소급 실행 안 함
    default_args={"retries": 2, "retry_delay": timedelta(minutes=5)},
    tags=["rag", "blog"],
)
def rag_index_blog():

    git_pull = BashOperator(
        task_id="git_pull",
        bash_command=f"cd {BLOG} && git pull --ff-only",
    )

    @task
    def changed_posts() -> list[str]:
        """직전 커밋 대비 바뀐 _posts/*.md 만 추려서 다음 Task로 넘김 (XCom)"""
        import subprocess
        out = subprocess.check_output(
            ["git", "-C", BLOG, "diff", "--name-only", "HEAD~1", "HEAD", "--", "_posts"],
            text=True,
        )
        return [p for p in out.split() if p.endswith(".md")]

    @task(pool="openai")                  # 임베딩 API 동시 호출 수 제한
    def index(paths: list[str]) -> int:
        """이전 글의 Ruby 스크립트를 그대로 호출. 언어 안 바꿈."""
        import subprocess
        if not paths:
            return 0
        subprocess.run(["ruby", "/srv/rag/index_posts.rb", *paths], check=True)
        return len(paths)

    @task
    def report(n: int, **ctx):
        """실행 기록을 StarRocks에 적재 — MySQL 프로토콜이라 pymysql 그대로"""
        import pymysql
        conn = pymysql.connect(host="starrocks-fe", port=9030, user="root", database="rag")
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO index_run (dt, dag_id, run_id, changed_posts) VALUES (%s, %s, %s, %s)",
                (ctx["ds"], ctx["dag"].dag_id, ctx["run_id"], n),
            )
        conn.commit()

    paths = changed_posts()
    git_pull >> paths                     # 의존성: git_pull 끝나야 changed_posts
    report(index(paths))                  # index → report 는 인자 전달로 자동 연결

rag_index_blog()
```

읽는 법:

- `@dag(...)`가 cron 한 줄에 해당한다. 다만 `retries`, `catchup`, `tags`가 같이 온다.
- `git_pull >> paths`가 **엣지**다. `>>`는 "왼쪽 끝나면 오른쪽".
- `report(index(paths))`처럼 **함수 호출로 인자를 넘기면 그게 곧 의존성**이다. TaskFlow API의 핵심.
- `ctx["ds"]`는 "이 실행이 담당하는 날짜"(`2026-09-10`). Backfill로 과거를 돌리면 이 값이 그 날짜가 된다. 그래서 Task는 "오늘"이 아니라 **`ds`를 기준으로** 짜야 멱등이 된다.

Task 하나가 실패하면 그 Task만 2번 재시도하고, 그래도 실패하면 DAG가 빨간불이 된다. UI에서 실패한 Task만 클릭해서 **Clear**하면 그 지점부터 다시 돈다. cron 시절 "로그 `grep` 해서 수동 재실행"이 클릭 한 번이다.

---

## 4. StarRocks: 집계 전용 MySQL 호환 DB

파이프라인이 매일 돌면 로그가 쌓인다. 검색 요청마다 "질문, 상위 5개 slug, 최고 유사도, 기대 slug가 포함됐는지, 응답 시간"을 남기면 하루 수만 행, 1년이면 수천만 행이다. 이걸 MySQL에 넣고 `GROUP BY dt`를 치면 어느 순간 수십 초가 걸린다.

**이유는 저장 방식이다.** MySQL/Postgres는 **행 저장(row store)**이다. 한 행의 모든 컬럼이 디스크에 붙어 있다. `SELECT * WHERE id = 42` 같은 OLTP 조회에 최적이다. 반면 `SELECT dt, AVG(latency_ms) GROUP BY dt`는 `latency_ms` 컬럼 하나만 필요한데, 행 저장은 모든 컬럼을 디스크에서 읽어야 한다.

StarRocks 같은 **OLAP DB는 열 저장(columnar)**이다. 컬럼마다 파일이 따로 있어서 필요한 컬럼만 읽고, 같은 타입이 연속으로 있으니 압축률이 높고, CPU가 벡터 단위로 한 번에 처리한다(**vectorized execution**). 거기에 여러 노드가 나눠서 병렬로 계산한다(**MPP**, Massively Parallel Processing). 억 단위 행의 `GROUP BY`가 초 단위로 끝나는 이유다.

| | MySQL / Postgres (OLTP) | StarRocks / ClickHouse / BigQuery (OLAP) |
|---|---|---|
| 잘하는 쿼리 | `WHERE id = ?` 한 건 조회, 트랜잭션 | `GROUP BY` 대량 집계, 스캔 |
| 저장 | 행 단위 | 열 단위 |
| 쓰기 | 한 건씩 빈번한 `INSERT/UPDATE` | 배치로 몰아서 적재 |
| 트랜잭션 | 완전한 ACID | 제한적 (적재 단위 원자성) |
| 인덱스 | B-Tree | 정렬 키 + 파티션 + 프루닝 |

StarRocks를 고른 이유는 하나 더 있다. **MySQL 프로토콜을 그대로 쓴다.** Java는 MySQL JDBC 드라이버, Ruby는 `mysql2` gem으로 붙는다. 새 클라이언트를 배울 필요가 없다.

### 4-1. 핵심 개념

- **FE / BE**: Frontend(쿼리 파싱·계획·메타데이터, 포트 9030)와 Backend(저장·실행). FE에 MySQL 클라이언트로 붙는다.
- **테이블 타입 4종**: 데이터 성격에 따라 고른다.

| 타입 | 언제 | SQL로 치면 |
|---|---|---|
| **Duplicate Key** | 그냥 쌓기만 (로그) | 일반 테이블, PK 없음 |
| **Aggregate Key** | 같은 키는 적재 시 자동 합산 (`SUM`, `MAX`) | `INSERT … ON DUPLICATE KEY UPDATE cnt = cnt + 1` 을 DB가 대신 |
| **Unique Key** | 같은 키면 최신값으로 덮어쓰기 | Upsert (읽을 때 병합) |
| **Primary Key** | Unique와 같지만 쓰기 시점에 병합 → 조회가 빠름. **요즘 기본 선택** | Upsert (쓸 때 병합) |

- **Partition**: 큰 범위 분할, 보통 날짜. `WHERE dt = '2026-09-10'`이면 그 파티션만 읽는다(**partition pruning**). Postgres 파티셔닝과 같은 개념.
- **Bucket (Distribution)**: 파티션 안에서 해시로 잘게 나눠 여러 BE에 분산. 샤딩과 같은 개념.
- **적재 방식**: `INSERT`(소량), **Stream Load**(HTTP로 CSV/JSON 밀어넣기, 배치), **Routine Load**(Kafka 토픽 구독, 스트리밍), **Broker Load**(S3/HDFS 파일).
- **Materialized View**: 자주 치는 집계 쿼리를 미리 계산해두고 주기적으로 갱신. 쿼리가 원본 테이블을 쳐도 옵티마이저가 알아서 MV로 바꿔 탄다(**query rewrite**).
- **External Catalog**: Hive / Iceberg / Hudi / Delta Lake 테이블을 복사 없이 바로 쿼리. 데이터 레이크 위에 StarRocks를 얹는 패턴.

### 4-2. 검색 로그 테이블

```sql
CREATE DATABASE IF NOT EXISTS rag;
USE rag;

-- 검색 요청 로그: 하루 수만 건, 같은 query_id 재적재 시 최신값으로
CREATE TABLE search_log (
  dt             DATE          NOT NULL,          -- 파티션 키
  query_id       VARCHAR(64)   NOT NULL,
  ts             DATETIME      NOT NULL,
  question       VARCHAR(1024),
  top_slug       VARCHAR(255),
  top_similarity DOUBLE,
  expected_slug  VARCHAR(255),                    -- 정답셋이 있을 때만
  hit_at_5       BOOLEAN,                         -- 상위 5건에 expected_slug 포함?
  latency_ms     INT
)
PRIMARY KEY (dt, query_id)
PARTITION BY date_trunc('day', dt)               -- 날짜별 자동 파티션
DISTRIBUTED BY HASH(query_id) BUCKETS 8
PROPERTIES ("replication_num" = "1");            -- 로컬/개발용. 운영은 3

-- Airflow 실행 기록
CREATE TABLE index_run (
  dt            DATE         NOT NULL,
  dag_id        VARCHAR(64)  NOT NULL,
  run_id        VARCHAR(128) NOT NULL,
  changed_posts INT
)
PRIMARY KEY (dt, dag_id, run_id)
DISTRIBUTED BY HASH(run_id) BUCKETS 4
PROPERTIES ("replication_num" = "1");
```

MySQL DDL과 다른 건 `PRIMARY KEY … PARTITION BY … DISTRIBUTED BY` 세 줄뿐이다.

### 4-3. 적재: 앱에서 바로 vs 배치로

**앱에서 한 건씩** — 검색 API가 응답 직후 남긴다. MySQL 드라이버 그대로.

```java
// Java: MySQL JDBC 드라이버, 포트만 9030
@Repository
@RequiredArgsConstructor
public class SearchLogRepository {
    private final JdbcTemplate starrocks;   // jdbc:mysql://starrocks-fe:9030/rag

    public void log(SearchLog l) {
        starrocks.update("""
            INSERT INTO search_log
              (dt, query_id, ts, question, top_slug, top_similarity, expected_slug, hit_at_5, latency_ms)
            VALUES (CURRENT_DATE, ?, NOW(), ?, ?, ?, ?, ?, ?)
            """,
            l.queryId(), l.question(), l.topSlug(), l.topSimilarity(),
            l.expectedSlug(), l.hitAt5(), l.latencyMs());
    }
}
```

```ruby
# Ruby: mysql2 gem 그대로
sr = Mysql2::Client.new(host: "starrocks-fe", port: 9030, username: "root", database: "rag")
sr.query(<<~SQL)
  INSERT INTO search_log (dt, query_id, ts, question, top_slug, top_similarity, hit_at_5, latency_ms)
  VALUES (CURRENT_DATE, '#{sr.escape(id)}', NOW(), '#{sr.escape(q)}', '#{top.slug}', #{top.sim}, #{hit}, #{ms})
SQL
```

> 한 건씩 `INSERT`는 편하지만 OLAP DB가 잘하는 방식은 아니다. 초당 수백 건 이상이면 **앱은 로그 파일이나 Kafka에만 쓰고, 적재는 배치(Stream Load)나 스트리밍(Routine Load)으로** 넘기는 게 정석이다. 아래가 그 배치 버전이다.
{: .prompt-warning }

**배치로** — Airflow Task에서 하루치 CSV를 Stream Load로 밀어넣는다. HTTP `PUT` 한 번이다.

```bash
curl --location-trusted -u root: \
  -H "label: search_log_2026-09-10" \
  -H "Expect: 100-continue" \
  -H "column_separator: ," \
  -H "columns: dt,query_id,ts,question,top_slug,top_similarity,expected_slug,hit_at_5,latency_ms" \
  -T /data/search_log_2026-09-10.csv \
  http://starrocks-fe:8030/api/rag/search_log/_stream_load
```

`label`은 **멱등 키**다. 같은 label로 두 번 보내면 두 번째는 거부된다 — Airflow 재시도와 Backfill이 안전한 이유. Airflow에서는 `BashOperator`로 위 curl을 그대로 부르거나, `SimpleHttpOperator`를 쓴다.

### 4-4. 집계: 이 파이프라인의 목적

이전 글 7장에서 "Recall@5를 재라"고 했다. 이제 그걸 매일 자동으로 볼 수 있다.

```sql
-- 최근 7일 검색 품질: 하루 요청 수, Recall@5, 응답시간 p95
SELECT
  dt,
  COUNT(*)                                 AS queries,
  AVG(CAST(hit_at_5 AS INT))               AS recall_at_5,
  AVG(top_similarity)                      AS avg_top_sim,
  PERCENTILE_APPROX(latency_ms, 0.95)      AS p95_ms
FROM search_log
WHERE dt >= CURRENT_DATE - INTERVAL 7 DAY
  AND expected_slug IS NOT NULL            -- 정답셋이 있는 요청만
GROUP BY dt
ORDER BY dt;

-- 유사도는 낮은데 자주 들어오는 질문 = 청킹·메타데이터 보강 후보
SELECT question, COUNT(*) AS n, AVG(top_similarity) AS sim
FROM search_log
WHERE dt >= CURRENT_DATE - INTERVAL 30 DAY
GROUP BY question
HAVING n >= 5 AND sim < 0.6
ORDER BY n DESC
LIMIT 20;
```

이 두 쿼리를 매번 치기 귀찮으면 Materialized View로 만든다.

```sql
CREATE MATERIALIZED VIEW daily_search_quality
REFRESH ASYNC EVERY (INTERVAL 1 HOUR)
AS
SELECT dt,
       COUNT(*)                     AS queries,
       AVG(CAST(hit_at_5 AS INT))   AS recall_at_5,
       AVG(top_similarity)          AS avg_top_sim
FROM search_log
WHERE expected_slug IS NOT NULL
GROUP BY dt;
```

이제 `SELECT * FROM daily_search_quality ORDER BY dt DESC LIMIT 30`이 대시보드 쿼리다. Grafana나 Metabase를 MySQL 데이터소스로 붙이면 끝난다 — **MySQL 프로토콜이라 그냥 붙는다.**

---

## 5. 전체 그림

```
                     ┌──────────────── Airflow (rag_index_blog, 매일 03:00) ────────────────┐
                     │ git_pull → changed_posts → index(ruby) → report                       │
                     └──────────────────────────┬───────────────────────────────┬───────────┘
                                                ▼                               ▼
   _posts/*.md  ──────────────────────▶  PostgreSQL + pgvector          StarRocks (rag)
   (Frontmatter + 본문)                    post_chunks                     index_run
                                                ▲                               ▲
                                                │ ORDER BY <=>                  │ INSERT / Stream Load
                                                │                               │
   사용자 질문 ──▶  검색 API (Java / Ruby)  ─────┘  ── 검색 결과 + 지표 로그 ─────┘
                          │
                          ▼
                    LLM 답변 (RAG)                              Grafana ──▶ daily_search_quality (MV)
```

역할이 셋으로 갈린다.

| 역할 | 저장소 | 이유 |
|---|---|---|
| **서빙**: 질문 하나에 5건 검색 | pgvector | 지연 수십 ms, 행 단위 조회 |
| **오케스트레이션**: 매일 재색인, 실패 시 재시도 | Airflow | DAG + 스케줄 + 재시도 + UI |
| **분석**: 한 달 로그를 `GROUP BY` | StarRocks | 열 저장 + MPP, MySQL 호환 |

세 가지를 한 DB로 하려고 하면(예: Postgres에 로그도 쌓고 집계도) 어느 순간 서빙 쿼리가 집계 쿼리에 밀려 느려진다. **OLTP와 OLAP를 물리적으로 분리**하는 게 데이터 파이프라인의 첫 번째 원칙이고, 그 사이를 잇는 게 오케스트레이터다.

---

## 6. 알아두면 좋은 용어 사전

파이프라인 문서나 채용 공고에서 자주 마주치는 단어들이다. 한 줄씩만.

### 흐름·방식

| 용어 | 뜻 | 한 줄 감각 |
|---|---|---|
| **ETL** | Extract → Transform → Load. 옮기기 **전에** 가공 | 앱 서버에서 가공해서 DB에 넣기 |
| **ELT** | Extract → Load → Transform. 일단 넣고 **DB 안에서** SQL로 가공 | 원본 그대로 StarRocks에 넣고 `CREATE TABLE AS SELECT` |
| **Batch** | 모아서 주기적으로 처리 | 매일 03:00 cron |
| **Streaming** | 들어오는 즉시 처리 | Kafka 컨슈머 |
| **Micro-batch** | 몇 초 단위로 작게 모아 처리. 둘의 절충 | Routine Load |
| **Orchestration** | 여러 작업의 순서·의존성·실패를 관리 | Airflow |
| **Scheduling** | 언제 실행할지만 결정 | cron |
| **Backfill** | 과거 기간 재실행 | `airflow dags backfill` |
| **Idempotent** | 몇 번 실행해도 결과 동일 | `ON CONFLICT DO UPDATE`, Stream Load `label` |
| **Exactly-once** | 중복도 누락도 없이 정확히 한 번 처리 | 멱등 쓰기 + 오프셋 커밋 |
| **Watermark** | 스트리밍에서 "이 시각까지의 데이터는 다 왔다"고 보는 기준선 | 지연 도착 데이터 처리 기준 |
| **SLA** | 정해진 시각까지 끝나야 하는 약속 | "03:30까지 재색인 완료" |
| **Lineage** | 이 컬럼이 어느 원천에서 어떤 변환을 거쳐 왔는지 추적 | 데이터의 `git blame` |

### 저장·구조

| 용어 | 뜻 | 한 줄 감각 |
|---|---|---|
| **OLTP** | 온라인 트랜잭션 처리. 한 건 읽기/쓰기, ACID | MySQL, Postgres |
| **OLAP** | 온라인 분석 처리. 대량 집계 | StarRocks, ClickHouse, BigQuery, Snowflake |
| **Row store / Column store** | 행 단위 저장 / 열 단위 저장 | OLTP / OLAP의 물리적 이유 |
| **MPP** | 여러 노드가 쿼리를 쪼개 병렬 실행 | `GROUP BY`를 8대가 나눠서 |
| **Vectorized execution** | 행 하나씩이 아니라 컬럼 블록 단위로 CPU 연산 | SIMD |
| **Partition** | 큰 범위 분할 (보통 날짜). 불필요한 범위를 스캔에서 제외 | Postgres 파티션 |
| **Bucket / Shard** | 해시로 잘게 나눠 노드에 분산 | 샤딩 |
| **Partition pruning** | `WHERE dt = ?`로 파티션만 골라 읽기 | 인덱스 대신 "안 읽기" |
| **Data Warehouse** | 정제된 분석용 DB. 스키마 있음 | StarRocks, Snowflake, Redshift |
| **Data Lake** | 원본 파일을 그대로 쌓는 저장소 (S3 + Parquet) | 스키마 나중에 |
| **Lakehouse** | 레이크 위에 테이블 포맷을 얹어 웨어하우스처럼 쿼리 | Iceberg + StarRocks |
| **Parquet** | 열 저장 파일 포맷. 레이크의 표준 | 압축 잘 되는 CSV |
| **Iceberg / Hudi / Delta Lake** | Parquet 파일 묶음을 "테이블"로 다루게 해주는 메타데이터 포맷 (스냅샷, 스키마 변경, 타임트래블) | 파일 더미에 트랜잭션 로그 |
| **Star schema** | 중앙 Fact 테이블 + 주변 Dimension 테이블 | `orders` + `users`, `products`, `dates` |
| **Fact / Dimension** | 측정값(매출, 건수) / 축(날짜, 지역, 상품) | `GROUP BY` 대상이 Dimension |
| **Materialized View** | 집계 결과를 물리적으로 저장하고 주기 갱신 | 캐시된 `GROUP BY` |
| **CDC** | Change Data Capture. DB의 binlog/WAL을 읽어 변경을 실시간 전파 | Debezium → Kafka → StarRocks |

### 도구 이름

| 도구 | 한 줄 |
|---|---|
| **Airflow** | DAG 오케스트레이터의 표준. Python 정의, 어떤 언어든 실행 |
| **Prefect / Dagster** | Airflow의 현대적 대안. 로컬 개발 경험·타입 안정성 강조 |
| **Argo Workflows** | Kubernetes 네이티브 DAG 실행기. 컨테이너 단위 |
| **dbt** | ELT의 T. SQL `SELECT`만으로 변환 테이블을 만들고 의존성(DAG)·테스트·문서를 관리 |
| **Kafka** | 스트리밍의 표준 메시지 로그. 토픽·파티션·컨슈머 그룹 |
| **Debezium** | CDC 도구. MySQL/Postgres 변경을 Kafka로 |
| **Spark / Flink** | 대규모 배치 / 스트리밍 처리 엔진. StarRocks는 이들 결과를 받는 쪽 |
| **ClickHouse** | StarRocks와 같은 급의 OLAP. 단일 테이블 스캔에 강하고 조인은 약한 편 |
| **Great Expectations** | 데이터 품질 테스트. "이 컬럼 NULL 0%" 같은 단언을 파이프라인에 넣음 |
| **Grafana / Metabase / Superset** | 대시보드. MySQL 프로토콜이면 StarRocks에 바로 붙음 |

---

## 7. 정리: 치트시트

| 내가 아는 것 | 데이터 파이프라인에서는 | 이 글의 예시 |
|---|---|---|
| cron 한 줄 | Airflow `@dag(schedule=…)` | `"0 3 * * *"` |
| 셸 스크립트의 함수 | Task (`@task`, `BashOperator`) | `changed_posts`, `index` |
| 함수 호출 순서 | DAG의 엣지 (`>>`, 인자 전달) | `git_pull >> paths` |
| 리턴값 | XCom (작은 값만) | `list[str]` 경로 목록 |
| `while` 재시도 루프 | `retries`, `retry_delay` | 2회, 5분 |
| 날짜 인자 받아 N번 실행 | Backfill + `ds` | `backfill -s … -e …` |
| `INSERT … ON CONFLICT` | 멱등 Task / Stream Load `label` | `search_log_2026-09-10` |
| `.env` | Connection / Variable | `starrocks-fe:9030` |
| Jenkins 대시보드 | Airflow UI (Grid / Graph 뷰) | 실패 Task 클릭 → Clear |
| MySQL | StarRocks (같은 프로토콜, 다른 엔진) | JDBC / mysql2 그대로 |
| 파티션 테이블 | `PARTITION BY date_trunc('day', dt)` | 날짜별 프루닝 |
| 샤딩 | `DISTRIBUTED BY HASH(...)` | 8 버킷 |
| Upsert | Primary Key 테이블 | `PRIMARY KEY (dt, query_id)` |
| 캐시된 집계 | Materialized View | `daily_search_quality` |

DAG는 자료구조, Airflow는 그걸 돌리는 지휘자, StarRocks는 결과를 빠르게 세는 장부다. 셋 다 새 언어를 요구하지 않는다 — cron·함수 호출·SQL이라는 이미 가진 감각을 이름만 바꿔 부르는 것에 가깝다.

---

## 참고

- [Apache Airflow — Core Concepts](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/index.html)
- [Airflow TaskFlow API 튜토리얼](https://airflow.apache.org/docs/apache-airflow/stable/tutorial/taskflow.html)
- [StarRocks Docs — Table Types](https://docs.starrocks.io/docs/table_design/table_types/)
- [StarRocks Docs — Stream Load](https://docs.starrocks.io/docs/loading/StreamLoad/)
- [StarRocks Docs — Asynchronous Materialized Views](https://docs.starrocks.io/docs/using_starrocks/async_mv/Materialized_view/)
- [이전 글: RAG · 벡터DB · Frontmatter 총정리](/posts/rag-vector-db-frontmatter-for-sql-java-ruby-developers/)
