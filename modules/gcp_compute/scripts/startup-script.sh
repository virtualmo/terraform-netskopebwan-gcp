#!/bin/bash

sed -i '/nsglan/d' /etc/iproute2/rt_tables
echo "1    nsglan" | tee -a /etc/iproute2/rt_tables
sleep 2
ip route add ${netskope_ip} src ${netskope_ip} dev ${interface} table nsglan
ip route add default via ${gcp_gw_ip} dev ${interface} table nsglan
ip rule add from ${netskope_ip}/32 table nsglan
ip rule add to ${netskope_ip}/32 table nsglan