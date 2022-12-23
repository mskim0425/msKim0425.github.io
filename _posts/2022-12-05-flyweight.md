---
layout: post
title:  "구조패턴 - 플라이웨이트 패턴"
date:   2022-12-05 15:11:04 +0900
categories: [CS ,  Design Pattern]
tags: [cs, design pattern]
---
# flyweight Pattern

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
  
　

>다수의 인스턴스를 가능한대로 공유시켜서 new처럼 불필요한 생성을 막아 메모리 낭비 최소화  
> 
>100만원이 있는데 구매하고자 하는 메모리 점퍼가 120만원이다.  
>점퍼를 매일 입지않는이상 60씩 지불하고 같이 돌려입으면된다. 
{: .prompt-tip}


---

　　
<img src="https://refactoring.guru/images/patterns/content/flyweight/flyweight-2x.png?id=6a8f17d9550c75c3d648a605c4d31b45" width="300" height="300">

## <span style="color: gold"> 플라이웨이트 패턴이란? </span>  
다수의 객체가 생성되는 경우(new Class) 모두가 갖는 본질적인 요소를 클래스화해서 공유함으로써 메모리를 절약하고,  
**`클래스의 경량화`**를 목적으로 하는 디자인 패턴이다. 여러개의 가상 인스턴스를 제공하여 메모리 절감을 함. 
　　
![img](https://refactoring.guru/images/patterns/diagrams/flyweight/example-2x.png?id=9423640fe3688a64201389b6e7aa1f48)

**`TreeType`**은 Tree 클래스에서 반복되는 상태를 추출한 클래스  
**`TreeFactory`**는 기존 TreeType을 사용할지 새로운 객체를 생성할지 결정하는 공간.  
**`Tree`**와 **`Forest`**는 flyweight의 클라이언트이며, Tree를 변경할 계획이 없으면 병합해도 된다.

같은 데이터를 여러 객체에 저장하는 방법 대신에 몇개의 플라이웨이트 객체들에 보관해서 메모리를 효율적으로 운용하는 방식의 패턴

---
## <span style="color: gold"> 결론 </span>  

 - 프로그램이 많은 수의 객체들을 지원해야하는데 RAM이 꽉 찼을때 쓸만한 패턴
 - 앱이 수많은 유사 객체들을 생성해야 할 경우
 - 장치에서 사용할 수 있는 모든 RAM을 소모할 경우
 - 여러 중복 상태들이 포함되어 있으며, 추출된 후 객체 간에 공유될 수 있을 경우
  
---
## <span style="color: gold"> 참고자료 </span>  
[Source Ⅰ](https://refactoring.guru/ko/design-patterns/flyweight)
---