Clear-Host
#Write-Host "joining the functions"
# Load the functions
$ScriptDirectory = Split-Path $MyInvocation.MyCommand.Path
foreach ($file in Get-ChildItem -Path $ScriptDirectory\Functions\*.ps1) {
    . $file.FullName
}
foreach ($file in Get-ChildItem -Path $ScriptDirectory\Troubleshooters\*.ps1) {
    . $file.FullName
}

#Write-Host "loading the config file"
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
    $User = Get-UserInfo -Authheader $Authheader -orgUrl $azureDevOpsOrganizationUrl -VSID $VSID
    Write-Host "User Info (from org)"
    $User.results | Format-List

    # Call Microsoft Graph API to get tenant-level info about a user Not Yet functional.
    #$graphResponse = Get-MSALTokenforGraphApi -tenantId $config.tenantId -OID $User.results.id
    #Write-Host "User Info (from Microsoft Graph)"
    #$graphResponse | Format-List

}


