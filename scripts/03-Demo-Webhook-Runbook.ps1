<#
.SYNOPSIS
    Demo 03 | Webhook Receiver Runbook
    Receiving runbook for an Azure Automation webhook trigger.

.DESCRIPTION
    The runbook side of a webhook trigger. Publish it, create a webhook against
    it, then fire it with 04-Demo-Webhook-Trigger.ps1.

    Azure passes a single $WebhookData object containing three properties:
      WebhookName   - name of the webhook that fired
      RequestBody   - the raw string body that was POSTed (parse it yourself)
      RequestHeader - hashtable of the HTTP headers

    The runbook validates an optional shared-secret header, parses the JSON body
    and branches on an 'action' property. It also handles being started manually,
    where $WebhookData is null.

    Security note: the webhook URL *is* the credential. Anyone holding it can run
    this runbook, so treat it like a password, always set an expiry, and validate
    a shared secret header as shown below.

.PARAMETER WebhookData
    Supplied automatically by Azure Automation when the runbook is started by a
    webhook. Leave it unset for manual test runs.

.EXAMPLE
    Invoke-RestMethod -Method Post -Uri $webhookUri `
        -Body (@{ message = 'Hi'; action = 'send-report'; target = 'Contoso-Prod' } | ConvertTo-Json)

    Triggers the runbook and requests the 'send-report' branch.

.EXAMPLE
    Start-AzAutomationRunbook -ResourceGroupName rg-automation-bootcamp `
        -AutomationAccountName aa-bootcamp -Name 'Demo-WebhookTarget'

    Starts the runbook manually; it warns and exits because no payload was sent.

.NOTES
    Author  : Matt Balzan | mattbalzan.github.io/My-Site
    Runs on : Azure sandbox (PowerShell 7.2)
    Identity: None required for the demo
    Optional: Create an encrypted Automation variable named 'WebhookSharedSecret'
              to enable shared-secret validation.
#>

param
(
    [Parameter(Mandatory = $false)]
    [object] $WebhookData
)

$ErrorActionPreference = 'Stop'

# 1. Guard clause - allows manual test runs without a webhook
if (-not $WebhookData) {
    Write-Warning "No WebhookData received. Runbook was started manually."
    return
}

Write-Output "Webhook name    : $($WebhookData.WebhookName)"

# 2. Optional shared-secret check (defence in depth)
#    Store the expected value as an encrypted Automation variable.
$expectedSecret = Get-AutomationVariable -Name 'WebhookSharedSecret' -ErrorAction SilentlyContinue
if ($expectedSecret) {
    $presented = $WebhookData.RequestHeader.'x-shared-secret'
    if ($presented -ne $expectedSecret) {
        throw "Rejected: invalid or missing x-shared-secret header."
    }
    Write-Output "Shared secret   : validated"
}

# 3. Parse the payload
try {
    $payload = ConvertFrom-Json -InputObject $WebhookData.RequestBody
}
catch {
    throw "Request body was not valid JSON: $($_.Exception.Message)"
}

Write-Output "Message         : $($payload.message)"
Write-Output "Environment     : $($payload.environment)"
Write-Output "Requested by    : $($payload.requestedBy)"

# 4. Do the work
switch ($payload.action) {
    'restart-service' { Write-Output "Would restart service '$($payload.target)'" }
    'send-report'     { Write-Output "Would generate report for '$($payload.target)'" }
    default           { Write-Output "No action requested - payload logged only." }
}

Write-Output "Completed at    : $((Get-Date).ToUniversalTime().ToString('u'))"
