
# Upgrade notes

The code has evolved over time. 
Some code changes will also require you to update the configuration files, or your scripts.

**To version 2024-03-26 and higher:**  

The module has been split into several parts.


`Get-iTopCommand` has been removed.

`Set-iTopConfigWritable` has been removed.
See `Unblock-iTopSetup` as the new alternative.



**To version 2022-06-07 and higher:**  

Filenames of configuration files (.json) should only consist of alphabetical characters, numbers and underscores.  

Some terms (such as the previous 'default.json') are forbidden in PowerShell.  
The new default file is now 'production.json'.


**To version 2021-07-08 and higher:**  

Adjust URL to contain ```login_mode``` parameter to URL in configurations.
Currently supported values are 'basic' and 'url'.


**To version 2020-11-09 and higher:**  

```$global:iTopEnvironments``` is no longer available.

Settings are now available through `Get-iTopEnvironment` and `Set-iTopEnvironment`

**To version 2020-04-02 and higher:**  

If you used the functions from previous versions of this module, it might be necessary to make some changes.  
First of all: multiple environments are now supported (for instance: development and production).  
There's now one .JSON file for each iTop environment.
The default environment is named "production.json".

Furthermore, ```Remove-iTopLanguages``` is now named Remove-iTopLanguage for consistency reasons.

