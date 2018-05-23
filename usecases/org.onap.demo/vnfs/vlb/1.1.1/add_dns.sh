#!/bin/bash

if [ ! "$#" -eq 1 ]
then
  echo "Usage: ./add_dns.sh [remote DNS server]"
  exit
fi

DNS_IPADDR=$1
IP_TO_PKTGEN_NET=$(cat /opt/config/ip_to_pktgen_net.txt)
IP_TO_DNS_NET=$(ifconfig eth2 | grep "inet addr" | tr -s ' ' | cut -d' ' -f3 | cut -d':' -f2 | awk -F '.' '{printf("99.99.99.%d", $4)}')
DNS_IPADDR_GRE=$(echo $DNS_IPADDR | awk -F '.' '{printf("99.99.99.%d", $4)}')
GRE_IPADDR="99.99.99.99"

VXLAN_ID=$(echo $DNS_IPADDR | awk -F '.' '{printf("%d", $4)}')

ovs-vsctl del-port ovsbr999 vxlan$VXLAN_ID
ovs-vsctl add-port ovsbr999 vxlan$VXLAN_ID -- set interface vxlan$VXLAN_ID type=vxlan options:key=$VXLAN_ID options:remote_ip=$DNS_IPADDR

sleep 3

vppctl lb as $IP_TO_PKTGEN_NET"/32" $DNS_IPADDR_GRE
sleep 1
GRE=$(vppctl create gre tunnel src $IP_TO_DNS_NET dst $DNS_IPADDR_GRE)
sleep 1
vppctl set int ip address $GRE $GRE_IPADDR"/32"
vppctl set int state $GRE up

# Update the number of vDNSs currently active
FD="/opt/VES/evel/evel-library/code/VESreporting/active_dns.txt"
CURR_DNS=$(cat $FD)
let CURR_DNS=$CURR_DNS+1
echo $CURR_DNS > $FD
