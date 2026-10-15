#!/usr/bin/env bash
# ECMP test: 8 host flows (8 extra source IPs on host-1) to host-2.
# Captures VXLAN on both LS-1 uplinks to see UDP source ports and spine choice.
# Run from the lab folder:  bash scripts/ecmp-test.sh
set -u
cd "$(dirname "$0")/.." || exit 1
sudo -v || exit 1
T=$(date +%Y%m%d-%H%M)
NS=clab-l2-overlay-LS-1
ALIASES="21 22 23 24 25 26 27 28"
OUT="outputs/${T}_LS-1_ecmp-test.txt"

{
echo "### LS-1 interface counters BEFORE"
netlab connect LS-1 show interfaces Ethernet1-2 counters

echo "### adding source addresses 172.16.10.21-28 on host-1"
for a in $ALIASES; do netlab connect host-1 ip addr add 172.16.10.$a/24 dev eth1 >/dev/null; done
netlab connect host-1 ip -4 addr show dev eth1

for i in et1 et2; do
  sudo ip netns exec "$NS" timeout 40 tcpdump -nn -U -Z root -i "$i" \
    -w "outputs/${T}_LS-1_${i}_ecmp.pcap" udp port 4789 \
    2>"outputs/${T}_LS-1_${i}_ecmp-tcpdump.log" &
done
sleep 2

for a in $ALIASES; do
  echo "### ping from 172.16.10.$a"
  netlab connect host-1 ping -c 2 -I 172.16.10.$a 172.16.10.12
done
wait

echo "### LS-1 interface counters AFTER"
netlab connect LS-1 show interfaces Ethernet1-2 counters

echo "### removing source addresses from host-1"
for a in $ALIASES; do netlab connect host-1 ip addr del 172.16.10.$a/24 dev eth1 >/dev/null; done

sudo chown "$USER" outputs/${T}_LS-1_* 2>/dev/null
for i in et1 et2; do
  echo "### LS-1 $i (Ethernet${i#et}) udp port 4789"
  tcpdump -nn -r "outputs/${T}_LS-1_${i}_ecmp.pcap"
done
} 2>&1 | tee "$OUT"
echo ">> saved $OUT"
