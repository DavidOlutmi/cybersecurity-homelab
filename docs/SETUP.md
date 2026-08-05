# Active Directory Lab: Step-by-Step Replication Guide

Based on Josh Madakor's AD homelab tutorial, but changed for a pfSense fronted architecture instead of a dual-NIC domain controller acting as its own router. If you already have pfSense handling your network edge, follow this version. It keeps routing, NAT, and firewall duties on pfSense and makes the DC a single-purpose directory server, which is closer to how a real enterprise separates these roles.

**Prerequisites:** pfSense already configured as your network edge with an internal LAN segment (this guide assumes `172.16.0.0/24`, adjust if yours is different).

---

## Part 1: Software Acquisition

1. Download and install **Oracle VirtualBox** plus the **Extension Pack** (install VirtualBox first, then the extension pack).
2. Download the **Windows Server 2019 ISO** from Microsoft's evaluation center, free for 180 days.
3. Download the **Windows 10 ISO** (64-bit) for the client machine.
4. Save both ISOs somewhere you'll actually remember. A dedicated `ISOs` folder is cleaner than the desktop.

---

## Part 2: Create the Domain Controller VM

1. VirtualBox → **New**
2. Name it `DC`. Type: **Other Windows (64-bit)**
3. **Base Memory:** 3072 to 4096 MB (3 to 4GB). The original tutorial suggests 2GB minimum, but on a modern host with 16GB or more, 3 to 4GB avoids a sluggish AD DS promotion.
4. Create the virtual disk with the defaults, dynamically allocated, 40GB.
5. Open **Settings** before starting the VM:
   - **General → Advanced:** Shared Clipboard set to Bidirectional, Drag and Drop set to Bidirectional
   - **System → Processor:** 2 cores (the tutorial uses 4, but 2 is enough for a DC and leaves headroom for your other VMs)
   - **System → Processor → Features:** confirm **PAE/NX** is checked
   - **System → Motherboard → Features:** confirm **I/O APIC** is checked (required for multi core VMs)
   - **Network → Adapter 1:** set to **Internal Network**, using the same internal network name your pfSense internal interface uses

   >  **This is the key difference from the original tutorial.** Josh's version gives the DC two adapters (NAT and Internal) so the DC itself routes traffic. Since pfSense already handles routing, NAT, and firewall duties at your network edge, the DC only needs one adapter, the internal network. Don't add a second NAT adapter here.

6. **Storage:** Attach the Windows Server 2019 ISO to the virtual optical drive.
7. Start the VM.

---

## Part 3: Install Windows Server 2019

1. Boot from the ISO → **Next** → **Install**.
2. **Select an edition:** choose **Windows Server 2019 Standard (Desktop Experience)**, not the non-Desktop Experience option, which installs with no GUI at all.
3. Accept the license terms → **Custom: Install Windows only** → select the virtual disk → **Next**.
4. Installation restarts the VM several times. **Do not press any key** if you see "Press any key to boot from CD or DVD" during these restarts. Pressing a key just re-triggers the installer instead of booting into Windows.
5. Once installation completes, set the built-in Administrator password (keep it simple and memorable for the lab; this isn't a security control, it's a local sandbox).
6. Log in: **Input → Keyboard → Insert Ctrl+Alt+Del** from the VirtualBox menu, then enter your password.

---

## Part 4: Post-Install Setup

1. **Install Guest Additions:** Devices menu → Insert Guest Additions CD image → run the installer from inside the VM (fixes mouse lag, lets the window resize properly).
2. After Guest Additions finishes, choose "reboot later," then fully shut down the VM and restart it so the changes actually take effect.
3. Log back in.
4. **Rename the computer:** Start → right click Start → System → Rename this PC → `DC` → restart.

---

## Part 5: Configure Networking

1. Network and Sharing Center → Change adapter options.
2. You should see one network adapter (internal). Rename it `internal` so it's clear later.
3. Right click → Properties → IPv4:
   - **IP address:** `172.16.0.1`
   - **Subnet mask:** `255.255.255.0`
   - **Default gateway:** leave blank if pfSense's DHCP will hand this out later. Or set it to your pfSense internal interface IP if you want the DC itself to have outbound access for updates during setup.
   - **DNS server:** `127.0.0.1` (loopback. The DC will serve as its own DNS once AD DS is installed.)

---

## Part 6: Install Active Directory Domain Services

