# Field notes: DC Fabric Part 3, Layer 2 EVPN overlay

Raw notes from lab runs. Copy the step block below for each test step.

---

## Step N: <what is being tested>

**Date:**
**Topology / state:** (topology.yml or topology-etr.yml; templates applied)

**Expected:**

**Observed:**

**Captures (outputs/):**
-

**Surprises / questions:**

**Reactions:**


---

## Step 0: Gate 0, underlay rebuilds from files

**Date:** 2026-10-15
**Topology / state:** Part 1 files copied unchanged (name: l2-overlay); all three underlay templates applied

**Expected:** LS-1 two sessions Estab; other leaf Lo0s with two next hops; SP-1 three sessions.

**Observed:** As expected. LS-1 PfxRcd 3 / PfxAdv 1 per spine; 10.12.12.12 and 10.13.13.13 via both spines; spine loopbacks single path. SP-1 PfxRcd 1 / PfxAdv 3 per leaf.

**Captures (outputs/):**
- 20261015-0748_LS-1_show-ip-bgp-summary.txt
- 20261015-0748_LS-1_show-ip-route-bgp.txt
- 20261015-0748_SP-1_show-ip-bgp-summary.txt

**Surprises / questions:** First `netlab up` failed: "address 192.168.121.103 is already reserved". Cause: five stopped containers from an old RR lab whose folder had been renamed, so netlab had lost track of it. Fixed with `containerlab destroy --name LB003RouteRe --cleanup`. Lesson: `netlab down` before renaming a lab folder.

**Reactions:**

---

## Step 1: MTU before anything else

**Date:** 2026-10-15
**Topology / state:** Step 0, then `mtu:` added to the spines and leaves groups

**Expected:** Fabric links at 1500 (netlab/cEOS default), no room for 50 bytes of VXLAN.

**Observed:** Ethernet1-3 at 1500 on LS-1 and SP-1. `mtu: 9214` (Arista sample value) rejected by netlab: "Node MTU 9214 ... is higher than the maximum MTU for eos (9194)". Set 9194 on switch groups only (hosts stay 1500). After rebuild: Ethernet1/2 at 9194, Management0 still 1500, BGP back, 9000-byte DF ping Lo0 to Lo0 succeeds (ttl=63, one spine hop).

**Captures (outputs/):**
- 20261015-0750_LS-1_show-ip-interface-brief.txt
- 20261015-0750_SP-1_show-ip-interface-brief.txt
- 20261015-0801_LS-1_show-ip-interface-brief.txt
- 20261015-0801_LS-1_show-ip-bgp-summary.txt
- 20261015-0801_LS-1_ping-10131313-source-10111111-size-9000-.txt

**Surprises / questions:** netlab caps EOS MTU at 9194 (source of the limit not yet checked). Part 4 SVI MTU becomes 9144, not Arista's 9164. MTU deliberately NOT set globally: a host at 9194 + 50 bytes would exceed the fabric. A single DF ping proves only one ECMP path.

**Reactions:**

---

## Step 2: Hosts and VLAN 10 (the "before")

**Date:** 2026-10-15
**Topology / state:** vlan module, VLAN 10 "tenant" bridge mode, host-1 (172.16.10.11) on LS-1 Et3, host-2 (172.16.10.12) on LS-3

**Expected:** VLAN 10 active with the access port; host-1 eth1 at 1500; host-1 to host-2 ping fails.

**Observed:** As expected. VLAN 10 ports "Et3, Cpu". host-1 eth1 172.16.10.11/24 mtu 1500. Ping 100% loss.

**Captures (outputs/):**
- 20261015-0846_LS-1_show-vlan.txt
- 20261015-0846_host-1_ip-addr-show-eth1.txt
- 20261015-0846_host-1_ping--c-3-172161012.txt

**Surprises / questions:** "Cpu" in VLAN 10: netlab generates an empty `interface Vlan10` (no IP) even in bridge mode (node_files/LS-1/vlan). Harmless, nothing to route. Resource use: each cEOS ~1.06 GiB RAM / ~40-45% of one core; hosts 12-18 MiB, ~0% CPU.

**Reactions:**

---

## Step 3: Loopback1 vs Part 1's prefix-lists

**Date:** 2026-10-15
**Topology / state:** Loopback1 + `network` statement on LS-1 only; then LS-1 PL-UNDERLAY-OUT seq 20; then range on all

