
**iptables DNAT 설정 스크립트입니다.**

[https://github.com/copyrat90/iptables\_DNAT\_Scripts](https://github.com/copyrat90/iptables_DNAT_Scripts)

**Q. 이 스크립트는 어떤 역할을 하나요?**

1. 외부에서 들어오는 SSH 와 HTTP 패킷의 포트번호 끝 3자리를 기준으로 대응되는 인스턴스로 연결되도록 iptables 로 Destination NAT 설정을 합니다.

말이 참 어렵네요.  아래에 좀 더 풀어 써 보겠습니다.



라우터와 외부 인터넷을 연결하는 NIC에서 패킷이 들어올겁니다.

SSH 의 경우 19xxx, HTTP 의 경우 18xxx 로 들어올텐데요.

뒷자리 xxx 를 확인해 192.168.0.xxx:(22 or 80) 으로 연결되도록 패킷의 경로를 다시 써(Network Address Translation)줍니다.

좀 더 이해하기 편하라고 그림을 준비했으니 확인해보세요.


![DNAT](https://user-images.githubusercontent.com/34793045/54202569-aebfa080-4513-11e9-8b3a-6cbdaed47f0c.png)
![DNAT(1)](https://user-images.githubusercontent.com/34793045/54202570-af583700-4513-11e9-81c4-2aa231c7e2ce.png)


가운데 Router 가  DNAT 을 수행할 수 있도록 라우터의 iptables 를 수정합니다.

핵심이 되는 명령어는 아래와 같습니다.

네트워크 관련 지식이 부족해 설명이 부정확할 수 있습니다.

[라우터 이름 확인]

sudo ip netns

[NIC 이름 확인]

sudo ip netns exec (라우터이름) ifconfig

[NAT 설정 확인]

sudo ip netns exec (라우터이름) iptables -t nat -vnL

[DNAT 설정 추가 (Add)]

sudo ip netns exec (라우터이름) iptables -t nat -A PREROUTING -i (NIC이름) -p tcp --dport 19xxx -j DNAT --to-destination 192.168.0.xxx:22

sudo ip netns exec (라우터이름) iptables -t nat -A PREROUTING -i (NIC이름) -p tcp --dport 18xxx -j DNAT --to-destination 192.168.0.xxx:80

sudo ip netns exec (라우터이름) iptables -t nat -A PREROUTING -i (NIC이름) -p udp --dport 18xxx -j DNAT --to-destination 192.168.0.xxx:80

[보너스 - MASQUERADE 설정 추가 (Add) : 편한 SNAT(?)]

sudo ip netns exec (라우터이름) iptables -t nat -A POSTROUTING -o (NIC이름) -j MASQUERADE



ip netns (라우터이름) exec ~

        라우터 이름이라고 썼지만 정확히는 네트워크 네임스페이스(netns) 이름입니다.

        지정한 네트워크 네임스페이스에 대해 exec 뒤의 명령어를 수행합니다.

        참고로 라우터에는 외부용/내부용 NIC 가 각각 1개 이상이라 최소 2개의 NIC가 있습니다.

iptables (-t nat) ~

        리눅스 커널 방화벽이 제공하는 테이블의 규칙을 관리하는 명령어입니다.

        그냥 쓰면 네트워크 필터를 관리하고, -t nat 옵션을 주면 NAT 규칙을 관리합니다.

 -A

                규칙 추가(Add)입니다.  반대로 규칙 삭제는 -D 입니다.

 PREROUTING

                패킷이 들어오면 가장 먼저 PREROUTING 단의 규칙을 검사합니다.

                Destination NAT 을 하려면 PREROUTING 단에 규칙을 추가해야합니다.

반대로 Source NAT 은 POSTROUTING 단에 규칙을 추가해야합니다.

정확한 원리는 저도 잘 모르겠습니다.

        -i (NIC 이름)

DNAT 을 할 패킷이 들어오는 장치를 설정합니다.

라우터와 인터넷을 Public IP 로 연결하는 NIC로 설정해야합니다.

그래야 외부에서 들어오는 패킷을 받을 수 있겠죠?

참고로 NIC(Network Interface Controller)는 흔히 랜 카드라고 부르는 것입니다.

 -p tcp / -p udp

                프로토콜을 TCP 혹은 UDP 로 설정합니다.

  SSH 는 TCP 를 사용하고, HTTP 는 TCP / UDP 를 모두 사용합니다.

                한 번에 설정이 안 되므로 HTTP DNAT 설정은 명령어 두 줄을 써야 합니다.

                참고 : [잘 알려진 포트 목록](https://ko.wikipedia.org/wiki/TCP/UDP%EC%9D%98_%ED%8F%AC%ED%8A%B8_%EB%AA%A9%EB%A1%9D)

        --dport (포트번호)

                외부에서 들어오는, 규칙을 적용받을 패킷의 포트 번호입니다.

                우리는 SSH 는 19xxx , HTTP 는 18xxx 을 사용하도록 설정할겁니다.

 -j DNAT

동작을 DNAT 으로 설정합니다.

--to-destination (내부IP주소):(포트번호)

                목적지 주소를 설정합니다.  이 주소로 패킷의 경로가 재설정됩니다.

                도착할 주소는 특정한 내부 인스턴스가 되겠죠.

 xxx

                여기다가는 내부 IP 뒷주소를 적습니다.

                당연히 xxx 를 그대로 적으면 안 됩니다.

변수를 2~254까지 반복문으로 돌리면서 명령어를 지정하면 됩니다.

참고로 0, 1, 255 는 인스턴스 용도로 사용하지 않습니다.  이유는 생략…





그러면 이제 스크립트를 사용해보도록 합시다.

ssh 로 연결해 작업해주므로 굳이 스크립트 파일을 컨트롤러 컴퓨터로 옮길 필요는 없습니다.

ssh 접속할 때는 컨트롤러에서 sudo 를 사용할 권한이 있는 사용자로 접속해야합니다.

![01](https://user-images.githubusercontent.com/34793045/54202380-41ac0b00-4513-11e9-8ca5-5d772639a296.png)
![02](https://user-images.githubusercontent.com/34793045/54202382-4244a180-4513-11e9-985c-45a986ad110c.png)
![03](https://user-images.githubusercontent.com/34793045/54202385-4244a180-4513-11e9-9dbf-efddadf19029.png)
![04](https://user-images.githubusercontent.com/34793045/54202386-42dd3800-4513-11e9-9376-4fa1ba429182.png)
![05](https://user-images.githubusercontent.com/34793045/54202387-42dd3800-4513-11e9-845d-8f4b26a695a0.png)
![06](https://user-images.githubusercontent.com/34793045/54202388-42dd3800-4513-11e9-9d7f-4eb56f9365ca.png)


보시다시피 잘 작동합니다.

컨트롤러에서 설정을 확인해보면 2~254 에 대해 잘 설정된 것을 볼 수 있습니다.

 ![07](https://user-images.githubusercontent.com/34793045/54202390-4375ce80-4513-11e9-8334-6b01bf7dd5c6.png)

**Q. 설정이 너무 많아서 지저분한데요?**

1. 네 저도 동의합니다.

2~254 전부 포워딩 할 필요 없는 분들은 스크립트의 반복문을 수정해서 줄이시면 됩니다.

그런데 포트/IP 범위 기반 NAT 이 불가능하기 때문에 규칙이 이렇게 많은 건 어쩔 수가 없습니다.



**Q. 스크립트에 버그가 있어요.**

1. 네 예외 처리 같은 작업은 하지 않았습니다.

sudo 권한 있는 사용자로 접속하세요.  잘못 입력하지 마세요.

혹시 진짜 제대로 했는데 버그가 난다면… 직접 고쳐 쓰세요.

