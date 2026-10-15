# DC Fabric Part 3: Layer 2 EVPN Overlay

Lab for the post **DC Fabric Part 3** on next-hop.dev (link added when published).
Builds on [Part 1's eBGP underlay](../dc-fabric-01-ebgp-underlay) and the theory in
[Part 2](https://next-hop.dev/dc-fabric-part-2-vxlan-evpn-theory/).

## What the lab shows

Part 1's fabric plus two hosts in the same VLAN and subnet on different leaves,
bridged across the routed underlay with VXLAN and an EVPN control plane.

| Node | Role | ASN | Loopback0 (EVPN peering) | Loopback1 (VTEP) |
|---|---|---|---|---|
| SP-1 | spine | 65001 | 10.1.1.1/32 | - |
| SP-2 | spine | 65002 | 10.2.2.2/32 | - |
| LS-1 | leaf | 65101 | 10.11.11.11/32 | 10.255.1.11/32 |
| LS-2 | leaf | 65102 | 10.12.12.12/32 | 10.255.1.12/32 |
| LS-3 | leaf | 65103 | 10.13.13.13/32 | 10.255.1.13/32 |
| host-1 | host on LS-1 Et3 | - | 172.16.10.11/24 | - |
| host-2 | host on LS-3 Et3 | - | 172.16.10.12/24 | - |

- VLAN 10 (`tenant`, bridge mode, no SVI address) maps to VNI 10010. LS-2 is in the VNI with no host.
- MTU 9194 on the switches (netlab's EOS maximum), 1500 on the hosts.
- Underlay: Part 1's policy plus one range entry, `10.255.1.0/24 ge 32`, for the VTEP block.
- Overlay: eBGP between Loopback0 addresses, EVPN address family only, extended communities sent,
  `next-hop-unchanged` on the spines, one shared route target `10010:10010` on every leaf.
- Leaves send only routes they originated on the EVPN sessions (`RM-EVPN-OUT`, AS_PATH `^$`), so a
  leaf never passes one spine's EVPN routes to the other.

`netlab up` builds the finished state from the post.

## Files

| File | Purpose |
|---|---|
| `topology.yml` | The lab: Part 1 fabric, hosts, VLAN 10, MTU, and all templates. |
| `templates/underlay-policy-*.j2`, `leaf-multipath.j2` | Part 1 underlay, unchanged. |
| `templates/vtep-underlay-spine.j2` | VTEP range in the spine prefix-lists. |
| `templates/vtep-loopback-leaf.j2` | Loopback1 and the leaf prefix-list entries. |
| `templates/evpn-overlay-spine.j2` | EVPN sessions on the spines. |
| `templates/evpn-overlay-leaf.j2` | EVPN sessions and the outbound policy on the leaves. |
| `templates/vxlan-l2vni-leaf.j2` | VLAN 10, Vxlan1 and the MAC-VRF. |
| `HAND-CONFIG.md` | The same config as typed by hand, in build order. |
| `LAB-WALKTHROUGH.md` | Step-by-step build with checks and "break it" exercises. |
| `NOTES.md` | Field notes and evidence from the lab runs. |
| `scripts/verify-overlay.sh` | Runs the full check list and saves it to `outputs/`. |
| `scripts/capture-vxlan.sh` | Captures VXLAN on LS-1's uplinks while host-1 pings host-2. |
| `scripts/ecmp-test.sh` | Eight host flows, captured on both LS-1 uplinks. |
| `outputs/` | Captured CLI and pcaps, named `<YYYYMMDD-HHMM>_<node>_<short-command>`. |

The per-node values in the templates (VTEP addresses, peer loopbacks and ASNs) are hardcoded tables,
the same approach as Part 1. Adding a leaf means updating them.

## How to run it

Requirements: netlab with the containerlab provider, and the Arista cEOS image imported as
`ceos:4.36.2`. The hosts use netlab's default Linux image.

```
source ~/netlab-venv/bin/activate
cd dc-fabric-03-l2-overlay
netlab up
bash scripts/verify-overlay.sh
netlab down
```

Pass commands to `netlab connect` without quotes, for example
`netlab connect LS-1 show bgp evpn summary`. A quoted command reaches the switch with the quotes still on.

The capture scripts run tcpdump from the host inside the containers' network namespaces, so they need
`sudo` and tcpdump on the host. Inside a cEOS container the ports are `et1`, `et2`, `et3`.

## Building the overlay by hand

Remove the five Part 3 templates from the `config:` lists in `topology.yml` and run `netlab up`. You get
Part 1's underlay, the hosts and VLAN 10, and nothing else. Then follow `LAB-WALKTHROUGH.md`.

## Observed on cEOS 4.36.2F (containerlab)

- The spines kept the leaf VTEP as the EVPN next hop with or without `next-hop-unchanged`.
- VXLAN traffic used one uplink only, although each flow got its own UDP source port. EOS shows two
  next hops; the Linux table in the container shows one. See NOTES.md, Steps 10 to 10c, and
  [ECMP on Arista cEOS](https://blog.ipspace.net/2026/03/ecmp-arista-ceos/) for forwarded vs locally
  originated traffic. This is a lab image behavior, not an EVPN one.