**Expected:** Lo1 in LS-1's BGP table but not advertised (PL-UNDERLAY-OUT permits Lo0 only).

**Observed:**
- 3a: 10.255.1.11/32 valid/local/best on LS-1; advertised-routes to SP-1 = 10.11.11.11 only; SP-1 table has no 10.255.1.11.
- 3b (LS-1 OUT opened): LS-1 advertises both; SP-1 shows LS-1 PfxRcd 2 / PfxAcc 1. Dropped by the spine's PL-UNDERLAY-IN.
- 3c (range `10.255.1.0/24 ge 32` on spine IN/OUT and leaf IN; exact /32 on leaf OUT): SP-1 2/2/5 per leaf; LS-1 5/5/2 per spine; 10.255.1.13 via both spines; 9000-byte DF ping VTEP to VTEP succeeds.

**Captures (outputs/):**
- 20261015-0851_LS-1_show-ip-bgp-10255111-32.txt
- 20261015-0851_LS-1_show-ip-bgp-neighbors-101110-advertised-.txt
- 20261015-0851_SP-1_show-ip-bgp.txt
- 20261015-0858_LS-1_show-ip-bgp-neighbors-101110-advertised-.txt
- 20261015-0858_SP-1_show-ip-bgp-summary.txt
- 20261015-0901_SP-1_show-ip-bgp-summary.txt
- 20261015-0901_LS-1_show-ip-bgp-summary.txt
- 20261015-0901_LS-1_show-ip-route-10255113.txt
- 20261015-0901_LS-1_ping-10255113-source-10255111-size-9000-.txt

**Surprises / questions:** Four filters in the path (leaf out, spine in, spine out, leaf in), none of which log anything. Design change from Part 1: one range entry for the VTEP block so a new leaf touches no other switch.

**Reactions:**

---

## Step 4: EVPN sessions, Lo0 to Lo0

**Date:** 2026-10-15
**Topology / state:** peer group EVPN, update-source Loopback0, ebgp-multihop 3, EVPN AF only. No send-community extended, no next-hop-unchanged (deliberate).

**Expected:** Sessions Estab, 0 prefixes; routing model multi-agent.

**Observed:** `service routing protocols model multi-agent`. SP-1 three EVPN sessions, LS-1 two, all Estab, 0/0/0.

**Captures (outputs/):**
- 20261015-1007_LS-1_show-running-config-all---include-servic.txt
- 20261015-1011_SP-1_show-bgp-evpn-summary.txt
- 20261015-1011_LS-1_show-bgp-evpn-summary.txt

**Surprises / questions:** netlab's generated config has `no bgp default ipv4-unicast`, so the new sessions carry EVPN only and can't bypass the IPv4 underlay policy.

**Reactions:**

---

## Step 5: VXLAN + MAC-VRF, no extended communities (the headline "nothing works")

**Date:** 2026-10-15
**Topology / state:** Vxlan1 (source Lo1, VLAN 10 -> VNI 10010), MAC-VRF vlan 10 (rd auto, RT both 10010:10010, redistribute learned) on all leaves. Still no send-community extended. EOS 4.36.2F (cEOSLab).

**Expected:** Type 3 routes arrive without RT/TunnelEncap, nothing imported, no remote VTEPs; next hop rewritten to spine Lo0.

**Observed:**
- Finding 1 (routes arrive, nothing imported): LS-3's own Type 3 carries `Route-Target-AS:10010:10010 TunnelEncap:tunnelTypeVxlan`; Type 3s from LS-1/LS-2 arrive via both spines, valid/best, with no extended communities. Same for host-1's Type 2: local on LS-1 with both communities, received on LS-3 with none. LS-3 EVPN instance shows RT import/export 10010:10010 (config is correct). `show vxlan vtep` 0 remote VTEPs; flood list empty. host-1 to host-2 ping 100% loss with Vxlan1 up. Vxlan1 reports "Replication/Flood Mode is headend with Flood List Source: EVPN".
- Finding 2 (next hop kept, PREDICTION WRONG): LS-3 sees `10.255.1.11 from 10.1.1.1`. SP-1 config has no next-hop-unchanged. The spine passed the leaf's VTEP through as next hop. Needs a docs check before writing up (Arista's sample still sets next-hop-unchanged).
- Finding 3 (leaves transit EVPN between spines): LS-1 PfxAdv 3 to SP-1 vs 1 to SP-2, because LS-1's best paths for LS-2/LS-3 routes are via SP-2 (">Ec ... 65002 65102"). SP-1 holds paths like `65101 65002 65102` and even LS-1's own route back via `65102 65002 65101`. SP-1 PfxRcd: LS-1 4 (2 originated), LS-2 2 (1), LS-3 3 (1). Part 1's RM-UNDERLAY-OUT only covers IPv4; unique spine ASNs mean AS_PATH loop prevention doesn't stop it.

