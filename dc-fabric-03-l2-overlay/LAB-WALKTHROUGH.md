# DC Fabric Part 3: Lab walkthrough (study copy)

The clean path from `netlab up` to a working Layer 2 EVPN overlay, one step
at a time. Each step: goal, config, checks, what you should see.
"Break it" boxes are optional: they recreate a failure we hit on purpose,
with the NOTES.md step that has the original evidence.

Conventions:
- Config: `netlab connect <node>`, paste at the `#` prompt.
- Checks: `cap <node> "<command>"` (saves to outputs/). For plain
  `netlab connect` to a host, do NOT quote the command.
- A `netlab up` wipes everything typed by hand. HAND-CONFIG.md has it all.

Addressing at a glance:

| Device | ASN   | Lo0 (router-id, EVPN peering) | Lo1 (VTEP)  |
|--------|-------|-------------------------------|-------------|
| SP-1   | 65001 | 10.1.1.1                      | -           |
| SP-2   | 65002 | 10.2.2.2                      | -           |
| LS-1   | 65101 | 10.11.11.11                   | 10.255.1.11 |
| LS-2   | 65102 | 10.12.12.12                   | 10.255.1.12 |
| LS-3   | 65103 | 10.13.13.13                   | 10.255.1.13 |

Hosts: host-1 172.16.10.11/24 on LS-1 Et3, host-2 172.16.10.12/24 on LS-3 Et3.
VLAN 10 <-> VNI 10010, route target 10010:10010 on every leaf.

---

## Step 0: Bring it up and check the underlay

```bash
cd ~/netlab-labs/Next-Hop-Labs/dc-fabric-03-l2-overlay
netlab up
```
Wait a minute, then:
```bash
cap LS-1 "show ip bgp summary"
cap LS-1 "show ip route bgp"
```
You should see: two sessions Estab (SP-1, SP-2); other leaf Lo0s with two
next hops each (ECMP from Part 1).

## Step 1: MTU (already in topology.yml)

