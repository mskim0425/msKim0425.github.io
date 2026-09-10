---
title: "RAG · 벡터DB · Frontmatter 총정리"
date: 2026-09-08 10:00:00 +0900
categories: [Dev, AI]
tags: [rag, vector-db, pgvector, embedding, frontmatter, spring-ai, ruby, semantic-search]
description: "RAG가 뭔지 SQL 한 줄로 이해하고, 벡터DB를 'B-Tree 대신 HNSW 인덱스가 붙은 컬럼'으로 받아들인 뒤, 내 Jekyll 블로그 글(Frontmatter 포함)을 pgvector + Java/Ruby로 검색 가능하게 만드는 실습까지 정리한다."
---

## 한 줄 요약

> **RAG = `SELECT` 해서 프롬프트에 붙이는 것.**   
벡터DB는 그 `SELECT`의 `WHERE LIKE`를 `ORDER BY 의미적 거리`로 바꿔주는 인덱스이고,    Frontmatter는 그 쿼리의 `WHERE` 절에 들어갈 메타데이터다.
{: .prompt-tip }

이 글은 SQL을 다뤄본 대상으로 쓴다. 수학은 최소한, 대신 익숙한 DB 개념에 하나씩 대응시켜 설명한다. 마지막에는 이 블로그의 마크다운 글들을 그대로 넣어서 "성수 맛집 4.5점 이상 중에 예약 필요한 곳"을 자연어로 물어볼 수 있게 하는게 목표.

---

## 1. LLM은 내가 가지고 있는 데이터를 모른다

ChatGPT에 "내 블로그에서 제일 별점 높은 강남 식당이 어디야?"라고 물으면 답을 못 한다.
학습 데이터에 내 블로그가 없기 때문이다. 해결책은 두 가지다.

| 방법 | 비유 | 비용 | 데이터 갱신 |
|---|---|---|---|
| **파인튜닝** | 직원을 재교육시킴 | 높음 (GPU, 시간) | 바뀔 때마다 재학습 |
| **RAG** | 직원에게 자료 찾아서 건네줌 | 낮음 (검색 + API 호출) | DB에 `INSERT`만 하면 끝 |

RAG의 핵심은 "모델을 똑똑하게 만드는" 문제를 "답변에 필요한 자료를 정확히 찾아주는" **검색 문제**로 바꾸는 데 있다.

> 용어 정리: **RAG는 쿼리가 아니라 패턴(파이프라인)이다.** "검색 → 붙이기 → 생성" 3단계 구조 전체를 가리키고, 그중 1단계 안에 쿼리가 들어 있다. 이름이 비슷한 **DAG**(Directed Acyclic Graph, Airflow 등에서 작업 순서를 표현하는 그래프)와는 전혀 다른 개념이다.
{: .prompt-info }

---

## 2. RAG: Retrieval-Augmented Generation

흐름은 세 단계다.

```
사용자 질문
   │
   ▼
[1. Retrieval]  DB에서 관련 문서 조각(chunk) 검색
   │
   ▼
[2. Augment]    검색 결과를 프롬프트에 붙임
   │
   ▼
[3. Generation] LLM이 그 자료를 근거로 답변
```

의사코드로 쓰면 이게 전부다.

```ruby
chunks = search(question)                       # 1. SELECT
prompt = "다음 자료를 근거로 답해라:\n#{chunks.join}\n\n질문: #{question}"  # 2. 붙이기
answer = llm.chat(prompt)                        # 3. 호출
```

핵심은 **Retrieval(검색)**이다. 여기서 "관련 문서"를 어떻게 찾느냐가 RAG 품질의 80%를 결정한다. 
그리고 여기서 기존 SQL 검색이 한계에 부딪힌다.

### 키워드 검색의 한계

```sql
SELECT title, body FROM posts WHERE body LIKE '%빙수%';
```
사용자는 "여름에 강남에서 먹을 만한 시원한 디저트"를 검색하고 싶지만,
이 쿼리로는 "shaved ice", "호텔 디저트", "여름 시그니처 메뉴"라고 쓴 글을 못 찾는다.
글에는 "빙수"라는 단어가 없으면 검색되는 건 0건이다.   
Full-text search(`tsvector`, GIN)를 써도 **동의어·의역·문맥**은 못 잡는다.

이걸 한계를 푸는게 **임베딩**과 **벡터 검색**이다.

