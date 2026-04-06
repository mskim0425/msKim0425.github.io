---
title: "Real-time SQL Aggregation vs Denormalized Counter Column — When to Use Which"
date: 2026-04-06 20:00:00 +0900
categories: [Database, Backend]
tags: [sql, database-design, denormalization, query-optimization, rails, mysql, counter-column, aggregation, performance, backend-architecture]
description: "Should you compute values on the fly with JOIN subqueries, or maintain a pre-computed counter column? A practical comparison with real-world Rails + MySQL examples."
image:
  path: /assets/img/sql-aggregation-vs-denormalized.png
  alt: Real-time SQL aggregation vs denormalized counter column comparison
---

## The Problem

You're building an order management system. Each order has multiple items, and each item can be partially fulfilled through a pre-shipment process. You need to calculate the **available quantity** for each item — that is, the total purchased minus the already-accepted pre-shipments.

Two approaches exist:

**Approach A — Real-time Aggregation**: JOIN against the fulfillment records table every time you query, summing up accepted counts on the fly.

**Approach B — Denormalized Counter Column**: Maintain a `fulfilled_count` column on the order item row, incrementing/decrementing it transactionally whenever a fulfillment is created or canceled.

I recently compared both approaches in a production Rails + MySQL system, and the answer isn't always obvious.

## Approach A: Real-time JOIN Subquery

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

Every query hits the `fulfillment_goods` table, groups by item, and joins the result. The number is always fresh.

### Pros
- **Always accurate** — no sync issues, no stale data
- **Single source of truth** — the fulfillment records table *is* the truth
- **No write-side complexity** — you don't need to remember to update a counter

### Cons
- **Query cost grows with data** — the subquery scans all fulfillment records for the items in scope
- **Slower reads** — adding a LEFT JOIN with GROUP BY on every list query adds latency
- **Index pressure** — needs a composite index on `(item_id, deleted_at, status)` to perform

## Approach B: Denormalized Counter Column

```sql
SELECT
  items.id,
  items.purchased_count,
  CAST(items.purchased_count AS SIGNED)
    - COALESCE(items.fulfilled_count, 0) AS available_count
FROM order_items items
WHERE items.order_id = 12345;
```

Dead simple. The `fulfilled_count` column is maintained by application code.

In Rails, this looks something like:

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

### Pros
- **Blazing fast reads** — no joins, no subqueries, just a column on the row you're already reading
- **Predictable performance** — query cost doesn't grow with fulfillment history
- **Simple queries** — easier to compose with other scopes and filters

### Cons
- **Every write path must update the counter** — miss one, and the number is wrong
- **Harder to debug** — if `fulfilled_count` is wrong, you need to reconcile against the source records
- **Migration risk** — adding a new fulfillment pathway (bulk import, admin override, API) means remembering to update the counter

## The Decision Framework

Ask yourself two questions:

**1. Are all write paths covered by transactional counter updates?**

If your system has a single, well-defined service layer that handles all fulfillment creation and cancellation, and all paths go through it inside a transaction — the counter column will stay accurate. In this case, **Approach B wins** on performance with no accuracy trade-off.

But if fulfillments can be created from multiple entry points (web UI, API, background jobs, admin panel, data migrations), the risk of a missed update grows. Consider Approach A, or at minimum, add a periodic reconciliation job.

**2. How often do you read vs write?**

If you query available counts on every page load (list views, dashboards, exports) but fulfillments only happen a few times per order, the read-heavy pattern strongly favors the counter column. You're paying a tiny cost on each write to save a big cost on every read.

If writes are frequent and reads are rare (batch processing, background analytics), the overhead of maintaining a counter on every write may not be justified.

## Hybrid: Counter + Reconciliation

In practice, the most robust systems use both:

```ruby
# Primary: counter column for fast reads
scope :available, -> {
  where('purchased_count - COALESCE(fulfilled_count, 0) > 0')
}

# Nightly reconciliation job
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

This gives you the speed of denormalization with a safety net for drift.

## Benchmarks

On a production dataset (500K order items, 1.2M fulfillment records):

| Query | Approach A (JOIN) | Approach B (Column) |
|-------|-------------------|---------------------|
| Single order (10 items) | 12ms | 2ms |
| List view (50 orders, 200 items) | 85ms | 8ms |
| Export (10K items) | 1,200ms | 45ms |

The gap widens as the fulfillment records table grows. With proper indexing, Approach A is acceptable for single-order views, but it becomes a bottleneck on list pages and exports.

## When to Pick Which

| Situation | Recommendation |
|-----------|---------------|
| Single service layer, all writes transactional | **Counter column** |
| Multiple write paths, hard to control | **Real-time aggregation** |
| Read-heavy (dashboards, list views) | **Counter column** |
| Write-heavy (batch processing) | **Real-time aggregation** |
| High data integrity requirements | **Both + reconciliation** |
| Prototype / early stage | **Real-time aggregation** (simpler, add counter later) |

## Conclusion

There's no universally correct answer — it depends on your system's write paths and read/write ratio. But in most production Rails applications with a well-structured service layer, the **denormalized counter column with a reconciliation safety net** is the practical choice. You get sub-10ms reads, predictable performance, and a nightly check that catches any drift before it becomes a problem.

The real-time aggregation approach is honest and pure — but that purity costs you on every single read. In a world where users expect instant page loads, that's a trade-off worth making consciously.

---

*Have a different approach? Found edge cases I missed? I'd love to hear about it — drop a comment or reach out on [GitHub](https://github.com/msKim0425).*
