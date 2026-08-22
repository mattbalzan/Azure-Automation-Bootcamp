<#
.SYNOPSIS
    Demo 06 | Build the whole lab with Az PowerShell
    Builds the complete Azure Automation bootcamp lab in one pass.

.DESCRIPTION
    End-to-end lab build. Creates the resource group and an Automation Account
    with a System-Assigned Managed Identity, grants that identity least-privilege
    RBAC scoped to the resource group, imports and publishes the demo runbooks,
    registers a nightly shutdown schedule, creates a webhook (capturing the URL,
    which Azure only ever shows once) and creates an empty Hybrid Worker Group
    ready for 07-Setup-HybridWorker.ps1.

    Run it from your own machine after Connect-AzAccount. Tear the lab down with
    Remove-AzResourceGroup.

.PARAMETER ResourceGroup
    Resource group to create or reuse. Defaults to 'rg-automation-bootcamp'.

.PARAMETER Location
    Azure region for all resources. Defaults to 'uksouth'.

.PARAMETER AutomationName
    Automation Account name. Defaults to a randomised 'aa-bootcamp-NNNN'.

.PARAMETER HybridGroupName
    Name of the Hybrid Worker Group to create. Defaults to 'hwg-onprem-01'.

.PARAMETER ScriptPath
    Folder containing the demo runbook .ps1 files. Defaults to this script's folder.

.EXAMPLE
    .\06-Setup-AutomationAccount.ps1

    Builds the lab with all defaults in UK South.

.EXAMPLE
    .\06-Setup-AutomationAccount.ps1 -ResourceGroup rg-aa-demo -Location westeurope `
        -AutomationName aa-demo-01

    Builds the lab with explicit names in West Europe.

.NOTES
    Author  : Matt Balzan | mattbalzan.github.io/My-Site
    Runs on : Your machine (Connect-AzAccount first)
    Modules : Az.Accounts, Az.Automation, Az.Resources
    Rights  : Owner or Contributor + User Access Administrator (for the role assignment)
#>

param
(
    [string] $ResourceGroup   = 'rg-automation-bootcamp',
    [string] $Location        = 'uksouth',
    [string] $AutomationName  = "aa-bootcamp-$((Get-Random -Maximum 9999))",
    [string] $HybridGroupName = 'hwg-onprem-01',
    [string] $ScriptPath      = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'

# 1. Resource group
Write-Host "[1/7] Resource group..." -ForegroundColor Cyan
if (-not (Get-AzResourceGroup -Name $ResourceGroup -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name $ResourceGroup -Location $Location | Out-Null
}

# 2. Automation Account with System-Assigned Managed Identity
Write-Host "[2/7] Automation Account '$AutomationName'..." -ForegroundColor Cyan
$aa = New-AzAutomationAccount `
        -ResourceGroupName $ResourceGroup `
        -Name              $AutomationName `
        -Location          $Location `
        -Plan              Basic `
        -AssignSystemIdentity

Write-Host "      Managed Identity principalId: $($aa.Identity.PrincipalId)"

# 3. Grant RBAC to the Managed Identity (least privilege - scope to the RG)
Write-Host "[3/7] RBAC assignment..." -ForegroundColor Cyan
$sub = (Get-AzContext).Subscription.Id
New-AzRoleAssignment `
    -ObjectId           $aa.Identity.PrincipalId `
    -RoleDefinitionName 'Virtual Machine Contributor' `
    -Scope              "/subscriptions/$sub/resourceGroups/$ResourceGroup" `
    -ErrorAction SilentlyContinue | Out-Null

# 4. Import and publish the demo runbooks
Write-Host "[4/7] Importing runbooks..." -ForegroundColor Cyan
$runbooks = @(
    @{ Name = 'Demo-HelloWorld';    File = '01-Demo-HelloWorld-Runbook.ps1' }
    @{ Name = 'Demo-StartStopVMs';  File = '02-Demo-ManagedIdentity-StartStopVMs.ps1' }
    @{ Name = 'Demo-WebhookTarget'; File = '03-Demo-Webhook-Runbook.ps1' }
    @{ Name = 'Demo-HybridWorker';  File = '05-Demo-HybridWorker-Runbook.ps1' }
)

foreach ($rb in $runbooks) {
    $path = Join-Path $ScriptPath $rb.File
    if (-not (Test-Path $path)) { Write-Warning "Missing $path - skipped"; continue }

    Import-AzAutomationRunbook `
        -ResourceGroupName    $ResourceGroup `
        -AutomationAccountName $AutomationName `
        -Name                 $rb.Name `
        -Path                 $path `
        -Type                 PowerShell72 `
        -Published -Force | Out-Null

    Write-Host "      published: $($rb.Name)"
}

# 5. Daily schedule linked to the start/stop runbook
Write-Host "[5/7] Schedule..." -ForegroundColor Cyan
$schedule = New-AzAutomationSchedule `
    -ResourceGroupName     $ResourceGroup `
    -AutomationAccountName $AutomationName `
    -Name                  'Nightly-Shutdown-1900' `
    -StartTime             (Get-Date).Date.AddDays(1).AddHours(19) `
    -DayInterval           1 `
    -TimeZone              'Europe/London'

Register-AzAutomationScheduledRunbook `
    -ResourceGroupName     $ResourceGroup `
    -AutomationAccountName $AutomationName `
    -RunbookName           'Demo-StartStopVMs' `
    -ScheduleName          $schedule.Name `
    -Parameters            @{ Action = 'Stop'; TagName = 'AutoShutdown'; TagValue = 'true' } | Out-Null

# 6. Webhook - the URL is returned ONCE, capture it now
Write-Host "[6/7] Webhook..." -ForegroundColor Cyan
$webhook = New-AzAutomationWebhook `
    -ResourceGroupName     $ResourceGroup `
    -AutomationAccountName $AutomationName `
    -Name                  'wh-demo-webhooktarget' `
    -RunbookName           'Demo-WebhookTarget' `
    -IsEnabled             $true `
    -ExpiryTime            (Get-Date).AddDays(90) `
    -Force

Write-Host "      URL (shown once - store it in Key Vault!):" -ForegroundColor Yellow
Write-Host "      $($webhook.WebhookURI)"
$env:AA_WEBHOOK_URI = $webhook.WebhookURI

# 7. Hybrid Worker Group
Write-Host "[7/7] Hybrid Worker Group..." -ForegroundColor Cyan
New-AzAutomationHybridRunbookWorkerGroup `
    -ResourceGroupName     $ResourceGroup `
    -AutomationAccountName $AutomationName `
    -Name                  $HybridGroupName `
    -ErrorAction SilentlyContinue | Out-Null

Write-Host "`nDone. Test the webhook with:" -ForegroundColor Green
Write-Host "  .\04-Demo-Webhook-Trigger.ps1"
Write-Host "`nTear the lab down with:" -ForegroundColor DarkGray
Write-Host "  Remove-AzResourceGroup -Name $ResourceGroup -Force"
