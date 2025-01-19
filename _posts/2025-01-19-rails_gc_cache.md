---
layout: post
title: "Ruby on Rails 성능 최적화: 가비지 컬렉션"
date: 2025-01-19 19:40:00 +0900
categories: [Web Development, Performance Optimization]
tags: [ruby-on-rails, garbage-collection, memory-management, performance-tuning, rails-optimization]
---

## 정리하게된 계기
Rails App 경우 자바와 같이 object가 생성될떄 힙에 실제데이터를 올리고 있는데       
메모리를 해제를 어떻게하는지 궁금해서 찾아보게 되었다.      
Ruby의 가비지 컬렉션(GC) 메커니즘은 메모리 관리의 핵심 부분이다. GC 모듈을 통해 이 과정을 이해하고 최적화할 수 있다.     
Rails 애플리케이션에서 메모리 사용량이 높아지는 주요 원인 중 하나는 객체 보유이다. (전부 다 객체화 하기때문인듯)     

### 수명이 짧은 객체(Short-Lived Objects)
보통의 루비 객체는 짧은 생명 주기를 가진다:
```ruby
User.where(name: "kms")
```
- ORM 쿼리 실행 시 여러 객체가 생성된다 (예: `where` 메서드, `:name` 심볼, `"kms"` 문자열).
- 쿼리 실행 후 이 객체들은 더 이상 참조되지 않아 GC 대상이 된다.      

### 전역 변수와 객체 보유
```ruby
$retain_data = []
999_999.times { $retain_data << "김나박이" }
```

이 경우:
- 999,999개의 문자열 객체에 대한 포인터가 힙에 생성된다.     
- 이 객체들은 전역 변수 `$retain_data`에 의해 참조되므로 GC 대상이 되지 않는다.       

#### 참고사항
- 상수, 전역 변수, 모듈, 클래스가 참조하는 객체는 GC 대상이 되지 않는다.
- 전역적으로 접근 가능한 객체를 참조할 때는 주의가 필요하다.
- 자주 사용해야하는 상수가 있다면, `freeze` 메서드를 사용하여 메모리 사용을 최적화할 수 있다.       

### 객체 해제(Object Freeing)
전역 변수 없이 실행하면:
```ruby
def foo
  999_999.times { "김나박이" }
end
foo
```
이 경우:
- `GC.stat[:total_freed_objects]`는 약 1,000,004개로 높게 나타난다.         
- `foo` 메서드가 종료되면 객체들이 더 이상 참조되지 않아 GC 대상이 된다.     
- 메모리 사용량이 전역에 비해 휠씬 줄어듬.     

---
## Ruby on Rails 가비지 컬렉션(GC) 최적화

Ruby의 GC는 애플리케이션의 메모리 관리를 담당한다. rails c로 접근해서 아래와같이 실행하면 된다.   

### GC 상태확인 및 기능들
Ruby의 `GC.stat` 메서드는 가비지 컬렉션의 상세한 통계를 제공한다. 이 통계를 이해하면 애플리케이션의 메모리 사용 패턴과 GC 동작을 파악할 수 있다.

#### 기본 GC 통계
- **count**: 총 GC 실행 횟수
- **minor_gc_count**: 마이너 GC 실행 횟
- **major_gc_count**: 메이저 GC 실행 횟수

이 통계는 GC가 얼마나 자주 실행되었는지를 보여준다. 마이너 GC가 메이저 GC보다 더 자주 실행되는 것이 일반적이다.      

### 힙 관련 정보
- **heap_allocated_pages**: 할당된 힙 페이지 수    
- **heap_sorted_length**: 정렬된 힙의 길이     
- **heap_allocatable_pages**: 추가 GC 없이 할당 가능한 페이지 수     
- **heap_available_slots**: 총 사용 가능한 슬롯 수     
- **heap_live_slots**: 현재 사용 중인 슬롯 수      
- **heap_free_slots**: 사용 가능한 빈 슬롯 수        