**Captures (outputs/):**
- 20261015-1016_LS-1_show-interfaces-Vxlan1.txt
- 20261015-1016_LS-1_show-bgp-evpn-summary.txt
- 20261015-1016_LS-3_show-bgp-evpn-route-type-imet-detail.txt
- 20261015-1016_LS-3_show-vxlan-vtep.txt
- 20261015-1022_host-1_ping--c-3-172161012.txt
- 20261015-1022_LS-1_show-mac-address-table-vlan-10.txt
- 20261015-1022_LS-1_show-bgp-evpn-route-type-mac-ip-detail.txt
- 20261015-1022_LS-3_show-bgp-evpn-route-type-mac-ip-detail.txt
- 20261015-1022_LS-3_show-bgp-evpn-instance.txt
- 20261015-1022_LS-3_show-vxlan-flood-vtep.txt
- 20261015-1022_LS-1_show-bgp-evpn-route-type-imet.txt
- 20261015-1022_SP-1_show-bgp-evpn-summary.txt
- 20261015-1022_SP-1_show-bgp-evpn-route-type-imet-detail.txt
- 20261015-1022_SP-1_show-running-config-section-router-bgp.txt
- 20261015-1022_SP-1_show-version.txt

**Surprises / questions:** Type 2 for host-1 is MAC only (no IP): pure L2, no SVI address, so no MAC/IP binding. Prediction for later: ARP suppression won't happen in Part 3 without an IP in the Type 2. Next hop behavior (Finding 2) to verify in docs.

**Reactions:**

---

## Step 5b: send-community extended (overlay works)

**Date:** 2026-10-15
**Topology / state:** Step 5 + `neighbor EVPN send-community extended` on all five switches

**Expected:** RT + TunnelEncap on received routes; LS-3 remote VTEPs .11 and .12 in the VLAN 10 flood list; ping works; host-1 MAC on Vx1; Type 2 still MAC-only.

**Observed:** All as expected.
- Received Type 3 and Type 2 routes carry `Route-Target-AS:10010:10010 TunnelEncap:tunnelTypeVxlan`; next hop still the VTEP (10.255.1.x).
- `show vxlan vtep`: 10.255.1.11 "flood, unicast", 10.255.1.12 "flood" only (LS-2 has no host, so Type 3 only, no Type 2).
- Flood list VLAN 10: 10.255.1.11, 10.255.1.12.
- host-1 to host-2: 0% loss, ttl=64 (bridged, no routing hop). First run's first reply 14.5 ms, later ~2.6-3.4 ms.
- LS-3 MAC table: host-1 aac1.ab47.1dfb on Vx1 (from EVPN), host-2 aac1.abbe.04fa on Et3.
- Type 2 routes are MAC only, no IP.

**Captures (outputs/):** (captured twice, 1027 and 1028; same content)
- 20261015-1027_LS-3_show-bgp-evpn-route-type-imet-detail.txt
- 20261015-1027_LS-3_show-vxlan-vtep.txt
- 20261015-1027_LS-3_show-vxlan-flood-vtep.txt
- 20261015-1027_host-1_ping--c-3-172161012.txt
- 20261015-1028_LS-3_show-bgp-evpn-route-type-mac-ip-detail.txt
- 20261015-1028_LS-3_show-mac-address-table-vlan-10.txt

**Surprises / questions:** The one missing knob was the whole difference between Step 5 and 5b: no log, no session reset, routes present both times. "flood" vs "flood, unicast" in show vxlan vtep shows Type 3 vs Type 2 at a glance.

**Reactions:**

---

## Step 6a: RT trap, LS-3 on auto RTs

**Date:** 2026-10-15
**Topology / state:** Step 5b, then on LS-3 only: `no route-target both 10010:10010`, `route-target export auto`, `route-target import auto 65103`. LS-1/LS-2 unchanged (10010:10010).

**Expected:** LS-3 auto RT built from 65103; nobody imports anybody across the mismatch; ping fails; sessions stay up.

