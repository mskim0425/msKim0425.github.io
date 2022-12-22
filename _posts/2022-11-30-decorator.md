---
layout: post
title:  "구조패턴 - 데코레이터 패턴"
date:   2022-11-30 15:11:04 +0900
categories: [CS ,  Design Pattern]
tags: [CS, Design Pattern]
---
# Decorator Pattern

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
  
　

>객체의 결합을 통해 기능을 동적으로 유연하게 확장  (주요 기능에 무엇인가를 추가)
>신발끈 색만 바꾸고 싶을 때, 똑같은 신발을 살 필요 없이 신발끈만 사서 바꾸면 된다.
{: .prompt-tip}

>Proxy 패턴과의 차이: 주요기능을 다양한 방식으로 컨트롤 해주는 것
{: .prompt-warning }

---
## <span style="color: gold"> 데코레이터 패턴이란? </span>  
기존에 구현되어 있는 클래스에 필요한 기능을 추가해 나가는 설계 패턴으로써 기능확장이 필요할 때,  
`객체간의 결합을 통해` 기능을 동적으로 `유연하게 확장`할 수 있게 해주어 `상속의 대안`으로 사용하는 디자인 패턴이다.

![img](https://www.baeldung.com/wp-content/uploads/2017/09/8poz64T.jpg)
<center><small> 데코레이터 패턴의 예 - Baeldung </small></center>   
　　

위의 그림구조는 런타임에 원하는 만큼 데코레이터를 추가할 수 있는 유연성을 제공한다.
기존의 장신구들이 있다면 굳이 트리를 살때, 똑같은 장신구를 살 필요없듯이 인터페이스로 받아서 사용하는 패턴이다.

---
## <span style="color: gold"> 결론 </span>  

 - 객체에 단순히 동작이나 상태를 CRUD할 경우
 - 클래스의 하나의 object 기능을 수정하고 다른 개체는 변경 할 필요 없을 경우
  
---
## <span style="color: gold"> 참고자료 </span>  
https://www.baeldung.com/java-decorator-pattern
---