이 정보는 Ruby의 메모리 할당 상태를 보여준다. 특히 `heap_free_slots`가 낮으면 GC가 곧 실행될 가능성이 높다.        
**heap_available_slots와 heap_live_slots** 의 이 두 값의 차이가 작아지면 마이너 GC가 실행될 가능성이 높다.     
메이저 GC는 이 차이가 지속적으로 작을 때 실행된다      


### 객체 관련 통계
- **total_allocated_objects**: 총 할당된 객체 수        
- **total_freed_objects**: 총 해제된 객체 수           
- **old_objects**: 오래된 세대의 객체 수      
- **old_objects_limit**: 오래된 세대 객체 수 제한       

이 통계는 객체의 생성과 소멸 패턴을 보여준다. `old_objects`가 `old_objects_limit`에 가까워지면 메이저 GC가 실행될 가능성이 높아진다.     
마이너 GC는 주로 새로 생성된 객체(young 객체)를 대상으로 한다.              

### 메모리 관련 정보
- **malloc_increase_bytes**: 마지막 GC 이후 증가한 메모리 양             
- **malloc_increase_bytes_limit**: 다음 GC 트리거 전 허용되는 메모리 증가량              

이 정보는 메모리 사용량의 증가를 추적한다. `malloc_increase_bytes`가 `malloc_increase_bytes_limit`에 가까워지면 GC가 트리거될 가능성이 높다.         
 `malloc_increase_bytes`가 급격히 증가하면 마이너 GC가 먼저 실행되고 헤당 값이 지속적으로 높게 유지되면 메이저 GC가 실행될 수 있다.

Ruby의 GC는 이러한 지표들을 복합적으로 고려하여 마이너 GC와 메이저 GC를 실행한다.         
마이너 GC는 더 자주, 더 빠르게 실행되며, 메이저 GC는 전체 힙을 대상으로 하므로 더 오래 걸리지만 덜 실행된다.       

### GC 환경변수 튜닝

GC의 동작을 최적화하기 위해 다양한 환경 변수를...      
셀에서 직접, ruby 스크립트 내에서, config/application.rb에서 설정할 수 있다.     

```ruby
# config 파일
config.before_initialize do
  GC.configure do |config|
    config.heap_init_slots = 1000000
  end
end
# 스크립트 스타일...
# 초기 힙 슰롯수 설정 값이 커질수록 초기 메모리 할당은 올라간다. but gc빈도 줄어듬
# 메모리가 충분한 환경에서 대규모 객체생성이 필요할때 증가시키면 좋을듯
ENV['RUBY_GC_HEAP_INIT_SLOTS'] = '1000000' 

# GC실행후 유지할 최소 빈 슬롯 수를 설정
# 값이 늘수록 GC 실행빈도는 줄어들지만, 메모리 사용량이 올라감
# 잦은 객체할당과 해제가 빈번한 app에서 GC 오버헤드를 줄이기 위해 사용하면 좋을듯
ENV['RUBY_GC_HEAP_FREE_SLOTS'] = '10000'

# 힙 크기 증가비율을 설정
# 값을 높이면 힙 크기가 증가해서 GC 실행빈도가 줄어들미잔 메모리 사용량 증가
# GC 빈도를 줄이고 넉넉한 메모리 사용증가를 감당하는 환경에서 사용
ENV['RUBY_GC_HEAP_GROWTH_FACTOR'] = '1.1'     

#RUBY_GC_HEAP_GROWTH_MAX_SLOTS
#RUBY_GC_MALLOC_LIMIT
#RUBY_GC_OLDMALLOC_LIMIT
#RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR
```


### GC 수동제어

특정 작업 동안 GC를 일시적으로 비활성화하여 성능을 향상시킬 수 있다.   

```ruby
GC.disable
# 메모리 집약적인 작업 수행
GC.enable
GC.start # 수동으로 GC 실행
```

[https://ruby-doc.org/core-2.7.4/GC/Profiler.html](https://ruby-doc.org/core-2.7.4/GC/Profiler.html)