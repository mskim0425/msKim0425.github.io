---
layout: post
title:  "인터넷 사용법?"
date:   2022-10-19 09:41:57 +0900
categories: [CS , Internet]
tags: [cs, internet]
---

# Internet 너는 대체 무엇인고? 🤷‍♂️
---


전 세계에 걸쳐 파일 전송 등의 데이터 통신 서비스를 받을 수 있는 컴퓨터 네트워크 시스템이다.

www.google.com을 찾아가는 데 있어서 바로 가는 것처럼 보이지만 수많은 노드들을 통해 지나간다.

그런 과정들을 아래에 풀어보고자 한다. 

우선 처음으로 인지해야 하는 점은 계층에서 무슨 일이 일어나는지에 대한 로드맵이다.

 이는 인터넷에서 서로 다른 기종의 컴퓨터들이 서로 정보를 주고받는데 쓰이는 프로토콜의 집합을 뜻한다. 
 
 아래의 방식의 규칙을 통해 우린 인터넷을 사용하고 있다.

![image](https://github.com/mskim0425/mskim0425.github.io/blob/main/images/internet/1TCPIP%EC%99%80%20OSI%207%EA%B3%84%EC%B8%B5%EC%9D%B4%20%ED%95%98%EB%8A%94%20%EC%97%AD%ED%95%A0%EC%9D%84%20%EA%B0%84%EB%9E%B5%ED%95%98%EA%B2%8C%20%EB%82%98%ED%83%80%EB%83%84.jpg?raw=true){: .shadow }

---

각 계층마다 무슨 액션을 했는지 알았으니, 


이젠 구글 URL 검색 시 무슨 일이 일어나는지... 컴퓨터가 구글닷컴을 어떻게 이해하는지 한번 보자.  

우선 Https://를 사용하기로 했으니 TCP연결을 한다는 것이고.. TCP 연결할 서버 주소를 찾아야한다. 그것이 바로 `DNS`

`DNS? Domain Name System`
www.google.com을 예로 들면 www를 제외한 나머지를 지칭하는 말이다. 

왜 이 말은 처음으로 시작했냐면....

원래는 IP 주소인 123.456.789.000을 검색해서 들어가야 하는데 일일이 다 외울 수 없지 않은가? 

>우리도 누군가에게 전화할 때 전화번호부에서 이름을 검색해서 찾듯이 우리에게 도움 주는 프로토콜이 바로 `DNS`다.  
{: .prompt-info}
  
![image](https://github.com/mskim0425/mskim0425.github.io/blob/main/images/internet/2DNS%EC%9E%91%EB%8F%99%EC%9B%90%EB%A6%AC.jpg?raw=true)


물론 host 파일이나 DNS cache 데이터가 있으면 아래와 같은 일 작동하지않는다.  
BUT 우린 지금은 둘다 정보가 없다는 가정하에 설명을 하겠다.   
PC가 아래의 순서대로 질의를 시작한다.  

## `DNS 작동원리`
1. 브라우저에서 구글로 접속하려고 하는데 구글 서버의 IP를 모르는 상황

2. 브라우저는 pc에 설정된 로컬 dns서버로 이동함. (통신사마다 local서버가 다르고, 또한 주소가 캐싱되어있다면 바로 반환함)

3. 주소 값이 어딨는지 모르면 root 서버에게 요청을 보냄 (root dns 서버는 전 세계에 13군데가 있음)

4. root서버는. com이라는 주소 값을 local dns서버로 반환함 그걸 토대로. com 담당 서버에게 보내줘서 해당 주소를 반환함.

5. com서버가 보내준 결과를 토대로 google.com서버에 가서 주소 값을 얻어와서 마침내 브라우저에게 반환하고... ※ 여기서 장난질 치는 게 dns 스푸핑


6. 브라우저에서 반환된 주소 값으로 구글 서버로 접속하게 된다.


`A Record는 뭐고 CNAME은 또 뭐지?`

A Record - IP와 도메인과의 직통 연결 *구글 행님과의 직통전화*  
010.123.12.123 <=> 주소

CNAME (canonical name) - IP가 유동적으로 변하는 서버를 위한 도메인 방식 (aws, firebase를 사용할 때 쓰는 방식)

A record는 직접적으로 IP가 할당되어 있기 때문에 IP가 변경되면 직접적으로 도메인에 영향을 미치지만, CNAME은 도메인에 도메인이 매핑되어 있기 때문에 IP의 변경에 직접적인 영향을 받지 않는다. 나의 블로그도 CNAME으로 매핑되어있는 상황이다. 원주소는 [ms92kim/github.io](https://mskim0425.github.io/) 였다.

---

![image](https://github.com/mskim0425/mskim0425.github.io/blob/main/images/internet/3httprequest.png?raw=true)

그럼 HTTP request 메시지를 구글 웹서버(포트 80)에게 보내는 것이다. 이 request를 위해서는 패킷을 만들어야 한다.


| 기본적인 HTTP 구조  |   |   |   |   |
|:---:|:---:|:---:|:---:|:---:|
|  Start Line |시작라인|   |   |   |
|Header|헤더|   |   |   |
|empty line   |공백라인   |   |   |   |
| Message body  |  메시지 바디 |


자세한 구조가 궁금하다면 CLI 창에 아래와같이 치면된다.

       curl -v www.google.com?query==http

위와 같은 패킷을 통해  전송계층으로 진행한다면 TCP가 두두둥장한다.

---

## `TCP/전송계층`

Transport layer(전송계층)은 한 줄로 요약하면 **`"End point 간 신뢰성 있는 데이터 전송을 담당하는 계층"이다`**

여기서 신뢰성은 `데이터를 순차적, 안정적으로 전달` 하는 걸 의미하고
전송은 포트 번호에 해당하는 프로세스에 데이터를 전달하는 것을 의미한다.

이외에도 TCP 프로토콜은 양방향 통신(3 way handshake), 흐름 제어, 혼합 제어, 오류 감지를 한다. (flow control,
Congestion Control, Error Detection)

 

TCP에서는 프로토콜 데이터 단위(PDU)로 세그먼트(Segment)를 사용하는데 큰 데이터를 잘게 잘라서

BIG Data → (TCP Header + Data) + (TCP Header + Data) + (TCP Header + Data) 식으로 만든다.

좀 더 자세히 알아보기 위해 아래 그림을 보자


![image](https://github.com/mskim0425/mskim0425.github.io/blob/main/images/internet/4TCP%20IP%20HEADER.jpg?raw=true)

#
 


## **TCP IP HEADER**

처음 보면 이거 뭐고...?라는 생각이 들것이다. 물론 당연한 생각이다. 하지만 여기선 빨간색으로 된 부분에 대한 얘기만 할 것이다. header에 이런 내용이 담겨있구나 정도만 알면 된다. 빨간색 부분 즉 `컨트롤 비트`를 이해하기 위해 3-way handshake로 설명하겠다.

![image](https://github.com/mskim0425/mskim0425.github.io/blob/main/images/internet/5_1_3way%20handshake%20(connetion%20%EC%97%B0%EA%B2%B0).jpg?raw=true)
#

## **3way handshake (connetion 연결)**
1. 처음 클라이언트가 서버에게 연결 요청할 때. SYN 플래그를 사용한다. 

2. SYN에다가 비트를 1로 설정해 패킷을 송신한다.

3. 그럼 서버에서 ACK를 통해서 "내가 받았어!" 이런 제스처를 보낸다. 즉 ACK 비트를 1로 설정해서 패킷을 송신한다.

하지만, 그림에서는 서버에서 보낼 때 SYN도 비트를 1로 한다. 이유는 바로 앞서 말한 양방향 통신이기에 서버 또한 클라이언트한테 요청을 요하는 SYN을 사용한다.

4. 그럼 클라이언트는 서버가 "오 나랑 연결에 응했네?"라며 ACK를 보내어 "나도 받았어"를 전달하는 방식이다. 

 
#
## `3줄 요약.`

`- SYN 연결 뚫을 때 사용함`

`- ACK 뭔가를 받았을 때 보내야 하는 패킷, 만약 못 받았다? 그럼 일정 시간 있다가 또 패킷을 쏜다.`

`- 이를 토대로 packet을 왔다 갔다 함.`

 

## **4 way handshake (connection close)**

통신을 종료할 때 사용되면서, 3 way와 비슷하게 "다 보냈어?"를 확인하는 FIN을 이용하는 것이 추가되었다.


<img src="https://github.com/mskim0425/mskim0425.github.io/blob/main/images/internet/5_4%20way%20handshake%20(connection%20close.jpg?raw=true">

# 

이렇게 신뢰성도 보장해주고 흐름 제어도 해주고 만능인 것 같은 TCP도 사실 문제점이 있다.

패킷을 중간에 잃어버리거나 도달하지 못하면 재전송해야 하는 점과 시간 손실이 발생된다.

 

그래서 나온 게 UDP이다.

순차 전송도 안 하고 흐름 제어도 안되고 혼잡 제어도 안되지만 전송 속도가 빠른 프로토콜이다.

이유는 TCP는 데이터를 쪼개는 반면 UDP는 데이터 앞에 header만 장착 후 발송하기 때문이다.

그래서 영상 스트리밍에서 자주 사용된다. (데이터의 신뢰성이 중요하지 않기 때문이다.)

 

자 아무튼 이렇게 HandShaking을 통해서 드디어 연결이 이루어지고 데이터가 오가게 된다.

그럼 데이터를 우쨰 보내야 하나....?

 --- 

## IP 인터넷 계층 + Network Access Layer

우리가 쓰는 컴퓨터는 보통 Private IP를 사용하고 있다. 그래서 공유기가 우리 소중한 IP주소를 public ip주소로 변환해준다.

이것을 NAT (Network Address Translation)이라 한다. 그럼 변환된 친구는 수많은 라우터를 거쳐 목적지 서버까지 도착하게 된다.

이제 아래의 그림을 보자.

![image](https://github.com/mskim0425/mskim0425.github.io/blob/main/images/internet/6%20ARP%20%EA%B5%AC%EB%8F%84%EB%B0%A9%EC%8B%9D.jpg?raw=true)

  


ARP 구도방식
라우팅을 거쳐 구글 서버와 연결된 라우터에 데이터가 도착하면 시스템 A 상황에 온다. 그럼 노란색 말풍선처럼 IP해더가 기록된 구글 서버의 IP주소를 통해 MAC 주소를 얻어오려고 한다. 이때 사용되는 친구가 ARP다. 이 친구는 라우터가 연결된 네트워크로 브로드캐스팅시켜주는 프로토콜이다. 요청을 받은 system B (구글 서버)는 오케이! 너구나 하고 MAC 주소로 응답해준다. 

 

이제야 목적지 구글 서버의 MAC 주소를 이해했으니 데이터가 물리적으로 전달될 수 있는 것이다.

 

데이터가 전송되었으니 이제 상호 간의 교류를 할 수 있다.  Transport layer 전송계층을  목적지 포트번호를 통해서 이것을 보고 해당 번호에 데이터를 전달해야 주고 Application layer에 다다르면 웹 서버가 사용될 HTTP Request 데이터를 GET 요청을 통해 적절하게 데이터를 얻을 수 있게 된다. 
#
 ![image](https://github.com/mskim0425/mskim0425.github.io/blob/main/images/internet/7%20%EC%9E%90%EC%A3%BC%20%EC%82%AC%EC%9A%A9%EB%90%98%EB%8A%94%20%ED%8F%AC%ED%8A%B8%EB%B2%88%ED%98%B8.jpg?raw=true)
 

자주 사용되는 포트번호
 

이러한 HTTP 요청과 응답 과정이 끝나면 연결을 종료해야 하는데 앞서 말한 4 handshaking 가 사용된다. 추가적으로 모든 과정이 끝나도 도착하지 못한 패킷이 있을 수도 있어서 일정 시간 소캣을 열어놓는다. 그런 잉여 패킷을 기다리는 상태를 TIME_WAIT이라 한다.