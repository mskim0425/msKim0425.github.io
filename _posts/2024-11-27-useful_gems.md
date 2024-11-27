---
layout: post


title: "Ruby GEM 시리즈"


date: 2024-11-27 22:00:00 +0900


categories: [Rails, Gems]


tags: [rails, gems]
---

## ZipLine gem

Zipline은 Rails 애플리케이션에서 동적으로 생성된 ZIP 파일을 스트리밍하기 위한 Ruby gem이다.

- 스트리밍 방식으로 ZIP 파일 생성을 위해 전체 파일이 완성될 때까지 기다리지 않는다. 따라서 대용량 ZIP 파일 생성에도 큰 디스크 공간이나 메모리가 필요하지 않아 대기 시간과 다운로드 시간이 감소한다.
- ZIP 생성 중 이전으로 되돌아가지 않고 HTTP를 통해 스트리밍한다.
- "directory/file" 형식으로 파일 이름을 지정하여 디렉토리 구조 생성이 가능하다고함.

```ruby
class MyController < ApplicationController
  include Zipline
  
  def index
    users = User.all
    files = users.map{ |user| [user.face, "#{user.username}.png"] }
    zipline(files, 'user_face.zip')
  end
end
```

## Kaminari gem

페이지네이션을 위한 Ruby gem이다. 풀스택용인듯

```ruby
class User < ApplicationRecord
  # 기본 페이지네이션
  User.page(params[:page]).per(25)
  
  # 스코프와 함께 사용
  User.where(age: 20..30).page(params[:page])
end
```

**뷰**
```erb
<%= paginate @users %>
<% @users.each do |user| %>
  <%= user.name %>
<% end %>

<!-- 부트스트랩 스타일 적용 -->
<%= paginate @users, theme: 'bootstrap4' %>
```

## Puma gem
Ruby/Rack 애플리케이션을 위한 고성능 웹 서버 gem이다. 설정용 GEM

- 멀티스레드 지원: 각 요청을 별도 스레드에서 처리
- 멀티프로세스: 클러스터 모드에서 메모리 효율적인 fork 지원
- 독립 실행형: SSL 지원, 무중단 재시작 가능

```ruby
# config/puma.rb
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

# 클러스터 모드 설정
workers ENV.fetch("WEB_CONCURRENCY") { 2 }

# 사전 로딩 설정
preload_app!

# 포트 설정
port ENV.fetch("PORT") { 3000 }

# 환경 설정
environment ENV.fetch("RAILS_ENV") { "development" }
```

## Jbuilder gem
Json을 편하게 처리하기 위한 gem

```ruby
json.post do
  json.title @post.title
  json.content @post.content
  
  # 조건을 넣을수 있다.
  json.author @post.author if @post.author.present?
  
  # 중첩을 넣어서
  json.comments @post.comments do |comment|
    json.content comment.content
    json.user do
      json.name comment.user.name
      json.avatar_url comment.user.avatar_url
    end
  end
end
```
```json
// 결과값
{
  "post": {
    "title": "첫 번째 게시글",
    "content": "안녕하세요",
    "author": "김철수",
    "comments": [
      {
        "content": "좋은 글이네요",
        "user": {
          "name": "박영희",
          "avatar_url": "https://example.com/avatar.jpg"
        }
      },
      {
        "content": "감사합니다",
        "user": {
          "name": "이민수",
          "avatar_url": "https://example.com/avatar2.jpg"
        }
      }
    ]
  }
}
```
---
```ruby
json.extract! user, :id, :name, :email
```
```json
// 결과값
{
  "id": 1,
  "name": "김철수",
  "email": "kim@example.com"
}
```
---

```ruby
# 복잡한 것은 따로 설정가능 코드의 복잡도를 해소
json.array! @users, partial: 'users/user', as: :user
```
```json
// 결과값
[
  {
    "id": 1,
    "name": "김철수",
    "email": "kim@example.com"
  },
  {
    "id": 2,
    "name": "박영희",
    "email": "park@example.com"
  }
]
```
