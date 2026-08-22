<#
.SYNOPSIS
    Demo 05 | Hybrid Runbook Worker Job
    Health and inventory runbook that executes on a Hybrid Runbook Worker.

.DESCRIPTION
    Runs ON the Hybrid Worker machine (on-prem or in another cloud) rather than
    in the Azure sandbox. Reports OS build, uptime and disk space, tests TCP
    line-of-sight to an internal endpoint, and lists automatic-start services
    that are not running.

    The point of the demo is reach: anything the worker VM can see, you can
    automate - file shares, SQL, Active Directory, legacy apps, appliances -
    none of which the Azure sandbox can touch.

    Start it with -RunOn <HybridWorkerGroupName>, or select "Run on: Hybrid
    Worker" in the portal.

.PARAMETER InternalEndpoint
    Hostname to TCP-test from the worker. Defaults to 'dc01.contoso.local'.

.PARAMETER Port
    Port to test on the internal endpoint. Defaults to 389 (LDAP).

.PARAMETER DiskWarningThresholdGB
    Free space below this value raises a warning. Defaults to 10 GB.

.EXAMPLE
    Start-AzAutomationRunbook -ResourceGroupName rg-automation-bootcamp `
        -AutomationAccountName aa-bootcamp -Name 'Demo-HybridWorker' `
        -RunOn 'hwg-onprem-01'

    Runs the inventory on the on-prem worker group.

.EXAMPLE
    Start-AzAutomationRunbook -ResourceGroupName rg-automation-bootcamp `
        -AutomationAccountName aa-bootcamp -Name 'Demo-HybridWorker' `
        -RunOn 'hwg-onprem-01' `
        -Parameters @{ InternalEndpoint = 'sql01.contoso.local'; Port = 1433 }

    Tests connectivity to an internal SQL Server instead of a domain controller.

.NOTES
    Author  : Matt Balzan | mattbalzan.github.io/My-Site
    Runs on : Hybrid Runbook Worker Group (Windows)
    Identity: The worker's own context. On an Arc-enabled server with a
              System-Assigned Managed Identity, Connect-AzAccount -Identity works here too.
#>

param
(
    [Parameter(Mandatory = $false)]
    [string] $InternalEndpoint = 'dc01.contoso.local',

    [Parameter(Mandatory = $false)]
    [int] $Port = 389,

    [Parameter(Mandatory = $false)]
    [int] $DiskWarningThresholdGB = 10
)

$ErrorActionPreference = 'Stop'

Write-Output "=== Hybrid Worker job starting ==="
Write-Output "Worker host     : $env:COMPUTERNAME"
Write-Output "Running as      : $([Security.Principal.WindowsIdentity]::GetCurrent().Name)"
Write-Output "PS version      : $($PSVersionTable.PSVersion)"
Write-Output ""

# 1. OS + uptime
$os = Get-CimInstance Win32_OperatingSystem
Write-Output "OS              : $($os.Caption) $($os.Version)"
Write-Output "Last boot       : $($os.LastBootUpTime)"
Write-Output "Uptime (days)   : $([math]::Round(((Get-Date) - $os.LastBootUpTime).TotalDays, 1))"
Write-Output ""

# 2. Disk space
Write-Output "--- Disks ---"
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
    $freeGB = [math]::Round($_.FreeSpace / 1GB, 1)
    $line   = "{0}  Free: {1} GB of {2} GB" -f $_.DeviceID, $freeGB, [math]::Round($_.Size / 1GB, 1)

    if ($freeGB -lt $DiskWarningThresholdGB) { Write-Warning "$line  <-- LOW" }
    else { Write-Output $line }
}
Write-Output ""

# 3. Internal connectivity - the whole reason you use a Hybrid Worker
Write-Output "--- Connectivity ---"
$test = Test-NetConnection -ComputerName $InternalEndpoint -Port $Port -WarningAction SilentlyContinue
if ($test.TcpTestSucceeded) {
    Write-Output "Reached $InternalEndpoint on port $Port ($([math]::Round($test.PingReplyDetails.RoundtripTime,0)) ms)"
}
else {
    Write-Warning "Could NOT reach $InternalEndpoint on port $Port"
}
Write-Output ""

# 4. Stopped services that should be running
Write-Output "--- Auto-start services that are stopped ---"
$stopped = Get-Service | Where-Object { $_.StartType -eq 'Automatic' -and $_.Status -ne 'Running' }
if ($stopped) { $stopped | Select-Object Name, DisplayName, Status | Format-Table -AutoSize | Out-String | Write-Output }
else { Write-Output "None - all good." }

Write-Output "=== Hybrid Worker job complete ==="
