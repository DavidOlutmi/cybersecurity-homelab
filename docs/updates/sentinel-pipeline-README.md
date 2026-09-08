# Wazuh-to-Sentinel Pipeline

<p>
<img src="https://img.shields.io/badge/scope-DC--only-orange" alt="scope badge">
<img src="https://img.shields.io/badge/status-working-brightgreen" alt="status badge">
<img src="https://img.shields.io/badge/cost-minimized-blue" alt="cost badge">
</p>

<p><em>A small, deliberately cost-scoped extension of the homelab, connecting the on-prem Wazuh SIEM to a cloud query surface in Microsoft Sentinel.</em></p>

## Why
I already had a working Wazuh SIEM and a separate Azure Sentinel lab, but they'd never been connected. I wanted a second, cloud-based lens on my domain controller's telemetry, without paying to ingest data from every host in the lab.


## The decision

<blockquote>
Rather than forwarding all lab telemetry (DC, client, Kali) to Sentinel, I scoped this to the domain controller only. Full-lab ingestion would have added ongoing cost with limited additional insight for a personal lab at this scale; most of what matters for this project happens on the DC. This was a deliberate cost-and-scope trade-off, not a limitation I ran into.
</blockquote>

## What I did

Connected the DC as a data source to my existing Log Analytics Workspace, configured forwarding, and confirmed telemetry was arriving correctly.

## What I verified

Ran a KQL query against the workspace and confirmed real DC events were present and queryable.

![Query Diagram](/images/Azure_DC_4769_Telemetry.png)

## A second data point on the same finding

<table>
<tr>
<td>
This mirrors what I found in Wazuh during the original Kerberoasting investigation. In both platforms, the underlying telemetry (Event ID 4769 for the targeted service accounts) is present and correctly logged, but no default analytic or detection rule maps this specific pattern to <strong>T1558.003 (Steal or Forge Kerberos Tickets: Kerberoasting)</strong>. Sentinel's MITRE ATT&CK page only surfaces techniques tied to a fired analytic rule or incident, not raw matching log events. No such rule ships by default for this technique, which is why the traffic shows up under Brute Force and similar adjacent categories instead of being named directly.
![Query Diagram](/images/Azure_DC_4769_Telemetry.png)

<br><br>
The same root cause, missing detection content rather than missing telemetry, shows up independently in two different SIEM platforms built by two different companies, which suggests this is a genuine, general gap in default detection coverage for Kerberoasting, not a quirk of either tool specifically.
<br><br>
Writing a Sentinel analytic rule for this, the cloud-side counterpart to the Sigma rule already planned for Wazuh, is the natural next step. Not required for this pipeline to be considered complete, but a clear direction for extending it.
</td>
</tr>
</table>

![MITRE ATT&CK](/images/Azure_DC_MITRE_ATT&CK.png)
## What's not done

Client and Kali telemetry are not forwarded to Sentinel; this pipeline covers the domain controller only, by design.

## What this enables

A second query surface for existing investigations (including the Kerberoasting case), and a foundation for extending cloud correlation later, without the cost of full-lab ingestion today.
