# Azure Monitor Workbook — Runbook Monitoring Setup Guide

A step-by-step guide to deploying [Runbook-Monitoring.workbook.json](Runbook-Monitoring.workbook.json), a workbook that reports Automation job outcomes, failure rates, error streams and runtime cost drivers.

---

## What you get

| Tile | Answers |
| ---- | ------- |
| **Jobs by outcome** | How many jobs completed, failed, stopped or suspended? |
| **Job outcomes over time** | Is the failure rate trending up? |
| **Failure rate by runbook** | Which runbook is the problem child? |
| **Recent error and warning streams** | What was the actual error message? |
| **Longest running jobs** | What is driving my per-minute billing? |
| **Sandbox vs Hybrid Worker** | Where are jobs actually executing? |

---

## Prerequisites

- An **Automation Account** with at least one runbook that has run.
- A **Log Analytics workspace** in the same tenant (it does not have to be the same region, but same-region avoids cross-region egress).
- **Permissions**:
  - `Monitoring Contributor` — to create the workbook and the diagnostic setting.
  - `Log Analytics Reader` — for anyone who only needs to view it.
- Roughly **15 minutes** of data before the tiles populate.

---

## Step 1 — Send Automation logs to Log Analytics

The workbook reads the `AzureDiagnostics` table. Nothing lands there until you create a diagnostic setting on the Automation Account.

**Portal:** Automation Account → *Monitoring* → **Diagnostic settings** → *Add diagnostic setting* → tick **JobLogs** and **JobStreams** → destination **Send to Log Analytics workspace**.

**PowerShell:**

```powershell
$aa = Get-AzAutomationAccount -ResourceGroupName 'rg-automation-bootcamp' -Name 'aa-bootcamp'
$ws = Get-AzOperationalInsightsWorkspace -ResourceGroupName 'rg-monitoring' -Name 'law-bootcamp'

$logs = @(
    New-AzDiagnosticSettingLogSettingsObject -Category 'JobLogs'    -Enabled $true
    New-AzDiagnosticSettingLogSettingsObject -Category 'JobStreams' -Enabled $true
)

New-AzDiagnosticSetting `
    -Name        'diag-automation-to-law' `
    -ResourceId  $aa.AutomationAccountId `
    -WorkspaceId $ws.ResourceId `
    -Log         $logs
```

**Azure CLI:**

```bash
az monitor diagnostic-settings create \
  --name diag-automation-to-law \
  --resource "$AA_RESOURCE_ID" \
  --workspace "$LAW_RESOURCE_ID" \
  --logs '[{"category":"JobLogs","enabled":true},{"category":"JobStreams","enabled":true}]'
```

> **Cost warning:** `JobStreams` includes every `Write-Output` line your runbooks emit. On a chatty runbook this dwarfs `JobLogs`. If ingestion cost becomes an issue, keep `JobLogs` and drop `JobStreams` — you lose the error-message tile only.

### Verify data is flowing

Run this in the workspace's Logs blade. If it returns nothing after ~15 minutes, the diagnostic setting is wrong or no jobs have run.

```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.AUTOMATION"
| summarize Records = count() by Category, ResultType
```

---

## Step 2 — Import the workbook

**Option A — Portal (quickest)**

1. Azure Portal → **Monitor** → **Workbooks** → **+ New**.
2. Click the **</> Advanced Editor** button in the toolbar.
3. Make sure the *Gallery Template* tab is selected.
4. Delete the placeholder JSON and paste the contents of `Runbook-Monitoring.workbook.json`.
5. Click **Apply**, then **Done Editing**.
6. **Save** — give it a name, pick the subscription, resource group and location.

**Option B — Deploy as code**

Workbooks are ARM resources of type `Microsoft.Insights/workbooks`. The template JSON goes into the `serializedData` property as a **string**, so it must be escaped:

```powershell
$serialized = (Get-Content .\Runbook-Monitoring.workbook.json -Raw)

New-AzResourceGroupDeployment `
    -ResourceGroupName    'rg-monitoring' `
    -TemplateFile         '.\workbook.bicep' `
    -serializedData       $serialized `
    -workbookDisplayName  'Azure Automation - Runbook Monitoring'
```

