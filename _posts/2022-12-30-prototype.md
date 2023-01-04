---
layout: post
title:  "생성 패턴 - 프로토타입 패턴"
date:   2022-12-26 15:10:57 +0900
categories: [CS ,  Design Pattern]
tags: [cs, design pattern]
---
# Prototype Method Pattern 🧙‍♂️

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
  
　　 
  
> 기존 객체를 복제함으로써 객체를 생성하여 **DB,네트워크 접근 비용을 절감**하는 패턴
{: .prompt-tip }

![img](https://img1.daumcdn.net/thumb/R1280x0/?fname=http://t1.daumcdn.net/brunch/service/user/9JHZ/image/ibUmFU3pjSudEbPlEUdiBwYfFGM.png)

## <span style="color: gold"> 프로토타입 패턴이란? </span> 
처음부터 일반적인 원형을 만들어 놓고, 그것을 복사한 후 **필요한 부분만 수정**하여 사용하는 패턴이다.  
생성할 객체의 원형을 제공하는 인스턴스에서 생성할 객체들의 타입이 결정되도록 설정하며, 객체를 생성할 때나,  
갖추어야 할 기본형태가 있을 때, 사용되는 패턴이다.


```java
public class Employees implements Cloneable {
    private List<String> nameList;

    public Employees() {
        this.nameList = new ArrayList<>();
    }

    public Employees(List<String> list) {
        this.nameList = list;
    }

    public void uploadData() {
        nameList.add("Kim");
        nameList.add("Park");
        nameList.add("Lee");
    }
    //핵심 내용
    @Override
    public Object clone() throws CloneNotSupportedException {
        List <String> temp = new ArrayList < > ();
        for (String str: this.nameList) {
            temp.add(str);
        }
        return new Employees(temp);
    }
}
```

```java
   
public class PrototypePattern {
    public static void main(String[] args) throws CloneNotSupportedException {
        Employees employees = new Employees();
        employees.uploadData(); // Kim, Park, Lee

        Employees employees1 = (Employees) employees.clone();
        Employees employees2 = (Employees) employees.clone();

        List < String > list1 = employees1.getList();
        list1.add("Na");

        List < String > list2 = employees2.getList();
        list2.remove("Lee");

        System.out.println("employees: " + employees.getList());
        System.out.println("employees 1: " + list1.getList());
        System.out.println("employees 2: " + list2.getList());
    }
}

/*
* employees : Kim, Park ,Lee
* employees 1: Kim, Park ,Lee, Na
* employees 2: Kim, Park
*/
```
Clone 메소드를 통해 DB로부터 한번의 호출을 통해서 데이터를 조작할 수 있었다.  


## <span style="color: gold"> 장 단점 </span>

`장점`  
- 객체를 생성해주기 위한 별도의 객체 생성 클래스가 필요하지 않다.  
- 비용절감  
  
`단점`  
- 생성해야할 객체들의 클래스들을 모두 clone()메서드로 구현해야함.  

## <span style="color: gold"> 결론 </span>
데이터를 바꾸고 저장하는 과정이 한번에 일어난다고 가정하면, 이러한 방법으로 속도를 향상 시키자.
객체를 복사하는 것이 네트워크 접근이나 DB 접근보다 훨씬 비용이 적다.

## <span style="color: gold"> 참고자료 </span>  
Head First 디자인패턴  
면접을 위한 CS 전공지식노트