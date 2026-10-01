# AI Alert Triage Assistant

<p>
<img src="https://img.shields.io/badge/model-Llama%203.1%208B-6A4C93" alt="model badge">
<img src="https://img.shields.io/badge/runtime-Ollama%2C%20local-blue" alt="runtime badge">
<img src="https://img.shields.io/badge/status-v1%20finding%20confirmed%2C%20v2%20fix%20pending%20verification-orange" alt="status badge">
</p>

<p><em>A small, self-hosted tool that reads saved security events from my homelab and asks a local LLM to draft a plain-language summary. A human then checks the summary against the event data. Part of the larger <a href="../">homelab</a> project, not a standalone product.</em></p>

## Why

I finished TCM Security's AI Fundamentals course. I wanted to apply it to something real rather than a toy dataset: could a self-hosted model turn a raw Windows Security event into a summary a non-technical reader could understand, without inventing anything that isn't in the data?

## Architecture

![Project flow](./ai_summarizer_flow.svg)

Saved Wazuh/Windows event data → Python script → Ollama (Llama 3.1 8B, local, low temperature) → plain-language summary → human verification against the known facts of the case.

The script reads a saved JSON file. It does not currently connect to the Wazuh API or process a live alert feed.

## The decision

Running everything locally, on the host machine, was a deliberate choice. An earlier attempt to stand up a dedicated Ubuntu VM for Ollama hit repeated setup friction, and since this is a single-user prototype with no need for isolation, running it directly on the host let the project actually get built instead of stalling on infrastructure.

## What I did

Wrote a Python script (`summarize_alert.py`) that loads a saved security event (or an array of events), sends it to a locally running Llama 3.1 8B model via Ollama's API with a system prompt constraining it to the supplied data, and prints the result.

## Test case

The input is five real Event ID 4769 entries from my own Active Directory lab, generated during the Kerberoasting investigation: service ticket requests for `svc-sql` from the `jdoe` account, spanning August 7 to August 29.

The original events were used for local testing. Before publishing any event file, I need to check it for account names, domain names, IP addresses, hostnames, and other details I do not want to expose. A sanitized sample can illustrate the input format without publishing the original records.

## What the first version got wrong

The first system prompt produced a technically accurate but materially incomplete summary. It described the requests as happening "multiple times" on "different dates" instead of stating the actual count (5) or date range, and it never mentioned the Kerberos ticket encryption type at all, even though that field (`0x17`, RC4) was present in every event it was given.

That omission matters specifically because of what the encryption type meant in my original Kerberoasting investigation: it's the detail that determines whether a classic "look for RC4" detection signal would even apply. A summarization tool that silently drops the one field an analyst would actually check has a real limitation, not a minor stylistic issue.

**Actual v1 output:**

> A user named "jdoe" with the account name "jdoe@MYDOMAIN.COM" has requested a Kerberos service ticket to access a Windows service named "svc-sql" multiple times. The requests were made from the IP address "::ffff:192.168.56.101" on different dates and times. The requests were all successful, as indicated by a failure code of 0x0. The service ticket requests can be correlated with Windows logon events by comparing the Logon GUID fields in each event.

## The proposed fix

I rewrote the system prompt to request the exact event count when more than one is present, the account and service involved, the encryption type stated by name for every event, and a non-verdict indication of whether the pattern is worth human review. The revised prompt is in `summarize_alert.py`.

A prompt can ask for these details, but it cannot guarantee that the model will report them correctly. I still need to rerun the script and compare its v2 output with the source events before calling this a verified fix.

<!-- TODO once re-verified end to end on the host:
- Paste the v2 output here, side by side with v1.
- Check whether the count (5), date range, and encryption type (RC4) are correct.
- Record anything v2 still gets wrong.
-->

**Status:** The v1 omission is confirmed. The v2 prompt revision is written but has not yet been rerun end to end after a local environment issue (Ollama was not reachable on a retry). I have not included a v2 output or claimed that the revision works.

## A pattern worth naming

This is the third time, across three different tools, that I've found the same underlying shape of problem: a system had the correct data the whole time, but didn't surface the one detail that actually mattered. Wazuh had the Kerberoasting events but no default rule named the technique. Sentinel had the same events but no default analytic rule either. Now this summarizer had the encryption type in every event and left it out of the summary by default. Different mechanisms each time, same lesson: having the data is not the same as surfacing what matters, whether the "analyst" is a SIEM's ruleset or an LLM's system prompt.

## What's not done

No Wazuh API integration yet; the script reads from a saved file, not a live alert feed. There has been no evaluation beyond this single test case. The v2 prompt revision remains unverified, as noted above.

## What this enables

A reusable pattern for turning saved security telemetry from this homelab into readable summaries, and a second, concrete example (beyond the SIEM detection-gap findings) of why "the AI said so" is never sufficient on its own. Every output needs to be checked against the event data before being trusted.
