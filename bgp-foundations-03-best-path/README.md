# BGP Foundations Part 3: Building and Breaking Every Best-Path Tie

Lab for the post **BGP Foundations Part 3: Building and Breaking Every Best-Path Tie** on next-hop.dev.
Post: https://next-hop.dev/learning-byte-003-bgp-best-path-selection-building-and-breaking-every-tie/

## What the lab shows

Three autonomous systems with multiple paths between the two edges, used to walk the BGP best-path decision process one tie-breaker at a time.

| Node | AS | Role | Loopback0 |
|---|---|---|---|
| r1 | 65100 | external, dual-homed to r2 and r4 | 10.1.1.1/32 |
| r2 | 65000 | edge, eBGP to r1 | 10.2.2.2/32 |
| r3 | 65000 | core, iBGP only | 10.3.3.3/32 |
| r4 | 65000 | edge, eBGP to r1 | 10.4.4.4/32 |
| r5 | 65000 | edge, eBGP to r7 | 10.5.5.5/32 |
| r6 | 65000 | edge, eBGP to r7 | 10.6.6.6/32 |
| r7 | 65200 | external, dual-homed to r5 and r6 | 10.7.7.7/32 |

- Inside AS65000, OSPF area 0 runs on the internal links and an iBGP full mesh runs between the Loopback0 addresses.
- eBGP runs on the /30 links at both edges: r1 to r2 and r4, r7 to r5 and r6.
- Two Alpine test hosts sit at the ends: host-a (192.0.2.10/24) behind r1, host-b (198.51.100.10/24) behind r7.
- All routers are Cisco IOL. A small custom template (`templates/no-cdp.j2`) turns off CDP on Ethernet0/0.

## Files

| File | Purpose |
|---|---|
| `topology.yml` | The lab topology. |
| `templates/no-cdp.j2` | Custom config applied to all routers through the `cisco_routers` group. |

## How to run it

Requirements: netlab with the containerlab provider, the Cisco IOL image packaged with vrnetlab as `vrnetlab/cisco_iol:17.12.01`, and `alpine:3.20` for the hosts.

```
cd bgp-foundations-03-best-path
netlab up
netlab connect r3 show ip bgp
netlab connect host-a ping -c 3 198.51.100.10
netlab down
```