**Observed:**
- EOS CLI help output (`?`, typed interactively on LS-3, not saved to outputs/): `route-target both` takes only a literal RT. `route-target import` offers `auto`, `any-as:nn` ("Wildcard 2-byte AS Route Target") and `evpn`. `route-target export auto` is accepted on its own, but `route-target import auto` is "% Incomplete command" and requires an ASN: `route-target import auto <ASN>`.
- LS-3 instance: import and export `Route-Target-AS:65103:268445466 (auto, VNI 10010)`.
- 268445466 = 0x1000271A: top nibble 1 (RFC 8365 auto-derived format, type VXLAN), low 24 bits = 10010 (the VNI). So EOS uses the RFC 8365 encoding, not a plain 65103:10010.
- LS-1 receives LS-3's Type 3 with RT 65103:268445466 (valid, best) but does not import it.
- LS-3: 0 remote VTEPs, empty MAC table for VLAN 10, host-1 to host-2 100% loss. BGP sessions untouched.

**Captures (outputs/):**
- 20261015-1044_LS-3_show-running-config-section-router-bgp.txt
- 20261015-1044_LS-3_show-bgp-evpn-instance.txt
- 20261015-1044_LS-1_show-bgp-evpn-route-type-imet-detail.txt
- 20261015-1044_LS-3_show-vxlan-vtep.txt
- 20261015-1044_LS-3_show-mac-address-table-vlan-10.txt
- 20261015-1044_host-1_ping--c-3-172161012.txt

**Surprises / questions:** Auto import needs the remote ASN, so with a unique ASN per leaf every leaf must list every other leaf's ASN: the same scaling cost as Part 1's exact prefix-lists. In a shared-ASN fabric it would be one line. Note: the help output was typed interactively and not saved; re-capture before quoting it verbatim.

**Reactions:**

---

## Step 6b: auto export + wildcard import on all leaves

**Date:** 2026-10-15
**Topology / state:** All leaves: `route-target export auto`, `route-target import any-as:268445466` (manual 10010:10010 removed)

**Expected:** Three different export RTs, one wildcard import matches all; VTEPs back; ping works.

**Observed:** As expected. LS-1 instance: import `Route-Target-Wildcard-AS:any-as:268445466`, export `Route-Target-AS:65101:268445466 (auto, VNI 10010)`. LS-1 receives 65102:268445466 and 65103:268445466 and imports both. LS-3: 2 remote VTEPs (.11 flood+unicast, .12 flood). Ping 0% loss, ttl=64.

**Captures (outputs/):**
- 20261015-1048_LS-1_show-bgp-evpn-instance.txt
- 20261015-1048_LS-1_show-bgp-evpn-route-type-imet-detail.txt
- 20261015-1048_LS-3_show-vxlan-vtep.txt
- 20261015-1048_host-1_ping--c-3-172161012.txt

**Surprises / questions:** The wildcard has to match the RFC 8365-encoded value (268445466), not the plain VNI. Experiment only: final config returns to the manual shared RT promised in Part 2.

**Reactions:**

---

## Step 6c: back to manual shared RT

**Date:** 2026-10-15
**Observed:** LS-3 instance import/export Route-Target-AS:10010:10010 (no "auto"); ping 0% loss.
**Captures (outputs/):** 20261015-1050_LS-3_show-bgp-evpn-instance.txt, 20261015-1050_host-1_ping--c-3-172161012.txt

---

## Step 7: leaves stop transiting EVPN between spines

**Date:** 2026-10-15
**Topology / state:** Leaves: `ip as-path access-list AS-LOCAL permit ^$ any`, `route-map RM-EVPN-OUT permit 10 / match as-path AS-LOCAL`, `neighbor EVPN route-map RM-EVPN-OUT out` in address-family evpn.

**Expected:** Spines receive only what each leaf originates (LS-1 2, LS-2 1, LS-3 2); LS-1 advertises 2 to each spine; spines hold one path per route; leaves keep two paths per remote route; ping works.

**Observed:**
- Before (10:51): LS-1 PfxAdv 2 to SP-1 but 5 to SP-2 (it originates 2). The transit had moved: at 10:22 LS-1 sent extras to SP-1 (3 vs 1), now to SP-2, because its best paths had flipped to SP-1 after the RT churn. SP-1 at 10:51 already showed 2/1/2 since the extras were going to SP-2 at that moment.
- After (10:52): LS-1 PfxAdv 2 / 2. SP-1 imet detail: one path per route (from the originating leaf only). LS-3 imet detail: still two paths per remote route (via SP-1 and SP-2). Ping 0% loss.

