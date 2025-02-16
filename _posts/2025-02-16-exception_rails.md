---
layout: post
title: "Ruby on Rails Exception 그리고 트랜잭션"
date: 2025-02-16 11:40:00 +0900
categories: [Web Development, Performance Optimization]
tags: [ruby-on-rails, exception, transaction]
---

# 예외처리
프로그램 실행중에 발생할 수 있는 예외를 처리하고 무엇보다 중단되지않도록 사용하는 기법이다.    
루비에서의 예외처리 기본구조는 아래와같다.    
```ruby
begin
  # 예외가 발생할 수 있는 코드
rescue Exception => e
  # 예외가 발생했을 때 처리할 코드
else
  # 예외가 발생하지 않았을 때 실행할 코드
ensure
  # 항상 실행되는 코드
end

# 커스텀 기본적인 예외처리 구조
def controller
 # 작동
 raise '에러메시지' if problem? # 비즈니스 로직상 예외처리
rescue Exception -> e
 #작동중 에러가 터지면 여기로 작동되게 함
end
```
### rescue_from 
`rescue_from`는 Ruby on Rails에서 Controller 수준에서 예외를 처리하는 데 사용되는 메서드이다.    
이 메서드는 특정 예외가 발생했을 때, 지정된 메서드나 블록을 호출하여 예외를 처리할 수 있도록 함.

```ruby
class ApplicationController < ActionController::Base
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found

  private

  def record_not_found(exception)
    render json: { error: exception.message }, status: :not_found
  end
end
```

이 코드는 `ActiveRecord::RecordNotFound` 예외가 발생하면 `record_not_found` 메서드를 호출하여 JSON 응답을 반환하는 구조이다.    

- **상속**: `rescue_from`는 Controller 계층에서 상속된다. 즉, ApplicationController에서 정의한 예외 처리는 모든 Controller에서 자동으로 적용됨.   
- **우선순위**: 예외 처리는 정의된 순서에 따라 우선순위가 결정되고 가장 구체적인 예외 처리가 먼저 호출된다.  
- **예외 전파**: 예외 처리 메서드 내에서 또 다른 예외가 발생하면, 그 예외는 외부로 전파되지 않는다.    

>`rescue_from`는 `ActionController::BadRequest` 예외를 처리할 수 없다.
{: .prompt-tip}    


#### **조건부 예외 처리**

조건부로 예외를 처리하고 싶다면, 메서드 내에서 조건문을 사용할 수 있다. 하지만 `rescue_from` 자체에서 조건을 지정하는 것은 불가능하다.    

```ruby
def record_not_found(exception)
  if request.local?
    # 로컬 환경에서의 처리
  else
    # 다른 환경에서의 처리
  end
end
```

#### **rescue_from 서비스단에서 사용가능**

`rescue_from`는 기본적으로 Controller에서만 사용할 수 있다. 하지만 `ActiveSupport::Rescuable` 모듈을 포함하여 다른 객체에서도 유사한 기능을 구현할 수 있다.   

```ruby
class MyService
  include ActiveSupport::Rescuable

  rescue_from MyCustomError do |exception|
    # 예외 처리 코드
  end

  def perform
    # 코드
  end
end
```

이렇게 하면 서비스 객체에서도 `rescue_from`와 같은 예외 처리 DSL을 사용할 수 있다. (굳이....)    


# 트랜젝션

트랜잭션은 여러 데이터베이스 작업을 하나의 논리적 단위로 묶어, 작업이 모두 성공하거나 모두 실패하는 것을 보장한다.    
Rails에서는 기본적으로 ActiveRecord::Base.transaction을 사용하여 트랜잭션을 구현할 수 있다.    
```ruby
ActiveRecord::Base.transaction do
  # 여러 데이터베이스 작업
end
```
### requires_new
새로운 독립적인 트랜잭션 생성을 하는 기능이다.  
해당기능의 사용 예시를 들어보자, 사용자가 결제를 진행할 때, 결제 정보는 별도의 시스템에 저장되어야한다.
이때, 결제 정보 저장이 실패하더라도 메인 주문 정보는 저장되게하려고할때의 예시의 코드.
```ruby
class OrderController < ApplicationController
  def create
    Order.transaction do
      # 주 주문 정보 저장
      order = Order.create!(user_id: current_user.id, total: 100)
      
      # 결제 정보 저장 (독립적인 트랜잭션)
      Payment.transaction(requires_new: true) do
        Payment.create!(order_id: order.id, amount: 100)
        # 결제 시스템과 통신하는 코드
        # 여기서 예외가 발생하면 결제 정보만 롤백
        raise ActiveRecord::Rollback if payment_failed?
      end
    end
  end

  private

  def payment_failed?
    # 결제 실패 여부를 판단하는 코드
  end
end

```

