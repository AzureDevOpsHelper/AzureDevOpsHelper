# Aquire MSAL Token interactively
function Get-MSALToken 
{
    Import-MSALAssemblies
    $config = Get-Content -Path "config.json" | ConvertFrom-Json
    [string[]]$devopsScopes = @($config.scope)
    $clientId = $config.clientId
    $redirectUri = $config.redirectUri
    $publicClientApp = [Microsoft.Identity.Client.PublicClientApplicationBuilder]::Create($clientId).WithRedirectUri($redirectUri).Build()
    $result = $publicClientApp.AcquireTokenInteractive($devopsScopes).ExecuteAsync().Result
    return $result
}