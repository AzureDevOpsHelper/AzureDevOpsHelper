# AzureDevOpsHelper

AzureDevOpsUserHelper is a diagnostic and informational script that will focus on pulling User information from Azure Devops and related systems.  I intend to add the ability to perform diagnostic checking for specific known issues, though I'm not planning to add any "fix" capability to ensure that this remains a diagnostic tool and can be run without risk. 

## Features

- Authenticate with Azure DevOps using MSAL (Microsoft Authentication Library).
- Retrieve the current user's information from Azure DevOps.
  - Auth to GraphAPI and gather user and tenant info from Entra (if applicable).  
  - Retrieve entitlement info from org for this user.
- Retrieve the projects in the Azure DevOps organization.
- Retrieve the groups the current user is a member of (both Entra and Azure DevOps).
  - _The api to pull a users "memberships" is not paginated so we can't reliably ask for all user memberships in large orgs_
  - This starts immediately after Auth and runs until complete, main thread waits until other calls a re complete then awaits completion.
  - Pull all Groups in the Org in pages of 500, use continuation token to repeat until done.
  - Check each user/container to see if membership exists (this also shows nested memberships!) 
  - These checks use a ForEach-Object -Parallel with -ThrottleLimit 25 making this significantly faster.
- Create output file with verbose details in configurable path.

- todo: Retrieve and display security namespaces and access control entries (ACEs) for the current user [Add Permissions Information](https://github.com/AzureDevOpsHelper/AzureDevOpsHelper/issues/1). 

## Prerequisites

- .Net Framework
- User account in an Azure DevOps Org

## Getting Started

1. Download this entire Repo somewhere in your file system.
2. Leave the folder structure intact or this will not work.
3. Run the `AzureDevOpsHelper.ps1` file in your favorite Powershell tool.
4. When prompted enter the name of your devops org and press enter.
5. Follow the log in flow to get a Token for your Azure DevOps.
6. Log in a second time, to authenticate to GraphAPI.
7. The script will output information about your user from devops and Entra.

## Contributing 

If you'd like to contribute please fork this Repo and make whatever changes you feel are needed, or add functionality.
Submit a PR with a good description of the changes and @SamGrantham to review, I'll take a look and approve/comment ASAP!

## Support and Feature Requests

- I will support this as much as I can but please be aware this is likely a "best effort" scenario.  
- If you have suggestions for additional functionality, changes or conserns I'd love to hear them and I'll take them up as I am able.

In both scenarios please add an issue with a good description and we will go from there!