---

## 3. 임베딩: 텍스트를 좌표로 바꾸기

임베딩 모델은 텍스트를 고정 길이 숫자 배열(벡터)로 바꾼다.    
예를 들어 OpenAI `text-embedding-3-small`은 어떤 문장이든 **1536개의 float**로 바꾼다.

```
"제주 애플망고 빙수"        → [0.021, -0.113, 0.087, ..., 0.004]   (1536개)
"Jeju apple mango shaved ice" → [0.019, -0.109, 0.091, ..., 0.006]   (1536개)
"MySQL 인덱스 튜닝"          → [-0.087, 0.201, -0.034, ..., 0.150]  (1536개)
```

중요한 성질 하나: **의미가 비슷하면 벡터가 가깝다.** 언어가 달라도 거의 같은 위치에 찍히고, 3번은 멀리 떨어진다.

> 해시(`MD5`, `SHA`)와 정반대다. 해시는 입력이 한 글자만 달라도 완전히 다른 값이 나오도록 설계됐고, 임베딩은 의미가 비슷하면 비슷한 값이 나오도록 학습됐다.
{: .prompt-info }

*가깝다*는 보통 **코사인 유사도**로 잰다. 두 벡터가 이루는 각도가 작을수록 유사(1에 가까움), 직각이면 무관(0).    
"거리 함수가 하나 있고, 그걸로 `ORDER BY` 한다"까지만 알아도 되지만, 그래도 그 숫자가 어떻게 나오는지는 한 번 손으로 계산해보는 게 좋다 — 1536차원이 무서워 보이지만 3차원으로 줄여도 원리는 같다.

### 3-1. 코사인 유사도, 직접 계산해보기

> **아래 숫자는 설명용으로 내가 지어낸 값이다.** 실제로 점수를 매기는 주체는 사람도 규칙도 아닌 **임베딩 모델**(3-2에서 설명할 가중치 덩어리)이고, 실제 1536개 축에는 "디저트" 같은 이름이 없다. 학습 중에 저절로 생긴 익명의 축이라 사람이 읽을 수 없고, 읽을 필요도 없다.
{: .prompt-warning }
벡터를 3개로 줄여서 각 축이 대충 1점만점으로 점수를 ["디저트스러움", "일식스러움", "IT용어스러움"]준다고 가정.

```
A = "제주 애플망고 빙수"        → [0.9, 0.1, 0.0]
B = "Jeju apple mango shaved ice" → [0.8, 0.2, 0.0]
C = "MySQL 인덱스 튜닝"          → [0.0, 0.0, 1.0]
```

코사인 유사도 공식은 이거 하나다.

```
cos(A, B) =  (A · B)  /  (a × b)
          =  내적      /  (절대값 길이 × 절대값 길이)
```

- 내적(A · B) : 같은 자리끼리 곱해서 전부 더한다. `0.9×0.8 + 0.1×0.2 + 0.0×0.0 = 0.74`
- 길이(a) : `√(0.9² + 0.1² + 0²) = √0.82 ≈ 0.906`, `|B| = √(0.64+0.04) ≈ 0.825`
- **결과**: `0.74 / (0.906 × 0.825) ≈ 0.99` → 거의 같은 방향, 즉 거의 같은 의미

같은 방식으로 A와 C를 계산하면 내적이 `0.9×0 + 0.1×0 + 0×1 = 0`이라 코사인 유사도도 **0**이다. 즉, 무관하다. 이게 "빙수 글"과 "MySQL 글"이 검색에서 갈리는 이유의 전부다.

코드로 쓰면 한 줄이다.

```ruby
def cosine(a, b)
  dot  = a.zip(b).sum { |x, y| x * y }
  dot / (Math.sqrt(a.sum { |x| x * x }) * Math.sqrt(b.sum { |y| y * y }))
end
cosine([0.9, 0.1, 0.0], [0.8, 0.2, 0.0])  # => 0.99
cosine([0.9, 0.1, 0.0], [0.0, 0.0, 1.0])  # => 0.0
```

pgvector의 `<=>`는 **코사인 거리** = `1 - 코사인 유사도`다. 그래서 `ORDER BY embedding <=> q` 는 "유사도 높은 순"과 같고, 값이 0이면 동일, 1이면 무관, 2면 정반대다.

