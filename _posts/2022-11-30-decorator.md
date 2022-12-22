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
  
　

>기존의 시스템에 부수적인 새로운 기능을 추가할떄 사용하는 패턴  
>하나의 클래스, 메서드를 통해서 징검다리 역할
{: .prompt-tip}


---
## <span style="color: gold"> 데코레이터 패턴이란? </span>  

---
## <span style="color: gold"> 결론 </span>  

 - 부모 추상클래스가 규칙을 정의할수 있고, 클래스에 규칙을 추가하고 싶을 경우
 - 객체에 대한 참조가 있는 추상클래스가 있고, 각각의 클래스에서 정의될 추상 메서드가 있는 경우  
  
---
## <span style="color: gold"> 참고자료 </span>  
https://www.baeldung.com/java-decorator-pattern
---