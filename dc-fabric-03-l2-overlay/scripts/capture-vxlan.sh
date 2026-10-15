#!/usr/bin/env bash
# Capture VXLAN (udp/4789) on LS-1's two uplinks while host-1 ARPs and pings host-2.
# Run from the lab folder:  bash scripts/capture-vxlan.sh
set -u
cd "$(dirname "$0")/.." || exit 1
sudo -v || exit 1
T=$(date +%Y%m%d-%H%M)
NS=clab-l2-overlay-LS-1

for i in et1 et2; do
  sudo ip netns exec "$NS" timeout 25 tcpdump -nn -U -Z root -i "$i" \
    -w "outputs/${T}_LS-1_${i}_vxlan.pcap" udp port 4789 \
    2>"outputs/${T}_LS-1_${i}_tcpdump.log" &
done
sleep 2

netlab connect host-1 ip neigh flush dev eth1
netlab connect host-1 ping -c 3 172.16.10.12
wait

sudo chown "$USER" outputs/${T}_LS-1_* 2>/dev/null
for i in et1 et2; do
  { echo "### LS-1 $i (Ethernet${i#et}) udp port 4789"
    tcpdump -nn -e -v -r "outputs/${T}_LS-1_${i}_vxlan.pcap"
  } 2>&1 | tee "outputs/${T}_LS-1_${i}_vxlan.txt"
done
echo ">> tcpdump logs: outputs/${T}_LS-1_et*_tcpdump.log"