### joinable
루비 온 레일즈에서 joinable 옵션은 트랜잭션의 중첩 방식을 제어하는 데 사용된다.    
joinable 옵션은 기본적으로 true로 설정되어 있으며, 내부 트랜잭션이 외부 트랜잭션에 참여할 수 있다.     
반면에 joinable: false를 설정하면 내부 트랜잭션이 외부 트랜잭션과 독립적으로 동작한다.   

```ruby
User.transaction do
  User.create(username: 'Minsub')
  
  # 내부 트랜잭션이 외부 트랜잭션에 참여하지 않도록 설정
  User.transaction(joinable: false) do
    User.create(username: 'Sothoughtful')
    raise ActiveRecord::Rollback
  end
end
```

### 트랜잭션 전파
루비 온 레일즈에서는 자바의 스프링처럼 명시적인 트랜잭션 전파 옵션이 제공되지 않는다고 한다.    
but `requires_new` 옵션을 사용하여 독립적인 트랜잭션을 생성할 수 있고, 자바의 `REQUIRES_NEW` 전파와 유사한 효과를 낼 수있다.    

| **개념** | **루비 온 레일즈** | **자바 스프링** |
| --- | --- | --- |
| **새로운 트랜잭션 생성** | `requires_new: true` | `Propagation.REQUIRES_NEW` |
| **기존 트랜잭션 참여** | `joinable: true` (기본값) | `Propagation.REQUIRED` |


| **옵션** |**트랜잭션 동작** | **내부 트랜잭션에서 예외 발생 시** |
| --- | --- | --- |
| **`requires_new: true`** | **새로운 독립적인 트랜잭션 생성** |외부 트랜잭션에 영향을 미치지 않음 |
| **`joinable: true`** | **기존 트랜잭션에 참여** |외부 트랜잭션도 롤백됨 |
| **`joinable: false`** |**기존 트랜잭션에 참여하지 않음** (독립적인 트랜잭션 생성) |외부 트랜잭션에 영향을 미치지 않음 |


```ruby
# requires_new 사용
User.transaction do
  User.create(username: 'Minsub')
  
  User.transaction(requires_new: true) do
    User.create(username: 'Sothoughtful')
    raise ActiveRecord::Rollback # 외부 트랜잭션에 영향을 미치지 않음
  end
end

# joinable: true (기본값)
User.transaction do
  User.create(username: 'Minsub')
  
  User.transaction do
    User.create(username: 'Sothoughtful')
    raise ActiveRecord::Rollback # 외부 트랜잭션도 롤백됨
  end
end

# joinable: false
User.transaction do
  User.create(username: 'Minsub')
  
  User.transaction(joinable: false) do
    User.create(username: 'Sothoughtful')
    raise ActiveRecord::Rollback # 외부 트랜잭션에 영향을 미치지 않음
  end
end
```

> **`requires_new`**: 내부 트랜잭션이 외부 트랜잭션과 독립적으로 동작해야 할 때 사용  
> **`joinable: false`**: 내부 트랜잭션이 외부 트랜잭션에 영향을 미치지 않도록 할 때 사용  
>  **requires_new** 와 **joinable: false** 가 비슷해 보이지만, requires_new: true는 명시적으로 새로운 독립적인 트랜잭션을 생성하도록 설계된 반면, joinable: false는 기존 트랜잭션에 참여하지 않도록 설정하는 것이다.
{: .prompt-tip}