#!/usr/bin/env bash
# Verify the full Part 3 build after `netlab up` (templates, no hand config).
# Run from the lab folder:  bash scripts/verify-overlay.sh
set -u
cd "$(dirname "$0")/.." || exit 1
T=$(date +%Y%m%d-%H%M)
OUT="outputs/${T}_verify-overlay.txt"

run() {  # run <node> <command words...>
  local node="$1"; shift
  echo; echo "### $node: $*"
  ( set -f; netlab connect "$node" "$@" )
}

{
echo "# Part 3 verification, $(date)"
run SP-1 show ip bgp summary
run SP-1 show bgp evpn summary
run SP-2 show bgp evpn summary
run LS-1 show ip interface brief
run LS-1 show ip route 10.255.1.13
run LS-1 ping 10.255.1.13 source 10.255.1.11 size 9000 df-bit repeat 2
run LS-1 show bgp evpn summary
run LS-1 show interfaces Vxlan1
run host-1 ping -c 3 172.16.10.12
run LS-3 show vxlan vtep
run LS-3 show vxlan flood vtep
run LS-3 show mac address-table vlan 10
run LS-3 show bgp evpn instance
run LS-3 show bgp evpn route-type imet detail
run LS-3 show bgp evpn route-type mac-ip detail
} 2>&1 | tee "$OUT"
echo ">> saved $OUT"
