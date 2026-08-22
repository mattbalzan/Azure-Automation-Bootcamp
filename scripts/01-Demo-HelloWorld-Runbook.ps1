<#
.SYNOPSIS
    Demo 01 | Hello World Runbook
    Smoke-test runbook that proves an Automation Account can run a job.

.DESCRIPTION
    The "does it even run?" runbook. Writes a greeting plus useful job context
    (UTC time, PowerShell version, sandbox host name) and demonstrates the
    Output, Verbose and Warning streams, each of which lands in its own tab of
    the job output blade.

    Runs in the Azure sandbox on PowerShell 7.2 and requires no identity, so it
    is the fastest way to confirm a new Automation Account is healthy before
    building anything complicated on top of it.

.PARAMETER Name
    Name to greet in the output. Defaults to 'Bootcamp'.

.EXAMPLE
    Start-AzAutomationRunbook -ResourceGroupName rg-automation-bootcamp `
        -AutomationAccountName aa-bootcamp -Name 'Demo-HelloWorld'

    Starts the runbook in the Azure sandbox with the default greeting.

.EXAMPLE
    Start-AzAutomationRunbook -ResourceGroupName rg-automation-bootcamp `
        -AutomationAccountName aa-bootcamp -Name 'Demo-HelloWorld' `
        -Parameters @{ Name = 'Matt' }

    Starts the runbook with a custom greeting.

.NOTES
    Author  : Matt Balzan | mattbalzan.github.io/My-Site
    Runs on : Azure sandbox (PowerShell 7.2)
    Identity: None required
#>

param
(
    [Parameter(Mandatory = $false)]
    [string] $Name = "Bootcamp"
)

$ErrorActionPreference = 'Stop'

try {
    Write-Output "Hello, $Name!"

    # Useful context to log on every job
    Write-Output "UTC time        : $((Get-Date).ToUniversalTime().ToString('u'))"
    Write-Output "PS version      : $($PSVersionTable.PSVersion)"
    Write-Output "Running on      : $env:COMPUTERNAME"

    # Each stream lands in a different tab of the job output
    Write-Verbose "Verbose stream (enable 'Log verbose records' on the runbook)" -Verbose
    Write-Warning "Warning stream - shows under the Warnings tab"
}
catch {
    Write-Error "Runbook failed: $($_.Exception.Message)"
    throw
}
