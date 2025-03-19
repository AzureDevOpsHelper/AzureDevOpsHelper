function Get-GroupInfo
{
    param (
        [string]$Authheader,
        [string]$orgUrl,
        [string]$descriptor,
        [string]$ScriptDirectory
    )
    $Authheader | Out-File "c:\temp\authheader.txt" 
    $azureDevOpsOrganizationUrl | Out-File "c:\temp\authheader.txt" -Append
    $descriptor | Out-File "c:\temp\authheader.txt" -Append
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
            $membershipurl = "$($_orgUrl)/_apis/graph/memberships/$($_descriptor)/$($groupitem.descriptor)?api-version=7.1-preview.1"
            try 
            {
                $memberResult = GET-AzureDevOpsRestAPI -RestAPIUrl $membershipurl -Authheader $_Authheader
                if ($memberResult.statusCode -eq 200)
                {
                    $_queue.Enqueue($groupitem)
                }
            }
            catch 
            {
                #if user is not a member of the group we will get a 404 error we will ignore this error and continue
            }
        } -ThrottleLimit 25 #this seems the best balance for performance and not overhead.
    }
    While  ($null -ne $Result.responseHeaders."x-ms-continuationtoken")

    $allGroups = @()
    $allGroups = [array]$threadSafeallgroups
    return $allGroups
}