**왜 "거리"가 아니라 "각도"를 쓰나.** 벡터의 길이는 문장이 길거나 단어가 반복되면 커지는 경향이 있다. "빙수 맛있다"와 "빙수 진짜 진짜 맛있다"는 방향은 같지만 길이가 다를 수 있다. 각도만 보면 이 길이 차이를 무시하고 순수하게 "무슨 얘기냐"만 비교한다. 참고로 대부분의 임베딩 API는 벡터를 길이 1로 정규화해서 주는데, 이 경우 `|A| × |B| = 1`이라 **코사인 = 내적**이 된다. pgvector에서 `<#>`(내적)가 `<=>`보다 약간 빠른 이유가 이것이다 — 나눗셈 두 번을 건너뛴다.

### 3-2. 그 숫자(가중치)는 어디서 오나

여기서 자연스럽게 드는 의문: `[0.021, -0.113, ...]` 이 1536개 숫자는 누가 정하나?

임베딩 모델은 **거대한 행렬 곱셈 덩어리**(트랜스포머 신경망)다. 텍스트가 들어오면 이런 일이 벌어진다.

```
"제주 애플망고 빙수"
   │  ① 토큰화: 조각으로 자름            → ["제주", "애플", "망고", "빙수"]
   │  ② 룩업: 조각마다 초기 벡터를 꺼냄   → 각 토큰 → 숫자 배열   (테이블 하나)
   │  ③ 변환: 행렬을 수십 층 곱하며 섞음   → 문맥이 반영된 벡터들  (행렬 수백 개)
   │  ④ 풀링: 하나로 합침                 → 1536차원 벡터 하나
   ▼
[0.021, -0.113, 0.087, ...]
```

②의 룩업 테이블과 ③의 행렬들 안에 들어 있는 숫자가 **가중치(weight)**다. `text-embedding-3-small` 같은 모델은 이런 가중치가 수억 개 있다. 우리가 API를 호출하면 이 가중치들은 **고정된 채로** 곱셈만 수행된다 — 즉 임베딩 API는 `f(text) = vector`인 **순수 함수**고, 같은 입력엔 같은 출력이 나온다(그래서 캐시해도 된다).

그럼 그 가중치는 어떻게 정해졌나. 사람이 한 개씩 쓴 게 아니라 **학습**으로 구해졌다.

1. 처음엔 가중치를 **난수**로 채운다. 이 상태의 모델은 "빙수"와 "MySQL"을 구분 못 한다.
2. **정답 쌍**을 수억 개 준비한다. "비슷한 문장 쌍"(같은 글의 제목과 본문, 원문과 번역문, 질문과 답변)과 "무관한 문장 쌍".
3. 현재 가중치로 두 문장을 임베딩해서 코사인 유사도를 잰다. 비슷한 쌍인데 유사도가 낮거나, 무관한 쌍인데 높으면 **틀린 만큼 벌점(loss)**을 매긴다.
4. 그 벌점이 줄어드는 방향으로 가중치를 **아주 조금씩** 수정한다(경사 하강법). 미분으로 "어느 가중치를 얼마나 움직이면 벌점이 줄어드는지"를 계산한다.
5. 2~4를 수십억 번 반복한다.

이렇게 "비슷한 건 당기고 다른 건 밀어내는" 방식을 **대조 학습(contrastive learning)**이라고 부른다. 결과적으로 가중치는 "의미가 비슷한 텍스트를 벡터 공간에서 가까운 곳에 놓는 함수"로 수렴한다. 3-1에서 A와 B가 0.99가 나온 건 우연이 아니라, 그렇게 되도록 가중치가 조정됐기 때문이다.

> 정리하면 **가중치를 구하는 건 모델 만드는 쪽(OpenAI 등)의 일**이고, 우리는 그 결과를 함수처럼 호출만 한다. 우리가 통제하는 건 세 가지뿐이다 — ① 어떤 모델을 쓸지(차원·품질·비용), ② 어떤 텍스트를 넣을지(청킹, 메타데이터 헤더), ③ 어떤 거리 연산자로 정렬할지(`<=>`, `<#>`). 이 셋이 4~6장의 내용이다.
{: .prompt-tip }

---

## 4. 벡터DB: 인덱스가 다른 DB일 뿐이다

