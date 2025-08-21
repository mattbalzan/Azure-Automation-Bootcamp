# --[ Trigger Azure Runbook Webhook            ]
# --[ Matt Balzan | mattGPT.co.uk | 05-08-2025 ]

<#

    Description:    Triggers webhook with parameters. 

#>


# --[ Set Variables ]
$webhookURI = "<paste\your\webhook-URI\here>"  

# --[ Parameters for Webhook ]
$payload  = @{  
                message = "Hello from the other side!" 
}

# --[ Create BODY and POST webhook ]  
$body = ConvertTo-Json -InputObject $payload  
$response = Invoke-WebRequest -Method Post -Uri $webhookURI -Body $body -UseBasicParsing  
$response

# --[ End of script ]


# - To test incoming parameters, the section below goes into your Runbook header script.

param  
(  
    [Parameter(Mandatory = $false)]  
    [object] $WebhookData  
)  
$payload = ConvertFrom-Json $webhookdata.RequestBody  
Write-Output $($payload.message)

# --[ End of script ]
