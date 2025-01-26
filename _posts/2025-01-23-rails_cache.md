---
layout: post
title: "Ruby on Rails 성능 최적화: 레일즈 캐싱"
date: 2025-01-25 19:40:00 +0900
categories: [Web Development, Performance Optimization]
tags: [ruby-on-rails, cache, memory-management, performance-tuning, rails-optimization]
---

Rails에서 제공하는 **캐싱(Caching)**은 웹 애플리케이션의 성능을 향상시키기 위해 자주 사용되는 데이터나 결과를 저장하여 불필요한 데이터베이스 호출이나 복잡한 연산을 줄이는 기술이다. Rails는 다양한 캐싱 메커니즘을 제공하며, 각각의 용도와 특징이 있다.    

## **1. Page Caching**
**페이지 캐싱**은 컨트롤러 액션의 전체 HTML 출력을 정적 HTML 파일로 저장하여 처리 속도를 높이는 방식이다. 이 방식은 인증이 필요 없는 정적 페이지에 적합하다. 동적 컨텐츠에는 부적합해보인다.

### ex
```ruby
class ProductsController < ActionController::Base
  caches_page :index

  def index
    @products = Product.all
  end
end
```
- `/products` 요청 시 Rails는 `public/products.html` 파일을 생성하고, 이후 요청은 이 정적 파일을 반환한다.
- Rails 4 이후에는 `actionpack-page_caching` gem을 설치해야 사용 가능하다.

---

## **2. Action Caching**
**액션 캐싱**은 페이지 캐싱과 유사하지만, 인증이나 필터와 같은 로직을 포함할 수 있다.

### ex
```ruby
class ProductsController < ActionController::Base
  caches_action :show

  def show
    @product = Product.find(params[:id])
  end
end
```
- `/products/:id` 요청 시 해당 액션의 결과가 캐싱된다.
- 이 방식도 Rails 4 이후에는 `actionpack-action_caching` gem이 필요하다.

---

## **3. Fragment Caching**
**프래그먼트 캐싱**은 페이지 일부(뷰 템플릿의 특정 부분)를 캐싱하는 방식으로, 동적 컨텐츠를 포함한 페이지에서 유용하다.

### ex: 제품 목록 캐싱
```erb
<% cache 'recent_products' do %>
  <ul>
    <% @products.each do |product| %>
      <li><%= product.name %></li>
    <% end %>
  </ul>
<% end %>
```
- `recent_products`라는 키로 HTML 조각이 캐시되며, 동일한 키를 가진 요청 시 캐시된 데이터를 반환한다.

### ex: 컬렉션 렌더링 캐싱
```erb
<%= render partial: 'products/product', collection: @products, cached: true %>
```
- `@products` 컬렉션의 각 항목에 대해 개별적으로 캐싱된다.

---

## **4. Russian Doll Caching**
**러시안 돌 캐싱**은 중첩된 프래그먼트 캐싱으로, 부모와 자식 요소가 서로 독립적으로 갱신될 수 있도록 한다. (이름 잘지은듯ㅋㅋ)

### ex: 댓글이 포함된 게시물 캐싱
```erb
<% cache @post do %>
  <h1><%= @post.title %></h1>
  <% cache [@post, @post.comments] do %> # 제목을 호출하고 댓글을 호출
    <ul>
      <% @post.comments.each do |comment| %>
        <li><%= comment.body %></li> # 제목하나당 각 댓글을 순회하며 내용을 표시한다.
      <% end %>
    </ul>
  <% end %>
<% end %>


```
- 게시물과 댓글 각각을 별도로 캐싱하여 효율적으로 관리한다.

---

## **5. Low-Level Caching**
**저수준 캐싱**은 특정 데이터나 연산 결과를 직접 저장하고 읽는 방식으로, 가장 세밀하게 제어할 수 있다.

### ex: `Rails.cache.fetch`
```ruby
class Product < ApplicationRecord
  def competing_price
    Rails.cache.fetch("#{cache_key_with_version}/competing_price", expires_in: 12.hours) do
      Competitor::API.find_price(id)
    end
  end
end

# 사용 예시:
price = Rails.cache.fetch('product_price') { calculate_price }
```
- `fetch`는 키(`cache_key_with_version/competing_price`)로 값을 검색하고, 없으면 블록을 실행해 값을 저장한다.
- 만료 시간(`expires_in`)을 설정해 자동으로 갱신할 수 있다.

### 저수준 API 사용 ex
```ruby
# 값 쓰기
Rails.cache.write('key', 'value', expires_in: 5.minutes)

# 값 읽기
Rails.cache.read('key')

# 값 삭제
Rails.cache.delete('key')
```

