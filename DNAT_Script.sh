#!/bin/bash

# iptables 로 ssh, http 를 DNAT 설정하는 스크립트
# ssh  == (Public IP):19xxx -> 192.168.0.xxx:22
# http == (Public IP):18xxx -> 192.168.0.xxx:80
# 위와 같이 포트 번호를 기준으로 내부 인스턴스로 DNAT
# 자세한 설명은 readme.md 를 참고하세요.


controller_ip=""
controller_ssh_port=""
ssh_public_port_prefix="19"    # ssh  19xxx -> 22
http_public_port_prefix="18"   # http 18xxx -> 80
ssh_inner_port="22"
http_inner_port="80"
inner_net_prefix="192.168.0."


echo "iptables DNAT 설정 스크립트입니다."
echo ""
echo "ssh  == (Public IP):${ssh_public_port_prefix}xxx -> ${inner_net_prefix}xxx:${ssh_inner_port}"
echo "http == (Public IP):${http_public_port_prefix}xxx -> ${inner_net_prefix}xxx:${http_inner_port}"
echo ""
while [[ -z $controller_ip ]]; do
    echo -n "컨트롤러 IP : "; read controller_ip
done
while [[ -z $controller_ssh_port ]]; do
    echo -n "컨트롤러 SSH Port : "; read controller_ssh_port
done
echo ""
echo "컨트롤러($controller_ip)에 ssh 로 접속합니다."
echo -n "username : "; read username;

ssh $username@$controller_ip -p $controller_ssh_port /bin/bash << '____HERE'
    echo ""
    for i in $(sudo ip netns); do
        if [[ $i != [0-9]* ]] && [[ $i != \(* ]]; then
	    echo "======= router name : $i ======="
            sudo ip netns exec $i ifconfig | egrep -w "mtu|inet"
            echo ""
        fi
    done
____HERE

    
    echo "DNAT 설정을 할 가상 라우터 및 NIC 정보를 입력해주세요."
    echo -n "router name  : "; read router_name;
    echo -n "out NIC name : "; read nic_name;
    echo ""
    while [[ $option != A ]] && [[ $option != D ]]; do
        echo -n "설정을 하시려면 A, 지우시려면 D 를 입력하세요 : "
        read option
    done
    echo ""

# EOF로 호출하면 내부 변수 참조 불가.
# ____HERE로 호출하면 외부 변수 참조 불가.
# 대체 어쩌라는... 매개 변수로 넘기자.

ssh $username@$controller_ip -p $controller_ssh_port /bin/bash -s ${router_name} ${option} ${nic_name} ${ssh_public_port_prefix} ${inner_net_prefix} ${ssh_inner_port} ${http_public_port_prefix} ${http_inner_port} << '____HERE' 
i=2
if [ ${2} = "A" ]; then
	text="완료"
elif [ ${2} = "D" ]; then
	text="삭제"
else
	echo "잘못된 옵션입니다. A 또는 D 를 입력하세요."
	exit 0
fi
while [ $i -lt 255 ]; do
	sudo ip netns exec ${1} iptables -t nat -${2} PREROUTING -i ${3} -p tcp --dport ${4}$(printf '%03d' $i) -j DNAT --to ${5}$(printf '%d' $i):${6}
	sudo ip netns exec ${1} iptables -t nat -${2} PREROUTING -i ${3} -p tcp --dport ${7}$(printf '%03d' $i) -j DNAT --to ${5}$(printf '%d' $i):${8}
	sudo ip netns exec ${1} iptables -t nat -${2} PREROUTING -i ${3} -p udp --dport ${7}$(printf '%03d' $i) -j DNAT --to ${5}$(printf '%d' $i):${8}
	echo "${5}$(printf '%d' $i) 의 DNAT 설정이 ${text}되었습니다."
	((i++))
	done
	echo ""
	echo "모든 설정이 ${text}되었습니다."
____HERE
