<#
.SYNOPSIS
    Demo 04 | Trigger a Runbook Webhook
    Triggers an Azure Automation runbook by POSTing a JSON payload to its webhook.

.DESCRIPTION
    Client-side companion to 03-Demo-Webhook-Runbook.ps1. Builds a JSON payload,
    optionally attaches a shared-secret header, POSTs it to the webhook URL and
    prints the Job Id(s) that Azure queued.

    Remember that a webhook returns HTTP 202 Accepted - that only means the job
    was queued, not that it succeeded. Use the returned Job Id to check the
    outcome.

    The webhook URL is only shown ONCE at creation time. Store it in Key Vault,
    an environment variable or a secret store - never commit it to source control.

.PARAMETER WebhookUri
    The Automation webhook URL. Falls back to $env:AA_WEBHOOK_URI.

.PARAMETER SharedSecret
    Optional value sent as the 'x-shared-secret' header and validated inside the
    runbook. Falls back to $env:AA_WEBHOOK_SECRET.

.EXAMPLE
    .\04-Demo-Webhook-Trigger.ps1

    Uses $env:AA_WEBHOOK_URI to fire the webhook.

.EXAMPLE
    .\04-Demo-Webhook-Trigger.ps1 -WebhookUri $uri -SharedSecret 'S3cr3t!'

    Fires the webhook with an explicit URL and shared-secret header.

.NOTES
    Author  : Matt Balzan | mattbalzan.github.io/My-Site
    Runs on : Your machine, a build agent, Power Automate - anything that can POST
#>

param
(
    # Falls back to an environment variable so the URL never lands in source control
    [Parameter(Mandatory = $false)]
    [string] $WebhookUri = $env:AA_WEBHOOK_URI,

    [Parameter(Mandatory = $false)]
    [string] $SharedSecret = $env:AA_WEBHOOK_SECRET
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($WebhookUri)) {
    throw "No webhook URI. Pass -WebhookUri or set `$env:AA_WEBHOOK_URI."
}

# 1. Build the payload
$payload = @{
    message     = "Hello from the other side!"
    action      = "send-report"
    target      = "Contoso-Prod"
    environment = "prod"
    requestedBy = $env:USERNAME
    timestamp   = (Get-Date).ToUniversalTime().ToString('o')
}

$body = $payload | ConvertTo-Json -Depth 5

# 2. Optional shared-secret header, validated inside the runbook
$headers = @{ 'Content-Type' = 'application/json' }
if ($SharedSecret) { $headers['x-shared-secret'] = $SharedSecret }

# 3. POST it
$response = Invoke-RestMethod -Method Post -Uri $WebhookUri -Headers $headers -Body $body

# 4. Azure returns the JobIds it queued - HTTP 202 means "accepted", not "succeeded"
Write-Host "Webhook accepted. Job Id(s):" -ForegroundColor Green
$response.JobIds

Write-Host "`nTrack the job with:" -ForegroundColor Cyan
Write-Host "  Get-AzAutomationJob -ResourceGroupName <rg> -AutomationAccountName <aa> -Id $($response.JobIds[0])"