---

## **6. Cache Store 설정**
Rails는 다양한 **캐시 스토어**를 지원하며, 필요에 따라 선택할 수 있다.
- 기본적으로 `file_store`, `memory_store`, `mem_cache_store`, `redis_cache_store` 등을 사용 가능하다.
- 설정 ex (`config/environments/production.rb`):
```ruby
config.cache_store = :redis_cache_store, { url: ENV['REDIS_URL'] }
```

### Memory Store (:memory_store)

- 가장 빠른 캐시 스토어로, Ruby 웹 서버의 프로세스 메모리에 데이터를 저장한다.
- 기본적으로 32MB의 메모리를 사용하며, 설정을 통해 크기를 조절할 수 있다.
- 개발 환경에서 주로 사용되며, Rails 5 이후 새로운 애플리케이션 생성 시 개발 환경의 기본 캐시 스토어로 설정된다.
- 서버 재시작 시 캐시가 자동으로 초기화되어 개발 중 편리하다.
- 여러 서버 프로세스를 사용하는 환경에서는 적합하지 않다.

### File Store (:file_store)

- 캐시 데이터를 파일 시스템에 저장한다.
- 디스크 용량이 허용하는 한 많은 데이터를 저장할 수 있지만, 다른 스토어에 비해 속도가 느리다.
- 하나 또는 두 개의 호스트에서 서비스되는 중소 규모 사이트에 적합하다.
- 주기적으로 오래된 캐시 항목을 정리해야 한다.

### Memcached Store (:mem_cache_store)

- Dalli gem과 Memcached를 사용하여 중앙 집중식 인메모리 캐시를 제공한다.
- 기본적으로 64MB의 캐시 크기를 사용하며, 설정을 통해 조정 가능하다.
- 여러 서버 프로세스나 호스트 간에 캐시를 공유할 수 있어 대규모 프로덕션 환경에 적합하다.
- Memcached 서버가 재시작되면 모든 캐시가 초기화된다.

### Redis Cache Store (:redis_cache_store)

- Redis를 사용하여 캐시 데이터를 저장한다.
- Rails 5.2에서 도입되었으며, Memcached와 유사한 기능을 제공한다.
- 분산 캐싱에 적합하며, 여러 애플리케이션 서버 인스턴스가 공통 캐시를 공유할 수 있다.
- 자동 만료 정책을 설정할 수 있어 메모리 관리가 용이하다.
- Redis의 영속성 기능으로 인해 서버 재시작 후에도 캐시 데이터가 유지될 수 있다.

개발 환경에서는 Memory Store나 File Store를, 프로덕션 환경에서는 Memcached Store나 Redis Cache Store를 사용하는 것이 좋다.

---
#### Redis Cache Store와 Memcached Store 비교

| 특징 | Redis Cache Store | Memcached Store |
|---|---|---|
| 데이터 구조 | 다양한 데이터 구조 지원 (문자열, 리스트, 해시, 셋 등) | 단순 키-값 저장만 지원 |
| 영속성 | 디스크에 데이터 저장 가능 (RDB, AOF) | 메모리에만 저장, 영속성 없음 |
| 복제 | 마스터-슬레이브 복제 지원 | 복제 기능 없음 |
| 트랜잭션 | 트랜잭션 지원 | 트랜잭션 지원 안 함 |
| 메모리 효율성 | Memcached에 비해 상대적으로 낮음 | 매우 높음 |
| 속도 | 매우 빠름 | 매우 빠름 (일부 작업에서 Redis보다 빠를 수 있음) |
| 확장성 | 클러스터링 지원 | 샤딩은 가능하지만 클러스터링은 제한적 |
| 키 크기 제한 | 512MB | 250 바이트 |
| 값 크기 제한 | 512MB | 1MB |
| 용도 | 캐싱, 세션 저장, 실시간 분석 등 다양한 용도 | 주로 단순 캐싱에 사용 |
| Rails 통합 | Rails 5.2 이후 기본 지원 | 오래전부터 지원됨 |
| 설정 복잡도 | 약간 복잡함 | 비교적 간단함 |
| 모니터링 도구 | 다양한 모니터링 도구 제공 | 제한적인 모니터링 도구 |

Redis는 더 다양한 기능과 데이터 구조를 제공하지만, Memcached는 단순하고 효율적인 캐싱에 특화되어 있다.        
 
> 샤딩은 대규모 데이터셋을 여러개 작은 샤드로 나누는 서버분산 기술     
> 클러스터링은 여러서버를 하나의 시스템처럼 작동하는 기술   
{: .prompt-tip}