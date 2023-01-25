---
layout: post
title:  "[Spring] Annotation"
date:   2022-09-27 15:41:57 +0900
categories: [Java , Spring]
tags: [java, spring]
---

# Spring Annotation
Annotation이란?
> 소스코드에 제공되는 메타데이터이다. 앱이 처리하는 데이터가 아닌 컴파일 과정,실행 과정에서 코드를 어떻게 처리해야 하는지 알려주는 용도로 사용된다.   
   
   
어노테이션에는 크게 2가지가 있다. 
- built-in 어노테이션
    Java 코드에 적용되는 어노테이션
    @Override, @Deprecated, @SuppressWarnings 등...
- meta 어노테이션
    다른 어노테이션에 적용되기 위한 어노테이션
    @Retention, @Documneted, @Target, @Inherited, @Repeatable 등  

이 중에 나는 meta 어노테이션인, 개발자가 직접 작성한 클래스를 Bean으로 등록할때 사용하는 어노테이션인 @Component의 특징을 보자
```java
@Target({ElementType.TYPE})
@Retention(RetentionPolicy.RUNTIME)
@Documented
@Indexed
public @interface Component {
    String value() default "";
}
```
위처럼 Component에는 @Target, @Rentetion, @Documneted, @Indexed 가 있다.  
차례대로 설명해보겠다.  
#### @Target
어노테이션을 작성할 곳이다. default값은 모든 대상이다. 만약 구체적으로 지정한다면 다른부분에서 적용시 에러가 난다.   
ElementType.??? ??? `호출 시 사용하겠다`
- ElementType.TYPE (class, interface, enum)  
- ElementType.FIELD (instance variable)  
- ElementType.METHOD 
- ElementType.PARAMETER  
- ElementType.CONSTRUCTOR  
- ElementType.LOCAL_VARIABLE  
- ElementType.ANNOTATION_TYPE (on another annotation)  
- ElementType.PACKAGE (remember package-info.java)  
이런식으로 다양한 종류가 있다.
  
#### @Retention 
리텐션은 보유를 의미하는 뜻으로 어노테이션의 지속시간, 얼마나 보유할지에 대한 설정을 하는 설정이다.
- RetentionPolicy.CLASS : `default` 값 입니다. 컴파일 타임 때만 .class 파일에 존재하고, 런타임 때는 없어진다. 바이트 코드 레벨에서 어떤 작업을 해야할 때 유용하다. Reflection 사용이 불가능.
- RetentionPolicy.SOURCE : 컴파일 후에 정보들이 사라진다. 이 어노테이션은 컴파일이 완료된 후에는 의미가 없어진다.그러기에 바이트 코드에 기록되지 않는다. 예시로는 `@Override와 @SuppressWarnings` 어노테이션이 있다.
- RetentionPlicy.RUNTIME : 이 어노테이션은 런타임시에도 .class 파일에 존재한다. 커스텀 어노테이션을 만들 때 주로 사용한다. Reflection 사용 가능이 가능  
<img src="https://github.com/msKim92/msKim92.github.io/blob/main/images/java/javacompiler.png?raw=true">

#### @Documented 
Java doc에 문서화 여부를 결정한다.  
#### @Indexed
해당 주석이 달린 요소가 인덱스에 대한 스테레오타입임을 나타내고 이 타입 기반으로 후보구성요소 (ex: 정규화된 이름)을 검색할 수 있다.
#### @Inherited 
해당 어노테이션을 하위 클래스에 적용한다.  

## 커스텀 어노테이션
간단하게 AOP를 위해 만든 실제 어노테이션을 이용한 예를 들겠다.  
그 전에, 커스텀 어노테이션을 만들떄는 몇가지 규칙이 있다.  
1. Annotation 타입은 java.lang.Annotation 인터페이스를 상속받기 떄문에 @interface로 정의해야한다.
2. 파라미터 맴버들의 접근자는 public or Default여야한다.
3. 파라미터 멤버들은 byte,short,char,int,float,double,boolean의 기본타입과 String, Enum, Class 어노테이션만 사용할 수 있다.
4. 클래스 메소드와 필드에 관한 어노테이션 정보를 얻고 싶으면, 리플렉션만 이용해서 얻을 수 있다. 다른 방법으로는 어노테이션 객체를 얻을 수 없다.
    
```java
@Target(ElementType.METHOD)//메소드 호출시 사용하겠다
@Retention(RetentionPolicy.RUNTIME) //런타임시 유지되도록하겠다
public @interface NeedEmail {
}
```
해당 어노테이션은 메소드 호출시 사용되고 런타임 환경에서는 꾸준히 기능을 사용하겠다는 뜻이다.  



### 출처  
[docs.spring.io](https://docs.spring.io/spring-framework/docs/current/javadoc-api/org/springframework/stereotype/package-summary.html)