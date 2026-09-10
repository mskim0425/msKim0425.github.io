---
title: "질문에서 답까지 — RAG 서빙 경로 8단계와 LLM이 답을 '생성'하는 방식 (Java/Ruby 구현)"
date: 2026-09-11 09:00:00 +0900
categories: [Dev, AI]
tags: [rag, llm, transformer, attention, tokenization, hybrid-search, reranking, spring-ai]
description: "LLM은 답을 찾아오지 않는다 — 한 토큰씩 만들어낸다. 질문이 들어와 답이 나가기까지 8단계(질문 다듬기 → 임베딩 → 하이브리드 검색 → 리랭킹 → 프롬프트 조립 → 생성 → 후처리)를 Java/Ruby로 구현하고, 그 중 '생성' 단계 안에서 토큰화·어텐션·다음 토큰 확률·샘플링·자기회귀가 어떻게 돌아가는지, 왜 검색된 근거가 답을 바꾸는지를 SQL 개발자 감각으로 뜯어본다."
---

## 한 줄 요약

> **LLM은 답을 조회하지 않는다. 프롬프트를 조건으로 "다음 토큰"의 확률을 계산하고 하나 뽑는 일을 답이 끝날 때까지 반복한다.** RAG 서빙은 그 확률이 **내 자료 쪽으로 기울도록** 검색된 원문 조각을 프롬프트에 넣어주는 8단계다. 벡터는 "어느 조각을 꺼낼지" 정하는 색인일 뿐, LLM은 벡터를 보지 않는다.
{: .prompt-tip }

[1편](/posts/rag-vector-db-frontmatter-for-sql-java-ruby-developers/)에서 창고(pgvector)를 지었고 [2편](/posts/dag-airflow-starrocks-data-pipeline-for-sql-java-ruby-developers/)에서 매일 채우는 걸 자동화했다. 이 글은 나머지 절반 — **창고에서 꺼내 답하기**다. 앞부분에서 경로 전체를 훑고, 중간에 LLM 내부로 깊이 들어갔다가, 뒷부분에서 코드로 돌아온다.

---

## 0. 먼저 잘라둘 오해 세 가지

이 글을 읽는 동안 계속 걸리적거릴 오해라서 먼저 정리한다.

| 오해 | 실제 |
|---|---|
| "ChatGPT/Claude도 질문할 때마다 DB에서 자료를 꺼내 온다" | 기본 LLM 대화는 **검색을 하지 않는다.** 학습 때 가중치에 새겨진 지식 + **지금 대화창에 있는 텍스트**만으로 답한다. RAG는 "대화창에 넣을 자료"를 벡터 검색으로 자동 선별하는 **추가 장치**다. |
| "LLM이 이해하기 쉽게 벡터로 바꿔서 저장한다" | LLM은 사람 언어를 아주 잘 읽는다. 벡터화는 **검색용 색인**이고, LLM에게 건네는 건 검색으로 찾은 **원문 텍스트**다. LLM은 pgvector의 벡터를 본 적이 없다. |
| "벡터 만드는 것도 LLM이 한다" | **임베딩 모델**은 챗 LLM과 다른, 훨씬 작은 별도 모델이다. 그리고 청킹·Frontmatter 파싱·DB 검색은 LLM이 아니라 **코드**가 한다. |

정리하면 LLM이 실제로 개입하는 지점은 딱 둘이다 — **질문을 검색하기 좋게 다듬을 때(선택)**와 **찾아온 조각을 읽고 답 문장을 만들 때**.

---

## 1. 서빙 경로 8단계

질문 하나가 들어와서 답이 나가기까지. 각 단계에 **누가** 일하는지, **토큰 비용**이 드는지를 같이 적었다.

```
① 질문 입력        ─ 코드         ─ 비용 없음
       │
② 질문 다듬기      ─ LLM (선택)   ─ 소량   "2022년 이후"→필터, 복합 질문→분해, 검색용 재작성
       │
③ 질문 임베딩      ─ 임베딩 모델   ─ 극소   문장 1개 → 벡터 1개
       │
④ 검색            ─ DB           ─ 없음   벡터 유사도 + WHERE(메타) + 키워드 → 상위 20 조각(텍스트)
       │
⑤ 리랭킹          ─ 리랭커 모델   ─ 소량   (질문, 조각) 쌍을 정밀 채점 → 상위 5
       │
⑥ 프롬프트 조립    ─ 코드         ─ 없음   [지시문] + [조각 5개 + 출처 번호] + [질문]
       │
⑦ 생성            ─ LLM          ─ 大     ← 이 글의 중심. 3장.
       │
⑧ 후처리          ─ 코드         ─ 없음   출처 링크화, "자료에 없음" 검사, 스트리밍, 로그 적재
```

