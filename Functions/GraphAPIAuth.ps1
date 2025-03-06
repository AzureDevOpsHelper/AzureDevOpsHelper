# Aquire MSAL Token interactively
function Get-MSALTokenforGraphApi 
{
    param (
        [string]$tenantId,
        [string]$OID
    )
    Import-GraphAssemblies
    $config = Get-Content -Path "config.json" | ConvertFrom-Json
    [string[]]$devopsScopes = @($config.graphscope)
    $clientId = $config.clientId
    $redirectUri = $config.redirectUri
    $options = @{
        TenantId = $tenantId
        ClientId = $clientId
        AuthorityHost = "https://login.microsoftonline.com"
        RedirectUri = $redirectUri
    }
    $interactiveCredential = [Azure.Identity.InteractiveBrowserCredentialBuilder]($options)
    $graphClient = New-Object [Microsoft.Graph.GraphServiceClient]($interactiveCredential, $devopsScopes)
    $result = $graphClient.Users[$OID].GetAsync().Result
    return $result
}