벡터DB라고 하면 뭔가 새로운 저장소 같지만, 본질은 **"벡터 컬럼 + 그 컬럼에 대한 최근접 이웃(Nearest Neighbor) 인덱스"**다. 전용 제품(Pinecone, Milvus, Chroma, Weaviate)도 있고, 기존 DB에 확장으로 붙이는 방식(**pgvector** for PostgreSQL, MySQL 9 VECTOR 타입, Redis, Elasticsearch)도 있다.

SQL 개발자라면 pgvector부터 보는 게 가장 빠르다. 이미 아는 Postgres에 컬럼 하나, 연산자 하나, 인덱스 하나만 추가되기 때문이다.

```sql
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE docs (
  id        bigserial PRIMARY KEY,
  content   text,
  embedding vector(1536)          -- ① 새 타입: 차원 수 고정
);

-- ② 새 연산자: <=> 는 코사인 거리 (0 = 동일, 2 = 정반대)
SELECT id, content
FROM docs
ORDER BY embedding <=> '[0.021, -0.113, ...]'::vector
LIMIT 5;

-- ③ 새 인덱스: HNSW (근사 최근접 탐색)
CREATE INDEX ON docs USING hnsw (embedding vector_cosine_ops);
```

이게 벡터DB의 전부다. 나머지는 익숙한 개념에 대응된다.

| 익숙한 SQL 개념 | 벡터DB 대응 | 비고 |
|---|---|---|
| `VARCHAR`, `INT` 컬럼 | `vector(1536)` 컬럼 | 차원 수는 임베딩 모델에 종속 |
| `=`, `LIKE` | `<=>` (코사인), `<->` (유클리드), `<#>` (내적) | 정확 일치가 아니라 **거리** |
| B-Tree 인덱스 | **HNSW**, IVFFlat | 정확한 답이 아니라 **근사(ANN)** 답을 빠르게 |
| `WHERE` 절 | 메타데이터 필터 | 벡터만으로는 못 거르는 조건 |
| `ORDER BY col LIMIT n` | `ORDER BY embedding <=> q LIMIT n` | Top-K 검색 |
| 테이블 | 컬렉션 / 인덱스 (전용 제품 용어) | 이름만 다름 |

### 왜 B-Tree가 아니라 HNSW인가

B-Tree는 "정렬 가능한 값"에서 정확히 일치하거나 범위에 있는 행을 찾는다. 1536차원 공간에서 "가장 가까운 5개"는 정렬로 못 푼다 — 모든 행과 거리를 계산해야 하니 `O(n)`이고, 100만 행이면 질문 하나에 100만 번 벡터 곱셈이다.

HNSW(Hierarchical Navigable Small World)는 벡터들을 다층 그래프로 연결해두고 "대충 가까운 쪽으로 점프"하며 내려간다. 결과는 **정확하지 않을 수 있지만**(근사), 수 ms 안에 나온다. 검색 엔진이 "정확히 몇 건인지"보다 "상위 10건이 뭔지"를 중시하는 것과 같은 트레이드오프다.

> 인덱스 없이 `ORDER BY embedding <=> q`를 실행하면 Postgres는 시퀀셜 스캔을 한다. 몇 천 행까지는 체감이 안 되지만, 그 이상이면 반드시 HNSW를 만들어라. `EXPLAIN ANALYZE`로 확인하는 습관은 여기서도 똑같이 유효하다.
{: .prompt-warning }

---

## 5. Frontmatter: 이미 구조화된 메타데이터

여기까지 오면 한 가지 문제가 남는다. **벡터 검색은 "의미"는 잘 찾지만 "조건"은 못 거른다.**

"강남에서 별점 4.5 이상인 식당"이라고 물었을 때, 벡터 유사도는 "강남 식당" 느낌의 글을 찾아주지만 `별점 >= 4.5`라는 숫자 조건은 벡터 공간에 없다. 4.2점 글도, 4.9점 글도 "강남 식당"이라는 의미에서는 똑같이 가깝다.

그래서 필요한 게 **메타데이터 필터**, 즉 `WHERE` 절이다. 그리고 Jekyll 같은 정적 블로그를 쓰고 있다면, 그 메타데이터를 **이미 갖고 있다.** 바로 마크다운 상단의 Frontmatter다.

