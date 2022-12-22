---
layout: post
title:  "구조패턴 - 컴포지트 패턴"
date:   2022-12-12 15:11:04 +0900
categories: [CS ,  Design Pattern]
tags: [CS, Design Pattern]
---
# Composite Pattern

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
  
　

>하나의 operation을 사용할때 client는 Component에 있는 operation만 쓰면된다.  
>
{: .prompt-tip}


---
## <span style="color: gold"> 컴포지트 패턴이란? </span>  

객체들의 관계를 트리구조로 구성하여 부분 - 전체 계층을 표현하는 패턴으로 사용자가 **`단일 객체와 복합 객체 모두 동일하게 다루도록`** 하는 패턴이다. 아래의 예제는 복합객체와 단일객체를 동일하게 취급하는 경우를 나타냈다.

```java
//기본 요소(basic component) 두개의 leaf가 필요로하는 메서드
public interface Department {
    void printDepartmentName();
}

// LEAFS 1
@RequiredConstructor @Getter @Setter
public class FinancialDepartment implements Department {

    private Integer id;
    private String name;

    public void printDepartmentName() {
        System.out.println(getClass().getSimpleName());
    }
    
}
// LEAFS 2
@RequiredConstructor @Getter @Setter
public class SalesDepartment implements Department {

    private Integer id;
    private String name;

    public void printDepartmentName() {
        System.out.println(getClass().getSimpleName());
    }
}
```

복합 요소(Composite Element)
```java
public class HeadDepartment implements Department {
    private Integer id;
    private String name;

    private List<Department> childDepartments;

    public HeadDepartment(Integer id, String name) {
        this.id = id;
        this.name = name;
        this.childDepartments = new ArrayList<>();
    }

    public void printDepartmentName() {
        childDepartments.forEach(Department::printDepartmentName);
    }

    public void addDepartment(Department department) {
        childDepartments.add(department);
    }

    public void removeDepartment(Department department) {
        childDepartments.remove(department);
    }
}

public class CompositeDemo {
    public static void main(String args[]) {
        Department salesDepartment = new SalesDepartment(
          1, "Sales department");
        Department financialDepartment = new FinancialDepartment(
          2, "Financial department");

        HeadDepartment headDepartment = new HeadDepartment(
          3, "Head department");

        headDepartment.addDepartment(salesDepartment);
        headDepartment.addDepartment(financialDepartment);

        headDepartment.printDepartmentName();
    }
}
// SalesDepartment와 FinacialDepartment가 출력된다.
```
위에는 계층구조로 된 회사 조직도를 코드로 나타낸것이다.
재정부서, 판매부서, HR 이렇게 3곳을 나타냈다.  
HR은 복합, 재정,판매는 단일객체의 형태를 띄고있다. 즉, 단일객체와 복합객체를 구분하지않고 `동일한 형태로 사용`할때의 예시이다.
아래의 main쪽을 보면 코드가 단순해지고 객체들이 모두 같은 타입으로 취급되므로 새로운 클래스를 쉽게 추가 할 수 있다.

다만, 지나치게 범용성을 가진다면 이를 제어하기 어려워질 수가 있다.

---
## <span style="color: gold"> 결론 </span>  

 - 객체들 간에 계급 및 계층구조가 있고 이를 표현해야할 경우
 - 클라이언트가 단일 객체와 집합 객체를 구분하지 않고 동일한 형태로 사용하고자 할 경우
 - 개방 폐쇄 원칙을 지킬 수 있다.
  
---
## <span style="color: gold"> 참고자료 </span>  
https://www.baeldung.com/java-composite-pattern
---