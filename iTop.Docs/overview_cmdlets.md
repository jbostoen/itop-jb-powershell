
# Overview of cmdlets

"Environment configuration" means the JSON file (created for this PowerShell module) containing the settings for an iTop environment.

Each module contains some specific functions.

**iTop.Environments**

This module is used to manage the iTop environments (configuration for PowerShell modules).

* `Get-iTopEnvironment`: Get settings of an iTop environment.
* `Set-iTopEnvironment`: Set settings of an iTop environment.


**iTop.API**

This module requires iTop.Environments.
In the environment file, make sure the "API" block is configured.

This module is used to interact with the iTop REST/JSON API of an iTop instance.


These cmdlets also inherits the limitations present in the iTop API, although there are some work-arounds available too.
The most important limitation is that with each HTTP request, only one object can be created, modified or deleted.

* `Get-iTopObject`: Get zero, one or more iTop objects (core/get).
* `Invoke-iTopRestMethod`: Invokes POST request.
* `New-iTopObject`: Create 1 iTop object (core/create).
* `Remove-iTopObject`: Delete iTop object(s) (core/delete).
* `Set-iTopObject`: Update iTop object(s) (core/update).


**iTop.Local**

This module requires iTop.Environments.
In the environment file, make sure the "App" block is configured.

This module is used to interact with a locally installed iTop environment. 
It can be used for management and/or local development: to (re)install iTop unattended, to tweak iTop, to run the iTop cron job process, ...


* `Get-iTopClass`: Gets overview of each class, including parent and module where the class was defined or last altered.
* `Install-iTopUnattended`: Performs an unattended (automatic) (re)installation of iTop.
* `New-iTopExtension`: Ceates new extension from template.
* `Remove-iTopLanguage`: Removes all unnecessary language files.
* `Rename-iTopExtension`: Renames an extension. Renames folder, renames default files, replaces extension name in those files...
* `Set-iTopExtensionReleaseInfo`: Sets iTop extension release info (in "extensions" folder defined in the environment).
* `Start-iTopCron`: Starts the cron background process for iTop cron jobs.
* `Unblock-iTopSetup`: This could be needed when installing/upgrading iTop. (Unsets read-only flag of the iTop configuration file, removes .maintenance and .readonly files if present).