```yaml
---
title: "Best Izakaya in Pyeongchon — Truffle Abalone Pasta at Enwoo"
date: 2026-06-20 20:00:00 +0900
categories: [Korean Food, Seoul]
tags: [enwoo, pyeongchon-izakaya, abalone-pasta]
restaurant:
  name: "Enwoo (엔우)"
  area: "Pyeongchon, Anyang"
  rating: 4.8
  price_range: "~₩25,000–30,000/person"
  reservation: "Recommended on weekends"
---
```

이건 사실상 **정규화된 테이블의 한 행**이다. `categories`는 배열 컬럼, `restaurant.rating`은 numeric 컬럼, `date`는 timestamp다. 파싱 비용이 0에 가깝고, 이미 내가 손으로 검증한 데이터다.

RAG에서 Frontmatter의 역할은 세 가지다.

| 역할 | 예시 | SQL로 치면 |
|---|---|---|
| **필터링** | 카테고리가 `Korean Food`이고 별점 4.5 이상인 청크만 검색 | `WHERE` |
| **출처 표시** | 답변에 "출처: 엔우 리뷰 (2026-06-20)" 붙이기 | `SELECT title, date` |
| **청크에 문맥 부여** | 본문 조각만 보면 어느 식당 얘긴지 모름 → 제목·식당명을 청크에 같이 넣음 | 비정규화 |

특히 세 번째가 실무에서 자주 놓친다. 글을 500자 단위로 잘랐을 때 "바질 짬뽕이 시그니처다"라는 조각만 있으면 어느 식당인지 알 수 없다. 청크 앞에 `[중앙감속기 · 성수 · 4.2점]` 같은 헤더를 붙이거나 메타데이터 컬럼을 같이 저장해야 검색과 답변 둘 다 정확해진다.

---

## 6. 실습: 내 Jekyll 블로그를 RAG로 만들기

이제 위 개념을 그대로 코드로 옮긴다. 구성은 다음과 같다.

- 데이터: `_posts/*.md` (Frontmatter + 본문)
- 벡터DB: PostgreSQL 16 + pgvector
- 임베딩: OpenAI `text-embedding-3-small` (1536차원)
- 코드: Java(Spring AI) / Ruby 두 버전

### 6-1. 스키마

```sql
CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE post_chunks (
  id            bigserial PRIMARY KEY,
  slug          text        NOT NULL,     -- 파일명에서 추출, 글 식별자
  chunk_index   int         NOT NULL,     -- 글 안에서 몇 번째 조각인지
  title         text        NOT NULL,     -- ┐
  categories    text[]      NOT NULL,     -- │
  tags          text[]      NOT NULL,     -- │ Frontmatter → 컬럼
  published_at  date        NOT NULL,     -- │
  rating        numeric(2,1),             -- │ restaurant.rating (없으면 NULL)
  area          text,                     -- ┘ restaurant.area
  content       text        NOT NULL,     -- 청크 본문
  embedding     vector(1536) NOT NULL,
  UNIQUE (slug, chunk_index)              -- 재색인 시 upsert 기준
);

CREATE INDEX ON post_chunks USING hnsw (embedding vector_cosine_ops);
CREATE INDEX ON post_chunks USING gin  (categories);
CREATE INDEX ON post_chunks USING gin  (tags);
CREATE INDEX ON post_chunks (rating);
```

Frontmatter 필드를 **컬럼으로 승격**시킨 게 포인트다. JSONB 하나에 몰아넣어도 되지만, 필터에 자주 쓰는 `categories`, `rating`은 컬럼으로 빼서 인덱스를 태우는 게 낫다. 일반 테이블 설계와 똑같은 판단이다.

### 6-2. 인덱싱 파이프라인

`파일 읽기 → Frontmatter 파싱 → 본문 청킹 → 임베딩 → INSERT`. 네 단계다.

#### Ruby

