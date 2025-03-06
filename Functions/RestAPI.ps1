
function GET-AzureDevOpsRestAPI {
    param (
        [string]$Authheader,
        [string]$RestAPIUrl
    )
    #Write-Host "Calling Azure DevOps Rest API"
    $debug = $false
    $Headers = @{
        Authorization           = $Authheader
        "X-TFS-FedAuthRedirect" = "Suppress"
    }
    $params = @{
        Uri                     = $RestAPIUrl
        Headers                 = $headers
        Method                  = 'GET'
        ContentType             = 'application/json'
        StatusCodeVariable      = 'statusCode' # this is a parameter to pass the variable (no $) to retain the status code of the HTTP Response.
        ResponseHeadersVariable = 'responseHeaders' #This is the parameter to pass the variable (no $) to retain the http headers from the response.
    }
    try
    {
        $result = Invoke-RestMethod @params 
        $results = New-Object "System.Collections.Generic.Dictionary[[String],[PSCustomObject]]"
        $results.Add("results", $result)
        $results.Add("responseHeaders", $responseHeaders)
        $results.Add("statusCode", $statusCode)

        return $results
    }
    Catch {
        Write-Host "ERROR: " -ForegroundColor red
        Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ -ForegroundColor red
        Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription -ForegroundColor red
        Write-Host "ErrorDescription:" $_ -ForegroundColor red
        Write-Host "at line $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor red
        throw ("Error in RestAPI Call")
    }
    finally {
        #region Debug&Throttle
        if #in theory this should add the details if debug is turned on OR if there is a non 200 pass OR if there is throttling happening 
        (
                ($Debug) `
            -or (($statusCode -lt 200)                                -or  ($statusCode -ge 300)) `
            -or (($null -ne $responseHeaders."Retry-After")           -and ($responseHeaders."Retry-After"           -gt 0)) `
            -or (($null -ne $responseHeaders."X-RateLimit-Resource")  -and ($responseHeaders."X-RateLimit-Resource"  -ne "")) `
            -or (($null -ne $responseHeaders."X-RateLimit-Delay")     -and ($responseHeaders."X-RateLimit-Delay"     -gt 0)) `
            -or (($null -ne $responseHeaders."X-RateLimit-Limit")     -and ($responseHeaders."X-RateLimit-Limit"     -gt 0)) `
            -or (($null -ne $responseHeaders."X-RateLimit-Remaining") -and ($responseHeaders."X-RateLimit-Remaining" -gt 0)) `
            -or (($null -ne $responseHeaders."X-RateLimit-Reset")     -and ($responseHeaders."X-RateLimit-Reset"     -gt 0)) `
        )
        {
            Write-Host "StatusCode: $statusCode`r`n"
            Write-Host "Headers:"
            Write-Host $responseHeaders
            Write-Host "`r`nBody:`r`n"
            Write-Host $Response | ConvertTo-Json -depth 100 
        }
        #endregion Debug&Throttle
    }
}