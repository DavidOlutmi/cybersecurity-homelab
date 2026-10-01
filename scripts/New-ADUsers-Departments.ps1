# ----- Edit these Variables for your own Use Case ----- #
$PASSWORD_FOR_USERS = "Password1"
$NAMES_FILE_PATH    = Join-Path $PSScriptRoot "names.txt"
$DOMAIN_DN          = ([ADSI]"").distinguishedName.ToString()
# ------------------------------------------------------ #

# ===================================================================
# Load names strictly from names.txt — no interactive fallback.
# Using $PSScriptRoot ensures this reads names.txt from the SAME
# folder as this script, regardless of your current working directory.
# Note: $PSScriptRoot only populates when running this as a saved .ps1
# file (F5 / Run). If pasting into the console line-by-line instead,
# replace $NAMES_FILE_PATH above with a full explicit path, e.g.
# "C:\Users\YourName\Desktop\ad-lab\names.txt"
# ===================================================================
if (-not (Test-Path $NAMES_FILE_PATH)) {
    Write-Host "ERROR: names.txt not found at: $NAMES_FILE_PATH" -ForegroundColor Red
    Write-Host "Current script folder (PSScriptRoot): $PSScriptRoot" -ForegroundColor Yellow
    exit
}

$USER_FIRST_LAST_LIST = Get-Content $NAMES_FILE_PATH | Where-Object { $_.Trim() -ne "" }

if (-not $USER_FIRST_LAST_LIST -or $USER_FIRST_LAST_LIST.Count -eq 0) {
    Write-Host "ERROR: names.txt was found but contains no usable names." -ForegroundColor Red
    exit
}

Write-Host "Loaded $($USER_FIRST_LAST_LIST.Count) names from $NAMES_FILE_PATH" -ForegroundColor Green

$password = ConvertTo-SecureString $PASSWORD_FOR_USERS -AsPlainText -Force

# ----- Base OU ----- #
if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '_USERS'" -SearchBase $DOMAIN_DN -ErrorAction SilentlyContinue)) {
    New-ADOrganizationalUnit -Name _USERS -ProtectedFromAccidentalDeletion $false
}

# ===================================================================
# ADDITION 1 — Departments: create a sub-OU for each department
# ADDITION 2 — Groups: create a matching security group per department
# (Both checks below make this safe to re-run without duplicate errors)
# ===================================================================
$departments = @("IT", "Finance", "HR", "Sales", "Marketing", "Engineering")

foreach ($dept in $departments) {
    if (-not (Get-ADOrganizationalUnit -Filter "Name -eq '$dept'" -SearchBase "OU=_USERS,$DOMAIN_DN" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $dept -Path "OU=_USERS,$DOMAIN_DN" -ProtectedFromAccidentalDeletion $false
    }
    if (-not (Get-ADGroup -Filter "Name -eq '$dept-Users'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name "$dept-Users" -GroupScope Global -GroupCategory Security -Path "OU=_USERS,$DOMAIN_DN"
    }
}

# ===================================================================
# Main user creation loop
# ===================================================================
foreach ($n in $USER_FIRST_LAST_LIST) {
    $parts = $n.Trim() -split "\s+"

    # Skip any line that isn't cleanly "First Last"
    if ($parts.Count -lt 2 -or [string]::IsNullOrWhiteSpace($parts[0]) -or [string]::IsNullOrWhiteSpace($parts[1])) {
        Write-Host "Skipping malformed name entry: '$n'" -ForegroundColor DarkYellow
        continue
    }

    $first    = $parts[0].ToLower()
    $last     = $parts[1].ToLower()
    $username = "$($first.Substring(0,1))$($last)".ToLower()

    # ADDITION 1 — assign a random department for this user
    $dept = Get-Random -InputObject $departments

    Write-Host "Creating user: $($username)  [$dept]" -BackgroundColor Black -ForegroundColor Cyan

    # ===================================================================
    # Using a splat (hashtable of parameters) instead of backtick line
    # continuation. This eliminates an entire class of bug: a single
    # invisible trailing space after a backtick silently breaks the
    # multi-line command and causes New-ADUser to prompt interactively
    # for "Name" — the exact symptom this replaces.
    # ===================================================================
    $userParams = @{
        AccountPassword     = $password
        GivenName           = $first
        Surname             = $last
        DisplayName         = $username
        Name                = $username
        EmployeeID          = $username
        PasswordNeverExpires = $true
        Path                = "OU=$dept,OU=_USERS,$DOMAIN_DN"
        Enabled             = $true
    }

    New-ADUser @userParams

    # ADDITION 2 — add the new user to their department's security group
    Add-ADGroupMember -Identity "$dept-Users" -Members $username
}

Write-Host "`nUser creation complete. $($departments.Count) departments populated with matching security groups.`n" -ForegroundColor Green