**Captures (outputs/):**
- 20261015-1051_host-1_ping--c-3-172161012.txt
- 20261015-1051_SP-1_show-bgp-evpn-summary.txt
- 20261015-1051_LS-1_show-bgp-evpn-summary.txt
- 20261015-1052_LS-1_show-bgp-evpn-summary.txt
- 20261015-1052_SP-1_show-bgp-evpn-route-type-imet-detail.txt
- 20261015-1052_LS-3_show-bgp-evpn-route-type-imet-detail.txt
- 20261015-1052_host-1_ping--c-3-172161012.txt
- Earlier "before" with transit paths on SP-1: 20261015-1022_SP-1_show-bgp-evpn-route-type-imet-detail.txt

**Surprises / questions:** Which spine receives the transit copies depends on the leaf's best-path tiebreak, so it moved between captures. Need SP-2 after-capture to close the loop.

**Reactions:**

---

## Step 7 (closing evidence): SP-2 after the filter

**Observed:** SP-2 PfxRcd 2/1/2, one path per route from the originating leaf. Matches SP-1.
**Captures (outputs/):** 20261015-1054_SP-2_show-bgp-evpn-summary.txt, 20261015-1054_SP-2_show-bgp-evpn-route-type-imet-detail.txt

---

## Step 8: Does the second ARP still flood?

**Date:** 2026-10-15
**Topology / state:** Step 7. tcpdump run from the laptop inside host-2's namespace (`sudo ip netns exec clab-l2-overlay-host-2 ...`): hosts have no tcpdump.

**Expected:** Both ARP requests from host-1 reach host-2 (Type 2 routes are MAC-only, so no binding for a leaf to answer from).

**Observed:** As expected. Flush verified each round (neighbor table empty after flush). host-2 saw two broadcast requests `aa:c1:ab:47:1d:fb > ff:ff:ff:ff:ff:ff ... who-has 172.16.10.12 tell 172.16.10.11` (11:01:57 and 11:02:02) and answered both. No leaf proxied the second ARP. Also seen: host-2's own unicast ARP check of 172.16.10.11 (normal Linux neighbor verification).

**Captures (outputs/):**
- 20261015-1101_host-2_tcpdump-arp-test.txt (script: flush check + pings + capture)
- 20261015-1101_host-2_tcpdump-arp.txt (parallel capture, same packets)

**Surprises / questions:** First attempt failed because `netlab connect host-1 "ip neigh flush dev eth1"` passes the quoted string as one word to the container ("sh: ... not found"); unquoted works. Frames from host-1 arrive at host-2 as 60 bytes (padded to the Ethernet minimum on the way through the leaves); host-2's own frames show 42 (captured before padding). Part 2 said ARP suppression needs Type 2 routes with an IP: confirmed by absence in a pure L2 segment. Part 4 (SVIs, MAC+IP Type 2) is where suppression can appear.

**Reactions:**

---

## Step 9: VXLAN on the wire (LS-1 uplinks)

**Date:** 2026-10-15
**Topology / state:** Step 7 state. `bash scripts/capture-vxlan.sh`: tcpdump in LS-1's namespace on et1 (Ethernet1, to SP-1) and et2 (Ethernet2, to SP-2), udp/4789; host-1 flushes ARP and pings host-2 x3.

**Expected:** ARP broadcast leaves LS-1 twice (to .12 and .13); ICMP unicast to .13 only; VNI 10010; source ports vary by flow.

**Observed:**
- Ingress replication: one ARP request from host-1 left LS-1 as two VXLAN packets at the same instant: 10.255.1.11.58242 > 10.255.1.13.4789 and > 10.255.1.12.4789 (LS-2 gets a copy with no host behind it).
- ARP reply from host-2 came back unicast from 10.255.1.13 (inner dst = host-1 MAC).
- ICMP echo request/reply: unicast .11 <-> .13 only, never to .12.
- Overhead exactly 50 bytes: ARP inner 60 -> outer frame 110; ICMP inner 98 -> outer 148. Outer IP DF set; outer TTL 64 leaving LS-1, 63 arriving from LS-3 (one spine hop). VXLAN flags [I] (0x08), vni 10010.
- Outer MACs: LS-1 Et1 ca:f0:00:03:00:01 <-> SP-1 ca:f0:00:01:00:01 (rewritten per hop).
- Source ports: ARP broadcast 58242; ICMP 7928 in BOTH directions; host-2's unicast ARP check 6648 in both directions. Same inner flow -> same port both ways; different flows -> different ports.
- ECMP: every packet (both directions) used et1 / SP-1; et2 captured nothing. Three flows is too few to show spreading.

