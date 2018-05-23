#!/bin/bash

LB_OAM_INT=$(cat /opt/config/lb_oam_int.txt)
LB_PRIVATE_INT=$(cat /opt/config/lb_private_ipaddr.txt)
PID=$(cat /opt/config/local_private_ipaddr.txt)
VERSION=$(cat /opt/config/demo_artifacts_version.txt)

VXLAN_ID=$(ifconfig eth1 | grep "inet addr" | tr -s ' ' | cut -d' ' -f3 | cut -d':' -f2 | awk -F '.' '{printf("%d", $4)}')

sleep 1
ovs-vsctl del-port ovsbr999 vxlan$VXLAN_ID
sleep 1
ovs-vsctl del-port ovsbr999 vi0
sleep 1
ovs-vsctl del-br ovsbr999
sleep 1
ovs-vsctl add-br ovsbr999
sleep 1
ovs-vsctl add-port ovsbr999 vxlan$VXLAN_ID -- set interface vxlan$VXLAN_ID type=vxlan options:key=$VXLAN_ID options:remote_ip=$LB_PRIVATE_INT

#changed to LB_PRIVATE_INT for azure(LB_OAM_INT)
java -jar dns-client-$VERSION.jar $PID $LB_PRIVATE_INT 8888 10 0
