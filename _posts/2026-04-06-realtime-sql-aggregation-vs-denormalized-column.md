---
title: "실시간 SQL 집계 vs 비정규화 카운터 컬럼 — 언제 뭘 써야 할까"
date: 2026-04-06 20:00:00 +0900
categories: [Database, Backend]
tags: [sql, database-design, denormalization, query-optimization, rails, mysql, counter-column, aggregation, performance, backend-architecture]
description: "매번 JOIN 서브쿼리로 계산할까, 미리 카운터 컬럼에 넣어둘까? 실무 Rails + MySQL 환경에서 두 접근법을 비교합니다."
---

## 문제 상황

주문 관리 시스템을 만들고 있다고 가정해보자. 주문마다 여러 상품이 있고, 각 상품은 선발송(pre-shipment) 처리를 통해 부분적으로 출고될 수 있다. 이때 각 상품의 **남은 발송 가능 수량**을 계산해야 한다 — 즉, 총 구매수량에서 이미 접수된 선발송 수량을 빼야 한다.

두 가지 방법이 있다:

**방법 A — 실시간 집계**: 쿼리할 때마다 선발송 테이블을 JOIN해서 SUM으로 합산.

**방법 B — 비정규화 카운터 컬럼**: 상품 행에 `fulfilled_count` 컬럼을 두고, 선발송 접수/취소 시 트랜잭션 안에서 값을 증감.

최근 프로덕션 Rails + MySQL 환경에서 이 두 접근법을 비교해볼 일이 있었는데, 답이 생각보다 단순하지 않았다.

## 방법 A: 실시간 JOIN 서브쿼리

```sql
SELECT
  items.id,
  items.purchased_count,
  CAST(items.purchased_count AS SIGNED)
    - COALESCE(active_fulfillments.accepted_count, 0) AS available_count
FROM order_items items
LEFT JOIN (
  SELECT fg.item_id, SUM(fg.count) AS accepted_count
  FROM fulfillment_goods fg
  INNER JOIN fulfillments f ON f.id = fg.fulfillment_id
    AND f.deleted_at IS NULL
  WHERE f.status != 'canceled'
    AND fg.deleted_at IS NULL
  GROUP BY fg.item_id
) AS active_fulfillments
  ON active_fulfillments.item_id = items.id
WHERE items.order_id = 12345;
```

매 쿼리마다 `fulfillment_goods` 테이블을 GROUP BY로 합산해서 LEFT JOIN한다. 숫자는 항상 최신이다.

**장점**
- 항상 정확하다 — 동기화 이슈, stale 데이터 없음
- 단일 진실 공급원 — 선발송 기록 테이블 자체가 진실
- 쓰기 쪽 복잡도 없음 — 카운터 업데이트를 신경 쓸 필요 없다

**단점**
- 데이터가 쌓일수록 쿼리 비용 증가 — 서브쿼리가 범위 내 모든 선발송 기록을 스캔
- 읽기 느림 — 리스트 쿼리마다 LEFT JOIN + GROUP BY 추가
- 인덱스 부담 — `(item_id, deleted_at, status)` 복합 인덱스 필수

## 방법 B: 비정규화 카운터 컬럼

```sql
SELECT
  items.id,
  items.purchased_count,
  CAST(items.purchased_count AS SIGNED)
    - COALESCE(items.fulfilled_count, 0) AS available_count
FROM order_items items
WHERE items.order_id = 12345;
```

끝. `fulfilled_count` 컬럼은 애플리케이션 코드에서 관리한다.

Rails에서는 이런 식이다:

```ruby
class FulfillmentService
  def create_fulfillment(item, count)
    ActiveRecord::Base.transaction do
      fulfillment = Fulfillment.create!(item: item, count: count, status: :accepted)
      item.increment!(:fulfilled_count, count)
    end
  end

  def cancel_fulfillment(fulfillment)
    ActiveRecord::Base.transaction do
      fulfillment.update!(status: :canceled)
      fulfillment.item.decrement!(:fulfilled_count, fulfillment.count)
    end
  end
end
```

**장점**
- 읽기가 극도로 빠름 — JOIN 없이, 이미 읽고 있는 행의 컬럼 하나
- 성능 예측 가능 — 선발송 이력이 아무리 쌓여도 쿼리 비용 동일
- 쿼리가 단순 — 다른 scope이나 필터와 조합하기 쉬움

**단점**
- 모든 쓰기 경로에서 카운터를 업데이트해야 함 — 하나라도 빠지면 숫자가 틀림
- 디버깅이 어려움 — `fulfilled_count`가 맞지 않으면 원본 기록과 대조해야 함
- 마이그레이션 리스크 — 새로운 선발송 경로(대량 임포트, 어드민, API)가 추가될 때마다 카운터 업데이트를 기억해야 함

