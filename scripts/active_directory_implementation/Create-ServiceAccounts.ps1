# ===================================================================
# Standalone: create seeded weak service accounts for Kerberoasting
# Safe to run on its own, independent of the bulk-user script.
# Idempotent — checks before creating, safe to re-run.
# ===================================================================

$DOMAIN_DN = ([ADSI]"").distinguishedName.ToString()

# ----- Base OU (idempotent) ----- #
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '_USERS'" -SearchBase $DOMAIN_DN -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name _USERS -ProtectedFromAccidentalDeletion $false
}
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '_ServiceAccounts'" -SearchBase "OU=_USERS,$DOMAIN_DN" -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name _ServiceAccounts -Path "OU=_USERS,$DOMAIN_DN" -ProtectedFromAccidentalDeletion $false
}

# ----- Seeded weak service accounts ----- #
# Intentionally weak, intentionally SPN-bearing — these are your
# planted Kerberoasting targets. Document them as such in your report.
$weakServiceAccounts = @(
    @{ Name = "svc-backup"; Password = "Summer2024!"; SPN = "MSSQLSvc/backup01.mydomain.com:1433"; Description = "Backup service account" },
    @{ Name = "svc-sql";    Password = "Password123";  SPN = "MSSQLSvc/sql01.mydomain.com:1433";    Description = "SQL service account" },
    @{ Name = "svc-web";    Password = "Welcome1!";    SPN = "HTTP/web01.mydomain.com";              Description = "Web application service account" }
)

foreach ($svc in $weakServiceAccounts) {
    $existing = Get-ADUser -Filter "Name -eq '$($svc.Name)'" -ErrorAction SilentlyContinue

    if ($existing) {
        Write-Host "Account $($svc.Name) already exists — checking SPN..." -ForegroundColor Yellow
        $currentSPNs = (Get-ADUser -Identity $svc.Name -Properties ServicePrincipalNames).ServicePrincipalNames
        if ($currentSPNs -notcontains $svc.SPN) {
            Set-ADUser -Identity $svc.Name -ServicePrincipalNames @{Add = $svc.SPN }
            Write-Host "  → SPN added to existing account." -ForegroundColor Green
        } else {
            Write-Host "  → SPN already set correctly." -ForegroundColor Green
        }
        continue
    }

    Write-Host "Creating SEEDED WEAK service account: $($svc.Name)" -BackgroundColor Black -ForegroundColor Red

    $svcPassword = ConvertTo-SecureString $svc.Password -AsPlainText -Force

    New-ADUser -Name $svc.Name `
               -AccountPassword $svcPassword `
               -Description $svc.Description `
               -PasswordNeverExpires $true `
               -Path "OU=_ServiceAccounts,OU=_USERS,$DOMAIN_DN" `
               -Enabled $true

    Set-ADUser -Identity $svc.Name -ServicePrincipalNames @{Add = $svc.SPN }
}

Write-Host "`nDone. Verify with: setspn -L svc-sql`n" -ForegroundColor Cyan
