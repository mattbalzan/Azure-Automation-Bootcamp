# Azure Automation Bootcamp
<img width="1024" height="1024" alt="image" src="https://github.com/user-attachments/assets/1d1bfe14-d274-498c-aba6-a3d65a04a45f" />

>What is Azure Automation?

Cloud-based automation service that provides:

- Runbooks (PowerShell/Python)
- Desired State Configuration (DSC)
- Update Management (for VMs)
- Change Tracking & Inventory
- Hybrid worker capability

>Pre-Reqs

- Azure Subscription
- Contributor or Owner permissions (initially)
- Automation Contributor role for scoped permissions

>Pricing

| Resource          | Pricing Example                               |
| ----------------- | --------------------------------------------- |
| Job Runtime       | First 500 mins free/month, then \~\$0.002/min |
| DSC nodes         | \~\$6/node/month                              |
| Update Management | Free (linked Log Analytics incurs costs)      |
| Log Analytics     | \~\$2.76/GB (UK South pricing)                |
| Hybrid Worker VMs | Your own VM cost (on-prem/cloud-hosted)       |

>Permissions Model

| Task                      | Role Required               |
| ------------------------- | --------------------------- |
| Create Automation Account | Owner/Contributor           |
| Author/Edit Runbooks      | Automation Contributor      |
| View Job Outputs          | Reader or Monitoring Reader |
| Hybrid Worker Setup       | VM Admin + Automation Admin |

>Setting up Azure Automation

1. Create Automation Account
2. Enable System Managed Identity (Add Graph permissions script: https://github.com/MG-Cloudflow/MSGraph-Examples/blob/main/Managed-Identity/GrandGraphApiPermissionV2.ps1)
3. Link to Log Analytics (for logs/monitoring)
4. Import Modules (Az, Graph, Intune, etc.)
5. Author a Runbook > PowerShell or Python (Use the graphical editor or import from GitHub/Storage)

>Types of Runbooks

| Runbook Type   | Language  | Notes                                              |
| -------------- | --------- | -------------------------------------------------- |
| PowerShell     | PS 5.1    | Most popular, rich module support                  |
| Python         | 2.7/3.8   | For DevOps/data pipelines                          |
| Graphical      | Drag/drop | No-code logic-based workflows                      |
| Hybrid Runbook | PS/Python | Runs on on-prem/cloud-hosted VMs via Hybrid Worker |
| Webhook        | HTTP/JSON | Trigger from apps or Logic Apps                    |
| Scheduled      | N/A       | Trigger on time-based schedules                    |

>Real world scenarios

| Scenario                       | Description                                            |
| ------------------------------ | ------------------------------------------------------ |
| Intune Device Compliance Audit | Use Graph API to report and alert on device compliance |
| AD Group Membership Checks     | Query Entra ID groups, email if over limits            |
| VM Patching                    | Schedule Update Management across VMs                  |
| Backup/Archive                 | Export data to Azure Storage or SharePoint             |
| Auto-deploy Intune Policies    | Upload JSON templates with detection/remediation logic |
| Clean-up Old Devices/Users     | Auto-delete stale users or devices in Entra or Intune  |

>Hybrid Worker Group setup (On-Prem or Cloud)

1. Prepare a VM (Windows Server 2016+)
2. Install Hybrid Worker Agent via script:
3. Register with Automation Account
4. Validate heartbeat and readiness in Azure portal

>Monitoring, Alerts & Reporting

Log Analytics integration enables:

- Job duration tracking
- Failure detection
- Scheduled reports
- Custom dashboards (Power BI / Workbooks)

Sample KQL Query:

`AzureDiagnostics
| where ResourceType == "AUTOMATIONACCOUNTS"
| where OperationName == "Job"
| summarize count() by JobStatus_s, bin(TimeGenerated, 1h)`

🥳