```ruby
# Gemfile: pg, ruby-openai, front_matter_parser
require "pg"
require "openai"
require "front_matter_parser"

conn   = PG.connect(dbname: "blog")
client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"])

def chunk(markdown, size: 800)
  # "## " 헤더 기준으로 자르고, 너무 길면 size 글자로 재분할
  markdown.split(/^(?=## )/).flat_map { |sec| sec.scan(/.{1,#{size}}/m) }
          .map(&:strip).reject(&:empty?)
end

Dir["_posts/*.md"].each do |path|
  parsed = FrontMatterParser::Parser.parse_file(path)
  fm     = parsed.front_matter
  slug   = File.basename(path, ".md").sub(/^\d{4}-\d{2}-\d{2}-/, "")
  rest   = fm["restaurant"] || {}

  chunk(parsed.content).each_with_index do |body, i|
    # 청크에 문맥 헤더를 붙여서 임베딩 — 조각만 봐도 어느 글인지 알게
    text = "[#{fm['title']} | #{rest['area']} | rating #{rest['rating']}]\n#{body}"
    vec  = client.embeddings(parameters: { model: "text-embedding-3-small", input: text })
                 .dig("data", 0, "embedding")

    conn.exec_params(<<~SQL, [slug, i, fm["title"], fm["categories"], fm["tags"],
                               fm["date"].to_date, rest["rating"], rest["area"], body, vec.to_s])
      INSERT INTO post_chunks
        (slug, chunk_index, title, categories, tags, published_at, rating, area, content, embedding)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10::vector)
      ON CONFLICT (slug, chunk_index) DO UPDATE
        SET content = EXCLUDED.content, embedding = EXCLUDED.embedding,
            rating = EXCLUDED.rating, tags = EXCLUDED.tags
    SQL
  end
end
```

#### Java (Spring AI)

```java
// build.gradle: spring-ai-openai-spring-boot-starter, spring-boot-starter-jdbc, snakeyaml
@Service
@RequiredArgsConstructor
public class PostIndexer {

    private final EmbeddingModel embeddingModel;   // Spring AI가 주입
    private final JdbcTemplate jdbc;
    private static final Pattern FM = Pattern.compile("^---\\n(.*?)\\n---\\n(.*)$", Pattern.DOTALL);

    public void indexAll(Path postsDir) throws IOException {
        try (var files = Files.list(postsDir)) {
            for (Path p : files.filter(f -> f.toString().endsWith(".md")).toList()) {
                indexOne(p);
            }
        }
    }

    @SuppressWarnings("unchecked")
    void indexOne(Path path) throws IOException {
        Matcher m = FM.matcher(Files.readString(path));
        if (!m.find()) return;

        Map<String, Object> fm = new Yaml().load(m.group(1));
        Map<String, Object> rest = (Map<String, Object>) fm.getOrDefault("restaurant", Map.of());
        String slug = path.getFileName().toString().replaceFirst("^\\d{4}-\\d{2}-\\d{2}-", "").replace(".md", "");
        List<String> chunks = chunk(m.group(2), 800);

        for (int i = 0; i < chunks.size(); i++) {
            String text = "[%s | %s | rating %s]\n%s".formatted(
                    fm.get("title"), rest.get("area"), rest.get("rating"), chunks.get(i));
            float[] vec = embeddingModel.embed(text);

            jdbc.update("""
                INSERT INTO post_chunks
                  (slug, chunk_index, title, categories, tags, published_at, rating, area, content, embedding)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?::vector)
                ON CONFLICT (slug, chunk_index) DO UPDATE
                  SET content = EXCLUDED.content, embedding = EXCLUDED.embedding,
                      rating = EXCLUDED.rating, tags = EXCLUDED.tags
                """,
                slug, i, fm.get("title"),
                toSqlArray((List<String>) fm.get("categories")),
                toSqlArray((List<String>) fm.get("tags")),
                toDate(fm.get("date")), rest.get("rating"), rest.get("area"),
                chunks.get(i), Arrays.toString(vec));
        }
    }

    static List<String> chunk(String md, int size) {
        return Arrays.stream(md.split("(?m)^(?=## )"))
                .flatMap(sec -> splitEvery(sec.strip(), size).stream())
                .filter(s -> !s.isBlank()).toList();
    }
    // toSqlArray, toDate, splitEvery 는 생략 — 각각 String[]→SQL 배열, YAML date→LocalDate, 고정 길이 분할
}
```

> Spring AI에는 `PgVectorStore`라는 추상화가 있어서 `vectorStore.add(List<Document>)` 한 줄로 끝낼 수도 있다. 다만 그 경우 메타데이터가 JSONB 한 컬럼에 들어가고 테이블 구조를 Spring AI가 정한다. **SQL을 직접 보고 싶은 단계에서는 위처럼 JdbcTemplate으로 시작하고**, 익숙해지면 `VectorStore`로 옮겨도 늦지 않다.
{: .prompt-info }

### 6-3. 검색: 벡터 + Frontmatter 필터 (하이브리드)

