---
layout: post
title:  "Java 8-17 정리"
date:   2023-01-21 21:20:57 +0900
categories: [Dev, Java]
tags: [java, basic]
---

### 자바 8...30년까지? 
이번 프로젝트를 하면서 자바 11을 VAR특성과 LTS(Long Term Support)이길래 사용해보았다...그런데 Oracle 사에서 Java8을 사용한 레거시 프로젝트들이 너무 많음을 고려하여 Java8이 Java11,Java17 보다 더 긴 지원기간을 갖게되었다. 🤷‍♂️
<img src="https://raw.githubusercontent.com/mskim0425/mskim0425.github.io/main/images/java/java_history.webp" width=500>  
자바 8이 2030년까지 지원한다는 소리를 듣고 이 참에 한번 각 버젼별로 괜찮은 기능을 정리해볼까한다.  

### JAVA 8
[자바8](https://www.oracle.com/java/technologies/javase/8-whats-new.html)
1. Lambda
2. Stream
3. interface default Method
4. Optional
5. LocalDateTime

이번 프로젝트에서도 많이 사용한 `interface default Method`, null이 올 수 있는 값을 감싸는 Wrapper 클래스로 감싸 NPE를 방지해주는 `Optional`, 컬랙션 연산을 더 효율적으로 하는 `Stream` 등 왜 오라클에서 30년까지 지원하는지 잘 알 수 있는 대목이다. 조만간 해당 점들을 블로깅 할 예정이다.  
아래는 interface default Method의 예로 exec를 따로 구현하지않고도 메서드를 사용하는 예이다.
```java
public interface Calculator {
	public int plus(int i, int j);
	public int multiple(int i, int j);
	default int exec(int i, int j){  //interface default Method
		return i + j;
	}
}

//Calculator인터페이스를 구현한 MyCalculator클래스
public class MyCalculator implements Calculator {

	@Override
	public int plus(int i, int j) {
		return i + j;
	}

	@Override
	public int multiple(int i, int j) {
		return i * j;
	}
}

public class MyCalculatorExam {
	public static void main(String[] args){
		Calculator cal = new MyCalculator();
		int value = cal.exec(5, 10);
		System.out.println(value);
	}
}
```

### JAVA 9
1. 모듈시스템의 등장(Jigsaw)  
2. stream  
takeWhile, dropWhile, iterate 등  
```java
Stream<String> stream = Stream.iterate(*""*, s -> s + *"s"*)
  .takeWhile(s -> s.length() < 10);
```
3. optional  
ifPresentOrElse 추가  

4. interface
private method 추가
  

### JAVA 10
1. var 추가
	```java
	//타입을 명시하지않아도 사용하는데 문제가 없다.
	String name = "홍길동";

	var name = "홍길동";
	var age = 25;
	```

2. Garbage Collector(GC) 병렬 처리 도입으로 인한 성능 향상
3. JVM heap 영역을 시스템 메모리가 아닌 다른 종류의 메모리에도 할당 가능
   
### JAVA 11
1. Java 소스 파일 을 먼저 컴파일 하지 않고도 실행할 수 있다. 엑셀 함수같은 스크립팅 기능
2. Lambda에 var 사용 가능
3. Oracle JDK와 OpenJDK 통합
### JAVA 13
1. 유니코드 11 지원
2. 간편해진? switch문
```java
String time;
switch (weekday) {
	case MONDAY:
	case FRIDAY:
		time = "09:00-18:00";
		break;
	case TUESDAY:
	case THURSDAY:
		time = "10:00-19:00";
		break;
	default:
		time = "휴일";
}
//일일히 브레이크를 넣어줘야했던 스위치문이
String time = switch (weekday) {
	case MONDAY, FRIDAY -> "09:00-18:00";
	case TUESDAY, THURSDAY -> "10:00-19:00";
	default -> "휴일";
};
```

### JAVA 17
자바 17은 11이후의 LTS이다.  
스위치문에 다양한 타입을 선언할 수 있도록 바뀌었다.  
이젠 obj를 전달하여 기능을 전환하고 특정 유형을 확인할 수 있다.
```java
public String test(Object obj) {

    return switch(obj) {

    case Integer i -> "An integer";

    case String s -> "A string";

    case Cat c -> "A Cat";

    default -> "I don't know what it is";

    };

}
```
Sealed Class (최종)  
```java
public abstract sealed class Shape
    permits Circle, Rectangle, Square {...}
```
위와같은 퍼블릭 Shape class가 있을떄 Shape을 만들수 있는 하위 클래스는 Circle, Rectangle, Square 3개뿐이다.

### JAVA 19
가상스레드, 새로운 메모리 API, Vector API등등 보이지만 이건 맛보기인듯 싶다.    
궁금하면 [클릭](https://www.happycoders.eu/java/java-19-features/)  

#출처
[baeldung](https://www.baeldung.com/project-jigsaw-java-modularity)  
[HappyCoders](https://www.happycoders.eu/java/java-19-features/)