SQL 개발자용 대응: ②는 **쿼리 파서**, ③④⑤는 **실행 계획 + 인덱스 스캔 + 정렬**, ⑥은 **결과 조립**, ⑦은… SQL에 없는 단계다. 결과를 "리턴"하는 게 아니라 결과를 **읽고 새 문장을 만든다.** 그래서 3장이 길다.

---

## 2. 왜 "찾아온다"가 아니라 "만들어낸다"인가

DB는 `SELECT`하면 저장된 행을 **그대로** 돌려준다. LLM은 다르다. 프롬프트를 읽고 **"다음에 올 토큰은 무엇일 확률이 높은가"**를 어휘 전체에 대해 계산한 뒤 하나를 고른다. 그 토큰을 프롬프트 끝에 붙이고 같은 계산을 반복한다. 답은 이 반복의 **부산물**이다.

```
프롬프트: "...[1] 엔우의 전복내장 크림 파스타는 트러플과... 질문: 엔우에서 뭘 먹어야 해? 답:"
   → 다음 토큰 확률: "전복"(0.61) "트러플"(0.18) "고등어"(0.09) "파스타"(0.05) ...
   → "전복" 선택
프롬프트 + "전복"
   → 다음 토큰 확률: "내장"(0.88) "요리"(0.04) ...
   → "내장" 선택
...
```

이걸 **자기회귀(autoregressive) 생성**이라고 부른다. 여기서 두 가지가 바로 따라 나온다.

- **환각의 정체**: 확률 계산은 프롬프트에 근거가 있든 없든 돌아간다. 근거가 없으면 학습 데이터에서 본 "그럴듯한" 패턴으로 확률이 채워진다. 그게 환각이다. 고장이 아니라 기본 동작이다.
- **RAG가 하는 일**: 프롬프트에 근거 텍스트를 넣으면 조건부 확률 `P(다음 토큰 | 프롬프트)`의 조건이 바뀐다. 근거와 일치하는 토큰의 확률이 급상승하고, 나머지는 눌린다. **RAG는 LLM을 바꾸지 않는다. 조건을 바꾼다.**

---

## 3. ⑦ 생성 단계의 내부

프롬프트가 LLM에 들어가서 첫 토큰이 나올 때까지 벌어지는 일을 순서대로 본다. 수식은 내적 하나로 끝나니 겁먹지 않아도 된다 — 1편 코사인 유사도에서 이미 한 계산이다.

### 3-1. 토큰화: 텍스트를 조각 번호로

LLM은 글자를 읽지 않는다. **토큰**이라는 조각 단위로 읽는다. 토크나이저(BPE 계열)가 텍스트를 자주 등장하는 조각으로 자르고 각 조각에 정수 ID를 매긴다.

```
"엔우의 전복내장 크림 파스타"
  → ["엔", "우", "의", " 전", "복", "내장", " 크림", " 파스타"]
  → [24851, 6913, 1202, 85712, 3391, 41202, 60117, 19773]
```

개발자가 알아야 할 것 세 가지.

- **한국어는 영어보다 토큰이 많이 든다.** 같은 뜻이라도 1.5~3배. 비용과 컨텍스트 창은 토큰 기준이니, 한국어 RAG는 예산을 더 넉넉히 잡아야 한다.
- **컨텍스트 창(context window)** = 한 번에 넣을 수 있는 토큰 상한. 128k 같은 숫자다. 이 안에 지시문 + 조각 + 질문 + **답변까지** 들어가야 한다.
- 토큰 수는 미리 셀 수 있다. Java는 `jtokkit`, Ruby는 `tiktoken_ruby`. ⑥에서 예산을 지킬 때 쓴다.

### 3-2. 토큰 → 내부 벡터

각 토큰 ID로 **LLM 내부의 룩업 테이블**에서 벡터를 꺼낸다(임베딩 행렬). 여기에 "몇 번째 위치인지" 정보(위치 인코딩)를 섞는다. 

