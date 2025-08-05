# --[ Trigger Azure Runbook Webhook            ]
# --[ Matt Balzan | mattGPT.co.uk | 05-08-2025 ]

<#

    Description:    Triggers webhook with parameters. 

#>


# --[ Set Variables ]
$webhookURI = "<paste\your\webhook-URI\here>"  

# --[ Parameters for Webhook ]
$params  = @{  
                message = "Hello from the other side!" 
}

# --[ Create BODY and POST webhook ]  
$body = ConvertTo-Json -InputObject $params  
$response = Invoke-WebRequest -Method Post -Uri $webhookURI -Body $body -UseBasicParsing  
$response

# --[ End of script ]
