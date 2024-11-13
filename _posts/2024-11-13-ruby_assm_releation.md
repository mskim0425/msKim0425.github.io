---
layout: post
title: "Rails AASM 상태관리와 관계설정"
date: 2024-11-13 22:00:00 +0900
categories: [Rails, Ruby]
tags: [aasm, activerecord]
---

상태 관리에서 매우 중요한 부분이다. Rails에서는 AASM(Acts As State Machine)을 통해 효과적으로 상태를 관리할 수 있다.

### AASM이란?

AASM은 Ruby 클래스에 유한 상태 기계(Finite State Machine) 기능을 추가하는 라이브러리이고. 원래 acts_as_state_machine 플러그인으로 시작했지만, 현재는 ActiveRecord뿐만 아니라 다양한 ORM을 지원하는 독립적인 라이브러리로 발전했다.

### 기본 사용법

```ruby
class Order
  include AASM

  aasm do
    state :draft, initial: true
    state :confirmed
    state :shipped
    state :delivered
    
    event :confirm do
      transitions from: :draft, to: :confirmed
    end
    
    event :ship do
      transitions from: :confirmed, to: :shipped
    end
    
    event :deliver do
      transitions from: :shipped, to: :delivered
    end
  end
end
```

이 코드를 통해 다음과 같은 메서드들이 자동으로 생성된다:
- `draft?`, `confirmed?`, `shipped?`, `delivered?` - 상태 확인
- `confirm!`, `ship!`, `deliver!` - 상태 변경
- `may_confirm?`, `may_ship?`, `may_deliver?` - 상태 변경 가능 여부 확인

### AASM의 장점

- **명확한 상태 관리**: 상태와 전환 규칙을 명확하게 정의
- **유연한 확장성**: 다양한 ORM 지원
- **안전한 상태 전환**: 유효하지 않은 상태 전환 방지
- **자동 검증**: 상태 변경 전/후 검증 가능


AASM을 활용하면 복잡한 상태 관리 로직을 깔끔하게 구현할 수 있고, 코드의 가독성과 유지보수성이 크게 향샹된다.

> 💡 **Tip**: 상태 변경 시 발생할 수 있는 예외 상황을 고려하여 적절한 에러 처리를 추가하는 것이 좋다.


---
## DB 관계설정 

### belongs_to

하나의 다른 모델에 종속되는 관계를 설정할 때 쓴다. 예를 들어 '책은 저자에게 속한다'는 관계다.

```ruby
class Book < ApplicationRecord
  belongs_to :author
end

class Author < ApplicationRecord
  has_many :books
end
```

belongs_to 쓸 때는 **반드시 단수**형으로 써야 한다. 복수형 쓰면 Rails가 클래스를 못 찾는다.

### has_many

한 모델이 다른 모델의 여러 인스턴스를 가질 수 있을 때 쓴다. belongs_to의 반대 관계라고 보면 된다.

```ruby
class User < ApplicationRecord
  has_many :posts
  has_many :comments
end

class Post < ApplicationRecord
  belongs_to :user
end
```

이렇게 설정하면 `user.posts`로 해당 유저의 모든 게시글을 가져올 수 있다.

### has_one

일대일 관계를 설정할 때 쓴다. belongs_to랑 비슷한데, 외래 키가 반대쪽 테이블에 있다는 게 다르다.

```ruby
class Supplier < ApplicationRecord
  has_one :account
end

class Account < ApplicationRecord
  belongs_to :supplier
end
```

### scope

모델에서 자주 쓰는 쿼리를 메서드처럼 정의해서 쓸 수 있게 해주는 기능이다.

```ruby
class Article < ApplicationRecord
  scope :published, -> { where(status: 'published') }
  scope :recent, ->(limit) { order(created_at: :desc).limit(limit) }
end
```

이렇게 정의하면 이런 식으로 체이닝해서 쓸 수 있다:

```ruby
Article.published.recent(5)
```

> 💡 **Tip**: scope는 항상 ActiveRecord::Relation을 반환해서 메서드 체이닝이 된다. scope 내 scope를 사용가능 클래스 메서드로도 같은 걸 할 수 있는데, scope 쓰면 코드가 더 깔끔하다.

## 실전 예시
```ruby
class User < ApplicationRecord
  has_many :posts
  has_many :comments
  has_one :profile
  
  scope :active, -> { where(active: true) }
  scope :recent, -> { order(created_at: :desc) }
end

class Post < ApplicationRecord
  belongs_to :user
  has_many :comments
  
  scope :published, -> { where(published: true) }
end

class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :post
end

class Profile < ApplicationRecord
  belongs_to :user
end
```

이런 식으로 관계 설정하면 이렇게 쓸 수 있다:
```ruby
user = User.active.first
user.posts.published
user.profile
post.comments
```

관계 설정 잘 해두면 복잡한 쿼리도 직관적으로 작성할 수 있고, 코드 관리도 훨씬 편하다! 1대1 1대N으로 생각하면...

```ruby
class User < ApplicationRecord
  has_one :cart                        # 1:1 관계
  has_many :orders                     # 1:N 관계
  has_many :product_reviews            # 1:N 관계
  has_many :reviewed_products, through: :product_reviews, source: :product  # N:M 관계 JOIN관계 명시
end

class Product < ApplicationRecord
  belongs_to :category                 # N:1 관계
  has_many :order_items               # 1:N 관계
  has_many :product_reviews           # 1:N 관계
  has_many :reviewers, through: :product_reviews, source: :user  # N:M 관계 JOIN관계 명시
end
```
| 💡 Tip: N:M 관계를 설정할 때는 through 옵션을 써서 조인 테이블을 명시해야 한다. 이렇게 하면 user.reviewed_products처럼 직관적으로 접근할 수 있다.