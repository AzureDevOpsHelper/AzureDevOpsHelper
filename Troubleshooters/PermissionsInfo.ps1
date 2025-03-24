function Get-PermissionsInfo
{
    param (
        [string]$Authheader,
        [string]$orgUrl,
        [string]$descriptor,
        [string]$ScriptDirectory
    )
    $threadSafeallPermissions = [System.Collections.Concurrent.ConcurrentQueue[pscustomobject]]::new()
    $namespaceUrl = "$($orgUrl)/_apis/securitynamespaces?api-version=7.2-preview.1"
    $namespaces = GET-AzureDevOpsRestAPI -RestAPIUrl $namespaceUrl -Authheader $Authheader
    #$namespaces.results.value | Format-List -Property name, namespaceId
    #Pause
    $namespaces.results.value | ForEach-Object -Parallel {
        $_queue           = $using:threadSafeallPermissions
        $_ScriptDirectory = $using:ScriptDirectory
        $_descriptor      = $using:descriptor
        $_orgUrl          = $using:orgUrl
        $_Authheader      = ($using:Authheader).ToString()
        $namespace        = $_

        #"`$_ScriptDirectory = $_ScriptDirectory" | Out-File -FilePath "C:\temp\AzureDevOpsHelper\testing.txt" -Append
        #"`$_descriptor = $_descriptor" | Out-File -FilePath "C:\temp\AzureDevOpsHelper\testing.txt" -Append
        #"`$_orgUrl = $_orgUrl" | Out-File -FilePath "C:\temp\AzureDevOpsHelper\testing.txt" -Append
        #"`$_Authheader = $_Authheader" | Out-File -FilePath "C:\temp\AzureDevOpsHelper\testing.txt" -Append
    
        foreach ($file in Get-ChildItem -Path $_ScriptDirectory\Functions\*.ps1) {
            . $file.FullName
        }   
        $permissionUrl = $_orgUrl + "/_apis/accesscontrollists/" + $namespace.namespaceId + "?descriptors=" + $_descriptor + "&includeExtendedInfo=true&recurse=true&api-version=7.2-preview.1"
        #"`$permissionUrl = $permissionUrl" | Out-File -FilePath "C:\temp\AzureDevOpsHelper\testing.txt" -Append
        #"`r`n" | Out-File -FilePath "C:\temp\AzureDevOpsHelper\testing.txt" -Append
        $permissionResult = GET-AzureDevOpsRestAPI -RestAPIUrl $permissionUrl -Authheader $_Authheader

        foreach ($permission in $permissionResult.results.value)
        {
            $allowNullSafe                = ($null -eq $permission.acesDictionary."$_descriptor".allow) ? 0 : $permission.acesDictionary."$_descriptor".allow
            $denyNullSafe                 = ($null -eq $permission.acesDictionary."$_descriptor".deny) ? 0 : $permission.acesDictionary."$_descriptor".deny
            $effectiveAllowNullSafe       = ($null -eq $permission.acesDictionary."$_descriptor".extendedInfo.effectiveAllow) ? 0 : $permission.acesDictionary."$_descriptor".extendedInfo.effectiveAllow
            $effectiveDenyNullSafe        = ($null -eq $permission.acesDictionary."$_descriptor".extendedInfo.effectiveDeny) ? 0 : $permission.acesDictionary."$_descriptor".extendedInfo.effectiveDeny
            
            $enumactions  = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
            #$denyed   = New-Object "System.Collections.Generic.Dictionary[[String],[Boolean]]"
            #$eAllowed = New-Object "System.Collections.Generic.Dictionary[[String],[Boolean]]"
            #$eDenyed  = New-Object "System.Collections.Generic.Dictionary[[String],[Boolean]]"
    
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

            $permissionitem = [pscustomobject]@{
                namespaceId          = $namespace.namespaceId
                namespaceName        = $namespace.name
                namespacedisplayName = $namespace.displayName
                inheritPermissions   = ($null -eq $permission.inheritPermissions) ? $false : $permission.inheritPermissions
                token                = ($null -eq $permission.token) ? "" : $permission.token
                descriptor           = ($null -eq $permission.acesDictionary."$_descriptor".descriptor) ? "" : $permission.acesDictionary."$_descriptor".descriptor
                allow                = $allowNullSafe
                deny                 = $denyNullSafe
                effectiveAllow       = $effectiveAllowNullSafe
                effectiveDeny        = $effectiveDenyNullSafe
                enumactions          = $enumactions
             } 

            if ($permissionitem.allow -gt 0 -or $permissionitem.deny -gt 0 -or $permissionitem.effectiveAllow -gt 0 -or $permissionitem.effectiveDeny -gt 0)
            {
                $_queue.Enqueue($permissionitem)
            }
        }
    } -ThrottleLimit 25 #this seems the best balance for performance and not overhead.
    $allPermissions = @()
    $allPermissions = [array]$threadSafeallPermissions
    $allPermissions = $allPermissions | Sort-Object -Property namespaceName, namespacedisplayName, token
    return $allPermissions
}