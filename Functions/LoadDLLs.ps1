# Function to Load the MSAL.NET assembly
function Import-MSALAssemblies
{
    #Write-Host "Checking and loading the MSAL.NET assemblies."
    $WP = $WarningPreference
    $WarningPreference = 'SilentlyContinue'
    $PP = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try 
    {
        $MSIDCdll = Resolve-Path ".\Libraries\Microsoft.Identity.Client.4.66.2\lib\net462\Microsoft.Identity.Client.dll"
        Add-Type -Path $MSIDCdll
        [Reflection.Assembly]::Load("Microsoft.Identity.Client") | Out-Null
    }
    catch 
    {
        if ($_ -match "Assembly with same name is already loaded")
        {
            Write-Host "Microsoft.Identity.Client.dll is already loaded."
        }
        else
        {
            Write-Host $_
            Write-Host "Error loading Microsoft.Identity.Client.dll you can try to download it from https://www.nuget.org/packages/Microsoft.Identity.Client/4.68.0 and place it in the Libraries folder."
        }
    }
    try
    {
        $MSIMAdll = Resolve-Path ".\Libraries\Microsoft.IdentityModel.Abstractions.6.35.0\lib\net45\Microsoft.IdentityModel.Abstractions.dll"
        Add-Type -Path $MSIMAdll 
        [Reflection.Assembly]::Load("Microsoft.IdentityModel.Abstractions") | Out-Null
    }
    catch 
   {
        if ($_ -match "Assembly with same name is already loaded")
       {
            Write-Host "Microsoft.IdentityModel.Abstractions.dll is already loaded."
        }
        else
        {
            Write-Host $_
            Write-Host "Error loading Microsoft.IdentityModel.Abstractions.dll you can try to download it from https://www.nuget.org/packages/Microsoft.IdentityModel.Abstractions/2.26.0 and place it in the Libraries folder."
        }
    }
    $WarningPreference = $WP
    $ProgressPreference = $PP
}