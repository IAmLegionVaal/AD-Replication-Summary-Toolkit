# AD Replication Summary Toolkit

PowerShell tools for Active Directory replication reporting and guarded replication recovery actions.

## Report

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\AD_Replication_Summary_Toolkit.ps1
```

## Repair

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\AD_Replication_Repair_Toolkit.ps1 -DomainController DC01 -SyncAll -DryRun
```

Examples:

```powershell
.\AD_Replication_Repair_Toolkit.ps1 -DomainController DC01 -SyncAll
.\AD_Replication_Repair_Toolkit.ps1 -DomainController DC01 -RegisterDns
.\AD_Replication_Repair_Toolkit.ps1 -DomainController DC01 -RestartNetlogon
.\AD_Replication_Repair_Toolkit.ps1 -DomainController DC01 -RestartKdc
```

The repair script captures `repadmin` and `dcdiag` evidence before and after repair, supports local or authorised remote service actions, and includes `-DryRun`, confirmation, logging and clear exit codes.

## Safety

Replication and domain-controller service changes can affect the wider domain. Use targeted actions after confirming DNS, time synchronisation and current replication state.

## Author

Dewald Pretorius — L2 IT Support Engineer
