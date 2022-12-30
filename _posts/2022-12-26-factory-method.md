---
layout: post
title:  "생성 패턴 - 팩토리 메서드 패턴"
date:   2022-12-26 15:10:57 +0900
categories: [CS ,  Design Pattern]
tags: [cs, design pattern]
---
# Factory Method Pattern

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

> 생성할 객체의 클래스를 국한하지 않고 생성한다.
{: .prompt-tip }


>추상 팩토리와의 차이:
{: .prompt-warning }


## <span style="color: gold"> 팩토리 메서드 패턴이란? </span> 
`상위클래스`에서는 인스턴스를 만드는 방법을 결정하고,  
`하위 클래스`에서는 데이터의 생성을 책임지고 조작하는 함수들을 오버라이딩하여 인터페이스와 실제 객체를 생성하는 클래스를 분리할 수 있는 특징을 갖는 디자인 패턴.

![img](https://velog.velcdn.com/images%2Fjamieshin%2Fpost%2F715a6f1b-2622-46fa-b945-531f0e5e874d%2Fimage.png){: .shadow }

<center><small> 팩토리 메소드 패턴 헤드 퍼스트 </small></center>

`Product`
```java
interface Pizza {
    public void prepare();
    public void bake();
    public void box();
}
```
`Creator`
```java
abstract class PizzaStore {
    public Pizza orderPizza(String type) {
        Pizza pizza = createPizza(type);    // factory method 사용
        pizza.prepare();
        pizza.bake();
        pizza.box();
        return pizza;
    }

    abstract Pizza createPizza(String type);    // factory method extends하면 필수구현
}
/*뉴욕 피자*/
class NYPizzaStore extends PizzaStore { 
    @Override
    Pizza createPizza(String type) {
        if ("cheese".equals(type)) {
            return new NYStyleCheesePizza();
        } else if ("pepperoni".equals(type)) {
            return new NYStylePepperoniPizza();
        }
        return null;
    }
}
/*시카고 피자*/
class ChicagoPizzaStore extends PizzaStore { 
    @Override
    Pizza createPizza(String type) {
        if ("cheese".equals(type)) {
            return new ChicagoStyleCheesePizza();
        } else if ("pepperoni".equals(type)) {
            return new ChicagoStylePepperoniPizza();
        }
        return null;
    }
}
```
`Main`
```java
psvm(){
    PizzaStore nyStore = new NYPizzaStore();
    PizzaStore chicagoStore = new ChicagoPizzaStore();

    Pizza pizza = nyStore.orderPizza("cheese");
    Pizza pizza1 = chicagoStore.orderPizza("pepperoni");
}
```
 위 처럼 추상클래스의 특징인 상속을 통해 자손 클래스에서 완성을 유도하는 방식으로(`미완성 설계도`) 구현한 패턴이다.

## <span style="color: gold"> 장 단점 </span>
장점  
- OCP와 DIP를 잘 지킴
- 느슨한 결합도 유지

단점
- 자식 클래스가 많아지면서 코드가 복잡해질 가능성이 있음

## <span style="color: gold"> 결론 </span>
팩토리 메소드 패턴은 클래스간의 결합도를 낮추기 위함이다.  
객체를 직접 생성해서 사용하는 것을 방지하고 서브 클래스에 위임해서 효과적인 코드제어와 의존성을 제거함이다.

## <span style="color: gold"> 참고자료 </span>
[참고 자료](https://refactoring.guru/ko/design-patterns/factory-method)  
[Head First Design Patterns / 에릭 프리먼]()
