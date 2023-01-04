---
layout: post
title:  "생성패턴 - 싱글톤 패턴"
date:   2022-12-22 12:15:07 +0900
categories: [CS ,  Design Pattern]
tags: [cs, design pattern]
---
# Singleton Pattern

<details>
<summary><span style="color: gold"> 디자인 패턴이란? </span></summary>
<div markdown="1">
## <span style="color: gold"> 디자인 패턴이란? </span>
- 디자인 패턴은 소프트웨어 공학의 소프트웨어 설계에서 공통으로 발생하는 문제를 자주 쓰이는 설계 방법을 정리한 패턴이다.
- 디자인 패턴을 참고하여 개발하면 효율성과 유지보수성, 운용성이 높아지며, 프로그램 최적화가 된다고 한다.
　 

디자인 패턴을 목적과 범위로 나눌수 있다

|구분|유형|설명|
|:---:|:---:|:---|
| |생성|객체 인스턴스 생성에 관여, 클래스 정의와 객체 생성 방식을 구조화, 캡슐화를 수행|
|목적|구조|더 큰 구조 형성 목적으로 클래스나 객체의 조합을 다루는 패턴|
|    |행위|클래스나 객체들이 상호작용하는 방법과 역할 분담을 다루는 패턴|
|범위|클래스|클래스간 관련성(상속), 컴파일 시 정적으로 결정|
|    |객체|객체 간 관련성을 다루는 패턴, 런타임 시 동적으로 결정|

---
</div>
</details>
　　

> 클래스의 인스턴스가 딱 1개만 생성되는 것을 보장하는 디자인패턴  
> 데이터베이스 연결 모듈에서 많이 쓰이는 패턴이다.
{: .prompt-tip}

## <span style="color: gold"> 싱글톤 패턴이란? </span>
전역 변수를 사용하지 않고 객체를 하나만 생성하도록 하며, 생성된 객체를 어디에 서든지 참조 할 수있도록 하는 디자인 패턴

```java

public class SingletonService(){
    private static final SingletonService instance = new SingletonService();

    public static SingletonService getInstance(){
        return instance;
    }

    private SingletonService(){
        
    }
    
    public void logic(){
        //로직
    }
}

// 다른 클래스
public static void main(String[] args){
   ...  = new SingletonService() // 생성자가 private이기에 막을 수 있다.
}
```
위의 코드처럼 client가 요청할 때마다 객체를 생성하는것이 아닌, 이미 만들어진 객체를 공유해서 효율적으로 사용할 수 있다.   
다만 수많은 문제점들이 있다.

## <span style="color: gold"> 장점과 단점 </span>
`장점`
- 객체보장
- 객체공유
  
`단점`
- 기본 셋팅 코드가 많이 들어간다. (1번부터 15번 라인까지)
- DIP, OCP 위반한다. *의존 관계상 클라이언트가 구현 클래스를 의존함
- 단위 테스트를 하기 어렵다. 각각의 테스트마다 **독립적인** 인스턴스를 만들기 어려움
- 내부 속성을 변경하거나 초기화 하기 어렵다

---

<details>
<summary><span style="color: gold"> 아니 그럼 왜 이렇게 문제가 많은데 왜 쓰는거지? -> 의존성 주입 (feat. 싱글톤 컨테이너!!) </span></summary>

<img src="https://github.com/msKim92/msKim92.github.io/blob/main/images/design/%EC%9D%98%EC%A1%B4%EC%84%B1.jpg?raw=true" width="1000" height="400">  
  
메인 모듈이 직접 다른 하위 모듈에 대한 의존성을 주기보다는 중간에 의존성 주입(DI)을 통해 메인 모듈이 간접적으로 의존성을 주입하는 방식. `디커플링` 이라고도 한다.  
의존성 주입의 장점: 모듈 간의 테스트를 쉽게하고 의존성 방향이 일관되고 관계가 명확해짐  
단점: 클래스 수가 늘어나 복잡해지고 약간의 런타임 패널티가 생김

스프링 컨테이너는 위에 언급한 문제점을 해결하면서 싱글톤의 장점을 살린다.  
`스프링 빈을 싱글톤 패턴으로 관리`  

<img src="https://github.com/msKim92/msKim92.github.io/blob/main/images/design/%EC%8A%A4%ED%94%84%EB%A7%81%20DI%EC%BB%A8%ED%85%8C%EC%9D%B4%EB%84%88.png?raw=true" width="1000" height="400">

<center><small> 김영한 강의 자료중 일부 발췌 </small></center>   

위의 그림처럼 싱글톤의 장점을 볼 수 있다.
　　  
</details>
　

---

## <span style="color: gold"> 결론 </span>

싱글톤 패턴은 안티패턴이라는 말이 있듯이 단독으로 사용되면 OOP설계를 위반하기 쉽다.  
하지만 위에서 소개한 내용대로 스프링 컨테이너의 도움을 받으면 싱글톤 패턴의 단점을 보완하면서 사용할 수 있다.  
*스프링 빈은 컨테이너의 도움을 받아 싱글톤 스콥으로 관리되고 있는걸 확인 할 수 있다.

## <span style="color: gold"> 참고자료 </span>
- 인프런 김영한 스프링 기본 강의