function Get-GroupInfo
{
    param (
        [string]$Authheader,
        [string]$orgUrl,
        [string]$descriptor,
        [string]$ScriptDirectory
    )
    $threadSafeallgroups = [System.Collections.Concurrent.ConcurrentQueue[pscustomobject]]::new()
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
        $Result.results.value | ForEach-Object -Parallel {
            $_ScriptDirectory = $using:ScriptDirectory
            foreach ($file in Get-ChildItem -Path $_ScriptDirectory\Functions\*.ps1) {
                . $file.FullName
            }
            $_queue = $using:threadSafeallgroups
            $_descriptor = $using:descriptor
            $_orgUrl = $using:orgUrl
            $_Authheader = $using:Authheader
            $group = $_
            if ($group.origin -eq "aad") 
            {
                $storageKeyURL = $group._links.storageKey.href
                $storageKey = GET-AzureDevOpsRestAPI -RestAPIUrl $storageKeyURL -Authheader $_Authheader            
            }            
            try 
            {
                $membershipurl = "$($_orgUrl)/_apis/graph/memberships/$($_descriptor)/$($group.descriptor)?api-version=7.1-preview.1"
                $memberResult = GET-AzureDevOpsRestAPI -RestAPIUrl $membershipurl -Authheader $_Authheader

                $groupitem = [pscustomobject]@{
                    storageKey    = ($group.origin -eq "aad") ? $storageKey.results.value : $group.originId
                    descriptor    = $group.descriptor
                    subjectKind   = $group.subjectKind
                    description   = $group.description
                    domain        = $group.domain
                    principalName = $group.principalName -replace '\\','\'
                    mailAddress   = $group.mailAddress
                    origin        = $group.origin
                    originId      = $group.originId
                    displayName   = $group.displayName
                    _links        = $group._links
                    url           = $group.url
                    amMember      = $true
                }
            }
            catch
            {
                $groupitem = [pscustomobject]@{
                    storageKey    = ($group.origin -eq "aad") ? $storageKey.results.value : $group.originId
                    descriptor    = $group.descriptor
                    subjectKind   = $group.subjectKind
                    description   = $group.description
                    domain        = $group.domain
                    principalName = $group.principalName -replace '\\','\'
                    mailAddress   = $group.mailAddress
                    origin        = $group.origin
                    originId      = $group.originId
                    displayName   = $group.displayName
                    _links        = $group._links
                    url           = $group.url
                    amMember      = $false
                }            
            }
            $_queue.Enqueue($groupitem)                          
        } -ThrottleLimit 25 #this seems the best balance for performance and not overhead.
    }
    While  ($null -ne $Result.responseHeaders."x-ms-continuationtoken")
    $allGroups = @()
    $allGroups = [array]$threadSafeallgroups
    $allGroups = $allGroups | Sort-Object -Property amMember, principalName
    return $allGroups
}