> 이 벡터는 1편에서 pgvector에 넣은 `text-embedding-3-small`의 벡터와 **다른 물건**이다. 그건 검색용 별도 모델의 출력이고, 이건 챗 LLM이 자기 내부에서 쓰는 표현이다. 이름이 둘 다 "임베딩"이라 헷갈릴 뿐, 서로 호환되지 않고 만날 일도 없다.
{: .prompt-warning }

### 3-3. 어텐션: 프롬프트 전체를 돌아보며 가중 평균

핵심이다. 각 토큰이 다음 층으로 넘어가기 전에 **프롬프트 안의 다른 모든 토큰을 돌아보고, 지금 나에게 중요한 토큰의 정보를 끌어와 섞는다.** 이걸 어텐션이라 한다.

토큰마다 벡터 세 개를 만든다(가중치 행렬 세 개를 곱해서).

| 이름 | 역할 | 비유 |
|---|---|---|
| **Q** (Query) | "나는 지금 무엇을 찾는가" | 검색어 |
| **K** (Key) | "나는 무엇에 관한 토큰인가" | 색인 키 |
| **V** (Value) | "나를 참조하면 가져갈 정보" | 실제 값 |

계산은 세 줄이다.

```
1. 점수  = Q · K          (내적. 1편 코사인 유사도의 분자와 같은 연산)
2. 가중치 = softmax(점수)   (점수를 0~1 확률로, 합이 1)
3. 출력  = Σ 가중치 × V    (가중 평균)
```

손으로 해보자. 지금 생성 중인 토큰이 "파스타"이고, 프롬프트에 "전복내장", "빙수", "예약"이라는 토큰이 있다고 치자. 벡터를 2차원으로 줄인다(설명용 숫자다).

```
Q("파스타")  = [1.0, 0.0]

K("전복내장") = [0.9, 0.1]   →  점수 = 1.0×0.9 + 0.0×0.1 = 0.90
K("빙수")     = [0.1, 0.9]   →  점수 = 0.10
K("예약")     = [0.5, 0.5]   →  점수 = 0.50

softmax([0.90, 0.10, 0.50])
  = [e^0.90, e^0.10, e^0.50] / 합
  = [2.46, 1.11, 1.65] / 5.21
  = [0.47, 0.21, 0.32]
```

"파스타" 토큰은 "전복내장"의 정보를 47%, "예약"을 32%, "빙수"를 21% 섞어서 자기 표현을 갱신한다. 이 비율이 **어텐션 가중치**이고, "모델이 어디를 보고 있는가"의 실체다. 검색으로 넣어준 조각 안에 "전복내장 크림 파스타"가 있으면, 답을 쓰는 동안 그 토큰들의 어텐션 가중치가 높게 잡힌다 — 근거가 답을 끌어당기는 물리적 메커니즘이 이것이다.

```ruby
def softmax(xs)
  exps = xs.map { |x| Math.exp(x) }
  exps.map { |e| e / exps.sum }
end

q  = [1.0, 0.0]
ks = { "전복내장" => [0.9, 0.1], "빙수" => [0.1, 0.9], "예약" => [0.5, 0.5] }
scores = ks.transform_values { |k| q.zip(k).sum { |a, b| a * b } }
p scores                                     # {"전복내장"=>0.9, "빙수"=>0.1, "예약"=>0.5}
p ks.keys.zip(softmax(scores.values)).to_h   # {"전복내장"=>0.47, "빙수"=>0.21, "예약"=>0.32}
```

SQL로 치면 어텐션은 **프롬프트의 모든 토큰에 대한 셀프 조인 + 가중 평균**이다.

```sql
-- 어텐션을 굳이 SQL로 쓰면 (개념 확인용)
SELECT me.id,
       SUM(softmax(dot(me.q, other.k)) * other.v) AS new_repr
FROM tokens me
JOIN tokens other ON other.pos <= me.pos     -- 생성 중엔 앞쪽만 본다 (causal mask)
GROUP BY me.id;
```

실제 모델은 이걸 **여러 관점으로 동시에**(멀티헤드 — 어떤 헤드는 문법, 어떤 헤드는 지시 관계, 어떤 헤드는 근거 참조) 하고, 그 결과를 **수십 층** 쌓는다. 층이 올라갈수록 "이 토큰이 지금 문맥에서 무슨 뜻인지"가 정교해진다. 가중치(Q·K·V 행렬, 층별 변환 행렬)는 1편 3-2에서 말한 것과 같은 방식으로 학습돼 있고, 서빙 중엔 고정이다.

