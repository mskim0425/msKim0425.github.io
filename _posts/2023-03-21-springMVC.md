---
layout: post
title:  "Spring용어,웹서버 그리고 Spring MVC"
date:   2023-03-21 11:01:04 +0900
categories: [MVC]
tags: [spring, mvc]
---

설명하고자하면 늘 잘 안나왔던 이야기를 정리해보고자 한다.  

## BeanFactory, ApplicationContext

`BeanFactory`는 빈을 생성하고 의존관계를 설정하는 기능을 담당하는 가장 기본적인 IoC 컨테이너이자 클래스를 말한다.   
`ApplicationContext`는 BeanFactory의 확장된 버전으로써 별도의 정보를 참고해서 빈의 생성, 관계 설정 등의 제어를 총괄하는 것에 초점을 맞춘 것이다.

특히 빈을 생성한 후 로딩하는 방식이 다르다. `BeanFactory`는 빈을 lazy loading 방식으로 로딩한다. 즉, 빈이 처음으로 요청될 때까지 빈이 초기화되지 않는다. 따라서 애플리케이션이 시작될 때 모든 빈을 로딩하지 않아서 애플리케이션 구동 속도가 빠르고 메모리 사용량이 적다.

반면에 `ApplicationContext`는 빈을 eager loading 방식으로 로딩한다. 즉, 애플리케이션을 시작할 때 모든 빈을 초기화하고 미리 로딩한다. 따라서 애플리케이션 구동 속도가 `BeanFactory`에 비해 느리고, 메모리 사용량이 많아질 수 있다.

대신, `ApplicationContext`는 `BeanFactory`보다 다양한 기능을 제공한다.  국제화(i18n), 이벤트 발생, AOP(Aspect Oriented Programming), 메시지 처리 등 다양한 기능을 제공한다.  
  
## Environment
프로파일(Profile)을 설정하고 어떤 것을 사용할지 선택할 수 있게 해주며, 소스 설정 및 프로퍼티 값을 가져오게 해준다.

## MessageSource
메시지에 대한 국제화(i18n)을 제공하는 인터페이스이다.  
i18n은 internationalization(국제화)의 약칭으로 소프트웨어가 언어에 종속적이지 않고 한국어든 영어든 동시에 입력해서 사용할 수 있어야 하는 것을 만족시켜주는 것을 말한다.  
메세지 설정 파일을 모아서 그 지역에 걸맞는 언어를 로컬라이징을 함으로써 메시지를 제공하는 기능이다.

## Bean Scope란?
> 스코프 = 빈이 존재할 수 있는 범위  

스프링 빈이 스프링 컨테이너의 시작과 함꼐 생성되어서 스프링 컨테이너가 종료될 때까지 유지된다. 이유는 스프링 빈이 기본적으로 싱글톤 스코프로 생성되기 떄문이다.

스코프에는 싱글톤,프로토타입, request, session, application이있다.    

프로토타입 스코프 같은 경우에는 생성과 의존관계 주입까지만 관여하고 그 이후에는 더이상 관여하지않는다. 즉, 해당 빈을 요청할때마다 새로운 인스턴스를 생성해서 반환한다.  

<img src = "https://github.com/mskim0425/mskim0425.github.io/blob/main/images/java/2.png?raw=true">

### Web Serever
> Apache, nginx

웹서버는 정적 컨텐츠(HTML, CSS, IMAGE)의 요청을 바로 응답을 하거나 동적 컨텐츠를 WAS에게 넘겨주는 역할을 한다. 이외에도 SSL에대한 암호화와 복호화 작업을 하기도 한다.   
로깅, 가상호스팅, 권한부여, 캐싱 등이있다.  

### Web Application Server
앞서 말한대로 동적인 컨텐츠를 처리하기 위한 서버이다.  사실 HTTP API를 응답하는 그 모든 역할을 하는 샘이다.  이렇게만 보면 WAS 하나로 시스템을 구성할수도 있다.  
그리고 실제로도 가능하다. 하지만 WAS가 너무 많은 역할을 하게되면 서비스 지연이 일어나면서 다운될 수 있다. 실제로 naver에서 개발자모드만 켜봐도 정적인 콘텐츠가 얼마나 많은지 알 수 있다.   
그래서 트래픽이 많이 발생하는 사이트는 웹서버를 로드벨런싱을 목적으로 사용하기도 한다.
  
`웹서버 = 정적 리소스 WAS = application 로직`   

> 1. Client -> Web Server (정적 컨텐츠)
> 2. Client -> WAS -> DB (서버 과부하 우려) 
> 3. Client -> Web Server -> WAS -> DB  (MVC와 템플릿엔진,API)
> 위 3가지 구조 중 하나를 가질 수 있다.
{: prompt.tip}

---
  
필자가 자주 사용하는 3번으로 얘기해보고자 한다.  
Client(브라우저) -> Web Server(Apache) -> WAS(Tomcat) + Servlet(ServletDispatcher) -> DI Container -> Controller

