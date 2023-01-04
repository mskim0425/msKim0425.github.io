---
layout: post
title:  "구조패턴 - 데코레이터 패턴"
date:   2022-11-30 15:11:04 +0900
categories: [CS ,  Design Pattern]
tags: [cs, design pattern]
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
  
　

>객체의 결합을 통해 기능을 동적으로 유연하게 확장(주요 기능에 무엇인가를 추가)  
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
`기본 윈도우`
```java
interface Window {
    public void draw(); // draws the Window
    public String getDescription(); // returns a description of the Window
}

class SimpleWindow implements Window {
    public void draw() {
    }

    public String getDescription() {
        return "simple window";
    }
}
```
`데코레이터 클래스`
```java
// abstract decorator class - note that it implements Window
abstract class WindowDecorator implements Window {
    protected Window decoratedWindow; // the Window being decorated

    public WindowDecorator (Window decoratedWindow) {
        this.decoratedWindow = decoratedWindow;
    }
}

// 첫번째 데코레이터 패턴 수직스크롤기능 추가
class VerticalScrollBarDecorator extends WindowDecorator {
    public VerticalScrollBarDecorator (Window decoratedWindow) {
        super(decoratedWindow);
    }

    public void draw() {
        drawVerticalScrollBar();
        decoratedWindow.draw();
    }

    private void drawVerticalScrollBar() {
        // draw the vertical scrollbar
    }

    public String getDescription() {
        return decoratedWindow.getDescription() + ", including vertical scrollbars";
    }
}

// 두번째 데코레이터 패턴 수평스크롤 기능 추가
class HorizontalScrollBarDecorator extends WindowDecorator {
    public HorizontalScrollBarDecorator (Window decoratedWindow) {
        super(decoratedWindow);
    }

    public void draw() {
        drawHorizontalScrollBar();
        decoratedWindow.draw();
    }

    private void drawHorizontalScrollBar() {
        // draw the horizontal scrollbar
    }

    public String getDescription() {
        return decoratedWindow.getDescription() + ", including horizontal scrollbars";
    }
}
```
`데코레이터 패턴이 적용된 객체 호출`
```java
public class DecoratedWindowTest {
    public static void main(String[] args) {
        // create a decorated Window with horizontal and vertical scrollbars
        Window decoratedWindow = new HorizontalScrollBarDecorator (
                new VerticalScrollBarDecorator(new SimpleWindow()));
    }
}
```
---
## <span style="color: gold"> 결론 </span>  

 - 객체에 단순히 동작이나 상태를 CRUD할 경우
 - 클래스의 하나의 object 기능을 수정하고 다른 개체는 변경 할 필요 없을 경우
  
---
## <span style="color: gold"> 참고자료 </span>  
[Source Ⅰ](https://www.baeldung.com/java-decorator-pattern)
[Source Ⅱ](https://ko.wikipedia.org/wiki/%EB%8D%B0%EC%BD%94%EB%A0%88%EC%9D%B4%ED%84%B0_%ED%8C%A8%ED%84%B4)  
Head First 디자인패턴  
면접을 위한 CS 전공지식노트
---