**Captures (outputs/):**
- 20261015-1114_LS-1_et1_vxlan.pcap / .txt
- 20261015-1114_LS-1_et2_vxlan.pcap / .txt (empty)
- 20261015-1114_LS-1_et*_tcpdump.log

**Surprises / questions:** cEOS interfaces inside the container are et1/et2/et3, not eth1 (only Linux hosts use eth1); first attempts failed with "No such device". Same source port in both directions suggests a symmetric hash; not verified beyond these flows. ECMP spread needs a multi-flow test next session. pcaps are good for Wireshark screenshots (packet anatomy diagram).

**Reactions:**

---

## Step 10: ECMP test, 8 flows

**Date:** 2026-10-15
**Topology / state:** Step 9 state. `bash scripts/ecmp-test.sh`: host-1 gets 172.16.10.21-28, each pings host-2 twice; capture both LS-1 uplinks; aliases removed after.

**Expected:** 8 different UDP source ports; flows split across Et1 (SP-1) and Et2 (SP-2).

**Observed:**
- Source ports: one per flow, stable per flow, same in both directions: .21=248, .22=1016, .23=760, .24=3576, .25=3320, .26=4088, .27=3832, .28=2552. ARP between the same MAC pair: 6648 (both directions), LS-3's ARP requests 64122. So the hash input includes inner IPs, not just MACs.
- PREDICTION WRONG on spreading: all 8 flows, both directions, on Et1 (SP-1). Et2 capture empty. (Previous Step 9 flows also all on Et1.)
- Ports are not limited to RFC 7348's recommended 49152-65535 (e.g. 248, 760).
- Unknown-unicast flooding seen: the first echo request from .21 was sent to BOTH .13 and .12, and host-1's ARP reply to host-2 too, because host-2's MAC had aged out and LS-1 learns remote MACs only from EVPN (Vxlan1: "Remote MAC learning via EVPN"). From the next packet on, unicast to .13 only.
- EOS `show interfaces Ethernet1-2 counters`: Out* counters stay 0 on cEOS (not usable); In counters include BGP traffic, so too noisy for this test.

**Captures (outputs/):**
- 20261015-1123_LS-1_ecmp-test.txt
- 20261015-1123_LS-1_et1_ecmp.pcap, 20261015-1123_LS-1_et2_ecmp.pcap (empty)

**Surprises / questions:** Why no spreading? RIB has two next hops (Step 3c). Candidate: cEOS forwards in software and the path hash may use outer IPs only (outer IPs are constant LS-1 <-> LS-3). To check before writing anything.

**Reactions:**

### Step 10b: why no spreading (kernel check) -- conclusion superseded by 10c

**Observed:**
- EOS RIB (`show ip route 10.255.1.13`): two next hops, Ethernet1 and Ethernet2.
- Linux kernel route inside LS-1's container: `10.255.1.13 via 10.1.11.0 dev et1 proto gated`: ONE next hop (et1 = Ethernet1 = SP-1).
- `net.ipv4.fib_multipath_hash_policy = 0` (L3-only), but irrelevant: the kernel has no second path to hash onto.
- Matches the capture: every VXLAN packet left on et1.

**Captures (outputs/):**
- 20261015-1127_LS-1_kernel-ecmp-check.txt
- 20261015-1127_LS-1_show-ip-route-10255113.txt

**Conclusion for the post (as observed, cEOS 4.36.2F in containerlab):** EOS computes ECMP (two next hops in the RIB) and VXLAN varies the UDP source port per flow, but the lab image's kernel forwarding table has a single next hop, so all traffic uses one spine. ECMP spreading in this lab is visible in the control plane, not the data plane. Hardware platforms hash in the ASIC; can't be shown here. Worth checking whether the same applies to Part 1's Lo0 ECMP (kernel route for 10.13.13.13).

**Reactions:**

### Step 10c: correction after research (do NOT use the 10b conclusion as written)