Minimal `workbook.bicep`:

```bicep
param location string = resourceGroup().location
param workbookDisplayName string
param serializedData string

resource workbook 'Microsoft.Insights/workbooks@2023-06-01' = {
  name:     guid(resourceGroup().id, workbookDisplayName)
  location: location
  kind:     'shared'
  properties: {
    displayName:    workbookDisplayName
    serializedData: serializedData
    category:       'workbook'
    version:        '1.0'
  }
}
```

---

## Step 3 — Set the parameters

At the top of the workbook you'll see three pills:

| Parameter | Notes |
| --------- | ----- |
| **Time range** | Defaults to 24 hours. Also controls the `bin()` grain on the trend chart. |
| **Log Analytics workspace** | Multi-select — point it at every workspace receiving Automation logs. |
| **Runbook** | Multi-select with an *All* option, populated from the data itself. |

Once set, use **Save** again so the selections persist as the workbook defaults.

---

## Step 4 — Alert on what matters

The workbook is for looking; alerts are for being told. Create a log search alert from the same query:

```kusto
AzureDiagnostics
| where ResourceProvider == "MICROSOFT.AUTOMATION"
| where Category == "JobLogs" and ResultType == "Failed"
| summarize Failures = dcount(JobId_g) by RunbookName_s
```

Portal → **Monitor** → **Alerts** → *New alert rule* → scope the workspace → paste the query → threshold `Failures > 0` → evaluate every 5 minutes over a 15-minute window → action group of your choice (email, Teams, webhook, or another runbook).

---

## Reference — the queries behind each tile

| Tile | Table | Key filter |
| ---- | ----- | ---------- |
| Jobs by outcome | `AzureDiagnostics` | `Category == "JobLogs"`, `ResultType in ("Completed","Failed","Stopped","Suspended")` |
| Outcomes over time | `AzureDiagnostics` | as above, binned by `{TimeRange:grain}` |
| Failure rate by runbook | `AzureDiagnostics` | `dcountif(JobId_g, ResultType == "Failed")` |
| Error streams | `AzureDiagnostics` | `Category == "JobStreams"`, `StreamType_s in ("Error","Warning")` |
| Longest running jobs | `AzureDiagnostics` | `minif`/`maxif` on `TimeGenerated` per `JobId_g` |
| Sandbox vs Hybrid | `AzureDiagnostics` | `RunOn_s` empty means the Azure sandbox |

Useful columns in `AzureDiagnostics` for Automation:

| Column | Meaning |
| ------ | ------- |
| `Category` | `JobLogs` (state changes) or `JobStreams` (output) |
| `ResultType` | `Started`, `Completed`, `Failed`, `Stopped`, `Suspended` |
| `RunbookName_s` | Name of the runbook |
| `JobId_g` | Correlates every record for a single job |
| `StreamType_s` | `Output`, `Verbose`, `Warning`, `Error` |
| `ResultDescription` | The actual message text |
| `RunOn_s` | Hybrid Worker Group name, empty for the Azure sandbox |

---

## Troubleshooting

| Symptom | Cause / fix |
| ------- | ----------- |
| All tiles empty | No diagnostic setting, or no jobs in the selected time range. Run the verify query in Step 1. |
| Runbook pill shows no options | `JobLogs` category not enabled, or the workspace parameter is unset. |
| Error stream tile empty but failures exist | `JobStreams` category not enabled. |
| `Sandbox vs Hybrid` shows only "Azure sandbox" | Expected if nothing runs on a Hybrid Worker. `RunOn_s` is emitted only for hybrid jobs — the query uses `column_ifexists` so it will not fail when the column is absent. |
| Duration column blank for some jobs | The job started before the selected time range, so no `Started` record was matched. Widen the time range. |
| Workbook saves but is empty for colleagues | They need `Log Analytics Reader` on the workspace, not just access to the workbook. |



<img src="./images/workbook-demo.png" height="300" alt="Az Automation Workbook">