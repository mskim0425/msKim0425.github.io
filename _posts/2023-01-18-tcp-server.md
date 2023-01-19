---
layout: post
title:  "서버에 저장된 FILE 가져오는 로직"
date:   2023-01-18 17:21:07 +0900
categories: [CS , Internet]
tags: [cs, internet] 
---

## <span style="color: gold"> 서버에 저장된 FILE 클라이언트에게 가져오기 </span>  
> 이 페이지는 다크모드 기반으로 그림을 그렸습니다.
> 클릭하면 더 커집니다.
{: .prompt-tip}

서버에서 저장된 파일을 가져올 떄 어떤 흐름으로 작동되는지 최근 한 영상을 보고 
 꺠달음을 얻고   
 해당 지식을 나의 해석방식과 나의 그림으로 그려냈다. [영상 링크](https://www.youtube.com/watch?v=K9L9YZhEjC0&t=1341s)

<img src="https://github.com/msKim92/msKim92.github.io/blob/main/images/internet/%EA%B7%B8%EB%A6%BC1.png?raw=true">  
<center> 서버 쪽 이미지 </center>
 　　 
 　　   

`1` File A.bmp를 찾아 READ를 시작한다.
DB → 드라이버  → 파일시스템을 거쳐 웹서버의 메모리영역 (*버퍼에 도달.*)

`2` A.bmp 1.4MB파일을 64kb 크기로 쪼개 파일 내용을 TCP Buffered I/O(3번)으로 `복사` 시킨다.  
   
`3` IP 단계로 내려오면서 `세그먼트`로 나누어짐 (퍼즐 4개가 64kb인데 더작게 나눠져 보내짐)  
   
`4` 넘버링을 해서 하나의 `패킷`이 된다. 그 패킷은 L2에서 `프레임` 단위로 바뀌어 전송된다.  
   
`5` 인터넷으로 날아갈떄 패킷은 논리적으로 앤드포인트에서 그대로 가지만 프레임은 인터넷을 타고가면서 여러 번 바뀐다.  

`8` window size가 보내려는 사이즈보다 크면 계속 보내고 작다면 wait한다.  
   이로인해 전송이 상당히 딜레이가 될 수 있다.

<img src="https://github.com/msKim92/msKim92.github.io/blob/main/images/internet/%EA%B7%B8%EB%A6%BC2.png?raw=true">
<center>클라이언트 쪽 이미지</center>
 　 
 　　    
    
`6` 인터넷을 타고 클라이언트 사이드로 도착하면서 `프레임이 여러번 바뀐다`. (택배차가 부산→서울 자주 바뀌는것처럼)  
     클라이언트에 도착하면 프레임 안에 있는 패킷을 꺼내는 작업한다.   
     `디캡슐화` (왜 택배오면 상자를 까서 내용물을 확인하는것처럼 말이다.)  

`7` 받아온 세그먼트를 합치는 공간 `window size`라고 한다. 전송이 느려질 때, 인터넷의 속도 문제일수도 있지만 TCP버퍼에  서 FILE I/O버퍼로 빨`리 읽히지 못해 속도가 느려진걸수도 있다`.

`8` 세그먼트를 2개이상 받으면 파일 잘받았다의 의미를 내포하는 `ACK를 서버쪽에 반환`한다. 이때 TCP버퍼에 남아있는 window size를 보내서 서버측에서 wait하고 있는 상태를 풀거나 자리가 남을떄까지 기다리게 한다.   

---

세그먼트(Segment) : 데이터를 네트워크를 통한 실질적인 전송을 위하여 적절한 크기로 분할한 조각.  
  
패킷(Packet) :  전송을 위해 분할된 데이터 조각(세그먼트)에 목적지까지의 전달을 위하여 Source IP 와 Destination IP가 포함된 IP Header가 붙은 형태의 메세지  
  
프레임(Frame) : 최종적으로 데이터를 전송하기 전에 패킷에 Header(Mac Address 포함)와  CRC를 위한 Trailer가 붙은 메세지  