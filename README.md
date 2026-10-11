# next-hop-labs

Lab sources for the posts on [next-hop.dev](https://next-hop.dev). Each folder is a self-contained [netlab](https://netlab.tools) topology that runs on [containerlab](https://containerlab.dev), small enough to bring up on a laptop.

## Labs

| Folder | Post | Platform |
|---|---|---|
| [`dc-fabric-01-ebgp-underlay`](dc-fabric-01-ebgp-underlay) | [DC Fabric Part 1: Building an eBGP Spine-Leaf Underlay](https://next-hop.dev/building-an-ebgp-spine-leaf-underlay/) | Arista cEOS 4.36.2 |
| [`bgp-foundations-03-best-path`](bgp-foundations-03-best-path) | [BGP Foundations Part 3: Building and Breaking Every Best-Path Tie](https://next-hop.dev/learning-byte-003-bgp-best-path-selection-building-and-breaking-every-tie/) | Cisco IOL 17.12.01 |

Each lab folder has its own README with what the lab shows and how to run it.

## Requirements

- netlab with the containerlab provider (the labs were built with netlab 26.08)
- Docker
- Vendor images, which you have to supply yourself:
  - Arista cEOS, imported as `ceos:4.36.2` (free download with an Arista account)
  - Cisco IOL packaged with vrnetlab as `vrnetlab/cisco_iol:17.12.01`
- About 16 GB of RAM is enough for any one lab here. Run them one at a time.

## Running a lab

```bash
cd dc-fabric-01-ebgp-underlay
netlab up
netlab connect LS-1 "show ip bgp summary"
netlab down
```

## License

Topologies, templates and configs are MIT licensed (see [LICENSE](LICENSE)). The blog posts themselves are not part of this repository.
