function Get-GraphInfo
{
    param (
        [string]$Authheader,
        [string]$Graphapiurl,
        [string]$oid,
        [string]$tid
    )
    $results = New-Object "System.Collections.Generic.Dictionary[[String],[PSCustomObject]]"
    $Graphapiurl = "https://graph.microsoft.com/v1.0/users/$($oid)?`$select=userPrincipalName,displayName,ID,creationType,externalUserState,identities"
    $result =  GET-AzureDevOpsRestAPI -RestAPIUrl $Graphapiurl -Authheader $graphAuthheader
    #Write-Host  $result.results
    $results.Add("user", $result.results)
    $results.Add("userResponseHeaders", $result.responseHeaders)
    $results.Add("userStatusCode", $result.statusCode)   
    
    $Graphapiurl = "https://graph.microsoft.com/v1.0/organization/$($tid)?`$select=Id,displayName,onPremisesSyncEnabled"
    $result =  GET-AzureDevOpsRestAPI -RestAPIUrl $Graphapiurl -Authheader $graphAuthheader
    #Write-Host  $result.results
    $results.Add("tenant", $result.results)
    $results.Add("tenantResponseHeaders", $result.responseHeaders)
    $results.Add("tenantStatusCode", $result.statusCode)   
    
    return $results
}