# PSM1 iTop module for PowerShell
Copyright (C) 2019-2021 Jeffrey Bostoen

[![License](https://img.shields.io/github/license/jbostoen/iTop-custom-extensions)](https://github.com/jbostoen/iTop-custom-extensions/blob/master/license.md)
[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.me/jbostoen)
🍻 ☕

Need assistance with iTop or one of its extensions?  
Need custom development?  
Please get in touch to discuss the terms: **jbostoen.itop@outlook.com**

## What?
A PowerShell module.
Note: this is my very first PowerShell module ever.

Written to automate some tasks which are repeated a lot in development and production environments.

**iTop API (REST/JSON) functions**
This also inherits the limitations present in the iTop API, although there are some work-arounds available too.
The most important limitation is that with each HTTP request, only one object can be created, modified or deleted.

* `Get-iTopObject`: get zero, one or more iTop objects (core/get)
* `New-iTopObject`: create 1 iTop object (core/create)
* `Remove-iTopObject`: delete iTop object(s) (core/delete)
* `Set-iTopObject`: update iTop object(s) (core/update)

**Miscellaneous**
* `Install-iTopUnattended`: performs an unattended (automatic) (re)installation of iTop.
* `Get-iTopClass`: gets overview of each class, including parent and module where it's defined or changed
* `Get-iTopCommand`: shows all iTop commands in this PS1 module.
* `Get-iTopEnvironment`: set settings of an iTop environment
* `Invoke-iTopRestMethod`: invokes POST request
* `New-iTopExtension`: creates new extension from template
* `Remove-iTopLanguage`: removes all unnecessary language files
* `Rename-iTopExtension`: renames an extension. Renames folder, renames default files, replaces extension name in those files...
* `Set-iTopConfigWritable`: makes or keeps (every 5 seconds) configuration file writable
* `Set-iTopEnvironment`: set settings of an iTop environment
* `Set-iTopExtensionReleaseInfo`: sets iTop extension release info (in "extensions" folder defined in the environment)
* `Start-iTopCron`: starts iTop cron jobs


## Configuration example

"default" is the name of the default environment and should always be included.
You can add more environments by adding a 'environment-name.json' file in **%UserProfile%\Documents\WindowsPowerShell\Modules\iTop\environments**

**API settings** are useful in all cases.
All other settings are primarily when you have iTop installed on the same machine as where you are running the PowerShell module on.


```
{

	"Variables": {
		"Environment": "production",
	},
	
	"API": {
		"Url":  "http://127.0.0.1/itop/web/webservices/rest.php?login_mode=url",
		"Version":  "1.3",
		"Password":  "admin",
		"Output_Fields":  "*",
		"User":  "admin"
	},
	
	"App":  {
		"Path":  "C:\\xampp\\htdocs\\iTop\\web", 
		"ConfigFile":  "C:\\xampp\\htdocs\\iTop\\web\\conf\\production\\config-itop.php", 
		
		
		"UnattendedInstall": {
			"Script":  "C:\\xampp\\htdocs\\iTop\\web\\toolkit\\unattended_install.php", 
			"XML":  "C:\\xampp\\htdocs\\iTop\\web\\toolkit\\unattended_install.xml",
			"CleanXML":  "C:\\xampp\\htdocs\\iTop\\web\\toolkit\\unattended_install_clean.xml",
		},
		 
		"Languages": [
			"en",
			"nl"
		] 
	},
	
	"Extensions": {
	   "Path":  "C:\\xampp\\htdocs\\iTop\\web\\extensions", 
	   "Url":  "https://github.com/jbostoen/iTop-custom-extensions",
	   "VersionMin":  "2.6.0", 
	   "VersionDataModel":  "1.6", 
	   "Author":  "Jeffrey Bostoen", 
	   "Company":  "", 
	   "VersionDescription":  "" 
	},
	
	"Cron": {
		"User": "admin",
		"Password": "admin"
	}
	
}

```

**Variables**: any key you define here, can be used as a variable (%name%) in the other parts of the configuration. Strings only for now.



## Upgrade notes

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
The default environment is named "default.json".

Furthermore, ```Remove-iTopLanguages``` is now named Remove-iTopLanguage for consistency reasons.


