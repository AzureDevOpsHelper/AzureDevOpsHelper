<#
Areas that still need to be looked at for friendly names:
https://learn.microsoft.com/en-us/azure/devops/organizations/security/namespace-reference?view=azure-devops

- "namespaceName": "Identity", "namespacedisplayName": "ServiceEndpoints" -serive Endpoints
  - Manages permissions to create and manage service connections. Role memberships for individual items are automatically inherited from the project-level roles.

- "namespaceName": "Identity", "namespacedisplayName": "Process",
  - Manages permissions to create, delete, and administer processes.

- "namespaceName": "Identity", "namespacedisplayName": "Plan",
  - Manages permissions for Delivery Plans to view, edit, delete, and manage delivery plans. You can manage these permissions through the web portal for each plan.

- "namespaceName": "Identity", "namespacedisplayName": "Iteration",
  - Manages iteration path object-level permissions to create, edit, and delete child nodes and view child node permissions. 
  - Token format: 'vstfs:///Classification/Node/Iteration_Identifier/'

- "namespaceName": "Identity", "namespacedisplayName": "CSS",
  - Manages area path object-level permissions to create, edit, and delete child nodes and set permissions to view or edit work items in a node.
  - Token format example: vstfs:///Classification/Node/{area_node_id}

- "namespaceName": "Identity", "namespacedisplayName": "AnalyticsViews",
  - Manages Analytics views permissions at the project-level and object-level to read, edit, delete, and generate reports. 
  - Token format for project level permissions: $/Shared/PROJECT_ID

- "namespaceName": "Identity", "namespacedisplayName": null,
  - Manages permissions to read, write, and delete user account identity information; manage group membership and create and restore identity scopes. 
  - Token format for project-level permissions: PROJECT_ID/Group_Origin_ID
  - this seems to need queryIDs and Dashboard IDs to be friendly