### 3-4. 다음 토큰의 확률 분포

마지막 층을 통과한 **마지막 위치의 벡터**를 어휘 크기(10만 개 안팎)의 행렬과 곱하면 토큰마다 점수(logit)가 나온다. softmax를 씌우면 확률 분포가 된다.

```
logits  → ["전복": 4.1, "트러플": 2.9, "고등어": 2.2, "파스타": 1.6, ..., "MySQL": -3.0]
softmax → ["전복": 0.61, "트러플": 0.18, "고등어": 0.09, "파스타": 0.05, ..., "MySQL": 0.00003]
```

이 분포가 **LLM의 진짜 출력**이다. 문장이 아니라 확률 10만 개. 여기까지가 한 번의 순전파(forward pass)다.

### 3-5. 샘플링: 확률에서 토큰 하나 고르기

분포에서 하나를 뽑는 규칙이 몇 개 있고, API 파라미터가 이걸 조절한다.

| 파라미터 | 뜻 | RAG 답변에서는 |
|---|---|---|
| `temperature` | 분포를 뾰족하게(0에 가까움) 또는 평평하게(1 이상) | **0~0.3**. 근거를 그대로 옮겨 적는 게 목적이라 낮게 |
| `top_p` | 누적 확률이 p가 될 때까지의 상위 토큰만 후보 | 0.9 안팎. temperature와 둘 중 하나만 조절 |
| `max_tokens` | 생성 상한 | 답변 길이 예산. 비용과 직결 |
| `stop` | 이 문자열이 나오면 중단 | `"\n\n질문:"` 같은 템플릿 경계 |

`temperature=0`이면 항상 최고 확률 토큰을 고르므로 같은 입력에 같은 출력이 나온다(거의). 테스트와 평가에는 0, 창의적 글쓰기엔 0.7~1.0.

### 3-6. 자기회귀 루프와 스트리밍

고른 토큰을 입력 끝에 붙이고 3-2부터 다시 한다. 종료 토큰(`<|end|>`)이 뽑히거나 `max_tokens`에 닿으면 멈춘다.

```
for step in 1..max_tokens:
    probs = forward(prompt_tokens + generated)   # 3-2 ~ 3-4
    next  = sample(probs, temperature, top_p)    # 3-5
    if next == EOS: break
    generated.append(next)
    yield decode(next)                           # ← 스트리밍: 토큰 하나 나올 때마다 전송
```

두 가지 실무 함의.

- **스트리밍이 자연스러운 이유**: 답이 한 번에 완성되는 게 아니라 토큰 단위로 나오니까, 나오는 대로 흘려보내면 된다. 첫 토큰까지의 지연(**TTFT**, time to first token)이 체감 속도를 좌우한다.
- **긴 프롬프트가 비싼 이유**: 첫 토큰을 내려면 프롬프트 전체를 한 번 처리해야 한다(TTFT ≈ 프롬프트 길이에 비례). 이후 토큰은 앞서 계산한 K·V를 캐시(**KV 캐시**)해두고 새 토큰 하나만 추가 계산하므로 빠르다. 조각을 5개 넣을지 10개 넣을지가 TTFT와 입력 토큰 비용을 동시에 결정한다.

### 3-7. 근거가 답을 바꾸는 방식, 그리고 한계

2장의 문장을 3장 용어로 다시 쓰면: 검색된 조각을 프롬프트에 넣으면 → 조각의 토큰들이 K·V로 프롬프트 안에 존재하게 되고 → 답을 생성하는 각 단계에서 어텐션이 그 토큰들을 높은 가중치로 참조하고 → 다음 토큰 분포가 조각의 내용과 일치하는 쪽으로 기운다.

그래서 한계도 같은 자리에서 나온다.

