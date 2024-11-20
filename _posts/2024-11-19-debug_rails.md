---
layout: post


title: "Rails 디버깅"


date: 2024-11-19 22:00:00 +0900


categories: [Rails, Debug]


tags: [rails, debug]
---


**View 헬퍼**
- `debug`: YAML 형식으로 객체를 출력
- `to_yaml`: YAML 변환
- `inspect`: 배열이나 해시 값을 문자열로 출력

```ruby
# 컨트롤러
@user = User.find(1)

# 뷰에서
<%= debug @user %>

# --- !ruby/object:User
# id: 1
# name: "John"
# email: "john@example.com"

@items = ['apple', 'banana', 'orange']
<%= @items.to_yaml %>

# ---
# - apple
# - banana
# - orange

@settings = { theme: 'dark', language: 'ko }
<%= @settings.inspect %> # 뒤에 안쳐도 동일하게 나오는것으로 보아 default인듯

# {:theme=>"dark", :language=>"ko"}
```

### Logger 활용
```ruby
logger.debug "데이터 확인: #{@data.inspect}"
logger.info "요청 처리 중..."
logger.error "심각한 오류 발생!"
```

로그 레벨: debug < info < warn < error < fatal

### byebug 사용법

1. 설치
```bash
gem install byebug
```

2. rails c, byebug에 따른 장점

```ruby
  # byebug rails c 했을때 쓸만한것들 모음
  >Order.where(Id: 222441).to_sql 
  >"SELECT `Order`.* FROM `Order` WHERE `Order`.Id` = 222441" 
```

3. 주요 명령어
- `next` (n): 다음 줄로 이동
- `step` (s): 메소드 내부로 진입
- `continue` (c): 실행 계속
- `break`: 중단점 설정

### 실용적인 디버깅 팁

**중단점 관리**
```ruby
break 20  # 20번 줄에 중단점 설정
info breakpoints  # 중단점 목록 확인
delete 1  # 1번 중단점 삭제
```

**변수 검사**
```ruby
var local  # 지역 변수 확인
var instance  # 인스턴스 변수 확인
p @user  # 변수 값 출력
```

### web-console 활용

view나 controller에서 바로 콘솔 사용 가능하다고 한다.
```ruby
<% console %>
```

### 성능 최적화 팁
로그 작성 시 블록 사용이 성능상 유리히다고 한다.
```ruby
# 좋은예
logger.debug { "데이터: #{expensive_operation}" }

# 좋지않은 예
logger.debug "데이터: #{expensive_operation}"
```


[rails 공식 문서](https://guides.rubyonrails.org/v6.0/debugging_rails_applications.html)