- Part 1 check: LS-1 kernel route for Lo0 10.13.13.13 also single next hop (`via 10.1.11.0 dev et1 proto gated`), while EOS RIB has two (Part 1 posts showed ECMP in the RIB only). Capture: outputs/20261015-1147_LS-1_kernel-route-lo0.txt
- ipSpace.net (2026-03, "ECMP on Arista cEOS"): on cEOS 4.35.2F the Linux table ALSO showed only one next hop, yet FORWARDED IPv4 traffic was spread across both paths; LOCALLY ORIGINATED traffic (traceroute from the switch itself) used one path. No config needed. So "kernel shows one next hop" does NOT prove cEOS can't ECMP.
- What we can say: VXLAN-encapsulated traffic leaving a cEOS 4.36.2F VTEP used a single uplink for all 8+ flows despite per-flow UDP source ports, and it was Ethernet1 (toward SP-1) on both LS-1 and LS-3 (return traffic arrived from SP-1), matching the first/only kernel next hop. That fits ipSpace's "locally originated" case: the leaf builds the outer packet itself. Cause not confirmed; state as observed and cite ipSpace.
- In this design every packet leaving a leaf toward the fabric is VXLAN-encapsulated, and the spines have one path per leaf, so there is no plain transit-ECMP case in Part 3 to compare against.

---

## Step 11: next-hop-unchanged on the spines

**Date:** 2026-10-15
**Topology / state:** Step 10 state + `neighbor EVPN next-hop-unchanged` on SP-1 and SP-2.

**Expected:** No change: spines already passed the leaf VTEP through as next hop (Step 5).

**Observed:** As expected. SP-1 config shows `neighbor EVPN next-hop-unchanged`. LS-3 imet detail identical to 10:52: next hops 10.255.1.11 / 10.255.1.12 via both spines, same communities, 2 paths each. Ping 0% loss (first reply 19 ms: MACs had aged out, first frame flooded).
mac-ip capture at 11:42 was EMPTY: taken before the ping, both MACs had aged out (no traffic since ~11:27). Re-capture after traffic.

**Captures (outputs/):**
- 20261015-1142_SP-1_show-running-config-section-router-bgp.txt
- 20261015-1142_LS-3_show-bgp-evpn-route-type-imet-detail.txt
- 20261015-1142_LS-3_show-bgp-evpn-route-type-mac-ip-detail.txt (empty, MAC aging)
- 20261015-1142_host-1_ping--c-3-172161012.txt

**Surprises / questions:** On cEOS 4.36.2F the knob made no visible difference. Kept in the final config to match Arista's design and state intent. Side observation: with no traffic, Type 2 routes disappear after MAC aging (default 300 s) and the next first frame floods.

**Reactions:**

### Step 11b: Type 2 re-captured after traffic

**Observed:** host-1 MAC aac1.ab47.1dfb via 10.255.1.11 from both spines (RT 10010:10010, TunnelEncap VXLAN, next hop unchanged); host-2 MAC aac1.abbe.04fa local. Ping first reply 3.5 ms (MACs fresh, no flood).
**Captures (outputs/):** 20261015-1145_host-1_ping--c-3-172161012.txt, 20261015-1146_LS-3_show-bgp-evpn-route-type-mac-ip-detail.txt

---

## Step 12: rebuild from templates (no hand config)

**Date:** 2026-10-15
**Topology / state:** netlab down, Part 3 templates added to topology.yml groups, netlab up, then `bash scripts/verify-overlay.sh`.

**Observed:** Everything up from files alone. Underlay: SP-1 PfxRcd 2 / PfxAdv 5 per leaf. EVPN: spines PfxRcd 1/1/1 (Type 3 only; the script captures summaries before the host ping), LS-1 PfxAdv 1 per spine. MTU 9194; Loopback1 10.255.1.11; Vlan10 SVI unassigned. Jumbo VTEP ping OK. Vxlan1 now also lists "Headend replication flood vtep list: 10 10.255.1.13 10.255.1.12". host ping OK. LS-3: VTEPs .11 "unicast, flood", .12 "flood"; flood list .11 .12; MACs on Vx1/Et3; RT 10010:10010; Type 3 and Type 2 with VTEP next hops and both communities.
Note: host MACs change on every rebuild (now host-1 aac1.abc2.70e8, host-2 aac1.abdb.59b3).

**Captures (outputs/):** 20261015-1157_verify-overlay.txt
