# Network Topology

## Overview

The cluster network is fully isolated behind OPNsense. Proxmox is **not** a router for cluster traffic — it only provides L2 bridge connectivity (vmbr1) and an SSH port-forwarding path for the admin machine to reach the Talos API.

## Topology Diagram

```mermaid
graph TD
    Internet(["Internet"])
    Internet --> vmbr0

    subgraph Proxmox Host ["Proxmox Host (pve02)"]
        vmbr0["vmbr0 — Management Bridge\n192.168.0.0/24"]
        vmbr1["vmbr1 — Cluster Bridge\n10.10.0.0/24\n(L2 only, no masquerade)"]
        PVE["Proxmox\n192.168.0.10 (mgmt)\n10.10.0.1 (vmbr1, tunnel only)"]
    end

    vmbr0 --> PVE
    vmbr0 --> OPNsense_WAN

    subgraph OPNsense VM ["OPNsense VM (cloned from template)"]
        OPNsense_WAN["WAN vtnet0\n192.168.0.x (DHCP)"]
        OPNsense_LAN["LAN vtnet1\n10.10.0.200/24"]
        OPNsense(["OPNsense\nNAT + Firewall\nDNS forwarder"])
        OPNsense_WAN --> OPNsense
        OPNsense --> OPNsense_LAN
    end

    OPNsense_LAN --> vmbr1

    subgraph TalosCluster ["Talos Kubernetes Cluster"]
        CP1["Control Plane 1\n10.10.0.10\ngw: 10.10.0.200"]
        CP2["Control Plane 2\n10.10.0.11\ngw: 10.10.0.200"]
        CP3["Control Plane 3\n10.10.0.12\ngw: 10.10.0.200"]
        W1["Worker 1\n10.10.0.20\ngw: 10.10.0.200"]
        W2["Worker 2\n10.10.0.21\ngw: 10.10.0.200"]
    end

    vmbr1 --> CP1
    vmbr1 --> CP2
    vmbr1 --> CP3
    vmbr1 --> W1
    vmbr1 --> W2

    Admin(["Admin Machine"])
    Admin -->|"SSH -L 5801:10.10.0.10:50000\n(Talos API tunnel)"| PVE
    PVE -. "L2 bridge lookup\n(no routing)" .-> CP1

    style OPNsense fill:#f96,stroke:#333
    style PVE fill:#6af,stroke:#333
    style Admin fill:#9f9,stroke:#333
```

## Key Design Decisions

| Concern | Solution |
|---------|----------|
| Cluster internet access | All cluster egress routes through OPNsense NAT (WAN → vmbr0 → Internet) |
| Proxmox masquerade | **Removed** — vmbr1 has no iptables MASQUERADE rule |
| Talos node default gateway | `10.10.0.200` (OPNsense LAN) set in Talos machine config by Terraform |
| OPNsense pre-configuration | Packer uploads `config.xml` to `/conf/` during template build — no manual UI config needed |
| Admin → Talos API access | SSH port-forward through Proxmox; works via L2 bridge (not routing) — unaffected by gateway change |
| OPNsense boot ordering | OPNsense is created first by Terraform (`talos-network` module dependency); pre-configured config.xml means it routes immediately on first boot |

## Port Reference

| Port | Protocol | Purpose |
|------|----------|---------|
| 6443 | TCP | Kubernetes API server |
| 50000 | TCP | Talos machine API |
| 22 | TCP | SSH to Proxmox (admin access + tunnel entry point) |

## Proxmox vmbr1 Role

Proxmox keeps `10.10.0.1/24` on vmbr1 **only** to satisfy the `bridge_ipv4_address` requirement and to enable L2 reachability for SSH tunnels. When the admin runs:

```bash
ssh -L 5801:10.10.0.10:50000 root@proxmox
```

Proxmox resolves `10.10.0.10` through its directly-connected vmbr1 route (not via any gateway). The packet path is entirely local: `Proxmox kernel → vmbr1 bridge → Talos VM NIC`. The Talos node's default gateway (`10.10.0.200`) is irrelevant to this path.
