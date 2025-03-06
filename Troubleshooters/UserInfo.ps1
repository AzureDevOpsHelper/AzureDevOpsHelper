function Get-UserInfo
{
    param (
        [string]$Authheader,
        [string]$orgUrl,
        [string]$VSID
    )
    $orgUrl = $orgUrl.Replace("dev.azure.com", "vssps.dev.azure.com")
    $userInfourl = "$($orgUrl)/_apis/graph/descriptors/$($VSID)?api-version=7.2-preview.1"
    $User =  GET-AzureDevOpsRestAPI -RestAPIUrl $userInfourl -Authheader $Authheader
    $descriptor = $User.results.Value
    $userInfourl = "$($orgUrl)/_apis/graph/users/$($descriptor)?api-version=7.2-preview.1"
    $Result =  GET-AzureDevOpsRestAPI -RestAPIUrl $userInfourl -Authheader $Authheader
    return $Result
}