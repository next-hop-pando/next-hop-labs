# DC Fabric Part 1: eBGP Spine-Leaf Underlay

Lab for the post **DC Fabric Part 1: Building an eBGP Spine-Leaf Underlay** on next-hop.dev.
Post: https://next-hop.dev/building-an-ebgp-spine-leaf-underlay/

## What the lab shows

A 2-spine, 3-leaf fabric running eBGP as the underlay, with a unique private ASN per node.

| Node | Role | ASN | Loopback0 |
|---|---|---|---|
| SP-1 | spine | 65001 | 10.1.1.1/32 |
| SP-2 | spine | 65002 | 10.2.2.2/32 |
| LS-1 | leaf | 65101 | 10.11.11.11/32 |
| LS-2 | leaf | 65102 | 10.12.12.12/32 |
| LS-3 | leaf | 65103 | 10.13.13.13/32 |

- Every spine-leaf link is a /31 with the spine on `.0`.
- Underlay policy: leaves advertise only their own Loopback0. Spines advertise their own Loopback0 plus the leaf loopbacks, so a leaf never becomes transit between spines. Exact-/32 prefix-lists `PL-UNDERLAY-IN/OUT`, route-maps `RM-UNDERLAY-IN/OUT`.
- ECMP: `maximum-paths 2` on the leaves only, so each leaf can install both spine paths to a remote leaf loopback.

`netlab up` builds the finished state from the post: policy and ECMP are both applied.

## Files

| File | Purpose |
|---|---|
| `topology.yml` | The lab as published in the post. |
| `topology-etr.yml` | Optional ECMP visualization experiment. Same fabric plus an Alpine host (ETR-HOST) behind LS-1. Not part of the post. |
| `templates/underlay-policy-spine.j2` | Spine prefix-lists, route-maps and neighbor bindings. |
| `templates/underlay-policy-leaf.j2` | Leaf prefix-lists, route-maps and neighbor bindings. |
| `templates/leaf-multipath.j2` | `maximum-paths 2` on the leaves. |
| `NOTES.md` | Field notes from the lab runs. |
| `outputs/` | Captured CLI, one file per command, named `<YYYYMMDD-HHMM>_<node>_<short-command>.txt`. |

The prefix lists in both policy templates are hardcoded. If you add a leaf, update the list in `underlay-policy-spine.j2` and the one in `underlay-policy-leaf.j2`.

## How to run it

Requirements: netlab with the containerlab provider, and the Arista cEOS image imported as `ceos:4.36.2`. The ETR-HOST variant also pulls `alpine:3.20`.

```
source ~/netlab-venv/bin/activate
cd dc-fabric-01-ebgp-underlay
netlab up                      # published lab
netlab connect LS-1 "show ip route"
netlab down
```

For the ECMP visualization experiment, run this instead:

```
netlab up topology-etr.yml
```

With the leaf policy applied, LS-1 does not advertise the ETR-HOST link (192.0.2.0/31) to the spines. ETR-HOST is reachable from LS-1 only.

## Reproducing the "before" states from the post

The custom config is applied through the `groups:` block in `topology.yml`. Remove templates from the `config:` lists to step back to the earlier states, then run `netlab up` again (or `netlab restart` if the lab is running).

Finished state (default):

```yaml
groups:
  spines:
    members: [ SP-1, SP-2 ]
    config: [ templates/underlay-policy-spine ]
  leaves:
    members: [ LS-1, LS-2, LS-3 ]
    config: [ templates/underlay-policy-leaf, templates/leaf-multipath ]
```

**No ECMP** (policy applied, one installed path per prefix): remove `templates/leaf-multipath` from the leaves.

```yaml
  leaves:
    members: [ LS-1, LS-2, LS-3 ]
    config: [ templates/underlay-policy-leaf ]
```

**No policy** (netlab's default eBGP config, ECMP on): remove both policy templates.

```yaml
  spines:
    members: [ SP-1, SP-2 ]
  leaves:
    members: [ LS-1, LS-2, LS-3 ]
    config: [ templates/leaf-multipath ]
```

For the plain netlab baseline with no policy and no ECMP, also drop `templates/leaf-multipath`. You can leave the `members:` lists in place.

Template names in `config:` keep the `templates/` prefix. netlab looks for custom templates relative to the topology directory.
