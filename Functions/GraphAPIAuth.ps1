# Aquire MSAL Token interactively for GraphAPI
# We Auth to Graph API seprately and interactivly to make sure that we don't run into any issues
# with reusing the Token from DevOps, It's also simpler because we don't have to create a
# Credientail Cache and use a broker.
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
