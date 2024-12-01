---
layout: post


title: "Ruby GEM 시리즈"


date: 2024-11-27 22:00:00 +0900


categories: [Rails, Gems]


tags: [rails, gems]
---

## ZipLine

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

## Kaminari

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

## Puma
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

## Jbuilder
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
## Pundit
권한 부여 시스템을 제공하는 gem, 간단하게 정책 기반 인증을 구현가능 
~~~ruby
class PostPolicy
  attr_reader :user, :post

  def initialize(user, post)
    @user = user
    @post = post
  end

  def update?
    user.admin? || post.user_id == user.id
  end

  def destroy?
    user.admin? || post.user_id == user.id
  end
end

class PostsController < ApplicationController
  def update
    @post = Post.find(params[:id])
    authorize @post # 정책이 정의된 클래스를 자동으로 찾음
    if @post.update(post_params)
      redirect_to @post
    end
  end
end
# app/policy 디렉토리에 정의함
class Policy
  attr_reader :user, :post
  
  def initialize(user, post)
    @user = user  # current_user가 자동으로 전달됨
    @post = post  # authorize에 전달된 객체
  end

  def update?
    user.admin? || post.user_id == user.id  # 관리자이거나 작성자인 경우만 true
  end
end
~~~

## Draper
[데코레이터 패턴](https://sothoughtful.dev/posts/decorator/)을 사용하도록 모델에서 자주 사용되는 함수들을 하나의 파일로 만들어 사용함.

~~~ruby
# app/decorators/user_decorator.rb
class UserDecorator < Draper::Decorator
  delegate_all

  def full_name
    "#{object.first_name} #{object.last_name}"
  end

  def member_since
    object.created_at.strftime("%B %Y")
  end

  def status_label
    if object.active?
      h.content_tag(:span, "활성", class: "badge badge-success")
    else
      h.content_tag(:span, "비활성", class: "badge badge-danger")
    end
  end
end

class UsersController < ApplicationController
  def show
    @user = User.find(params[:id]).decorate
  end
end
~~~

## Paper Trail
모델의 변경 이력을 추적하고 관리할 수 있게 해주는 gem
~~~ruby
class Post < ApplicationRecord
  has_paper_trail
  
  # 특정 필드만 추적
  has_paper_trail only: [:title, :content]
  
  # 메타데이터 추가
  has_paper_trail meta: {
    editor_id: :editor_id,
    category: :category_name
  }
end
~~~
## Sidekiq
백그라운드 작업 처리를 위한 gem입니다.

**설정 예시**
```ruby
# app/workers/email_worker.rb
class EmailWorker
  include Sidekiq::Worker
  
  def perform(user_id)
    user = User.find(user_id)
    UserMailer.welcome_email(user).deliver_now # 대충 user한테 알림을 보낸 메서드
  end
end

# 기본으로 제공하는 메서드
EmailWorker.perform_async(user.id)  # 비동기 실행
EmailWorker.perform_in(2.hours, user.id)  # 2시간 후 실행
EmailWorker.perform_at(2.days.from_now, user.id)  # 특정 시간에 실행
```

**장점 단점**
- Redis를 사용하여 빠른 처리 속도 하지만 그만큼 비용이 많이 들고 레디스 메모리도 증가함
- 실시간 모니터링 대시보드 제공
- 실패한 작업 재시도 기능
- 다중 큐 지원

## Carrierwave
간단한 코드 작성으로 파일 업로드를 위한 gem. 로컬이나 AWS s3 버킷에 저장가능

**설정 예시**
```ruby
# app/uploaders/image_uploader.rb
class ImageUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick  # 이미지 처리

  storage :file  # 로컬 저장
  storage :fog  # AWS S3 등 클라우드 저장

  # 썸네일 생성
  version :thumb do
    process resize_to_fit: [100, 100]
  end

  # 허용하는 파일 형식
  def extension_allowlist
    %w(jpg jpeg gif png)
  end
end

# 모델에서 사용
class User < ApplicationRecord
  mount_uploader :avatar, ImageUploader
end
```

**사용 예시**
```ruby
# 컨트롤러
def create
  @user = User.new(user_params)
  @user.avatar = params[:file]  # 파일 업로드
  @user.save
end

# 뷰
<%= image_tag @user.avatar.url %>  # 원본 이미지
<%= image_tag @user.avatar.thumb.url %>  # 썸네일, S3로 부터 받음
```

## Figaro
환경 변수 관리를 위한 gem. application.yml에 들어가는 민감정보를 방지함.

**설정 예시**
```yaml
# config/application.yml
development:
  AWS_KEY: "dev_key_123"
  API_SECRET: "dev_secret_456"

production:
  AWS_KEY: "prod_key_789"
  API_SECRET: "prod_secret_012"
```

**사용 예시**
```ruby
# 어플리케이션 코드에서 접근
ENV["AWS_KEY"]
Figaro.env.aws_key

# 필수 키 지정
Figaro.require_keys("aws_key", "api_secret")
```
Figaro를 설치하게되면 config/application.yml 파일 생성되고
.gitignore 파일에 /config/application.yml 자동 추가된다. 그래서 직접적인 파일공유를 해야하므로 별도의 환경변수 설정이 필요함. Heroku를 안쓰면 Rails credentials이 난듯?

---
## RSpec-Rails
Rails 애플리케이션을 위한 테스팅 프레임워크

**테스트 예시**
```ruby
# spec/models/user_spec.rb
RSpec.describe User, type: :model do
  # 모델 유효성 검사
  it "vaildation이 잘되나" do
    user = User.new(
      email: "test@example.com",
      password: "password123"
    )
    expect(user).to be_valid
  end

  # 연관 관계 테스트
  it "has many posts" do
    should have_many(:posts)
  end
end

# spec/controllers/users_controller_spec.rb
RSpec.describe UsersController, type: :controller do
  describe "GET #index" do
    it "returns a success response" do
      get :index
      expect(response).to be_successful
    end
  end

  describe "POST #create" do
    it "creates a new user" do
      expect {
        post :create, params: { user: valid_attributes }
      }.to change(User, :count).by(1)
    end
  end
end
```

다양한 테스트 도구 제공 (목업, 스텁 등)과 리포트를 제공함.
하지만 나는 rails c or s 하고 직접값 입력하는게 루비를 잘쓰는게 아닐까 싶다.