1. **Server Manager → Add Roles and Features → Next → Next**
2. Select **Active Directory Domain Services** → Add Features when prompted → Next → Install.
3. Once installed, click the notification flag in Server Manager → **Promote this server to a domain controller**.
4. Select **Add a new forest** → domain name: `homelab.local` (or whatever you prefer. Avoid `.com` for a lab domain since `.local` makes it obvious this isn't a live public domain.)
5. Set a **Directory Services Restore Mode (DSRM)** password.
6. Continue through the remaining screens (NetBIOS name, paths) → **Install**.
7. The server restarts automatically.

---

## Part 7: Create a Dedicated Domain Admin Account

1. Log in as `HOMELAB\Administrator` with your password.
2. **Server Manager → Tools → Active Directory Users and Computers**
3. Right click your domain → **New → Organizational Unit** → name it `_Admins`.
4. Inside `_Admins`, right click → **New → User**.
5. Use an admin naming convention, something like `a-david` (the `a-` prefix makes it obvious this is an admin account at a glance; it's a real-world AD convention).
6. Set a password, check **Password never expires** (this is a lab convenience only, never do this in production).
7. Right click the new user → **Properties → Member Of → Add → Domain Admins**.
8. Sign out and log back in as this new admin account instead of the built-in Administrator.

---

## Part 8: Configure DHCP on the Domain Controller

>  **Second difference from the original tutorial.** Josh's version also installs the Remote Access/Routing role on the DC for NAT. Skip that role entirely. pfSense already handles NAT and routing at the network edge. Installing RRAS on the DC too would create two devices fighting over routing duties on the same segment.
>
> You still need DHCP on the DC, not pfSense, for this specific segment, because a real AD environment expects the DC to hand out its own IP as the DNS server through DHCP. That's what makes domain-joined clients "just work." Disable pfSense's DHCP service on this internal interface before continuing, so you don't end up with two DHCP servers on the same segment fighting over leases.

1. **Add Roles and Features → DHCP Server → Add Features → Install**.
2. **Tools → DHCP** → right click IPv4 → **New Scope**.
3. Name the scope (something like `172.16.0.100-200`).
4. **Start address:** `172.16.0.100`, **End address:** `172.16.0.200`, **Subnet mask:** `255.255.255.0`
5. Lease duration: the default (8 days) is fine for a lab.
6. **DHCP Options, this step matters:**
   - **Router (Option 003):** `172.16.0.1` if you want clients to route through the DC. Otherwise point this at your pfSense internal interface IP if pfSense is the actual gateway for internet-bound traffic.
   - **DNS Servers (Option 006):** `172.16.0.1`, always the DC. This is what makes AD authentication and name resolution actually work.
7. Activate the scope.
8. Right-click the DHCP server node → **Authorize**.

>  **Gateway decision point:** since pfSense is your actual router and firewall, Option 003 should point to pfSense's internal interface IP, not the DC. The DC isn't routing traffic in this setup. Only Option 006 (DNS) should point to the DC.

---

## Part 9: Bulk Create Users with PowerShell

1. On the DC, disable **IE Enhanced Security Configuration** (Server Manager → Local Server) so you can download the script and names file.
2. Download a PowerShell AD bulk user script and a `names.txt` file (1,000 sample names) to the desktop.
3. Open **PowerShell ISE as Administrator**.
4. Run: `Set-ExecutionPolicy Unrestricted` (lab-only setting, never do this in production).
5. Read through the script logic before running it. It should:
   - Read names from `names.txt`
   - Convert a plaintext password into a `SecureString` object
   - Create a `_Users` OU
   - Loop through each name, build a username (first initial plus last name), and run `New-ADUser`
6. Navigate to the script's directory (`cd` to the desktop folder) and run it.
7. This takes a while for 1,000 users. Let it finish.
8. Refresh Active Directory Users and Computers → confirm the `_Users` OU is actually populated.

---

## Part 10: Create the Windows 10 Client VM

1. VirtualBox → **New** → name it `Client1`, type Windows 10 (64 bit), **4096 MB RAM**.
2. **Network → Adapter 1:** **Internal Network**, same internal network as the DC, not NAT.
3. Attach the Windows 10 ISO, start the VM.
4. Install → **Windows 10 Pro** → "I don't have a product key" → Custom install.
5. At the setup screen, choose limited/offline setup to create a local account (skip the Microsoft account for a lab machine) and name it `user`.

---

## Part 11: Verify Connectivity and Join the Domain

1. Open Command Prompt → `ipconfig`. Confirm the client has an IP in the `172.16.0.100–200` range.
2. If there's no default gateway listed, double-check DHCP Option 003 on the DC and run `ipconfig /renew`.
3. Confirm internet access: `ping google.com` (this checks DNS and routing through pfSense).
4. Confirm domain resolution: `ping homelab.local` (this checks that the DC's DNS is working).
5. **Rename the computer** to `Client1` (System → Rename this PC → Advanced).
6. In the same dialog, join the domain: enter `homelab.local`, authenticate with your domain admin account (`a-david`) when it asks.
7. Restart.

---

## Part 12: Final Verification

1. On the DC: **DHCP → Address Leases**. Confirm `Client1` shows a lease.
2. **Active Directory Users and Computers → Computers container**. Confirm `Client1` shows up as a domain member.
3. On the client, log in as one of the bulk-created domain accounts (any username from your 1,000 user script) instead of the local `user` account.
4. Open Command Prompt → `whoami`. It should return `HOMELAB\username`, which proves domain authentication is actually working.

---

## Part 13: Extensions Beyond the Base Tutorial (My Build)

Once the above is working, here's what I added on top of Josh's original scope:

1. **Sysmon**, installed on both DC and Client1 with a curated config (SwiftOnSecurity or Olaf Hartong) for better telemetry.
2. **Group Policy** to enable advanced audit logging (Kerberos events, logon events, account management). The DC barely logs anything useful by default.
3. **Wazuh agents** on both DC and Client1, pointed at my existing Ubuntu Wazuh manager.
4. **Attack simulation from Kali**, Kerberoasting, AS-REP roasting, password spraying against the domain, then confirming each one shows up in Wazuh (event IDs 4768/4769/4625/4648).
5. **Cloud forwarding**, extending logging to Azure Log Analytics and Sentinel through my existing pipeline.

---

## Differences vs the Original Tutorial

| Original Tutorial | This Build |
|---|---|
| DC has 2 NICs (NAT and Internal), does its own routing | DC has 1 NIC (Internal only). pfSense handles routing, NAT, and firewall. |
| RRAS/NAT role installed on DC | Skipped entirely. pfSense already does this. |
| DHCP Option 003 (Router) points to DC's own IP | DHCP Option 003 points to pfSense's internal interface IP |
| Domain: `mydomain.com` (as the tutorial originally suggests) | Kept as `mydomain.com`. Worked fine as a lab domain name. |

These changes mirror how a real enterprise separates edge security (firewall/router) from directory services (DC), which is worth mentioning if this project comes up in an interview.

---

## Known Issues Encountered

- **VM freezes at the Windows loading screen during install.** Root cause: PAE/NX was disabled (needed for a 64-bit guest kernel to initialize), combined with VirtualBox's default Hyper-V style Paravirtualization Interface being incompatible with a very new AMD CPU generation. Fix: enable PAE/NX (Processor tab) and set Paravirtualization Interface to KVM (Acceleration tab). Both changes were needed together.
- **PowerShell bulk user script gave an interactive "Supply values for Name" prompt.** Caused by backtick line continuation silently breaking on invisible trailing whitespace. Fix: replaced backtick continuation with parameter splatting (`$params = @{...}; New-ADUser @params`).
- **PowerShell script threw a SearchBase type conversion error.** `([ADSI]"").distinguishedName` returns a non-string object type that fails strict parameter binding. Fix: cast with `.ToString()` at the point of assignment.
- **Subnet collision and a dual NIC misconfiguration.** Following the tutorial's addressing literally (`172.16.0.1`) put the DC on a network that was disconnected from the pfSense LAN this build had already set up at `192.168.56.0/24`. The DC's two NICs were also split across both networks, one correctly wired, one isolated. Fix: disabled the disconnected NIC, re-addressed the remaining one to `192.168.56.40` inside the real LAN, and rebuilt the DHCP scope entirely (the old scope couldn't just be patched; Windows correctly refused since it wasn't a subset of the real range).
- **Client domain sign-in failed with "domain isn't available."** Root cause was two things at once: the DHCP scope's DNS option wasn't being honored on the client's active lease (the client was resolving the domain through pfSense instead of the DC, which forwarded it to an unrelated real-world address), plus a stale DNS/AD computer record left over from an earlier, deleted client. Fix: forced a clean DHCP lease (`/release /flushdns /renew`), deleted the stale DNS Host (A) record and AD computer object, then rejoined cleanly.

Full writeups of each issue, including what I ruled out along the way, are in the repo's main README and the project's GitHub release notes.