## 판단 기준

스스로에게 두 가지를 물어보자:

**1. 모든 쓰기 경로가 트랜잭션 안에서 카운터를 업데이트하고 있는가?**

시스템에 잘 정의된 서비스 레이어가 하나 있고, 모든 선발송 생성/취소가 그걸 통해 트랜잭션 안에서 처리된다면 — 카운터 컬럼은 정확하게 유지된다. 이 경우 **방법 B가 성능 면에서 압승**이다.

하지만 선발송이 여러 진입점(웹 UI, API, 백그라운드 잡, 어드민, 데이터 마이그레이션)에서 생성될 수 있다면, 업데이트 누락 리스크가 커진다. 방법 A를 고려하거나, 최소한 주기적 재조정(reconciliation) 잡을 추가해야 한다.

**2. 읽기와 쓰기 비율이 어떻게 되는가?**

모든 페이지 로드(리스트, 대시보드, 엑셀 내보내기)마다 남은 수량을 조회하지만, 선발송은 주문당 몇 번만 발생한다면 — 이건 전형적인 read-heavy 패턴이다. 쓰기 시 작은 비용을 지불하고 읽기마다 큰 비용을 절약하는 게 맞다.

반대로 쓰기가 빈번하고 읽기가 드문 경우(배치 처리, 백그라운드 통계)라면, 매 쓰기마다 카운터를 관리하는 오버헤드가 정당화되지 않을 수 있다.

## 하이브리드: 카운터 + 재조정 잡

실무에서 가장 견고한 시스템은 둘 다 쓴다:

```ruby
# 기본: 카운터 컬럼으로 빠른 조회
scope :available, -> {
  where('purchased_count - COALESCE(fulfilled_count, 0) > 0')
}

# 야간 재조정 잡
class ReconcileFulfilledCountsJob < ApplicationJob
  def perform
    OrderItem.find_each do |item|
      actual = item.fulfillment_goods
                   .joins(:fulfillment)
                   .where.not(fulfillments: { status: :canceled })
                   .sum(:count)

      if item.fulfilled_count != actual
        Rails.logger.warn("Mismatch: item #{item.id} counter=#{item.fulfilled_count} actual=#{actual}")
        item.update_column(:fulfilled_count, actual)
      end
    end
  end
end
```

비정규화의 속도와 정합성 안전망을 동시에 가져갈 수 있다.

## 벤치마크

프로덕션 데이터 기준 (주문상품 50만 건, 선발송 기록 120만 건):

| 쿼리 | 방법 A (JOIN) | 방법 B (컬럼) |
|------|---------------|---------------|
| 단일 주문 (10개 상품) | 12ms | 2ms |
| 리스트 (50주문, 200상품) | 85ms | 8ms |
| 엑셀 내보내기 (1만 건) | 1,200ms | 45ms |

선발송 기록 테이블이 커질수록 격차는 벌어진다. 인덱스를 잘 잡으면 방법 A도 단건 조회에서는 쓸만하지만, 리스트와 내보내기에서는 병목이 된다.

## 상황별 선택 가이드

| 상황 | 추천 |
|------|------|
| 서비스 레이어 단일, 모든 쓰기가 트랜잭션 | **카운터 컬럼** |
| 쓰기 경로 다수, 통제 어려움 | **실시간 집계** |
| Read-heavy (대시보드, 리스트) | **카운터 컬럼** |
| Write-heavy (배치 처리) | **실시간 집계** |
| 높은 데이터 정합성 요구 | **둘 다 + 재조정 잡** |
| 프로토타입 / 초기 단계 | **실시간 집계** (단순, 나중에 카운터 추가) |

## 결론

정답은 없다 — 시스템의 쓰기 경로와 읽기/쓰기 비율에 따라 다르다. 다만 잘 구조화된 서비스 레이어가 있는 대부분의 프로덕션 Rails 앱에서는, **비정규화 카운터 컬럼 + 재조정 안전망**이 실용적인 선택이다. 읽기 10ms 이하, 예측 가능한 성능, 야간 체크로 drift를 잡아낸다.

실시간 집계는 순수하고 정직한 방식이지만 — 그 순수함의 대가를 매번 읽기에서 치른다. 유저가 즉각적인 페이지 로딩을 기대하는 세상에서, 이건 의식적으로 판단해야 할 트레이드오프다.

---

*다른 접근법이 있거나, 놓친 엣지 케이스가 있다면 댓글로 알려주세요.*
