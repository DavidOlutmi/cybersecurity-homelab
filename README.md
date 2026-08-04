# Multi-Layer Network & Security Homelab

![Status](https://img.shields.io/badge/status-active--development-yellow)
![Platform](https://img.shields.io/badge/platform-VirtualBox-blue)
![Type](https://img.shields.io/badge/type-personal--project-lightgrey)

**[Environment](#environment) • [Features](#features) • [Architecture](#architecture) • [Setup Guide](./docs/SETUP.md) • [Roadmap](#roadmap)**

A self-built simulation of a corporate network firewall, Active Directory domain, and SIEM — designed to practice end-to-end enterprise security operations, detection engineering, and incident investigation.

## Why This Exists

As a Computer Science student, I found it difficult to gain hands-on cybersecurity experience without a real environment to practice in. Rather than wait for that experience to come from a job, I built it myself, starting from a simple two-machine attacker/defender setup and expanding it into a realistic, segmented network once I recognized that real environments involve many interconnected systems, not just one attacker and one target.

This repository documents the full build: architecture decisions, configuration, detections, and the real troubleshooting encountered along the way.

## Environment

### Host Machine
| Spec | Value |
|---|---|
| CPU | AMD Ryzen AI 7 450 w/ Radeon 860M |
| RAM | 32GB |
| Virtualization | Oracle VirtualBox |
| Host OS | Windows 11 |

### Virtual Machines
| VM | Role | OS | RAM (approx.) |
|---|---|---|---|
| pfSense | Firewall, NAT, routing, VLAN segmentation | pfSense (FreeBSD) | ~1GB |
| Domain Controller | AD DS, DNS, DHCP | Windows Server 2019 | ~4GB |
| Client1 | Domain-joined endpoint | Windows 10 | ~4GB |
| Wazuh Host | SIEM — manager, indexer, dashboard | Ubuntu Server | ~4–6GB |
| Kali | Attacker machine | Kali Linux | ~2GB |

*Allocations are sized to fit within host RAM alongside the other VMs — see [`docs/SETUP.md`](./docs/SETUP.md) for the reasoning behind each.*

## Features

- [x] Segmented internal network behind a pfSense firewall (edge NAT/routing, VLAN-capable)
- [x] Active Directory domain (`mydomain.com`); DC, DNS, DHCP
- [x] 1,000+ scripted user accounts across 6 departments, each with a matching security group
- [x] 3 seeded service accounts with registered SPNs (deliberately weak, deliberately Kerberoastable)
- [x] Domain-joined Windows 10 client
- [x] Wazuh SIEM ingesting logs across the environment, agent active on the DC
- [x] Kerberos Service Ticket auditing enabled; the DC is actually logging what the attack will produce
- [ ] Sysmon instrumentation (DC + client)
- [ ] Kerberoasting attack simulation, executed and investigated
- [ ] Detection tuning and a formal incident report
- [ ] Wazuh-to-Sentinel cloud forwarding pipeline for the AD environment

## Architecture

![Network Diagram](./images/homelab_publish_diagram.svg)

| Component | Role |
|---|---|
| **pfSense** | Network edge — firewall, NAT, routing, VLAN segmentation |
| **Windows Server 2019 (DC)** | Active Directory Domain Services, DNS, DHCP — `mydomain.com` |
| **Windows 10 Client** | Domain-joined endpoint |
| **Kali Linux** | Attacker machine — Impacket, hashcat, Kerberoasting tooling |
| **Ubuntu Server (Wazuh)** | SIEM — manager, indexer, dashboard; ingests logs from every host |

**Design decision:** pfSense handles routing and NAT here, not the DC, closer to how a real network would actually be laid out, with the firewall as its own dedicated box instead of something bolted onto the domain controller. See [`docs/SETUP.md`](./docs/SETUP.md) for the full deviation from the reference tutorial this was adapted from.

## Tech Stack

| Tool | Purpose |
|---|---|
| pfSense | Firewall, NAT, network segmentation |
| Windows Server 2019 | Active Directory Domain Services, DNS, DHCP |
| Wazuh | SIEM — log aggregation, correlation, alerting |
| PowerShell | Bulk AD provisioning, automation scripting |
| Kali Linux / Impacket | Attack simulation (Kerberoasting, enumeration) |
| Hashcat | Offline credential cracking |
| VirtualBox | Hypervisor for the entire environment |

<!--## Demo

 Screenshots go here once the attack simulation is complete:
- Wazuh dashboard showing the Kerberoasting alert
- Raw Event ID 4769 detail with encryption type visible
- Enumeration + crack output from Kali

*Screenshots coming once the attack simulation and detection tuning are complete.*
-->

## Get Started

Full step-by-step replication instructions including every deviation from the reference tutorial and the exact fixes for any issues encountered are in [`docs/SETUP.md`](./docs/SETUP.md).

## Roadmap

- [ ] Run and investigate the Kerberoasting attack against the seeded service accounts
- [ ] Write Sigma detection rules for the attack, with tuning notes
- [ ] Deploy Sysmon on the DC and client for richer telemetry
- [ ] Purple team exercise — Atomic Red Team vs. current detection coverage
- [ ] Extend log forwarding to Microsoft Sentinel for the AD environment specifically
- [ ] Publish a full incident report for the Kerberoasting investigation

## Build Log & Troubleshooting

Real problems encountered and resolved during the build are kept here because the debugging process is as valuable as the working result.

| Issue | Root Cause | Resolution |
|---|---|---|
| Ubuntu static IP reverting on reboot | NetPlan and NetworkManager both active, NetworkManager overriding config | Deactivated NetworkManager, standardized on NetPlan, full reset |
| Windows Server VM freezing at loading screen during install | 64-bit guest requires PAE/NX, which was disabled; VirtualBox's default Hyper-V-style paravirtualization interface was incompatible with a very new AMD CPU generation | Enabled PAE/NX (Processor tab) and switched Paravirtualization Interface from Default to KVM (Acceleration tab) |
| PowerShell bulk-user script — interactive "Supply values for Name" prompt on every user | Backtick line-continuation broke silently due to invisible trailing whitespace, fragmenting the `New-ADUser` command | Replaced backtick continuation with parameter splatting (`$params = @{...}; New-ADUser @params`) — eliminates this entire bug class |
| PowerShell script — "SearchBase" type conversion error | `([ADSI]"").distinguishedName` returns a non-string ADSI object type; direct parameter binding rejected it while string interpolation elsewhere silently worked | Explicitly cast with `.ToString()` at the point of assignment |
| Subnet collision + dual-NIC misconfiguration | Followed the reference tutorial's addressing literally, which placed the DC on a network disconnected from the pfSense LAN this build had already established | Disabled the disconnected NIC, re-addressed the remaining one inside the real LAN, rebuilt the DHCP scope entirely |
| Client domain sign-in failure ("domain isn't available") | DHCP wasn't handing out the DC as DNS server on the client's active lease, plus a stale DNS/AD record from an earlier, deleted client | Forced a clean DHCP lease, deleted the stale DNS record and AD computer object, rejoined cleanly |

## Skills Demonstrated

`Network segmentation` `Firewall configuration` `Active Directory administration` `DNS/DHCP` `PowerShell automation` `SIEM deployment & tuning` `Systematic troubleshooting` `Root cause analysis`

## What I Learned

Building the environment was the easy part; in hindsight, the harder skill was turning a wall of terminal output into something someone could actually act on. When the client kept failing to join the domain, the fix wasn't obvious from the error message; it took walking backward from "domain isn't available" to a stale DNS record left behind by a machine that no longer existed. Writing that up clearly, in a way that made sense to someone who hadn't been staring at it for hours, turned out to matter more than the fix itself. That's the part of security I actually want to get better at.

## Acknowledgements

The base Active Directory build follows [Josh Madakor's AD homelab walkthrough](https://www.youtube.com/@JoshMadakor) — credit to him for the original structure and PowerShell bulk-user script this was adapted from. See [`docs/SETUP.md`](./docs/SETUP.md) for exactly what was changed and why.

## License

This is a personal learning project. Feel free to reference the approach or adapt the scripts — the environment itself is specific to my own setup and troubleshooting history.

---

*Built and documented by David Olutimi — [LinkedIn](https://www.linkedin.com/in/david-olutimi/)*
