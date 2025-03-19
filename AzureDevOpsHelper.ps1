Clear-Host
$ScriptDirectory = Split-Path $MyInvocation.MyCommand.Path
foreach ($file in Get-ChildItem -Path $ScriptDirectory\Functions\*.ps1) {
    . $file.FullName
}
foreach ($file in Get-ChildItem -Path $ScriptDirectory\Troubleshooters\*.ps1) {
    . $file.FullName
}
$config = Get-Content -Path ".\config.json" | ConvertFrom-Json
$devOpsbaseURL = $config.devOpsBaseURL

Write-Host "Please enter your Org Name"
$orgName = Read-Host
$azureDevOpsOrganizationUrl = $devOpsBaseURL + $orgName
$token = Get-MSALToken
$token = $token[-1] 
$Authheader = $Token.CreateAuthorizationHeader()
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$projectsurl = $azureDevOpsOrganizationUrl + "/_apis/projects?stateFilter=All&api-version=2.2"
$Result =  GET-AzureDevOpsRestAPI -RestAPIUrl $projectsurl -Authheader $Authheader

$VSID = ""
if ($null -ne $Result.responseHeaders."x-vss-userdata") 
{
    $VSID = $Result.responseHeaders."x-vss-userdata"
    $VSID = $VSID.Split(":")
    $headerinfo = @{
        VSID = $VSID[0]
        UPN  = $VSID[1]
    }
    Write-Host "Header Info"
    $headerinfo  | Format-Table
    $VSID = $VSID[0]
}
if ($VSID -eq "") 
{
    Write-Host "VSID not found"
    exit
}
else {
    $User = Get-UserInfo -Authheader $Authheader -orgUrl $azureDevOpsOrganizationUrl -VSID $VSID
    $runspace = [runspacefactory]::CreateRunspace()
    $runspace.Open()
    $ps = [powershell]::Create()
    $ps.Runspace = $runspace
    $ps.AddScript(
        {   
            Param ($_Authheader, $_azureDevOpsOrganizationUrl, $_descriptor, $_ScriptDirectory) 
            foreach ($file in Get-ChildItem -Path $_ScriptDirectory\Functions\*.ps1) {
                . $file.FullName
            }
            foreach ($file in Get-ChildItem -Path $_ScriptDirectory\Troubleshooters\*.ps1) {
                . $file.FullName
            }
            $_UserResult = Get-GroupInfo -Authheader $_Authheader -orgUrl $_azureDevOpsOrganizationUrl -descriptor $_descriptor -ScriptDirectory $_ScriptDirectory
            $_UserResult
        }
    )
    $ps.AddArgument($Authheader)
    $ps.AddArgument($azureDevOpsOrganizationUrl)
    $ps.AddArgument($($User.results.descriptor))
    $ps.AddArgument($ScriptDirectory)
    $job = $ps.BeginInvoke()

    Write-Host "User Info (from org)"
    $User.results | Format-List -Property subjectKind,metaType,directoryAlias,domain,principalName,mailAddress,origin,originId,displayName,descriptor
    $graphtoken = Get-MSALTokenforGraphApi
    $graphtoken = $graphtoken[-1]
    $graphAuthheader = $graphtoken.CreateAuthorizationHeader()
    
    Write-Host "User Info (from Microsoft Graph)"
    $Result =  Get-GraphInfo -Authheader $graphAuthheader -oid $User.results.originId -tid $User.results.domain
    $Result.user | Format-List -Property id,userPrincipalName,displayName,creationType,externalUserState
    Write-Host "Allowed user log ins:"
    $Result.user.identities | Format-List
    
    Write-Host "Tenant Info (from Microsoft Graph)"
    $Result.tenant | Format-List -Property Id,displayName,onPremisesSyncEnabled 
}
Write-Host "since Authentication we have been Individually checking each Group for Membership, this may take a while and makes up to 25 simultaneous calls"
while ($job.IsCompleted -eq $false) {
        Start-Sleep -Seconds 1    
}
$UserGroups = $ps.EndInvoke($job)
$runspace.Close()
Write-Host "User Group Memberships: $($UserGroups.Count)"
$UserGroups | Format-Table -Property origin, principalName
$stopwatch.Stop()
Write-Host "Script execution time: $($stopwatch.Elapsed)"