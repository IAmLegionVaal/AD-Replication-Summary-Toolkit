# AD Replication Summary Toolkit

PowerShell tooling for Active Directory replication reporting and guarded recovery actions.

## Scripts

- `AD_Replication_Summary_Toolkit.ps1` — read-only replication reporting.
- `AD_Replication_Repair_Toolkit.ps1` — targeted replication, DNS registration, and domain-controller service recovery.

## Requirements

- Windows with `repadmin.exe` and `dcdiag.exe` from AD DS or RSAT tools.
- Appropriate Active Directory and remote-management permissions.
- PowerShell remoting for repairs against a remote domain controller.

Local DNS or service repair requires an elevated PowerShell session. Remote repairs are authorized by the remote credentials and WinRM configuration.

## Examples

Preview a replication synchronization:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\AD_Replication_Repair_Toolkit.ps1 `
  -DomainController DC01 -SyncAll -DryRun
```

Run selected recovery actions:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\AD_Replication_Repair_Toolkit.ps1 `
  -DomainController DC01 -SyncAll -RegisterDns -RestartNetlogon -Yes
```

Available actions are `-SyncAll`, `-RegisterDns`, `-RestartNetlogon`, and `-RestartKdc`. Omit `-Yes` to require typing `YES`.

## Evidence and verification

Each run writes `before.json`, `after.json`, and `repair.log` to a timestamped directory under `%ProgramData%\ADReplicationRepair` unless `-OutputPath` is supplied. `syncall.txt` is added when replication synchronization is requested.

The before-state file is the pre-repair evidence backup. Verification checks the post-action `repadmin /replsummary` result, DNS resolution after registration, and requested service states. `-DryRun` records intended actions without applying or verifying them.

## Exit codes

| Code | Meaning |
|---:|---|
| 0 | Completed successfully, including a successful dry run |
| 2 | Invalid arguments |
| 3 | Unsupported platform or missing AD support tools |
| 4 | Elevation required for local service repair |
| 10 | User cancelled |
| 20 | One or more repair actions failed |
| 30 | Post-repair verification failed |

## Safety

Replication and domain-controller service actions can affect the wider domain. Confirm DNS, time synchronization, and replication topology before use, and prefer a maintenance window for service restarts.

## Validation status

The scripts were source-reviewed during this update. They were not runtime-tested in an Active Directory domain.

## Author

Dewald Pretorius — L2 IT Support Engineer
