---
layout: post



title:  "ROR 사용시 혼동되는거 정리"



date:   2023-10-29 13:01:04 +0900



categories: [ruby, ruby on rails]



tags: [ruby, ruby on rails]
---
# <% > 와 <%= > 차이

ERB 뷰작업을 하다보면 mybatis 처럼 동적쿼리를 실행하기 위해서, 즉 상황에 따른 데이터값을 보여주기 위해서 <% >, 와 <%= >를 사용하게 된다.  
**<% >**는 출력을 안하고 제어흐름을 관리하는데 사용된다.  
**<%= >**는 변수의 값을 문자열로 출력하기 위해서 사용된다.  
~~~ruby
<% if user_logged_in? %>
  <p>Welcome, <%= current_user.name %>!</p>
<% else %>
  <p>Please log in.</p>
<% end %>
~~~

# 버튼 제작시, 중복클릭에 대한 대비
버튼을 만들때, 여러번 요청을 하면 서버단에서 해당 이슈를 막을수도 있지만, 프론트단에서도 처리중으로 표현하는 방법이 필요하다.  
~~~JS
let isClicked = false;  
$('#create_stop_order').on('click', function () {  
  if (isClicked) {  
    alert('처리중입니다.');  
    return;  
  }  
  
  isClicked = true;
~~~  
또는    
~~~ruby
<%= button_tag "버튼이름",  type: "submit", class: "btn btn-info", data: { disable_with: "처리중입니다." } %> 
~~~
이런식으로 처리한다.  