- **없는 근거는 참조할 수 없다.** 검색(④⑤)이 틀리면 ⑦은 그럴듯한 오답을 만든다. RAG 품질의 80%가 검색이라는 1편의 말이 여기서 다시 나온다.
- **근거가 있어도 안 볼 수 있다.** 프롬프트 한가운데 묻힌 조각은 어텐션이 덜 간다는 실험 결과가 있다(**lost in the middle**). 중요한 조각은 앞이나 뒤에 놓는다.
- **지시문도 조건이다.** "자료에 없으면 없다고 답해라"는 문장은 "없음"이라는 토큰의 확률을 올리는 조건이다. 효과는 있지만 보장은 아니다. ⑧에서 코드로 한 번 더 검사한다.
- **근거를 따라 쓰는 것과 근거를 검증하는 것은 다르다.** LLM은 조각이 사실인지 모른다. 조각이 틀리면 답도 틀린다. 창고에 넣는 데이터 품질이 곧 답 품질이다.

### 3-8. 비용과 지연, 숫자로

```
지시문     200 토큰
조각 5개  1,500 토큰   (300 × 5)
질문        60 토큰
─────────────────
입력     1,760 토큰    → TTFT, 입력 단가
출력       400 토큰    → 토큰당 생성 시간, 출력 단가 (보통 입력의 3~5배)
```

입력을 줄이려면 조각 수·크기·리랭킹, 출력을 줄이려면 `max_tokens`와 "간결하게 답하라" 지시. 2편의 `search_log.prompt_tokens / completion_tokens`가 바로 이 두 숫자다.

---

## 4. ①~⑧ 구현

1편의 `post_chunks` 테이블과 2편의 `search_log`를 그대로 쓴다. Java(Spring AI)로 전체 흐름을, Ruby로 핵심 단계를 보인다.

### ① 입력

```java
public record Ask(String question, @Nullable String sessionId) {}
```

### ② 질문 다듬기 — LLM으로 검색 조건 뽑기

사용자 문장을 그대로 임베딩하면 "2022년 이후", "4.5점 넘는" 같은 **조건이 벡터에 녹아 사라진다.** 조건은 `WHERE`로 가야 한다. LLM에게 JSON으로 분리시킨다.

```java
record QueryPlan(String searchQuery, Filters filters, List<String> subQuestions) {}
record Filters(@Nullable Double minRating, @Nullable String area, @Nullable Integer minYear) {}

QueryPlan plan(String question) {
    return chatClient.prompt()
        .system("""
            사용자 질문을 검색 계획으로 바꿔라. JSON만 출력.
            - searchQuery: 조건을 뺀 검색용 문장 (동의어 보강 가능)
            - filters: 질문에 명시된 조건만. 없으면 null
            - subQuestions: 질문이 둘 이상이면 분해, 아니면 빈 배열
            """)
        .user(question)
        .call()
        .entity(QueryPlan.class);          // Spring AI가 JSON → record 매핑
}
// "강남 쪽에서 4.5점 넘는 데이트 식당 중 예약 필요한 곳"
// → {searchQuery:"강남 데이트 식당 예약 필요", filters:{minRating:4.5, area:"Gangnam"}, subQuestions:[]}
```

```ruby
def plan(question)
  res = client.chat(parameters: {
    model: "gpt-4o-mini", temperature: 0,
    response_format: { type: "json_object" },
    messages: [
      { role: "system", content: "질문을 검색 계획 JSON으로: {searchQuery, filters:{minRating,area,minYear}, subQuestions[]}. 조건은 filters로 분리." },
      { role: "user",   content: question }
    ]
  })
  JSON.parse(res.dig("choices", 0, "message", "content"))
end
```

> 이 단계는 **선택**이다. 질문이 단순하면 LLM 호출 1회(지연 300~800ms, 소량 토큰)가 아깝다. 실무에선 "질문에 숫자·연도·지역이 보이면 ② 실행, 아니면 건너뛰기" 같은 규칙으로 시작한다.
{: .prompt-info }

### ③ 임베딩

```java
float[] q = embeddingModel.embed(plan.searchQuery());
```

### ④ 하이브리드 검색 — 벡터 + 키워드 + 메타 필터, RRF로 합치기

벡터는 의미를, 키워드는 고유명사("엔우", "중앙감속기")를 잘 잡는다. 둘 다 돌리고 **순위**로 합친다(Reciprocal Rank Fusion). 점수 스케일이 달라도 순위는 합칠 수 있다.

```sql
-- 준비: 키워드 검색용 컬럼과 인덱스 (1편 스키마에 추가)
ALTER TABLE post_chunks
  ADD COLUMN tsv tsvector GENERATED ALWAYS AS (to_tsvector('simple', content)) STORED;
CREATE INDEX ON post_chunks USING gin (tsv);
```

