---
layout: post
title:  "Persistence Context"
date:   2023-01-06 15:11:04 +0900
categories: [JPA, SQL]
tags: [jpa, sql]
---

## 영속성 컨텍스트

JPA를 사용함에 있어 가장 중요한 개념이자 Entity를 영구 저장하는 환경이다.  
논리적인 개념이기에 자주 까먹어서 이참에 정리하고자 한다.  

> 프레임워크랑 DB 사이에 있는 논리적인 공간
{: .prompt-tip}

## 엔티티의 생명주기
왜 뜬금없이 엔티티의 생명주기냐 하겠지만, 영속성 컨텍스트를 이해하는데 땔 수 없는 관계이기에 설명하고자 한다.  

<img src="https://t1.daumcdn.net/cfile/tistory/233A5A475551AB5617">  

크게 4가지 영역으로 나뉘는데 New, managed, detached, removed 이다.  
1. 비영속 (new)는 영속성 컨텍스트와 전혀관계가 없는 말그대로 NEW인 상태이다.  
```java
Member member = new Member(); //맴버 객체에는 ID와 이름이 저장된다.
member.setId(1L);
member.setName("회원A")
```  
2. 영속(persist)는 객체를 생성하고 저장까지한 상태 *코드가 계속 이어진다고 생각하면 된다.*
```java
EntityManager em = entityManagerFactory.createEntityManager(); //팩토리에서 매니저발령
em.getTransaction().begin();

em.persist(member); // 객체를 영속성 컨텍스트에 저장한 상태
```

3. 준영속(detach), 삭제(remove)는 논리적인 공간에서 분리시키거나 삭제한 상태  
```java
em.detach(memeber);
em.remove(member);
```