Goal: VXLAN adds 50 bytes and must not fragment.
```bash
cap LS-1 "show ip interface brief"
cap LS-1 "ping 10.13.13.13 source 10.11.11.11 size 9000 df-bit repeat 2"
```
You should see: Ethernet1/2 at 9194 (netlab's EOS maximum), 9000-byte DF
ping succeeds. Hosts stay at 1500 on purpose. (NOTES Step 1)

## Step 2: The "before"

```bash
cap host-1 "ping -c 3 172.16.10.12"
```
You should see: 100% loss. Same VLAN, same subnet, nothing joins LS-1's
VLAN 10 to LS-3's. (NOTES Step 2)

## Step 3: Loopback1 (VTEP) and the underlay policy

Goal: every VTEP reachable over the underlay. Part 1's prefix-lists only
allow Lo0, so they need one range entry for the VTEP block.

SP-1 and SP-2 (identical):
```
configure
ip prefix-list PL-UNDERLAY-IN
   seq 100 permit 10.255.1.0/24 ge 32
ip prefix-list PL-UNDERLAY-OUT
   seq 100 permit 10.255.1.0/24 ge 32
end
```
LS-1:
```
configure
interface Loopback1
   description VTEP
   ip address 10.255.1.11/32
ip prefix-list PL-UNDERLAY-IN
   seq 100 permit 10.255.1.0/24 ge 32
ip prefix-list PL-UNDERLAY-OUT
   seq 20 permit 10.255.1.11/32
router bgp 65101
   address-family ipv4
      network 10.255.1.11/32
end
```
LS-2:
```
configure
interface Loopback1
   description VTEP
   ip address 10.255.1.12/32
ip prefix-list PL-UNDERLAY-IN
   seq 100 permit 10.255.1.0/24 ge 32
ip prefix-list PL-UNDERLAY-OUT
   seq 20 permit 10.255.1.12/32
router bgp 65102
   address-family ipv4
      network 10.255.1.12/32
end
```
LS-3:
```
configure
interface Loopback1
   description VTEP
   ip address 10.255.1.13/32
ip prefix-list PL-UNDERLAY-IN
   seq 100 permit 10.255.1.0/24 ge 32
ip prefix-list PL-UNDERLAY-OUT
   seq 20 permit 10.255.1.13/32
router bgp 65103
   address-family ipv4
      network 10.255.1.13/32
end
```
Checks:
```bash
cap SP-1 "show ip bgp summary"
cap LS-1 "show ip route 10.255.1.13"
cap LS-1 "ping 10.255.1.13 source 10.255.1.11 size 9000 df-bit repeat 2"
```
You should see: SP-1 2/2/5 per leaf; 10.255.1.13 via both spines; jumbo
VTEP-to-VTEP ping works.

> **Break it:** add only Lo1 + the `network` line on LS-1 (no prefix-list
> changes). The route is in LS-1's table but never advertised. Then open
> only LS-1's OUT list: SP-1 shows PfxRcd 2 / PfxAcc 1 (dropped inbound).
> Four filters, none of them log anything. (NOTES Step 3)

## Step 4: EVPN sessions, Lo0 to Lo0

Goal: separate BGP sessions that carry only EVPN.

SP-1:
```
configure
router bgp 65001
   neighbor EVPN peer group
   neighbor EVPN update-source Loopback0
   neighbor EVPN ebgp-multihop 3
   neighbor EVPN send-community extended
   neighbor 10.11.11.11 peer group EVPN
   neighbor 10.11.11.11 remote-as 65101
   neighbor 10.11.11.11 description LS-1-EVPN
   neighbor 10.12.12.12 peer group EVPN
   neighbor 10.12.12.12 remote-as 65102
   neighbor 10.12.12.12 description LS-2-EVPN
   neighbor 10.13.13.13 peer group EVPN
   neighbor 10.13.13.13 remote-as 65103
   neighbor 10.13.13.13 description LS-3-EVPN
   address-family evpn
      neighbor EVPN activate
end
```
SP-2: identical, but `router bgp 65002`.

LS-1:
```
configure
router bgp 65101
   neighbor EVPN peer group
   neighbor EVPN update-source Loopback0
   neighbor EVPN ebgp-multihop 3
   neighbor EVPN send-community extended
   neighbor 10.1.1.1 peer group EVPN
   neighbor 10.1.1.1 remote-as 65001
   neighbor 10.1.1.1 description SP-1-EVPN
   neighbor 10.2.2.2 peer group EVPN
   neighbor 10.2.2.2 remote-as 65002
   neighbor 10.2.2.2 description SP-2-EVPN
   address-family evpn
      neighbor EVPN activate
end
```
LS-2: identical, but `router bgp 65102`. LS-3: identical, but `router bgp 65103`.

Checks:
```bash
cap SP-1 "show bgp evpn summary"
cap LS-1 "show bgp evpn summary"
```
You should see: all Estab, 0 prefixes (nothing to advertise yet).
netlab's `no bgp default ipv4-unicast` keeps these sessions EVPN-only.

## Step 5: VXLAN interface and MAC-VRF

Goal: make each leaf a VTEP for VLAN 10 / VNI 10010.

LS-1:
```
configure
interface Vxlan1
   vxlan source-interface Loopback1
   vxlan udp-port 4789
   vxlan vlan 10 vni 10010
router bgp 65101
   vlan 10
      rd auto
      route-target both 10010:10010
      redistribute learned
end
```
LS-2 (also needs the VLAN; it has no host so netlab didn't create it):
```
configure
vlan 10
   name tenant
interface Vxlan1
   vxlan source-interface Loopback1
   vxlan udp-port 4789
   vxlan vlan 10 vni 10010
router bgp 65102
   vlan 10
      rd auto
      route-target both 10010:10010
      redistribute learned
end
```
LS-3: same as LS-1, but `router bgp 65103`.

Checks:
```bash
cap host-1 "ping -c 3 172.16.10.12"
cap LS-3 "show vxlan vtep"
cap LS-3 "show vxlan flood vtep"
cap LS-3 "show mac address-table vlan 10"
cap LS-3 "show bgp evpn route-type imet detail"
cap LS-3 "show bgp evpn route-type mac-ip detail"
```
You should see:
- ping works, ttl=64 (bridged, no routing hop)
- remote VTEPs: 10.255.1.11 "flood, unicast", 10.255.1.12 "flood" only
  (LS-2 sent a Type 3 but has no host, so no Type 2)
- flood list for VLAN 10: .11 and .12 (built from Type 3 routes)
- host-1's MAC on Vx1 (installed from BGP), host-2's on Et3
- received routes carry `Route-Target-AS:10010:10010 TunnelEncap:tunnelTypeVxlan`,
  next hop = the advertising leaf's VTEP
- Type 2 routes carry a MAC only, no IP

> **Break it: no extended communities.** Remove
> `neighbor EVPN send-community extended` on all five switches. Routes
> still arrive, valid and best, but with no RT and no encapsulation
> community. Nothing is imported: 0 remote VTEPs, ping fails, sessions
> stay up, nothing logs. (NOTES Step 5)

> **Break it: automatic RTs.** On LS-3 replace the RT with
> `route-target export auto` + `route-target import auto 65103`. EOS builds
> 65103:268445466 (RFC 8365 encoding: 0x1000271A = type VXLAN + VNI 10010).
> No other leaf matches it. Fix with automatic RTs needs
> `route-target import any-as:268445466` on every leaf. Restore
> `route-target both 10010:10010` afterwards. (NOTES Step 6a/6b/6c)

## Step 6: Stop the leaves passing EVPN routes between spines

Goal: Part 1's "leaves never transit" rule, for the EVPN address family.
Unique spine ASNs mean AS_PATH loop prevention won't do it for us.

On each leaf (LS-1 shown; use 65102 / 65103 on LS-2 / LS-3):
```
configure
ip as-path access-list AS-LOCAL permit ^$ any
route-map RM-EVPN-OUT permit 10
   match as-path AS-LOCAL
router bgp 65101
   address-family evpn
      neighbor EVPN route-map RM-EVPN-OUT out
end
```
Checks:
```bash
cap host-1 "ping -c 3 172.16.10.12"
cap SP-1 "show bgp evpn summary"
cap SP-2 "show bgp evpn summary"
cap LS-1 "show bgp evpn summary"
```
You should see: each spine receives only what a leaf originates
(LS-1 2, LS-2 1, LS-3 2); LS-1 advertises 2 to each spine. Leaves still have
two paths (one per spine) for every remote route.

> **What it looked like before:** a leaf advertised spine-learned routes to
> the other spine (e.g. LS-1 PfxAdv 5 to SP-2 while originating 2), and the
> spines held paths like `65101 65002 65102`. Which spine got the extras
> depended on tiebreaks and moved between captures. (NOTES Step 5, Step 7)

## Step 7: Watch ARP

Goal: confirm ARP still floods (Type 2 routes have no IP to answer from).
```bash
sudo -v
F=outputs/$(date +%Y%m%d-%H%M)_host-2_tcpdump-arp-test.txt
{
sudo ip netns exec clab-l2-overlay-host-2 timeout 40 tcpdump -n -e -l -i eth1 arp > /tmp/arp-cap.txt 2>&1 &
sleep 2
for i in 1 2; do
  netlab connect host-1 ip neigh flush dev eth1
  netlab connect host-1 ip neigh show dev eth1
  netlab connect host-1 ping -c 1 172.16.10.12
  sleep 3
done
wait
cat /tmp/arp-cap.txt
} 2>&1 | tee "$F"
```
You should see: two broadcast `who-has 172.16.10.12` requests from host-1
reach host-2, and host-2 answers both. No leaf proxies. (NOTES Step 8)

## Step 8: See VXLAN on the wire

```bash
bash scripts/capture-vxlan.sh
```
Captures LS-1's uplinks (et1 = Ethernet1 to SP-1, et2 = Ethernet2 to SP-2;
cEOS ports are et1/et2 inside the container, not eth1) while host-1 ARPs
and pings host-2. You should see: the ARP broadcast leave LS-1 twice (to
10.255.1.12 and 10.255.1.13), ICMP unicast to .13 only, VNI 10010, exactly
50 bytes added (98-byte inner frame, 148-byte outer). The .pcap files open
in Wireshark. (NOTES Step 9)

## When you're done

```bash
netlab down
```