```sql
-- $1: 질문 임베딩, $2: 검색 문장, $3: 최소 별점
WITH vec AS (
  SELECT id, ROW_NUMBER() OVER (ORDER BY embedding <=> $1::vector) AS r
  FROM post_chunks
  WHERE rating >= $3
  ORDER BY embedding <=> $1::vector
  LIMIT 20
),
kw AS (
  SELECT id, ROW_NUMBER() OVER (ORDER BY ts_rank_cd(tsv, q) DESC) AS r
  FROM post_chunks, plainto_tsquery('simple', $2) AS q
  WHERE tsv @@ q AND rating >= $3
  LIMIT 20
)
SELECT c.id, c.slug, c.title, c.area, c.rating, c.content,
       COALESCE(1.0 / (60 + vec.r), 0) + COALESCE(1.0 / (60 + kw.r), 0) AS rrf
FROM post_chunks c
LEFT JOIN vec ON vec.id = c.id
LEFT JOIN kw  ON kw.id  = c.id
WHERE vec.id IS NOT NULL OR kw.id IS NOT NULL
ORDER BY rrf DESC
LIMIT 20;
```

`1/(60+순위)`가 RRF다. 양쪽에서 상위에 있는 조각이 합산에서 앞으로 온다. 60은 관례 상수. `WHERE rating >= $3`가 ②에서 뽑은 필터 — 1편의 "벡터는 조건을 못 거른다"가 여기서 해결된다.

```ruby
# ActiveRecord + neighbor: 벡터 쪽만 (키워드 쪽은 위 SQL을 find_by_sql로)
PostChunk.where("rating >= ?", plan["filters"]["minRating"] || 0)
         .nearest_neighbors(:embedding, q_vec, distance: "cosine")
         .limit(20)
```

> 한국어 키워드 검색에 `'simple'` 설정은 형태소 분석이 없어서 "파스타를"과 "파스타"를 다른 단어로 본다. 제대로 하려면 `pg_bigm`(2-gram) 확장이나 외부 형태소 분석기를 붙인다. 일단은 고유명사용으로 쓴다고 생각하면 된다.
{: .prompt-warning }

### ⑤ 리랭킹 — 20개를 5개로

④의 벡터 검색은 질문과 조각을 **따로** 임베딩해서 비교한다(bi-encoder). 빠르지만 거칠다. 리랭커는 (질문, 조각)을 **한 쌍으로 같이** 읽고 점수를 낸다(cross-encoder). 느리지만 정확하다. 그래서 순서가 "④로 20개 → ⑤로 5개"다.

```java
record Hit(long id, String slug, String title, String area, BigDecimal rating, String content) {}

List<Hit> rerank(String question, List<Hit> candidates, int topN) {
    var body = Map.of(
        "model", "rerank-v3.5",
        "query", question,
        "documents", candidates.stream().map(Hit::content).toList(),
        "top_n", topN);
    var res = restClient.post().uri("https://api.cohere.com/v2/rerank")
        .header("Authorization", "Bearer " + cohereKey)
        .body(body).retrieve().body(RerankResponse.class);   // results[].index, relevance_score
    return res.results().stream().map(r -> candidates.get(r.index())).toList();
}
```

로컬로 돌리고 싶으면 `bge-reranker-v2-m3` 같은 오픈 모델을 작은 HTTP 서비스로 띄우고 같은 인터페이스로 호출한다. 리랭커도 토큰을 쓰지만(질문+조각 20쌍) 생성 단계보다 훨씬 싸다.

### ⑥ 프롬프트 조립 — 예산 안에서

```java
static final String SYSTEM = """
    너는 아래 [자료]만 근거로 답하는 맛집 안내 봇이다.
    - 문장마다 근거 번호를 [n] 형식으로 붙여라.
    - 자료에 없는 내용은 "자료에 없음"이라고만 답해라.
    - 간결하게, 한국어로.
    """;

String buildUserPrompt(String question, List<Hit> hits, int budgetTokens) {
    var sb = new StringBuilder("[자료]\n");
    int used = countTokens(SYSTEM) + countTokens(question) + 50;
    int n = 1;
    for (Hit h : hits) {                                  // 리랭킹 순서 = 중요도 순. 앞에 놓는다 (3-7)
        String block = "[%d] (%s · %s · ★%s)\n%s\n\n".formatted(n, h.title(), h.area(), h.rating(), h.content());
        int t = countTokens(block);
        if (used + t > budgetTokens) break;               // 예산 초과면 나머지 버림
        sb.append(block); used += t; n++;
    }
    return sb.append("[질문]\n").append(question).toString();
}
// countTokens: jtokkit (cl100k_base) 로 실제 토큰 수. 대충 세면 한국어에서 크게 틀린다.
```

