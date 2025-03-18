# Aquire MSAL Token interactively for Azure DevOps
# We use interactive/MSAL Auth to make aquiring a token as simple as possible
# We don't want to use a PAT because part of what theses scripts are trying to do 
# help troubleshoot AUTH.
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