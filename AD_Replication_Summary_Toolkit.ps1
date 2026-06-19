#requires -Version 5.1
[CmdletBinding()]
param([string]$OutputPath)
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
if([string]::IsNullOrWhiteSpace($OutputPath)){$OutputPath=Join-Path ([Environment]::GetFolderPath('Desktop')) 'AD_Replication_Reports'}
New-Item -ItemType Directory -Path $OutputPath -Force|Out-Null
try{Import-Module ActiveDirectory -ErrorAction Stop}catch{Write-Error 'ActiveDirectory module not found.';return}
$dcs=Get-ADDomainController -Filter *|Select-Object HostName,Site,IPv4Address,OperatingSystem,IsGlobalCatalog,OperationMasterRoles
$partners=Get-ADReplicationPartnerMetadata -Target * -Scope Domain -ErrorAction SilentlyContinue|Select-Object Server,Partner,Partition,LastReplicationAttempt,LastReplicationSuccess,ConsecutiveReplicationFailures,LastReplicationResult
$dcs|Export-Csv (Join-Path $OutputPath "domain_controllers_$stamp.csv") -NoTypeInformation -Encoding UTF8
$partners|Export-Csv (Join-Path $OutputPath "replication_partners_$stamp.csv") -NoTypeInformation -Encoding UTF8
@{Generated=Get-Date;DomainControllers=$dcs;ReplicationPartners=$partners}|ConvertTo-Json -Depth 6|Set-Content (Join-Path $OutputPath "ad_replication_$stamp.json") -Encoding UTF8
$html="<h1>AD Replication Summary</h1><p>Generated $(Get-Date)</p><h2>Domain Controllers</h2>$($dcs|ConvertTo-Html -Fragment)<h2>Replication Partners</h2>$($partners|ConvertTo-Html -Fragment)"
$html|ConvertTo-Html -Title 'AD Replication Summary'|Set-Content (Join-Path $OutputPath "ad_replication_$stamp.html") -Encoding UTF8
Write-Host "Reports saved to: $OutputPath" -ForegroundColor Green
