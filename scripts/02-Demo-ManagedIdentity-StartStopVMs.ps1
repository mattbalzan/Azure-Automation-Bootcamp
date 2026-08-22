<#
.SYNOPSIS
    Demo 02 | Start / Stop VMs by Tag
    Starts or stops every VM carrying a given tag, using a Managed Identity.

.DESCRIPTION
    The classic Azure cost-saver. Authenticates with the Automation Account's
    System-Assigned Managed Identity (no secrets, nothing to rotate), finds all
    VMs matching a tag name/value pair, and starts or deallocates them.

    VMs already in the requested power state are skipped, and every action is
    reported in a summary table at the end of the job. Pair it with two
    schedules - 07:00 with -Action Start and 19:00 with -Action Stop.

.PARAMETER Action
    'Start' or 'Stop'. Stop deallocates the VM so compute billing ceases.

.PARAMETER TagName
    Tag key used to select VMs. Defaults to 'AutoShutdown'.

.PARAMETER TagValue
    Tag value that must match. Defaults to 'true'.

.PARAMETER SubscriptionId
    Optional subscription to target. Defaults to the identity's default context.

.PARAMETER WhatIfMode
    When $true, reports the VMs that would be actioned without changing anything.

.EXAMPLE
    Start-AzAutomationRunbook -ResourceGroupName rg-automation-bootcamp `
        -AutomationAccountName aa-bootcamp -Name 'Demo-StartStopVMs' `
        -Parameters @{ Action = 'Stop' }

    Deallocates every VM tagged AutoShutdown=true.

.EXAMPLE
    Start-AzAutomationRunbook -ResourceGroupName rg-automation-bootcamp `
        -AutomationAccountName aa-bootcamp -Name 'Demo-StartStopVMs' `
        -Parameters @{ Action = 'Start'; TagName = 'Env'; TagValue = 'dev'; WhatIfMode = $true }

    Dry run showing which dev VMs would be started.

.NOTES
    Author  : Matt Balzan | mattbalzan.github.io/My-Site
    Runs on : Azure sandbox (PowerShell 7.2)
    Modules : Az.Accounts, Az.Compute, Az.Resources
    Identity: System-Assigned Managed Identity with 'Virtual Machine Contributor'
              on the target scope.
#>

param
(
    [Parameter(Mandatory = $true)]
    [ValidateSet('Start', 'Stop')]
    [string] $Action,

    [Parameter(Mandatory = $false)]
    [string] $TagName = 'AutoShutdown',

    [Parameter(Mandatory = $false)]
    [string] $TagValue = 'true',

    [Parameter(Mandatory = $false)]
    [string] $SubscriptionId,

    # Dry run - report what would happen without touching anything
    [Parameter(Mandatory = $false)]
    [bool] $WhatIfMode = $false
)

$ErrorActionPreference = 'Stop'

# 1. Connect using the Managed Identity
Write-Output "Connecting with System-Assigned Managed Identity..."
Disable-AzContextAutosave -Scope Process | Out-Null
$ctx = (Connect-AzAccount -Identity).Context

if ($SubscriptionId) {
    $ctx = Set-AzContext -SubscriptionId $SubscriptionId -DefaultProfile $ctx
}
Write-Output "Subscription    : $($ctx.Subscription.Name) ($($ctx.Subscription.Id))"

# 2. Find tagged VMs
$vms = Get-AzVM -Status -DefaultProfile $ctx |
       Where-Object { $_.Tags[$TagName] -eq $TagValue }

if (-not $vms) {
    Write-Output "No VMs found with tag $TagName=$TagValue. Nothing to do."
    return
}

Write-Output "Found $($vms.Count) VM(s) tagged $TagName=$TagValue."

# 3. Act
$results = foreach ($vm in $vms) {

    $powerState = ($vm.PowerState -replace 'VM ', '')
    $needsWork  = ($Action -eq 'Start' -and $powerState -ne 'running') -or
                  ($Action -eq 'Stop'  -and $powerState -eq 'running')

    if (-not $needsWork) {
        Write-Output "[skip]  $($vm.Name) already '$powerState'"
        continue
    }

    if ($WhatIfMode) {
        Write-Output "[whatif] Would $Action $($vm.Name)"
        continue
    }

    try {
        if ($Action -eq 'Start') {
            Start-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -DefaultProfile $ctx | Out-Null
        }
        else {
            # -Force skips the confirmation, -StayProvisioned:$false deallocates so billing stops
            Stop-AzVM -ResourceGroupName $vm.ResourceGroupName -Name $vm.Name -Force -DefaultProfile $ctx | Out-Null
        }

        Write-Output "[ok]    $Action`ed $($vm.Name)"
        [pscustomobject]@{ VM = $vm.Name; Action = $Action; Result = 'Success' }
    }
    catch {
        Write-Error "[fail]  $($vm.Name): $($_.Exception.Message)"
        [pscustomobject]@{ VM = $vm.Name; Action = $Action; Result = "Failed - $($_.Exception.Message)" }
    }
}

# 4. Summary - shows nicely in the job output
$results | Format-Table -AutoSize | Out-String | Write-Output