여기가 이 글의 핵심 쿼리다. "강남/성수 쪽에서 별점 4.5 이상인 곳 중에 예약이 필요한 식당"을 찾는다고 하자.

```sql
-- $1: 질문 임베딩, $2: 최소 별점
SELECT slug, title, area, rating, content,
       1 - (embedding <=> $1::vector) AS similarity
FROM post_chunks
WHERE 'Korean Food' = ANY(categories)      -- Frontmatter 필터 (WHERE)
  AND rating >= $2                          -- Frontmatter 필터 (WHERE)
ORDER BY embedding <=> $1::vector           -- 의미 검색 (ORDER BY)
LIMIT 5;
```

이 쿼리 하나가 RAG의 "R"이다. `WHERE`는 Frontmatter에서 왔고, `ORDER BY`는 임베딩에서 왔다. 둘을 같이 쓰는 걸 **하이브리드 검색**이라고 부르는데, 거창한 이름에 비해 실체는 이 정도다.

#### Ruby (ActiveRecord + neighbor gem)

```ruby
# Gemfile: neighbor
class PostChunk < ApplicationRecord
  has_neighbors :embedding
end

q_vec = embed("강남 쪽 별점 높은 식당 중 예약 필요한 곳")

PostChunk
  .where("? = ANY(categories)", "Korean Food")
  .where("rating >= ?", 4.5)
  .nearest_neighbors(:embedding, q_vec, distance: "cosine")
  .limit(5)
  .pluck(:title, :area, :rating, :content)
```

#### Java

```java
record Hit(String slug, String title, String area, BigDecimal rating, String content, double similarity) {}

List<Hit> search(String question, double minRating) {
    float[] q = embeddingModel.embed(question);
    return jdbc.query("""
        SELECT slug, title, area, rating, content,
               1 - (embedding <=> ?::vector) AS similarity
        FROM post_chunks
        WHERE 'Korean Food' = ANY(categories) AND rating >= ?
        ORDER BY embedding <=> ?::vector
        LIMIT 5
        """,
        (rs, i) -> new Hit(rs.getString("slug"), rs.getString("title"), rs.getString("area"),
                           rs.getBigDecimal("rating"), rs.getString("content"), rs.getDouble("similarity")),
        Arrays.toString(q), minRating, Arrays.toString(q));
}
```

### 6-4. 답변 생성: 검색 결과를 프롬프트에 붙이기

```java
String answer(String question) {
    List<Hit> hits = search(question, 4.5);

    String context = hits.stream()
        .map(h -> "### %s (%s, ★%s)\n%s".formatted(h.title(), h.area(), h.rating(), h.content()))
        .collect(Collectors.joining("\n\n"));

    return ChatClient.create(chatModel).prompt()
        .system("""
            너는 아래 자료만 근거로 답하는 맛집 안내 봇이다.
            자료에 없는 내용은 '자료에 없음'이라고 답하고, 답변 끝에 참고한 글 제목을 출처로 나열해라.
            """)
        .user("자료:\n" + context + "\n\n질문: " + question)
        .call()
        .content();
}
```

```ruby
def answer(question)
  hits    = search(question, min_rating: 4.5)
  context = hits.map { |h| "### #{h.title} (#{h.area}, ★#{h.rating})\n#{h.content}" }.join("\n\n")

  client.chat(parameters: {
    model: "gpt-4o-mini",
    messages: [
      { role: "system", content: "아래 자료만 근거로 답해라. 없으면 '자료에 없음'. 끝에 출처(글 제목)를 나열해라." },
      { role: "user",   content: "자료:\n#{context}\n\n질문: #{question}" }
    ]
  }).dig("choices", 0, "message", "content")
end
```

`system` 프롬프트의 "자료만 근거로", "없으면 없다고" 두 줄이 환각(hallucination)을 막는 가장 싼 방법이다. 그리고 출처를 나열하게 하면 Frontmatter의 `title`이 그대로 인용으로 쓰인다 — 5장에서 말한 두 번째 역할이다.

---

## 7. 실무에서 걸리는 것들

**청킹 단위.** 너무 잘게 자르면 문맥이 사라지고, 너무 크면 관련 없는 내용이 프롬프트를 채운다. 마크다운은 `##` 헤더가 자연스러운 경계라 그걸 1차 기준으로 쓰고, 500~1000자 정도로 2차 분할하는 게 무난하다. 문단 경계에서 50~100자 겹치게(overlap) 자르면 경계에 걸린 문장이 살아난다.

