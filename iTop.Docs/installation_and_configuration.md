
# Installation

Hint: It's possible to always load these modules by default.

- [ ] Enter `$env:PSModulePath` to see from which directories PowerShell tries to load modules.
- [ ] Extract the directories of each module ( `iTop.API` , `iTop.Environments`, `iTop.Local` ) in that path. 
- [ ] Open a new PowerShell console window.


# Configuration example

You can add more environments by adding an '**<environment-name>**.json' file in `<Powershell module directory>\iTop\environments` .
For PowerShell 5.x, this is likely `%UserProfile%\Documents\WindowsPowerShell\Modules\iTop\environments` .
For PowerShell 7.x, this is likely `%UserProfile%\Documents\PowerShell\Modules\iTop\environments` .

⚠ To be future proof: only use alphabetical characters, numbers or underscores in the filenames.  
Some words are reserved words in PowerShell, so this module will not use "default.json" as a name.



**Variables**: any key you define here, can be used as a variable (%name%) in the other parts of the configuration. Strings only for now.

All other settings are primarily relevant when you have iTop installed on the same machine as where you are running the PowerShell module on.

Here is a full example.

```
{

	// Note: It is not necessary to include or adjust all settings below.
	// For example, if you're only interested in using the API, the "API" block is already enough.

	// If this mostly inherits settings from another configuration file, you can specify the name of that configuration here.
	// It allows you to for example have one common configuration file, with very few adjustments.
	"InheritFrom": "someOtherEnvironmentName",
	
	// Variables can be used at any time. They are placeholders that are defined here.
	// For example, here a variable 'Environment' (can be anything, as long as it's a valid JSON property name) is configured and its value is set to 'production'.
	// In other settings, whenever %Environment% is used somewhere, it will be replaced with 'production'.
	"Variables": {
		"Environment": "production",
	},
		
	// This section below is only relevant when using the iTop.API PowerShell module.
	
		// More info: https://www.itophub.io/wiki/page?id=latest:advancedtopics:rest_json
		"API": {
			// The iTop REST/JSON API endpoint URL.
			// Explicitly add the login mode.
			// Currently supports:
			// login_mode=url (URL parameters such as auth_user and auth_pwd will be added)
			// login_mode=basic (HTTP Basic Authentication will be used)
			// login_mode=token (iTop application token will be used)
			"Url":  "http://127.0.0.1/itop/web/webservices/rest.php?login_mode=url",
			// Version of the iTop API.
			"Version":  "1.3",
			// Username and password for the iTop API user.
			// Mind that for now, the module uses the configured URL to determine how to authenticate.
			"User":  "admin",
			"Password":  "admin",
			// Or alternatively, use an application token:
			"Token": "iTopApplicationToken",
			// Specify the default output. '*' means all attributes of the queried class, '*+' means all attributes of the object's class.
			// For example, if tickets are queried, '*' would return all the attributes which are defined for the ticket class.
			// However, tickets could include changes, incidents, user requests, ... . Those classes each have some unique attributes. '*+' would expose those attributes in the result.
			"Output_Fields":  "*"
		},
	
	// This section below is only relevant when you want to use the iTop.Local PowerShell module 
	// to interact with an iTop environment on the local machine.
	

		// This is used when using the an unattended installation or upgrade, 
		// or when performing certain tweaks (e.g. Remove-iTopLanguage).
		"App":  {
		
			// Local path to an iTop installation.
			"Path":  "C:\\xampp\\htdocs\\iTop\\web",
			
			// Name of the iTop environment. For 99% of the use cases, this will be "production".
			// Only when working with different iTop environment names, this needs to be adjusted.
			"Environment":  "%Environment%",
		
			// Only relevant for unattended install of iTop.
			// More info: https://www.itophub.io/wiki/page?id=latest:advancedtopics:automatic_install
			"UnattendedInstall": {
				// This setting points to the location where the PHP script is found to execute an unattended installation.
				"Script":  "C:\\xampp\\htdocs\\iTop\\web\\toolkit\\unattended_install.php", 
				// These settings point to the unattended XML file.
				"InstallXML":  "C:\\xampp\\htdocs\\iTop\\web\\toolkit\\unattended_install.xml",
				"UpgradeXML":  "C:\\xampp\\htdocs\\iTop\\web\\toolkit\\unattended_upgrade.xml",
			},
			
			// The short code of the language files that should be kept by default.
			// For example, use "en" for English. Check the iTop language files to discover all prefixes.
			"Languages": [
				"en",
				"de",
				"fr",
				"nl"
			] 
		},
		
		// Cron settings.
		// If you're planning to execute the cron background process from the command line (Start-iTopCron),
		// the iTop user credentials must be provided here.
		"Cron": {
			"User": "admin",
			"Password": "admin"
		},
		
		// Extension settings.
		// This is meant to ease local development.
		// The settings are used when creating or renaming extensions; or to quickly set common publisher info.
		"Extensions": {
		   "Path":  "C:\\xampp\\htdocs\\iTop\\web\\extensions", 
		   "Url":  "https://jeffreybostoen.be",
		   "VersionMin":  "2.7.0", 
		   "VersionDataModel":  "1.7", 
		   "Author":  "Jeffrey Bostoen", 
		   "Company":  "Jeffrey Bostoen", 
		   "VersionDescription":  "" 
		},
		
		"PHP": {
			"Path": "C:\\xampp\\php\\php.exe"
		}
	
}

```

