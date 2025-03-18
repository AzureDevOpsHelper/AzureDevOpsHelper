function Get-GroupInfo
{
    param (
        [string]$Authheader,
        [string]$orgUrl,
        [string]$descriptor
    )
    $allGroups = @()
    $orgUrl = $orgUrl.Replace("dev.azure.com", "vssps.dev.azure.com")
    $Result = $null
    Do
    {
        if  ($null -eq $Result.responseHeaders."x-ms-continuationtoken")
        {
            $groupInfourl = "$($orgUrl)/_apis/graph/groups?api-version=7.1-preview.1"
        }
        else 
        {
            $groupInfourl = "$($orgUrl)/_apis/graph/groups?continuationToken=$($Result.responseHeaders."x-ms-continuationtoken")&api-version=7.1-preview.1"
        }
        $Result =  GET-AzureDevOpsRestAPI -RestAPIUrl $groupInfourl -Authheader $Authheader
        foreach ($group in $Result.results.value)
        {
            $groupitem = [pscustomobject]@{
                subjectKind   = $group.subjectKind
                description   = $group.description
                domain        = $group.domain
                principalName = $group.principalName -replace "\\","\"
                mailAddress   = $group.mailAddress
                origin        = $group.origin
                originId      = $originId.domain
                displayName   = $group.displayName
                _links        = $group._links
                url           = $group.url
                descriptor    = $group.descriptor
            }
            $membershipurl = "$($orgUrl)/_apis/graph/memberships/$($descriptor)/$($groupitem.descriptor)?api-version=7.1-preview.1"
            try 
            {
                $memberResult =  GET-AzureDevOpsRestAPI -RestAPIUrl $membershipurl -Authheader $Authheader
                if ($memberResult.statusCode -eq 200)
                {
                    $allGroups += $groupitem
                }
            }
            catch 
            {
                #if user is not a member of the group we will get a 404 error we will ignore this error and continue
            }
        }
    }
    While  ($null -ne $Result.responseHeaders."x-ms-continuationtoken")
    #todo: use descriptor to look up group info. 
    
    return $allGroups
}