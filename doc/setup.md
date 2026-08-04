# Active Directory Lab: Step-by-Step Replication Guide

Adapted from Josh Madakor's AD homelab tutorial, modified for a **pfSense-fronted architecture** rather than a dual-NIC domain-controller-as-router setup. If you already have pfSense handling your network edge, follow this version — it keeps routing/NAT/firewall duties on pfSense and makes the DC a single-purpose directory server, closer to how a real enterprise separates these roles.

**Prerequisites:** pfSense already configured as your network edge with an internal LAN segment (this guide assumes `172.16.0.0/24`, adjust if yours differs).

---

## Part 1: Software Acquisition

1. Download and install **Oracle VirtualBox** + the **Extension Pack** (install VirtualBox first, then the extension pack).
2. Download the **Windows Server 2019 ISO** — Microsoft's evaluation center, free for 180 days.
3. Download the **Windows 10 ISO** (64-bit) for the client machine.
4. Save both ISOs somewhere you'll remember — a dedicated `ISOs` folder is cleaner than the desktop.

---

## Part 2: Create the Domain Controller VM

1. VirtualBox → **New**
2. Name: `DC`. Type: **Other Windows (64-bit)**
3. **Base Memory:** 3072–4096 MB (3–4GB). *(The original tutorial suggests 2GB minimum — on a modern host with 16GB+, 3–4GB avoids sluggish AD DS promotion.)*
4. Create the virtual disk with defaults — **dynamically allocated**, 40GB.
5. Open **Settings** before starting the VM:
   - **General → Advanced:** Shared Clipboard → Bidirectional, Drag and Drop → Bidirectional
   - **System → Processor:** 2 cores (the tutorial uses 4; 2 is sufficient for a DC and leaves headroom for your other VMs)
   - **System → Processor → Features:** confirm **PAE/NX** is checked
   - **System → Motherboard → Features:** confirm **I/O APIC** is checked (required for multi-core VMs)
   - **Network → Adapter 1:** set to **Internal Network**, same internal network name your pfSense internal interface uses

   > ⚠️ **This is the key deviation from the original tutorial.** Josh's version gives the DC two adapters (NAT + Internal) so the DC itself routes traffic. Since pfSense already handles routing/NAT/firewall at your network edge, the DC only needs **one adapter** — the internal network. Don't add a second NAT adapter here.

6. **Storage:** attach the Windows Server 2019 ISO to the virtual optical drive.
7. Start the VM.

---

## Part 3: Install Windows Server 2019

