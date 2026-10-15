# DC Fabric Part 3: hand-built config log

Everything typed at the CLI on top of `netlab up`, in the order it was added.
This is the source for the Jinja templates at the end. A `netlab up` wipes it.

Values:
- VTEP (Loopback1): LS-1 10.255.1.11, LS-2 10.255.1.12, LS-3 10.255.1.13
- EVPN sessions: Lo0 to Lo0, eBGP multihop 3, EVPN address family only
- VLAN 10 <-> VNI 10010, RT 10010:10010 on every leaf, RD auto

## Step 3: Loopback1 + underlay policy (VTEP range 10.255.1.0/24 ge 32)

Spines (SP-1, SP-2):
```
ip prefix-list PL-UNDERLAY-IN
   seq 100 permit 10.255.1.0/24 ge 32
ip prefix-list PL-UNDERLAY-OUT
   seq 100 permit 10.255.1.0/24 ge 32
```

Leaves (shown for LS-1; LS-2 .12 / AS 65102, LS-3 .13 / AS 65103):
```
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
```

## Step 4: EVPN overlay sessions (+ descriptions)

Spine (SP-1 shown; SP-2 is AS 65002):
```
router bgp 65001
   neighbor EVPN peer group
   neighbor EVPN update-source Loopback0
   neighbor EVPN ebgp-multihop 3
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
```

Leaf (LS-1 shown; LS-2 AS 65102, LS-3 AS 65103):
```
router bgp 65101
   neighbor EVPN peer group
   neighbor EVPN update-source Loopback0
   neighbor EVPN ebgp-multihop 3
   neighbor 10.1.1.1 peer group EVPN
   neighbor 10.1.1.1 remote-as 65001
   neighbor 10.1.1.1 description SP-1-EVPN
   neighbor 10.2.2.2 peer group EVPN
   neighbor 10.2.2.2 remote-as 65002
   neighbor 10.2.2.2 description SP-2-EVPN
   address-family evpn
      neighbor EVPN activate
```
Deliberately NOT yet configured: send-community extended, next-hop-unchanged.

## Step 5: VXLAN + MAC-VRF (leaves)

LS-2 only (no host, so netlab did not create the VLAN):
```
vlan 10
   name tenant
```

All leaves (LS-1 shown):
```
interface Vxlan1
   vxlan source-interface Loopback1
   vxlan udp-port 4789
   vxlan vlan 10 vni 10010
router bgp 65101
   vlan 10
      rd auto
      route-target both 10010:10010
      redistribute learned
```

## Step 5b: send extended communities (all five switches)

```
router bgp <asn>
   neighbor EVPN send-community extended
```
Before this, received EVPN routes carried no Route-Target or TunnelEncap
communities, so nothing was imported (`show vxlan vtep` empty).

## Open items found along the way
- EVPN next hop: EOS kept the leaf VTEP (10.255.1.x) as next hop through the
  spines WITHOUT next-hop-unchanged (predicted a rewrite to the spine Lo0).
  Verify against Arista docs before writing it up.
- Leaves re-advertise spine-learned EVPN routes to the other spine
  (LS-1 PfxAdv 3 to SP-1, 1 to SP-2). Part 1 blocked this transit in IPv4
  with RM-UNDERLAY-OUT; the EVPN AF has no such policy, and unique spine
  ASNs mean AS_PATH loop prevention does not stop it either.

## Step 6 (experiment, reverted): RT options
6a LS-3: `route-target export auto` + `route-target import auto 65103` -> mismatch, ping fails.
6b all leaves: `route-target export auto` + `route-target import any-as:268445466` -> works.
Reverted to `route-target both 10010:10010` on all leaves. Not part of the final templates.

## Step 7: EVPN outbound policy on the leaves (no transit between spines)

```
ip as-path access-list AS-LOCAL permit ^$ any
route-map RM-EVPN-OUT permit 10
   match as-path AS-LOCAL
router bgp <leaf asn>
   address-family evpn
      neighbor EVPN route-map RM-EVPN-OUT out
```

## Step 11: spines keep the leaf VTEP as next hop (explicit)

```
router bgp <spine asn>
   neighbor EVPN next-hop-unchanged
```
No visible change on cEOS 4.36.2F (next hop already preserved); kept to match Arista's design.

## Templates (end of Part 3)
All of the above now lives in templates/ and is applied by topology.yml groups:
- spines: underlay-policy-spine (Part 1), vtep-underlay-spine, evpn-overlay-spine
- leaves: underlay-policy-leaf, leaf-multipath (Part 1), vtep-loopback-leaf, evpn-overlay-leaf, vxlan-l2vni-leaf
Verify a fresh build with: bash scripts/verify-overlay.sh
