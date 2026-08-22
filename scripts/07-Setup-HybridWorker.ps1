<#
.SYNOPSIS
    Demo 07 | Onboard a Hybrid Runbook Worker
    Onboards an Azure VM or Arc-enabled server as an Extension-based Hybrid Runbook Worker.

.DESCRIPTION
    Creates the Hybrid Worker Group if it does not exist, registers the target
    machine into it, then installs the HybridWorkerExtension.

    There are two paths:
      AzureVM - install the extension directly on the Azure VM
      Arc     - connect the on-prem or other-cloud machine to Azure Arc first,
                then install the same extension on the Arc resource

    The legacy Log Analytics agent-based Hybrid Worker was retired on
    31 August 2024, so extension-based onboarding is the only supported route.

.PARAMETER ResourceGroup
    Resource group containing the Automation Account and the target machine.

.PARAMETER AutomationName
    Name of the Automation Account.

.PARAMETER HybridGroupName
    Hybrid Worker Group to create or join.

.PARAMETER MachineName
    Name of the Azure VM or Arc-enabled server to onboard.

.PARAMETER Location
    Region of the target machine. Defaults to 'uksouth'.

.PARAMETER MachineType
    'AzureVM' or 'Arc'. Determines which extension cmdlet is used.

.EXAMPLE
    .\07-Setup-HybridWorker.ps1 -ResourceGroup rg-automation-bootcamp `
        -AutomationName aa-bootcamp -HybridGroupName hwg-onprem-01 -MachineName vm-worker-01

    Onboards an Azure VM as a Hybrid Runbook Worker.

.EXAMPLE
    .\07-Setup-HybridWorker.ps1 -ResourceGroup rg-automation-bootcamp `
        -AutomationName aa-bootcamp -HybridGroupName hwg-onprem-01 `
        -MachineName srv-onprem-01 -MachineType Arc

    Onboards an Arc-enabled on-prem server as a Hybrid Runbook Worker.

.NOTES
    Author  : Matt Balzan | mattbalzan.github.io/My-Site
    Runs on : Your machine (Connect-AzAccount first)
    Modules : Az.Accounts, Az.Automation, Az.Compute, Az.ConnectedMachine
    Linux   : Change ExtensionType to 'HybridWorkerForLinux'.
#>

param
(
    [Parameter(Mandatory = $true)]  [string] $ResourceGroup,
    [Parameter(Mandatory = $true)]  [string] $AutomationName,
    [Parameter(Mandatory = $true)]  [string] $HybridGroupName,
    [Parameter(Mandatory = $true)]  [string] $MachineName,
    [Parameter(Mandatory = $false)] [string] $Location = 'uksouth',

    # 'AzureVM' or 'Arc'
    [Parameter(Mandatory = $false)]
    [ValidateSet('AzureVM', 'Arc')]
    [string] $MachineType = 'AzureVM'
)

$ErrorActionPreference = 'Stop'

# 1. Ensure the Hybrid Worker Group exists
Write-Host "[1/3] Hybrid Worker Group '$HybridGroupName'..." -ForegroundColor Cyan
if (-not (Get-AzAutomationHybridRunbookWorkerGroup -ResourceGroupName $ResourceGroup `
            -AutomationAccountName $AutomationName -Name $HybridGroupName -ErrorAction SilentlyContinue)) {

    New-AzAutomationHybridRunbookWorkerGroup `
        -ResourceGroupName     $ResourceGroup `
        -AutomationAccountName $AutomationName `
        -Name                  $HybridGroupName | Out-Null
}

# 2. Register the machine as a worker
Write-Host "[2/3] Registering '$MachineName' as a worker..." -ForegroundColor Cyan

$vmResourceId = if ($MachineType -eq 'AzureVM') {
    (Get-AzVM -ResourceGroupName $ResourceGroup -Name $MachineName).Id
}
else {
    (Get-AzConnectedMachine -ResourceGroupName $ResourceGroup -Name $MachineName).Id
}

New-AzAutomationHybridRunbookWorker `
    -ResourceGroupName     $ResourceGroup `
    -AutomationAccountName $AutomationName `
    -HybridRunbookWorkerGroupName $HybridGroupName `
    -Name                  ([guid]::NewGuid().Guid) `
    -VmResourceId          $vmResourceId | Out-Null

# 3. Install the Hybrid Worker extension
Write-Host "[3/3] Installing HybridWorkerExtension..." -ForegroundColor Cyan

$aa       = Get-AzAutomationAccount -ResourceGroupName $ResourceGroup -Name $AutomationName
$settings = @{ AutomationAccountURL = $aa.AutomationHybridServiceUrl }

$extParams = @{
    ResourceGroupName  = $ResourceGroup
    Location           = $Location
    Publisher          = 'Microsoft.Azure.Automation.HybridWorker'
    ExtensionType      = 'HybridWorkerForWindows'   # 'HybridWorkerForLinux' for Linux
    TypeHandlerVersion = '1.1'
    Settings           = $settings
    Name               = 'HybridWorkerExtension'
}

if ($MachineType -eq 'AzureVM') {
    Set-AzVMExtension @extParams -VMName $MachineName -EnableAutomaticUpgrade $true
}
else {
    New-AzConnectedMachineExtension @extParams -MachineName $MachineName -EnableAutomaticUpgrade
}

Write-Host "`nDone. Verify the heartbeat under:" -ForegroundColor Green
Write-Host "  Automation Account > Hybrid worker groups > $HybridGroupName"
Write-Host "`nThen run a job on it:" -ForegroundColor Cyan
Write-Host "  Start-AzAutomationRunbook -ResourceGroupName $ResourceGroup ``"
Write-Host "    -AutomationAccountName $AutomationName -Name 'Demo-HybridWorker' ``"
Write-Host "    -RunOn '$HybridGroupName'"
