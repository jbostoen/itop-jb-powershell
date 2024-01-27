
# Overview of cmdlets

"Environment configuration" means the JSON file (created for this PowerShell module) containing the settings for an iTop enviromnent.

**iTop API (REST/JSON) functions**

In the environment file, make sure the "API" block is configured.

These cmdlets also inherits the limitations present in the iTop API, although there are some work-arounds available too.
The most important limitation is that with each HTTP request, only one object can be created, modified or deleted.

* `Get-iTopObject`: Get zero, one or more iTop objects (core/get).
* `New-iTopObject`: Create 1 iTop object (core/create).
* `Remove-iTopObject`: Delete iTop object(s) (core/delete).
* `Set-iTopObject`: Update iTop object(s) (core/update).

**Unattended install**

In the environment file, make sure the "App" block is configured.

* `Install-iTopUnattended`: Performs an unattended (automatic) (re)installation of iTop.
* `Set-iTopConfigWritable`: Sets or keeps (every 5 seconds) the iTop configuration file (config-itop.php) writable. This is needed when installing/upgrading iTop.

**Extensions development**

In the environment file, make sure the "Extensions" block is configured.

* `New-iTopExtension`: Ceates new extension from template.
* `Rename-iTopExtension`: Renames an extension. Renames folder, renames default files, replaces extension name in those files...
* `Set-iTopExtensionReleaseInfo`: Sets iTop extension release info (in "extensions" folder defined in the environment).
* `Start-iTopCron`: Starts the cron background process for iTop cron jobs.


**Miscellaneous**

* `Get-iTopClass`: Gets overview of each class, including parent and module where it's defined or changed.
* `Get-iTopCommand`: Shows all iTop commands in this PowerShell module.
* `Get-iTopEnvironment`: Get settings of an iTop environment.
* `Invoke-iTopRestMethod`: Invokes POST request.
* `Remove-iTopLanguage`: Removes all unnecessary language files.
* `Set-iTopEnvironment`: Set settings of an iTop environment.

