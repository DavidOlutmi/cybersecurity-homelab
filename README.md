This project is a virtualized cybersecurity homelab designed to simulate real-world SOC (Security Operations Center) and DFIR (Digital Forensics & Incident Response) workflows.

The environment includes centralized logging, firewall monitoring, Windows event auditing, network segmentation, attack simulation, and SIEM visibility using industry-relevant tools and infrastructure.

The objective of this lab is to develop hands-on blue team, detection engineering, and incident response skills through practical security monitoring and analysis.

---

# Lab Architecture

## Components

| System | Purpose |
|---|---|
| pfSense Firewall | Network routing, segmentation, and firewall logging |
| Ubuntu Server | Wazuh SIEM and centralized log analysis |
| Windows VM | Endpoint monitoring and event generation |
| Kali Linux | Attack simulation and security testing |

---

## Network Layout

```text
                           ┌────────────────────┐
                           │      Internet      │
                           └─────────┬──────────┘
                                     │
                                    WAN
                                     │
                     ┌───────────────▼───────────────┐
                     │     pfSense Firewall          │
                     │      Gateway / Router         │
                     └───────────────┬───────────────┘
                                     │
                                    LAN
                                     │
        ┌────────────────────────────┼────────────────────────────┐
        │                            │                            │
        │                            │                            │
┌───────▼────────┐        ┌──────────▼──────────┐       ┌────────▼────────┐
│ Ubuntu Server  │        │     Kali Linux      │       │  Windows 10 VM  │
│ Wazuh SIEM     │        │   Attacker Machine  │       │   Target System │
│ Manager        │        │ Nmap / Hydra        │       │ Wazuh Agent     │
│ 192.168.56.20  │        │ 192.168.56.10       │       │ 192.168.56.30   │
└────────────────┘        └─────────────────────┘       └─────────────────┘

                    VirtualBox Internal Network (LabNet)
```
