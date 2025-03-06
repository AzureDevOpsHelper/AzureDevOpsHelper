# Aquire MSAL Token interactively
function Get-MSALTokenforGraphApi 
{
    $config = Get-Content -Path "config.json" | ConvertFrom-Json
    [string[]]$graphScopes = @($config.graphscope)
    $clientId = $config.clientId
    $redirectUri = $config.redirectUri
    $publicClientApp = [Microsoft.Identity.Client.PublicClientApplicationBuilder]::Create($clientId).WithRedirectUri($redirectUri).Build()
    $result = $publicClientApp.AcquireTokenInteractive($graphScopes).ExecuteAsync().Result
    return $result
}
