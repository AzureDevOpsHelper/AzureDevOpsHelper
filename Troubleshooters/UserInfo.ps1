function Get-UserInfo
{
    param (
        [string]$Authheader,
        [string]$orgUrl,
        [string]$VSID
    )
    $results = New-Object "System.Collections.Generic.Dictionary[[String],[PSCustomObject]]"
    $orgUrl = $orgUrl.Replace("dev.azure.com", "vssps.dev.azure.com")
    $userInfourl = "$($orgUrl)/_apis/identities?identityIds=$($VSID)&queryMembership=None&api-version=7.2-preview.1"
    $User =  GET-AzureDevOpsRestAPI -RestAPIUrl $userInfourl -Authheader $Authheader
    $results.Add("Identity", $User)
    $descriptor = $User.results.Value.subjectDescriptor
    $userInfourl = "$($orgUrl)/_apis/graph/users/$($descriptor)?api-version=7.2-preview.1"
    $userResult =  GET-AzureDevOpsRestAPI -RestAPIUrl $userInfourl -Authheader $Authheader
    $results.Add("User", $userResult)
    $orgUrl = $orgUrl.Replace("vssps.dev.azure.com","vsaex.dev.azure.com")
    $userInfourl = "$($orgUrl)/_apis/userentitlements/$($VSID)?api-version=7.2-preview.1"
    #Write-Host $userInfourl
    try 
    {
        $entitlementResult =  GET-AzureDevOpsRestAPI -RestAPIUrl $userInfourl -Authheader $Authheader
        $results.Add("Entitlements", $entitlementResult)
    }
        catch 
    {
        #if user does not have permission to see entitlements we will get a 403 error, and give a dummy response
        $results.Add("EntitlementresponseHeaders", $entitlementResult.responseHeaders)
    }

    
    return $results
}