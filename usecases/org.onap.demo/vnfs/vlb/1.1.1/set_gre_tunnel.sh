#!/bin/bash

if [ ! "$#" -eq 1 ]
then
  echo "Usage: ./set_gre_tunnel.sh [LB public IP address]"
  exit
fi

LB_PUBLIC_IP=$1
LB_PRIVATE_IP=$(cat /opt/config/lb_private_ipaddr.txt | awk -F '.' '{printf("99.99.99.%d", $4)}')
MY_PRIVATE_IP=$(ifconfig eth1 | grep "inet addr" | tr -s ' ' | cut -d' ' -f3 | cut -d':' -f2 | awk -F '.' '{printf("99.99.99.%d", $4)}')
PG_PRIVATE_IP=$(cat /opt/config/pg_private_ipaddr.txt)

sed -i "s/x.x.x.x/"$LB_PUBLIC_IP"/g" /etc/bind/named.conf.options

ovs-vsctl add-port ovsbr999 vi0 -- set Interface vi0 type=internal
ifconfig vi0 $MY_PRIVATE_IP netmask 255.255.255.0
ip tunnel add gre123 mode gre remote $LB_PRIVATE_IP local $MY_PRIVATE_IP ttl 255
ip link set gre123 up
ip addr add $LB_PUBLIC_IP"/32" dev gre123
route add $PG_PRIVATE_IP"/32" dev gre123
#ifconfig eth0 down

service bind9 restart
