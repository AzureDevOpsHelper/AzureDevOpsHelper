Clear-Host
$outputJson = New-Object "System.Collections.Generic.Dictionary[[String],[PSCustomObject]]"
$responseJson = New-Object "System.Collections.Generic.Dictionary[[String],[PSCustomObject]]"
$ScriptDirectory = Split-Path $MyInvocation.MyCommand.Path
foreach ($file in Get-ChildItem -Path $ScriptDirectory\Functions\*.ps1) {
    . $file.FullName
}
foreach ($file in Get-ChildItem -Path $ScriptDirectory\Troubleshooters\*.ps1) {
    . $file.FullName
}
$config = Get-Content -Path ".\config.json" | ConvertFrom-Json
$devOpsbaseURL = $config.devOpsBaseURL
$outputpath = $config.outputFolder

Write-Host "Please enter your Org Name"
$orgName = Read-Host
$azureDevOpsOrganizationUrl = $devOpsBaseURL + $orgName
$token = Get-MSALToken
$token = $token[-1] 
$Authheader = $Token.CreateAuthorizationHeader()
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$projectsurl = $azureDevOpsOrganizationUrl + "/_apis/projects?stateFilter=All&api-version=2.2"
$Result =  GET-AzureDevOpsRestAPI -RestAPIUrl $projectsurl -Authheader $Authheader
$outputJson.Add("projects",$Result.results)
$responseJson.Add("projects",$Result.responseHeaders)
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
    ) | Out-Null
    $ps.AddArgument($Authheader) | Out-Null
    $ps.AddArgument($azureDevOpsOrganizationUrl) | Out-Null
    $ps.AddArgument($($User.User.results.descriptor)) | Out-Null
    $ps.AddArgument($ScriptDirectory) | Out-Null
    $job = $ps.BeginInvoke()

    Write-Host "User Info (from org)"
    $outputJson.Add("devopsUser",$User.User.results)
    $responseJson.Add("devopsUser",$User.User.responseHeaders)
    $User.User.results | Format-List -Property subjectKind,metaType,directoryAlias,domain,principalName,mailAddress,origin,originId,displayName,descriptor
    Write-Host
    Write-Host "User Entitlement Info (from org)"
    $outputJson.Add("devopsUserEntitlements",$User.Entitlements.results)
    $responseJson.Add("devopsUserEntitlements",$User.Entitlements.responseHeaders)
    $User.Entitlements.results.accessLevel | Format-List 
    Write-Host "LastAccessDate: " -NoNewline -ForegroundColor Green
    Write-Host $User.Entitlements.results.lastAccessedDate.ToString()
    Write-Host "dateCreated: " -NoNewline -ForegroundColor Green
    Write-Host $User.Entitlements.results.dateCreated.ToString()
    Write-Host
    Write-Host
    $graphtoken = Get-MSALTokenforGraphApi
    $graphtoken = $graphtoken[-1]
    $graphAuthheader = $graphtoken.CreateAuthorizationHeader()
    
    Write-Host "User Info (from Microsoft Graph)"
    $graphResult =  Get-GraphInfo -Authheader $graphAuthheader -oid $User.User.results.originId -tid $User.User.results.domain
    $outputJson.Add("graphUser",$graphResult.user)
    $responseJson.Add("graphUser",$graphResult.userResponseHeaders)
    $graphResult.user | Format-List -Property id,userPrincipalName,displayName,creationType,externalUserState
    Write-Host "Allowed user log ins:"
    $graphResult.user.identities | Format-List
    
    Write-Host "Tenant Info (from Microsoft Graph)"
    $outputJson.Add("graphTenant",$graphResult.tenant)
    $responseJson.Add("graphTenant",$graphResult.tenantResponseHeaders)
    $graphResult.tenant | Format-List -Property Id,displayName,onPremisesSyncEnabled 
}
Write-Host "Checking each Group for Membership, this started asynchronously right after" 
Write-Host "authorization. This function makes up to 25 simultaneous calls for best performance."
while ($job.IsCompleted -eq $false) {
        Start-Sleep -Seconds 1    
}
$UserGroups = $ps.EndInvoke($job)
$runspace.Close()
$outputJson.Add("userGroups",$UserGroups)
Write-Host "User has Membership in the following $($UserGroups.Count) groups:"
$UserGroups | Format-Table -Property origin, principalName
if (!(Test-Path -Path $outputpath)) {
    New-Item -Path $outputpath -Type Directory | Out-Null
}
$timestamp = Get-Date -Format o | ForEach-Object { $_ -replace ":", "." }
$outputJson | ConvertTo-Json -depth 100 | Out-File -Path "$($outputpath)$($timestamp)_User.json"
$responseJson | ConvertTo-Json -depth 100 | Out-File -Path "$($outputpath)$($timestamp)_Response.json"
$stopwatch.Stop()
Write-Host "Script execution time: $($stopwatch.Elapsed)"