### Web server (아파치)
웹서버는 이미 저장되어 있는 정적인 컨텐츠(html)을 응답한다. 만약 사용자가 직접 정보를 검색하거나 저장하려면 web server의 문서를 직접 고쳐야했다.  
그러기에 이러한 점을 동적으로 변하는 페이지가 필요로 하게 되었고, 동적인 처리를 담당하는 CGI(Common Gateway Interface)가 나왔다.  

> `CGI는 서버와 응용 프로그램간에 데이터를 주고받기 위한 방법이나 규약을 뜻한다`  
> 1. 웹 브라우저의 HTML의 폼을 통해 요청이 웹 서버로 전달
> 2. 웹 서버는 요청에 들어 있는 주소가 CGI 프로그램에 대응되는지 확인
> 3. 대응될 경우 그 프로그램을 실행, 환경 변수와 표준 입력의 형태로 요청을 전달한다.
> 4. 웹 서버는 CGI 프로그램이 표준 출력으로 돌려 보낸 내용을 그대로 응답으로 돌려 준다.
{: .prompt:info}

이러한 CGI 방식은 멀티프로세스 방식을 취하므로 요청이 올때마다 프로세스를 늘려야했고 이는 자원낭비로 이어졌다. 이를 해결하기위해 멀티쓰레드 방식인 자바의 Servlet이 등장했다.  

참고로, 스프링 부트에서는 resources.static 폴더에 html 파일을 올리면 정적인 콘텐츠를 올려준다. [공식 문서 링크](https://docs.spring.io/spring-boot/docs/2.3.1.RELEASE/reference/html/spring-boot-features.html#boot-features-spring-mvc-static-content)

### 서블릿

<img src="https://github.com/mskim0425/mskim0425.github.io/blob/main/images/java/2.png?raw=true">

서블릿은 자바에서 만든 확장된 CGI다. 앞서 설명한 기본 CGI와는 다르게 멀티스레드 방식으로 동작한다. 서버가 시작되고 서블릿을 만들게 되면 메모리에 저장해두고, 같은 서블릿을 사용하여 요청을 처리한다.  
  
처음 웹서버로 요청이 전달 되었을때 동적인 컨텐츠를 응답해야 할 경우 동적인 컨텐츠를 전담하는 Web Application Server 로 요청을 전달한다.  

`서블릿의 역할`은 서버 TCP/IP 대기, 소캣연결 -> HTTP 요청 메시지를 파싱해서 읽고 ->  
POST 방식, URL 요청 -> Content-Type 확인 -> HTTP 메시지 바디 내용 파싱 -> 저장 프로세스 실행과 비즈니스 로직으로 부터 받은 데이터를 HTTP 응답메시지로 생성해서 보내느것과 TCP/IP에 응답 전달과 소켓종료의 이런 반복동작을 자동화 해준다.  

### 서블릿 컨테이너 (WAS)
JAVA의 대표적인 Servlet Container(WAS)는 Apache Tomcat으로 각각의 서블릿을 실행하고 관리하는 역할을 대신해준다. 요청마다 스레드를 만들고, 통신을 위한 소켓을 연결하고, 서블릿의 생성과 소멸 주기 관리를 모두 Container가 담당한다.  

1. 서블릿 컨테이너는 서블릿 객체의 생성,초기화, 종료하는 생명주기를 관리 (빈의 생명주기)  
2. 서블릿 객체는 싱글톤으로 관리된다.  
3. JSP도 서블릿으로 변환되어서 사용된다.  
4. 동시 요청을 위한 멀티 쓰레드 처리 지원  
여기서 발생하는 튜닝실력... 최대 쓰레드 수를 너무 높게 잡으면 서버 리소스가 과하게 사용될 수 있고, 너무 낮게 잡으면 클라이언트가 접속에 불편을 겪게될 수 있기 때문에 개발자가 적절하게 컨트롤할 수 있어야 한다.   


### Annotation 기반 스프링 MVC 등장

<img src="https://github.com/mskim0425/mskim0425.github.io/blob/main/images/java/%EB%94%94%EC%8A%A4%ED%8C%A8%EC%B9%984.png?raw=true">

이제서야 스프링 MVC에 대해 얘기할 수 있다.   
spring에서 서블릿을 사용하고 있다면 대부분 프론트 컨트롤러인 dipatcher servlet을 사용한다. 여담으로 과거에는 mvc model 1에서는 컨트롤러단에서 view와 자바코드가 혼재되어 유지보수가 어려웠다고 한다.    
  
현재는 스프링 MVC는 Front Controller Pattern을 구현하고 있다.  앞단에 Dispatcher Servlet이 하나의 서블릿으로 모든 것을 관리하기 떄문에 코드의 중복도도 엄청나게 줄어 들었다.   

다시말해 WebServer -> WAS(Tomcat) -> ServletDispatcher 순으로 요청을 전달 받게 된다.   
Spring MVC 는 ServletDispatcher라는 Servlet으로 요청이 오면 녀석이 요청의 url을 분석하여 해당 요청을 수행할 수 있는 Spring Bean(Controller)에 요청을 보내준다.  
특이하게도 정적 자원이 오면 컨트롤러를 탐색하고 난뒤에 resourse.static 디렉토리를 탐색하게 된다고 한다.  


##