I likely need to run this against a few more organizations to get a better idea of what is out there.
but this should be a good start.
#>
function Get-PermissionsInfo
{
    param (
        [string]$Authheader,
        [string]$orgUrl,
        [string]$descriptor,
        [string]$ScriptDirectory,
        [PSCustomObject]$Projects,
        [PSCustomObject]$Domain,
        [PSCustomObject]$UserGroups,
        [PSCustomObject]$User 
    )
    $threadSafeallPermissions = [System.Collections.Concurrent.ConcurrentQueue[pscustomobject]]::new()
    $gitInfoUrl = "$($orgUrl)/_apis/git/repositories/"
    $gitInfo =  GET-AzureDevOpsRestAPI -RestAPIUrl $gitInfoUrl -Authheader $Authheader
    $gitInfo = $gitInfo.results.value
    $namespaceUrl = "$($orgUrl)/_apis/securitynamespaces?api-version=7.2-preview.1"
    $namespaces = GET-AzureDevOpsRestAPI -RestAPIUrl $namespaceUrl -Authheader $Authheader
    $namespaces.results.value | ForEach-Object -Parallel {
        $_queue           = $using:threadSafeallPermissions
        $_ScriptDirectory = $using:ScriptDirectory
        $_descriptor      = $using:descriptor
        $_orgUrl          = $using:orgUrl
        $_Projects        = $using:Projects
        $_Domain          = $using:Domain
        $_Authheader      = $using:Authheader
        $_gitInfo         = $using:gitInfo
        $_groups          = $using:UserGroups
        $_User            = $using:User
        $namespace        = $_
        foreach ($file in Get-ChildItem -Path $_ScriptDirectory\Functions\*.ps1) {
            . $file.FullName
        }   
        $permissionUrl = $_orgUrl + "/_apis/accesscontrollists/" + $namespace.namespaceId + "?descriptors=" + $_descriptor + "&includeExtendedInfo=true&recurse=true&api-version=7.2-preview.1"
        $permissionResult = GET-AzureDevOpsRestAPI -RestAPIUrl $permissionUrl -Authheader $_Authheader
        foreach ($permission in $permissionResult.results.value)
        {
            $allowNullSafe                = ($null -eq $permission.acesDictionary."$_descriptor".allow) ? 0 : $permission.acesDictionary."$_descriptor".allow
            $denyNullSafe                 = ($null -eq $permission.acesDictionary."$_descriptor".deny) ? 0 : $permission.acesDictionary."$_descriptor".deny
            $effectiveAllowNullSafe       = ($null -eq $permission.acesDictionary."$_descriptor".extendedInfo.effectiveAllow) ? 0 : $permission.acesDictionary."$_descriptor".extendedInfo.effectiveAllow
            $effectiveDenyNullSafe        = ($null -eq $permission.acesDictionary."$_descriptor".extendedInfo.effectiveDeny) ? 0 : $permission.acesDictionary."$_descriptor".extendedInfo.effectiveDeny
            $tokenNullSafe   = ($null -eq $permission.token) ? "" : $permission.token
            $enumactions  = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            foreach ( $action in $namespace.actions )
            {
                if (( $allowNullSafe -band $action.bit ) -eq $action.bit ) 
                {
                    $enumactions.Add($action.displayName, "Allow")
                }
                elseif (( $effectiveAllowNullSafe -band $action.bit ) -eq $action.bit )
                {
                    $enumactions.Add($action.displayName, "Inherited Allow")
                }
                elseif (( $effectiveDenyNullSafe -band $action.bit ) -eq $action.bit )
                {
                    $enumactions.Add($action.displayName, "Inherited Deny")
                }
                elseif (( $denyNullSafe -band $action.bit ) -eq $action.bit )
                {
                    $enumactions.Add($action.displayName, "Deny")
                }
                else
                {
                    $enumactions.Add($action.displayName, "Not Set")
                }
            }  
            $friendlyToken = $tokenNullSafe
            if ($tokenNullSafe -ne "")
            {
                $regex = [regex]'\b[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}\b'
                $matches = $regex.Matches($friendlyToken)
                foreach ($match in $matches)
                {
                    if ($match.Value -eq $($_Domain.Id)) 
                    { 
                        $friendlyToken = $friendlyToken.Replace($match.Value, $Domain.displayName.ToString()) 
                    }
                    $projectname = ($_Projects | Where-Object { $_.id -eq $match.Value } | Select-Object -ExpandProperty name) 
                    if (($null -ne $projectname) -and ("" -ne $projectname))
                    {
                        $friendlyToken = $friendlyToken.Replace($match.Value, $projectname)
                    }
                    elseif ($namespace.name = "Identity")
                    {                          
                        $identityname = ($_groups | Where-Object { $_.storageKey -eq $match.Value } | Select-Object -ExpandProperty principalName -ErrorAction SilentlyContinue )
                        if (($null -ne $identityname) -and ("" -ne $identityname))
                        {
                            $friendlyToken = $friendlyToken.Replace($match.Value, $identityname)
                        } 
                        else
                        {
                            $identityname = ($_groups | Where-Object { $_.originId -eq $match.Value } | Select-Object -ExpandProperty principalName -ErrorAction SilentlyContinue )
                            $identityname = $identityname | Select-Object -ExpandProperty principalName                                      
                            if (($null -ne $identityname) -and ("" -ne $identityname))
                            {
                                $friendlyToken = $friendlyToken.Replace($match.Value, $identityname)
                            } 
                            else 
                            {
                                $userInfourl = "$($_orgUrl)/_apis/identities?identityIds=$($match.Value)&queryMembership=None&api-version=7.2-preview.1"
                                $userInfourl = $userInfourl.Replace("dev.azure.com", "vssps.dev.azure.com")
                                $userResult =  GET-AzureDevOpsRestAPI -RestAPIUrl $userInfourl -Authheader $_Authheader
                                $identityname = $userResult.results.value.principalName
                                if (($null -ne $identityname) -and ("" -ne $identityname))
                                {
                                    $identityname = $identityname.Replace("\\","\")
                                    $friendlyToken = $friendlyToken.Replace($match.Value, $identityname)
                                }
                                else
                                {
                                    if ($match.Value -eq $_User.Entitlements.results.Id)
                                    {
                                        $identityname = "[$($_User.Entitlements.results.accessLevel.licenseDisplayName)]\$($_User.Entitlements.results.user.principalName)"
                                        $friendlyToken = $friendlyToken.Replace($match.Value, $identityname)
                                    }
                                    else 
                                    {
                                        if ($null -ne $enumactions."Record query execution information")
                                        {
                                            $projectguid = $tokenNullSafe.Substring(2,36)
                                            $queryInfoUrl = $($_orgUrl)+ "/" + $($projectguid) + "/_apis/wit/queries/" + $($match.Value) + "?api-version=7.2-preview.2"
                                            $queryInfo =  GET-AzureDevOpsRestAPI -RestAPIUrl $queryInfoUrl -Authheader $_Authheader
                                            $queryName = $queryInfo.results.name

                                            $friendlyToken = $friendlyToken.Replace($match.Value, $queryName)

                                        }
                                        #elseif ($null -ne $enumactions."Edit dashboard")
                                        #{
                                        #    $projectguid = $tokenNullSafe -split '/' | Select-Object -Index 1
                                        #    $dashboardInfoUrl = "$($_orgUrl)/_apis/dashboard/dashboards/$($match.Value)?api-version=7.2-preview.1"
                                        #    $dashboardInfo =  GET-AzureDevOpsRestAPI -RestAPIUrl $dashboardInfoUrl -Authheader $_Authheader
                                        #    $friendlyToken = $friendlyToken.Replace($match.Value, $dashboardInfo.results.name)
                                        #}
                                        
                                    }
                                }
                            }
                        }
                    }
                    if($namespace.displayName -match "GIT")
                    {                               

                        if ( ($tokenNullSafe -split '/').Count -ge 3)
                        {                         
                            $RepoName = ($_gitInfo | Where-Object { $_.id -eq $match.Value } | Select-Object -ExpandProperty name) 
                            $friendlyToken = $friendlyToken.Replace($match.Value, $RepoName)
                        }                    
                        if ( ($tokenNullSafe -split '/').Count -ge 4)
                        { 
                            for ($i = 5 ; $i -lt ($tokenNullSafe -split '/').Count ; $i = $i + 1) 
                            {
                                $asciiChars = (($tokenNullSafe -split '/')[$i]) -split "00" 
                                $charstring = ''
                                ForEach ($char in  $asciiChars)
                                {
                                    if ($char -ne '')
                                    {
                                        $charstring = $charstring + [char][byte]"0x$char" 
                                    }
                                }
                                $friendlyToken = $friendlyToken.Replace((($tokenNullSafe -split '/')[$i]), $charstring)
                            }
                        }
                    }
                }
            }
            $permissionitem = [pscustomobject]@{
                namespaceId          = $namespace.namespaceId
                namespaceName        = $namespace.name
                namespacedisplayName = $namespace.displayName
                inheritPermissions   = ($null -eq $permission.inheritPermissions) ? $false : $permission.inheritPermissions
                token                = $tokenNullSafe
                friendlyToken        = $friendlyToken
                descriptor           = ($null -eq $permission.acesDictionary."$_descriptor".descriptor) ? "" : $permission.acesDictionary."$_descriptor".descriptor
                allow                = $allowNullSafe
                deny                 = $denyNullSafe
                effectiveAllow       = $effectiveAllowNullSafe
                effectiveDeny        = $effectiveDenyNullSafe
                enumactions          = $enumactions
             } 

            if ($permissionitem.allow -gt 0 -or $permissionitem.deny -gt 0 -or $permissionitem.effectiveAllow -gt 0 -or $permissionitem.effectiveDeny -gt 0)
            {
                $regex = [regex]'\b[0-9a-fA-F]{8}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{4}\b-[0-9a-fA-F]{12}\b'
                $matches = $regex.Matches($permissionitem.friendlyToken)
               # if ($matches.Count -ge 1)
               # {
                    $_queue.Enqueue($permissionitem)
               # } #to find things that are still not friendly
            }
        }
    } -ThrottleLimit 25 #this seems the best balance for performance and overhead.
    $allPermissions = @()
    $allPermissions = [array]$threadSafeallPermissions
    $allPermissions = $allPermissions | Sort-Object -Property namespaceName, namespacedisplayName, token
    return $allPermissions
}