조각에 붙인 `(제목 · 지역 · ★별점)`이 1편 5장의 "청크에 문맥 부여"다. 번호 `[n]`은 ⑧에서 출처 링크로 바뀐다.

### ⑦ 생성 — 낮은 temperature, 스트리밍

```java
Flux<String> answer(String question) {
    var plan  = plan(question);                                  // ②
    var q     = embeddingModel.embed(plan.searchQuery());         // ③
    var cands = hybridSearch(q, plan.searchQuery(), plan.filters()); // ④ → 20
    var hits  = rerank(question, cands, 5);                      // ⑤ → 5
    var user  = buildUserPrompt(question, hits, 6_000);          // ⑥

    return chatClient.prompt()
        .system(SYSTEM)
        .user(user)
        .options(OpenAiChatOptions.builder().temperature(0.2).maxTokens(600).build())
        .stream()                                                // ⑦ 토큰 단위로 Flux<String>
        .content();
}
```

```ruby
def answer(question, &on_token)
  plan  = plan(question)
  hits  = rerank(question, hybrid_search(embed(plan["searchQuery"]), plan), 5)
  user  = build_user_prompt(question, hits, 6_000)

  client.chat(parameters: {
    model: "gpt-4o-mini", temperature: 0.2, max_tokens: 600,
    messages: [{ role: "system", content: SYSTEM }, { role: "user", content: user }],
    stream: proc { |chunk, _| tok = chunk.dig("choices", 0, "delta", "content"); on_token.call(tok) if tok }
  })
end
```

3장을 읽었다면 이 호출이 하는 일이 보인다 — `SYSTEM + user`가 토큰화되고(3-1), 어텐션이 `[자료]` 블록을 참조하며(3-3), `temperature 0.2`로 뾰족해진 분포에서(3-5) 토큰이 하나씩 나와 `Flux`로 흘러온다(3-6).

### ⑧ 후처리 — 코드가 마지막 검사

```java
record Answer(String text, List<Source> sources, boolean grounded) {}

Answer postProcess(String raw, List<Hit> hits) {
    boolean grounded = !raw.strip().startsWith("자료에 없음");
    var cited = new TreeSet<Integer>();
    var m = Pattern.compile("\\[(\\d+)]").matcher(raw);
    while (m.find()) cited.add(Integer.parseInt(m.group(1)));

    var sources = cited.stream()
        .filter(n -> n >= 1 && n <= hits.size())                // 존재하지 않는 번호 인용 = 환각 신호
        .map(n -> new Source(n, hits.get(n - 1).title(), "/posts/" + hits.get(n - 1).slug() + "/"))
        .toList();

    if (grounded && sources.isEmpty()) grounded = false;         // 근거 번호 하나도 없으면 미검증 처리
    return new Answer(raw, sources, grounded);
}
```

그리고 2편의 `search_log`에 한 줄 — 질문, 상위 slug, 유사도, `hit_at_5`, 지연, `prompt_tokens`, `completion_tokens`, `cost_usd`. 이 로그가 없으면 "검색이 문제인지 생성이 문제인지"를 영영 감으로 판단하게 된다.

---

## 5. 자주 하는 실수

**조각을 많이 넣을수록 좋다고 믿는 것.** 3-7의 lost in the middle과 3-8의 비용이 동시에 나빠진다. 리랭킹으로 5개 이내로 줄이고, 중요한 것을 앞에 둔다.

**temperature를 기본값(1.0)으로 두는 것.** 같은 질문에 다른 답이 나오고, 근거에서 살짝 벗어난 표현이 섞인다. RAG는 0~0.3.

**② 없이 조건이 있는 질문을 벡터에만 맡기는 것.** "4.5점 이상"이 벡터 공간에서 사라진다. 조건은 `WHERE`로.