**차원은 계약이다.** `vector(1536)`은 `text-embedding-3-small` 기준이다. 모델을 바꾸면(예: `-large`는 3072) 컬럼도 바꾸고 **전체 재색인**해야 한다. 서로 다른 모델의 벡터를 한 테이블에 섞으면 거리 계산이 무의미해진다. 마이그레이션 계획에 넣어라.

**재색인 전략.** `UNIQUE (slug, chunk_index)` + `ON CONFLICT DO UPDATE`로 글 수정 시 덮어쓰기 하되, 글이 짧아져서 청크 수가 줄었을 때 남는 꼬리 청크는 `DELETE ... WHERE slug = $1 AND chunk_index >= $2`로 정리해야 한다. 파일 해시를 저장해두고 바뀐 글만 다시 임베딩하면 API 비용이 크게 준다.

**필터를 먼저 걸어라.** `WHERE`로 100만 행을 1만 행으로 줄인 뒤 벡터 정렬을 하는 게 훨씬 빠르다. pgvector 0.8+는 필터가 있을 때 HNSW를 이어서 탐색(iterative scan)하므로, `SET hnsw.iterative_scan = relaxed_order;`를 세션에서 켜두면 "필터 때문에 결과가 5개 미만으로 나오는" 문제가 완화된다.

**키워드 검색을 버리지 마라.** 고유명사("엔우", "중앙감속기")는 벡터보다 `tsvector`/`ILIKE`가 정확하다. 벡터 상위 20건 + 키워드 상위 20건을 합쳐 재정렬(RRF, Reciprocal Rank Fusion)하는 게 실무 표준에 가깝다. 기존 Full-text 인덱스가 있다면 그대로 살려 쓰면 된다.

**평가는 쿼리 로그로.** 정답셋 20~30개(질문 → 기대 글 slug)를 만들어두고, 검색 상위 5건에 기대 slug가 들어가는 비율(Recall@5)을 재라. 청킹 크기나 프롬프트를 바꿀 때마다 이 숫자를 보면 감으로 튜닝하는 걸 피할 수 있다.

---

## 8. 정리: SQL 개발자용 치트시트

| 내가 아는 것 | RAG/벡터DB에서는 | 이 글의 예시 |
|---|---|---|
| 테이블 | 컬렉션 (pgvector에선 그냥 테이블) | `post_chunks` |
| 행 | 청크 (문서 조각) | `##` 단위로 자른 본문 |
| 컬럼 | 메타데이터 | Frontmatter의 `title`, `categories`, `rating` |
| `vector(n)` 컬럼 | 임베딩 | `text-embedding-3-small` → 1536 |
| B-Tree | HNSW / IVFFlat | `USING hnsw (embedding vector_cosine_ops)` |
| `WHERE` | 메타데이터 필터 | `rating >= 4.5 AND 'Korean Food' = ANY(categories)` |
| `LIKE` / Full-text | 벡터 유사도 (`<=>`) | `ORDER BY embedding <=> q` |
| `ORDER BY ... LIMIT k` | Top-K 검색 | `LIMIT 5` |
| `SELECT` 결과를 앱에서 조립 | 프롬프트에 컨텍스트 주입 | `"자료:\n" + context + "\n질문:" + q` |
| `UPSERT` | 재색인 | `ON CONFLICT (slug, chunk_index) DO UPDATE` |

RAG는 새 패러다임이라기보다 **"검색 + 문자열 조립 + API 호출"**이고, 벡터DB는 **"거리 연산자와 ANN 인덱스가 추가된 DB"**다. Frontmatter는 그 위에서 `WHERE` 절과 출처 표시를 공짜로 얻게 해주는, 이미 손에 있던 정규화된 메타데이터다. 셋 다 SQL 개발자가 이미 갖고 있는 감각으로 충분히 다룰 수 있다.

---

## 참고

- [pgvector — GitHub](https://github.com/pgvector/pgvector)
- [Spring AI Reference — Vector Databases](https://docs.spring.io/spring-ai/reference/api/vectordbs.html)
- [neighbor gem (Ruby / ActiveRecord)](https://github.com/ankane/neighbor)
- [OpenAI Embeddings Guide](https://platform.openai.com/docs/guides/embeddings)