1. Boot from the ISO → **Next** → **Install**.
2. **Select an edition:** choose **Windows Server 2019 Standard (Desktop Experience)** — *not* the non-Desktop-Experience option, which installs with no GUI (command-line only).
3. Accept the license terms → **Custom: Install Windows only** → select the virtual disk → **Next**.
4. Installation will restart the VM multiple times. **Do not press any key** if prompted "Press any key to boot from CD or DVD" during these restarts — pressing a key re-triggers the installer instead of booting into Windows.
5. Once installation completes, set the built-in Administrator password (use something simple and memorable for the lab — this is not a security control, it's a local sandbox).
6. Log in: **Input → Keyboard → Insert Ctrl+Alt+Del** from the VirtualBox menu, then enter your password.

---

## Part 4: Post-Install Setup

1. **Install Guest Additions:** Devices menu → Insert Guest Additions CD image → run the installer from inside the VM (fixes mouse lag, enables resizing).
2. After Guest Additions finishes, choose **"reboot later,"** then fully shut down the VM and restart it (ensures the changes take effect cleanly).
3. Log back in.
4. **Rename the computer:** Start → right-click Start → System → Rename this PC → `DC` → restart.

---

## Part 5: Configure Networking

1. Network and Sharing Center → Change adapter options.
2. You should see **one** network adapter (internal). Rename it to `internal` for clarity.
3. Right-click → Properties → IPv4:
   - **IP address:** `172.16.0.1`
   - **Subnet mask:** `255.255.255.0`
   - **Default gateway:** leave blank *if pfSense's DHCP will hand this out later, or set it to your pfSense internal interface IP if you want the DC itself to have outbound access for updates/downloads during setup.*
   - **DNS server:** `127.0.0.1` (loopback — the DC will serve as its own DNS once AD DS is installed)

---

## Part 6: Install Active Directory Domain Services

1. **Server Manager → Add Roles and Features → Next → Next**
2. Select **Active Directory Domain Services** → Add Features when prompted → Next → Install.
3. Once installed, click the **notification flag** in Server Manager → **Promote this server to a domain controller**.
4. Select **Add a new forest** → domain name: `homelab.local` (or your preferred name — avoid `.com` for a lab domain, since `.local` signals clearly that it's not a live public domain).
5. Set a **Directory Services Restore Mode (DSRM)** password.
6. Next through the remaining screens (NetBIOS name, paths) → **Install**.
7. The server restarts automatically.

---

## Part 7: Create a Dedicated Domain Admin Account

1. Log in as `HOMELAB\Administrator` with your set password.
2. **Server Manager → Tools → Active Directory Users and Computers**
3. Right-click your domain → **New → Organizational Unit** → name it `_Admins`.
4. Inside `_Admins`, right-click → **New → User**.
5. Use an admin naming convention, e.g. `a-david` (the `a-` prefix signals "admin account" at a glance — a real-world AD convention).
6. Set a password, check **Password never expires** (lab convenience only — never do this in production).
7. Right-click the new user → **Properties → Member Of → Add → Domain Admins**.
8. Sign out and log back in as this new admin account instead of the built-in Administrator.

---

## Part 8: Configure DHCP on the Domain Controller

> ⚠️ **Second deviation from the original tutorial.** Josh's version also installs the Remote Access/Routing role on the DC for NAT. **Skip that role entirely** — pfSense already handles NAT and routing at the network edge. Installing RRAS on the DC as well would create two devices fighting over routing duties on the same segment.
>
> You still need **DHCP on the DC** (not pfSense) for this specific segment, because a real AD environment expects the DC to hand out its own IP as the DNS server via DHCP — this is what makes domain-joined clients "just work." **Disable pfSense's DHCP service on this internal interface** before continuing, to avoid two DHCP servers on the same segment fighting over leases.

1. **Add Roles and Features → DHCP Server → Add Features → Install**.
2. **Tools → DHCP** → right-click IPv4 → **New Scope**.
3. Name the scope (e.g., `172.16.0.100-200`).
4. **Start address:** `172.16.0.100` · **End address:** `172.16.0.200` · **Subnet mask:** `255.255.255.0`
5. Lease duration: default (8 days) is fine for a lab.
6. **DHCP Options — critical step:**
   - **Router (Option 003):** `172.16.0.1` *(if you want clients to route through the DC — otherwise point this at your pfSense internal interface IP if pfSense is the actual gateway for internet-bound traffic)*
   - **DNS Servers (Option 006):** `172.16.0.1` *(always the DC — this is what makes AD authentication and name resolution work)*
7. Activate the scope.
8. Right-click the DHCP server node → **Authorize**.

> 💡 **Gateway decision point:** Since pfSense is your actual router/firewall, Option 003 should point to **pfSense's internal interface IP**, not the DC — the DC is not routing traffic in this architecture. Only Option 006 (DNS) should point to the DC.

---

## Part 9: Bulk-Create Users with PowerShell

1. On the DC, disable **IE Enhanced Security Configuration** (Server Manager → Local Server) to allow downloading the script and names file.
2. Download a PowerShell AD bulk-user script and a `names.txt` file (1,000 sample names) to the desktop.
3. Open **PowerShell ISE as Administrator**.
4. Run: `Set-ExecutionPolicy Unrestricted` (lab-only setting — never do this in production).
5. Review the script logic before running it:
   - Reads names from `names.txt`
   - Converts a plaintext password into a `SecureString` object
   - Creates a `_Users` OU
   - Loops through each name, builds a username (first initial + last name), and runs `New-ADUser`
6. Navigate to the script's directory (`cd` to the desktop folder) and execute it.
7. This takes a while for 1,000 users — let it run to completion.
8. Refresh Active Directory Users and Computers → confirm the `_Users` OU is populated.

---

## Part 10: Create the Windows 10 Client VM

1. VirtualBox → **New** → name `Client1`, type Windows 10 (64-bit), **4096 MB RAM**.
2. **Network → Adapter 1:** **Internal Network** — same internal network as the DC (not NAT).
3. Attach the Windows 10 ISO, start the VM.
4. Install → **Windows 10 Pro** → "I don't have a product key" → Custom install.
5. At the setup screen, choose **limited/offline setup** to create a **local account** (avoid a Microsoft account for a lab machine) — name it `user`.

---

## Part 11: Verify Connectivity and Join the Domain

1. Open Command Prompt → `ipconfig` — confirm the client has an IP in the `172.16.0.100–200` range.
2. If there's no default gateway listed, double-check DHCP Option 003 is set correctly on the DC and run `ipconfig /renew`.
3. Confirm internet access: `ping google.com` (validates DNS + routing through pfSense).
4. Confirm domain resolution: `ping homelab.local` (validates the DC's DNS is working).
5. **Rename the computer** to `Client1` (System → Rename this PC → Advanced).
6. In the same dialog, join the domain: enter `homelab.local`, authenticate with your domain admin account (`a-david`) when prompted.
7. Restart.

---

## Part 12: Final Verification

1. On the DC: **DHCP → Address Leases** — confirm `Client1` shows a lease.
2. **Active Directory Users and Computers → Computers container** — confirm `Client1` appears as a domain member.
3. On the client: log in as one of the bulk-created domain accounts (e.g., a username from your 1,000-user script) rather than the local `user` account.
4. Open Command Prompt → `whoami` — confirm it returns `HOMELAB\username`, proving domain authentication is working.

---

## Part 13: Extensions Beyond the Base Tutorial (Your Build)

Once the above is working, layer in the pieces that go beyond Josh's original scope:

1. **Sysmon** — install on both DC and Client1 with a curated config (SwiftOnSecurity or Olaf Hartong) for high-fidelity telemetry.
2. **Group Policy** — enable advanced audit logging (Kerberos events, logon events, account management) — the DC barely logs anything useful by default.
3. **Wazuh agents** — point both DC and Client1 at your existing Ubuntu Wazuh manager.
4. **Attack simulation from Kali** — Kerberoasting, AS-REP roasting, password spraying against the domain; confirm each shows up in Wazuh (event IDs 4768/4769/4625/4648).
5. **Cloud forwarding** — extend logging to Azure Log Analytics / Sentinel per your existing pipeline.

---

## Deviations Summary (vs. the Original Tutorial)

| Original Tutorial | This Build |
|---|---|
| DC has 2 NICs (NAT + Internal), does its own routing | DC has 1 NIC (Internal only); pfSense handles routing/NAT/firewall |
| RRAS/NAT role installed on DC | Skipped entirely — pfSense already performs this function |
| DHCP Option 003 (Router) → DC's own IP | DHCP Option 003 → pfSense's internal interface IP |
| Domain: `mydomain.com` (as originally suggested by tutorial) | Kept as `mydomain.com` — worked fine as a lab domain name |

These changes mirror how a real enterprise separates edge security (firewall/router) from directory services (DC) — a detail worth mentioning explicitly if this project comes up in an interview.

---

## Known Issues Encountered

- **VM freezes at Windows loading screen during install** — root cause: PAE/NX was disabled (required for a 64-bit guest kernel to initialize), combined with VirtualBox's default Hyper-V-style Paravirtualization Interface being incompatible with a very new AMD CPU generation. **Fix:** enable PAE/NX (Processor tab) and set Paravirtualization Interface to KVM (Acceleration tab) — both changes were required together.
- **PowerShell bulk-user script — interactive "Supply values for Name" prompt** — caused by backtick line-continuation silently breaking on invisible trailing whitespace. **Fix:** replaced backtick continuation with parameter splatting (`$params = @{...}; New-ADUser @params`).
- **PowerShell script — SearchBase type conversion error** — `([ADSI]"").distinguishedName` returns a non-string object type that fails strict parameter binding. **Fix:** cast with `.ToString()` at the point of assignment.
- **Subnet collision + dual-NIC misconfiguration** — following the tutorial's addressing literally (`172.16.0.1`) placed the DC on a network disconnected from the pfSense LAN this build already had established at `192.168.56.0/24`. The DC's two NICs were also split across both networks — one correctly wired, one isolated. **Fix:** disabled the disconnected NIC, re-addressed the remaining one to `192.168.56.40` inside the real LAN, rebuilt the DHCP scope entirely (the old scope couldn't simply be patched — Windows correctly refused since it wasn't a subset of the real range).
- **Client domain sign-in failure ("domain isn't available")** — root cause was twofold: the DHCP scope's DNS option wasn't being honored on the client's active lease (client was resolving the domain through pfSense instead of the DC, which forwarded to an unrelated real-world address), and a stale DNS/AD computer record from an earlier, deleted client was left behind. **Fix:** forced a clean DHCP lease (`/release /flushdns /renew`), deleted the stale DNS Host (A) record and AD computer object, then rejoined cleanly.

Full narrative writeups of each issue — including what was ruled out along the way — are in the repo's main README and the project's GitHub release notes.
