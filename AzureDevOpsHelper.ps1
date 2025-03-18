Clear-Host
# Load the functions
$ScriptDirectory = Split-Path $MyInvocation.MyCommand.Path
foreach ($file in Get-ChildItem -Path $ScriptDirectory\Functions\*.ps1) {
    . $file.FullName
}
foreach ($file in Get-ChildItem -Path $ScriptDirectory\Troubleshooters\*.ps1) {
    . $file.FullName
}

# Load info from config file
$config = Get-Content -Path ".\config.json" | ConvertFrom-Json
$devOpsbaseURL = $config.devOpsBaseURL


# Prompt for the organization name
Write-Host "Please enter your Org Name"
$orgName = Read-Host
$azureDevOpsOrganizationUrl = $devOpsBaseURL + $orgName

# Acquire the token interactively
$token = Get-MSALToken
$token = $token[-1] 
$Authheader = $Token.CreateAuthorizationHeader()
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
    # Call Microsoft Graph API to get tenant-level info about a user this currently requires a second sign in.
    # This is because the token we have is for Azure DevOps and not for Microsoft Graph.
    # I'm looking into trying to cache the refresh token to see if we can get a token for Microsoft Graph without signing in again.
    $User = Get-UserInfo -Authheader $Authheader -orgUrl $azureDevOpsOrganizationUrl -VSID $VSID
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
# Lets Gather Information about the Users Group Memberships in Azure DevOps
Write-Host "Individually checking each Group Membership, this may take a while and make a lot of calls"
$UserGroups = Get-GroupInfo -Authheader $Authheader -orgUrl $azureDevOpsOrganizationUrl -descriptor $User.results.descriptor
Write-Host "User Group Memberships: $($UserGroups.Count)"
$UserGroups | Format-Table -Property origin, principalName
