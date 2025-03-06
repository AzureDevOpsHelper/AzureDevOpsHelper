# AzureDevOpsHelper

AzureDevOpsUserHelper is a diagnostic and informational script that will focus on pulling User information from Azure Devops.  I intend to add the ability to perform diagnostic checking for specific known issues, though I'm not planning to add any "fix" capability to ensure that this remains a diagnostic tool and can be run without risk. 

## Features

- Authenticate with Azure DevOps using MSAL (Microsoft Authentication Library) and fallback to ADAL (Active Directory Authentication Library) if necessary.
- Authentication will fall back to a PAT but my current feeling is if you can't auth either of the above you likely can't get a PAT either.

- Retrieve the current user's information from Azure DevOps.
 > - todo: Auth to GraphAPI and gather user info from Entra (if applicable).  
- Retrieve the projects in the Azure DevOps organization.
- Retrieve the groups the current user is a member of.
 > - todo: Retrieve group memberships from Entra.
 > - todo: Determine how to handle nesting for both group types
- Retrieve and display security namespaces and access control entries (ACEs) for the current user.

## Prerequisites

- .Net Framework
- User account in an Azure DevOps Org

## Getting Started

1. Download this entire Repo somewhere in your file system.
2. Leave the folder structure intact or this will not work.
3. Run the `AzureDevOpsHelper.ps1` file in your favorite Powershell tool.
4. When prompted enter the name of your devops org and press enter.
5. Follow the log in flow to Get a Token for your user.
6. The script will output information about your user.

## Contributing 
1. TBD