**⑤ 없이 ④의 상위 5개를 그대로 쓰는 것.** bi-encoder의 상위 5는 생각보다 자주 틀린다. 리랭커 하나로 Recall@5가 눈에 띄게 오른다.

**출처 번호를 검증하지 않는 것.** LLM은 `[7]`처럼 존재하지 않는 번호도 만든다. ⑧에서 걸러야 한다.

**캐시를 안 하는 것.** 같은 질문의 임베딩(③)과 최종 답변(⑦)은 캐시 대상이다. FAQ성 질문이 많은 서비스에선 절반 이상이 캐시로 끝난다.

**평가 없이 튜닝하는 것.** 정답셋 30개로 검색은 Recall@5, 생성은 **faithfulness**(답이 근거에 충실한가)와 **answer relevance**(질문에 맞는가)를 잰다. RAGAS 같은 도구가 이 두 지표를 LLM으로 자동 채점해준다.

---

## 6. 정리: 치트시트

| 단계 | 담당 | 토큰 비용 | 틀리면 생기는 증상 |
|---|---|---|---|
| ② 질문 다듬기 | LLM (선택) | 소 | 조건이 무시된 결과, 복합 질문 반쪽 답 |
| ③ 임베딩 | 임베딩 모델 | 극소 | — |
| ④ 하이브리드 검색 | DB (pgvector + tsvector + RRF) | 없음 | 고유명사 못 찾음 / 의미 못 찾음 |
| ⑤ 리랭킹 | 리랭커 | 소 | 상위 5에 정답 없음 → 그럴듯한 오답 |
| ⑥ 프롬프트 조립 | 코드 | 없음 | 예산 초과, 중요한 조각이 중간에 묻힘 |
| ⑦ 생성 | LLM | **大** | 환각, 장황함, 비결정적 답 |
| ⑧ 후처리 | 코드 | 없음 | 가짜 출처 번호, 미검증 답 노출 |

| LLM 내부 (⑦) | 한 줄 | 개발자가 만지는 손잡이 |
|---|---|---|
| 토큰화 | 텍스트 → 조각 ID. 한국어는 토큰 많음 | 예산 계산 (`jtokkit`, `tiktoken`) |
| 내부 벡터 | 토큰 ID → 모델 내부 표현 (pgvector 벡터와 무관) | — |
| 어텐션 | Q·K 내적 → softmax → V 가중 평균. 근거를 "참조"하는 메커니즘 | 근거 배치 순서, 조각 수 |
| 다음 토큰 분포 | 어휘 전체에 대한 확률 | — |
| 샘플링 | 분포에서 하나 고름 | `temperature`, `top_p`, `max_tokens`, `stop` |
| 자기회귀 | 붙이고 반복, 종료 토큰까지 | 스트리밍, TTFT, KV 캐시 |

1편이 "무엇을 저장하나", 2편이 "언제 어떻게 채우나"였다면, 이 글은 "꺼내서 어떻게 답이 되나"다. 세 글을 합치면 문서 더미에서 출처 있는 답이 나오기까지의 경로가 빠짐없이 이어진다. 그리고 그 경로의 어느 단계도 마법이 아니다 — 파서, 인덱스, 조인, 가중 평균, 확률 분포에서 하나 뽑기. 전부 개발자가 이미 아는 것들의 조합이다.

---

## 참고

- [Attention Is All You Need (Vaswani et al., 2017)](https://arxiv.org/abs/1706.03762)
- [The Illustrated Transformer — Jay Alammar](https://jalammar.github.io/illustrated-transformer/)
- [Lost in the Middle: How Language Models Use Long Contexts](https://arxiv.org/abs/2307.03172)
- [Reciprocal Rank Fusion (Cormack et al., 2009)](https://plg.uwaterloo.ca/~gvcormac/cormacksigir09-rrf.pdf)
- [Spring AI — ChatClient (structured output, streaming)](https://docs.spring.io/spring-ai/reference/api/chatclient.html)
- [Cohere Rerank API](https://docs.cohere.com/reference/rerank)
- [RAGAS — RAG 평가 프레임워크](https://docs.ragas.io/)
- [1편: RAG · 벡터DB · Frontmatter 총정리](/posts/rag-vector-db-frontmatter-for-sql-java-ruby-developers/) · [2편: DAG · Airflow · StarRocks 총정리](/posts/dag-airflow-starrocks-data-pipeline-for-sql-java-ruby-developers/)
