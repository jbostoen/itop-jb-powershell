# copyright   Copyright (C) 2019-2022 Jeffrey Bostoen
# license     https://www.gnu.org/licenses/gpl-3.0.en.html
# version     2022-06-13 15:59:00

# Variables

# Read configuration from JSON-file.
# Let's make it available in the entire scope of this module so it can easily be altered or used for different purposes.
$Script:iTopEnvironments = [PSCustomObject]@{}


If($PsISE) {

    # Workaround for PowerShell ISE
    $Environments = @()
    $Paths = @(
        "$($env:USERPROFILE)\OneDrive\Documents\WindowsPowerShell\Modules\iTop\environments", 
        "$($env:USERPROFILE)\Documents\WindowsPowerShell\Modules\iTop\environments"
    )


    $Paths | ForEach-Object {

        $EnvironmentPath = $_

        if((Test-Path -Path $EnvironmentPath) -eq $true -And $Environments.Count -eq 0) {

            $Environments = Get-ChildItem -Path $EnvironmentPath -Include "*.json" -Recurse
            Write-Host $EnvironmentPath
            return

        }

    }

    if($Environments.Count -eq 0) {
        
        Write-Host "Warning: no configuration of iTop environments found in $($EnvironmentPath)"

    }

    
    

}
Else {
    $Environments = Get-ChildItem -Path "$($PSScriptRoot)\environments" -Include "*.json" -Recurse
}

# Perform actions on several environments
$Environments | ForEach-Object {

	$EnvName = $_.Name -Replace ".json", ""

    If($EnvName -notmatch "^[A-Za-z0-9_]{1,}$" -or $EnvName -eq "default") {
        Write-Error "Invalid name for JSON file: $($EnvName)"
    }

	$UnmodifiedSettings = ConvertFrom-JSON (Get-Content -Path $_.FullName -Raw)
    $SettingsJSON = Get-Content -Path $_.FullName -Raw
    
    If($UnmodifiedSettings.Variables -ne $null) {


        # Replace variables
        $UnmodifiedSettings.Variables.PSObject.Properties | ForEach-Object {
        
            # Still needs to be converted to JSON, so escape backslash again
            $SettingsJSON = $SettingsJSON -Replace "%$($_.Name)%", $($_.Value -replace "\\", "\\")

        }

	    
	}
    
    Add-Member -InputObject $Script:iTopEnvironments -NotePropertyName $EnvName -NotePropertyValue ($SettingsJSON | ConvertFrom-Json)
    

    

	# Write-Host "Loaded environment $EnvName"
}



$Expression = "Add-Type -TypeDefinition @`"
    public enum iTopEnvironment {
$($Script:iTopEnvironments.PSObject.Properties.Name -Join ",`n" | Out-String)}
`"@"


try {

    Invoke-Expression $Expression

}  
catch {

    Write-Error "Invalid filename. Avoid using reserved words in PowerShell such as 'default'. Hint: the filename of your JSON file does not need to match the iTop environment's name."
 

}

# region Common

	function Get-iTopCommand {
	<#
	 .Synopsis
	 Lists commands for iTop

	 .Description
	 Lists commands for iTop

	 .Parameter Credentials
	 Credentials

	 .Example
	 Get-iTopCommand
	 

	#>   
		param(
			
		)
		
		Write-Host "Getting help: Get-Help <name function>"
		Get-Command | Where { $_.Source -eq 'iTop' } | Format-Table

	}
	
# endregion


#region iTop environments


	function Set-iTopEnvironment {
	<#
	 .Synopsis
	 Create/edit an iTop environment in the current session
	 
	 .Description
	 Create/edit an iTop environment in the current session
	 
	 .Parameter Environment
	 Environment name
	 
	 .Parameter Settings
	 Environment settings (object)
	 
	 .Parameter Persistent
	 Optional. Save settings to the configuration file (JSON). Defaults to $False.
	 
	 .Notes
	 2020-11-09: added function
	#>
		param(
			[Parameter(Mandatory=$true)][iTopEnvironment] $Environment,
			[Parameter(Mandatory=$true)][PSCustomObject] $Settings,
			[Parameter(Mandatory=$false)][Boolean] $Persistent = $False
		)
	 
		$Script:iTopEnvironments."$Environment" = $Settings
		
		If($Persistent -eq $True) {

			If($PsISE) {
				# Workaround for PowerShell ISE
				$EnvironmentPath = "$($env:USERPROFILE)\Documents\WindowsPowerShell\Modules\iTop\environments"
			}
			Else {
				$EnvironmentPath = "$($PSScriptRoot)\environments"
			}
			
			$Settings | ConvertTo-JSON | Out-File "$($EnvironmentPath)\$($Environment).json"

		}
	 
	}
	
	function Get-iTopEnvironment {
	<#
	 .Synopsis
	 Create/edit an iTop environment in the current session
	 
	 .Description
	 Create/edit an iTop environment in the current session
	 
	 .Parameter Environment
	 Optional. If specified, only this environment will be returned.
	 
	 .Notes
	 2020-11-09: added function
	#>
		param(
			[Parameter(Mandatory=$false)][iTopEnvironment]$Environment
		)
	 
		$Environments = $Script:iTopEnvironments
		
		If($Environment -ne $null) {
			$Environments = $Environments."$Environment"
			
			if($Environments -eq $null) {
				throw "Environment $($Environment) was not defined (case sensitive!)"
			}
		}
			
		
		return $Environments
	 
	}
	
#endregion iTop environments

#region iTop (un)install related functions

	<#
	 .Synopsis
	 Installs iTop unattended.

	 .Description
	 Installs iTop unattended.
	 
	 .Parameter Environment
	 Environment name
			
	 .Parameter Clean
	 Switch. Installs clean environment. Warning: drops data!

	 .Parameter Force
	 Switch. Forces removal of .maintenance and .readonly files if present (blocking ex
	 
	 .Example
	 Install-iTopUnattended

	 .Notes
	 2019-08-18: added function
	 2020-04-01: added parameter Environment (required)
	 2021-02-04: added parameter Clean (optional)
	 2021-09-02: added parameter Force (optional)
	#>
	function Install-iTopUnattended { 

		param(
			[iTopEnvironment]$Environment,
			[Switch] $Clean,
            [Switch] $Force
		)
		
		if($Script:iTopEnvironments.PSObject.Properties.Name -notcontains $Environment) {
			throw "iTop module: no configuration for environment '$($Environment)'"
		}
		
		$EnvSettings = $Script:iTopEnvironments."$Environment"
		
		$InstallScript = $EnvSettings.App.UnattendedInstall.Script
		
        # Legacy
        if($EnvSettings.App.UnattendedInstall.UpgradeXML -ne $null) {
            $UpgradeXML = $EnvSettings.App.UnattendedInstall.UpgradeXML
        }
        elseif($EnvSettings.App.UnattendedInstall.XML -ne $null) {
            Write-Host "Warning: you are using 'XML' instead of 'UpgradeXML' in the JSON configuration file ($Environment). This is deprecated and will not be supported in a future release." -ForegroundColor Yellow
            $UpgradeXML = $EnvSettings.App.UnattendedInstall.XML
        }


		$InstallXML = $EnvSettings.App.UnattendedInstall.InstallXML
		$PhpExe = $EnvSettings.PHP.Path
		
		If((Test-Path -Path $InstallScript) -eq $False) {
			throw "Unattended install script not found: $($InstallScript). Download from iTop Wiki or specify correct location"
		}
		If($Clean.IsPresent -eq $false -and (Test-Path -Path $UpgradeXML) -eq $False) {
			throw "Unattended upgrade install XML not found: $($UpgradeXML). Specify correct location"
		}
		If($Clean.IsPresent -eq $true -and $InstallXML -ne $null -and (Test-Path -Path $InstallXML) -eq $False) {
			throw "Unattended clean install XML not found: $($InstallXML). Specify correct location"
		}
		If((Test-Path -Path $PhpExe) -eq $False) {
			throw "PHP.exe not found: $($PhpExe). Specify correct location"
		}
		
		# Make config writable
		Set-iTopConfigWritable -Environment $Environment
		
		# PHP.exe: require statements etc relate to current working directory. 
		# Need to temporarily change this!
		$OriginalDir = (Get-Item -Path ".\").FullName;
		$ScriptDir = (Get-Item -Path $InstallScript).Directory.FullName;
		
		cd $ScriptDir
		

        If($Force.IsPresent) {
            $FileReadOnly = "$($EnvSettings.App.Path)\data\.readonly"
            $FileMaintenance = "$($EnvSettings.App.Path)\data\.maintenance"
            If((Test-Path -Path $FileReadOnly) -eq $true) {
                Remove-Item -Path $FileReadOnly
            }
            If((Test-Path -Path $FileMaintenance) -eq $true) {
                Remove-Item -Path $FileMaintenance
            }
        }
		
		
		If($Clean.IsPresent) {
            $Cmd = "$($PhpExe) $($InstallScript) --response_file=$($InstallXML) --clean=1";
		}
        Else {
            $Cmd = "$($PhpExe) $($InstallScript) --response_file=$($UpgradeXML)";
        }
		
		Write-Host "Start: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
		Write-Host "Running PHP script for unattended installation..."
		Write-Host "Command: $($Cmd)"
		Write-Host "$('*' * 25)"
		
		PowerShell.exe -Command $Cmd
		
		cd $OriginalDir
		
		Write-Host ""
		Write-Host "$('*' * 25)"
		Write-Host "Ran unattended installation. See above for details."
		Write-Host "Finish: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
		

	}


	function Set-iTopConfigWritable {
	<#
	 .Synopsis
			Makes iTop configuration file writable

	 .Description
			Makes iTop configuration file writable

	 .Parameter Environment
	 Environment name
	 
	 .Parameter Loop
	 Keep looping (resets the file to writable every 15 seconds)

	 .Example
	 Set-iTopConfigWritable
	 
	 .Example
	 Set-iTopConfigWritable -loop $true

	 .Notes
	 2020-04-01: added parameter Environment (optional)
	#>   
		param(
			[Boolean] $Loop = $False,
			[iTopEnvironment] $Environment
		)

		if($Script:iTopEnvironments.PSObject.Properties.Name -notcontains $Environment) {
			throw "iTop module: no configuration for environment '$($Environment)'"
		}
		
		$EnvSettings = $Script:iTopEnvironments."$Environment"
		
		$Count = 0;
		while($Loop -eq $true -or $Count -eq 0) {
		
			$Count = $Count + 1;

			If((Test-Path -Path $EnvSettings.App.ConfigFile) -eq $True) {
                Get-Item -Path $EnvSettings.App.ConfigFile | Set-ItemProperty -Name IsReadOnly -Value $False
			    Write-Host "Set write permissions on iTop configuration file ($($EnvSettings.App.ConfigFile)) (#$($Count))"
			}
            Else {
                Write-Host "iTop configuration file not found: ($($EnvSettings.App.ConfigFile)) (#$($Count))"
            }
			
			
			
			If($Loop -eq $true) {
				Start-Sleep -Seconds 15
			}		
		}
	}
	
	

	function Remove-iTopLanguage {
	<#
	 .Synopsis
	 Removes languages (improves performance of existing iTop installations)

	 .Description
	 Removes languages (improves performance of existing iTop installations)

	 .Parameter Confirm
	 Confirm. Defaults to false and does NOT remove language files!
	 
	 .Parameter Environment
	 Environment name
	 
	 .Example
	 Remove-iTopLanguages
	 
	 .Example
	 Remove-iTopLanguages -KeepLanguages @("en", "nl") -confirm $true

	 .Notes
	 2020-04-01: renamed function from Remove-iTopLanguages to Remove-iTopLanguage (consistency)
	           : added parameter Environment (optional)
	           : removed unused parameter Languages (required) (listed languages to remove, had already moved to config file)
	#>
		param(
			[Boolean] $Confirm = $False,
			[iTopEnvironment] $Environment 
		)

		if($Script:iTopEnvironments.PSObject.Properties.Name -notcontains $Environment) {
			throw "iTop module: no configuration for environment '$($Environment)'"
		}
		
		$EnvSettings = $Script:iTopEnvironments."$Environment"
		
		$LanguageFiles = Get-ChildItem -Path $EnvSettings.App.Path -Recurse -Include @("*.dict.*.php", "*.dictionary.*.php")

		# Exclude languages that must be kept
		$KeepLanguages = $EnvSettings.App.Languages -Join "|"
		$Regex = "^(" + $KeepLanguages + ").*\.(dict|dictionary)\.(.*?)\.php$"
		
		$LanguageFiles_Remove = $LanguageFiles | Where-Object { 
			($_.Name -notmatch $Regex)
		}
		
		Write-Host "Languages to keep: $($KeepLanguages)"
		
		if($Confirm -eq $False) {
			# Just list
			$LanguageFiles_Remove
			Write-Host "Warning: performed simulation. Did NOT remove languages. Use -Confirm `$true"
		}
		else {
			# Delete
			$LanguageFiles_Remove | Remove-Item		
			Write-Host "Removed all other languages"
		}

	}
	
#endregion

#region Extension-related functions


	function New-iTopExtension {
	<#
	 .Synopsis
	 Creates new extension from a template

	 .Description
	 Creates new extension from a template

	 .Parameter Name
	 Specify a name. Only alphanumerical characters and hyphen (-) are accepted.

	 .Parameter Description
	 Specify a description. Briefly explains what the extension does.

	 .Parameter Environment
	 Environment name
	 
	 .Parameter Label
	 Specify a label. This is the title of the extension.

	 .Example
	 New-iTopExtension 

	 .Notes
	 2020-04-01: added parameter Environment (optional)
	#>
		param(
			[Parameter(Mandatory=$true)][String] $Name,
			[Parameter(Mandatory=$False)][String] $Description = '',
			[Parameter(Mandatory=$False)][String] $Label = 'Group name: something',
			[iTopEnvironment] $Environment
		)

		if($Script:iTopEnvironments.PSObject.Properties.Name -notcontains $Environment) {
			throw "iTop module: no configuration for environment '$($Environment)'"
		}
		
		$EnvSettings = $Script:iTopEnvironments."$Environment"
		
		# Prevent issues with filename
		# This may be more limiting than what Combodo allows
		If( $Name -notmatch "^[A-z][A-z0-9\-]{1,}$" ) {
			throw "The extension's name preferably starts with an alphabetical character. Furthermore, it preferably consists of alphanumerical characters or hyphens (-) only."
		}

		$Extension_Source = "$($Env:USERPROFILE)\Documents\WindowsPowerShell\Modules\iTop\data\template"
		$Extension_Destination = "$($EnvSettings.Extensions.Path)\$($Name)"

		# Prevent issues with copy-item, running second time
		If( (Test-Path -Path $Extension_Source) -eq $false ) {
			throw "The source folder $($Extension_Source) does not exist. So there is no template available."
		}
		
		# Prevent issues with copy-item, running second time
		If( (Test-Path -Path $Extension_Destination) -eq $true ) {
			throw "The destination folder $($Extension_Destination) already exists."
		}

		# Copy directory 
		Copy-Item -Path $Extension_Source -Destination $Extension_Destination -Recurse -Container 

		# Rename some files
		$Files = Get-ChildItem -Path $Extension_Destination
		$Files | Foreach-Object {
			Move-Item -Path "$($Extension_Destination)\$($_.Name)" -Destination "$($Extension_Destination)\$( $_.Name -Replace "template", $Name )"
		}

		# Replace variables in template files
		$Files = Get-ChildItem -Path "$($Extension_Destination)"

		$Files | ForEach-Object {
		
			[String]$C = (Get-Content "$($Extension_Destination)\$($_.Name)" -Raw);
		
			# Parameters
			$C = $C.replace('{{ ext_Name }}', $Name);
			$C = $C.replace('{{ ext_Description }}', $Description);
			$C = $C.replace('{{ ext_Label }}', $Label);

			# Defaults from variables
			$C = $C.replace('{{ ext_Url }}', $EnvSettings.Extensions.Url);
			$C = $C.replace('{{ ext_VersionDescription }}', $EnvSettings.Extensions.VersionDescription);
			$C = $C.replace('{{ ext_VersionDataModel }}', $EnvSettings.Extensions.VersionDataModel);
			$C = $C.replace('{{ ext_Author }}', $EnvSettings.Extensions.Author);
			$C = $C.replace('{{ ext_Company }}', $EnvSettings.Extensions.Company);
			$C = $C.replace('{{ ext_VersionMin }}', $EnvSettings.Extensions.VersionMin);
			$C = $C.replace('{{ ext_Version }}', ($EnvSettings.Extensions.VersionMin -Replace "\.[0-9]+$","") + "." + $(Get-Date -Format "yyMMdd"));
			
			$C = $C.replace('{{ ext_ReleaseDate }}', $(Get-Date -Format "yyyy-MM-dd"));
			$C = $C.replace('{{ ext_Year }}', $(Get-Date -Format "yyyy"));
			$C = $C.replace('{{ ext_TimeStamp }}', $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") );
		
			$C | Set-Content "$($Extension_Destination)\$($_.Name)"
		}

		Write-Host "Created extension $($Name) from template in $Extension_Source"

	}

	function Rename-iTopExtension {
	<#
	 .Synopsis
	 Renames existing extension with minimal effort (standard file names only). Careful: simple search and replace operation.

	 .Description
	 Renames existing extension with minimal effort (standard file names only) Careful: simple search and replace operation.
	 Always give your extensions a proper name, preferably starting with something like 'yourprefix-'.

	 .Parameter Environment
	 Environment name

	 .Parameter From
	 Original extension name

	 .Parameter To
	 New extension name

	 .Example
	 Rename-iTopExtension -From "some-name" -To "New-name"

	 .Notes
	 2020-04-01: added parameter Environment (optional)
	           : removed parameter Path (optional)
	#>
		param(
			[Parameter(Mandatory=$true)][String] $From = '',
			[Parameter(Mandatory=$true)][String] $To = '',
			[iTopEnvironment] $Environment
		
		)
		
		if($Script:iTopEnvironments.PSObject.Properties.Name -notcontains $Environment) {
			throw "iTop module: no configuration for environment '$($Environment)'"
		}
		
		$EnvSettings = $Script:iTopEnvironments."$Environment"
		$Path = $EnvSettings.Extensions.Path
		
		# Rename directory 
		Move-Item -Path "$($Path)\$($From)" -Destination "$($Path)\$($To)" 

		# Rename all files containing the string
		# This searches for default patterns only.
		$Files = Get-ChildItem -Path "$($Path)\$($To)\*" -Include "*.$($From).php", "*.$($From).xml", "extension.xml", "readme.md"

		$Files | ForEach-Object {
		
			# Replace content within those files found above
			[String]$C = (Get-Content "$($Path)\$($To)\$($_.Name)" -Raw);	
			$C = $C.replace($From , $To ); 	
			$C | Set-Content "$($Path)\$($To)\$($_.Name)"
		
			# Rename 
			Move-Item -Path "$($Path)\$($To)\$($_.Name)" -Destination "$($Path)\$($To)\$($_.Name -Replace $($From),$($To) )"
		
		}

		Write-Host "Renamed extension from $($From) to $($To)"

	}
	
	function Set-iTopExtensionReleaseInfo {
	<#
	 .Synopsis
	 Sets iTop extension release info.

	 .Description
	 Sets iTop extension release info. Goes over every PHP file, every datamodel XML and every script file (.bat, .ps1, .psm1, .sh) in the specified iTop's extension folder.
	 Warning: ignores any files in "template" folder.
	 
	 .Parameter Environment
	 Environment name
	 
	 .Parameter Folder
	 Optional. Folder name (short). If specified, the release info is only updated for this specific extension.
	 
	 .Example
	 Set-iTopExtensionReleaseInfo
	 
	 .Example
	 Set-iTopExtensionReleaseInfo -Environment "default" -Folder "some-extension-folder"

	 .Notes
	 2020-04-01: added parameter Environment (optional)
	 2020-10-19: added parameter Folder (optional)
     2023-01-23: parameter Folder: if not specified, action must be confirmed now.
	#>
		param(
			[iTopEnvironment] $Environment,
			[Parameter(Mandatory=$False)][String] $Folder = $null
		)
		
		if($Script:iTopEnvironments.PSObject.Properties.Name -notcontains $Environment) {
			throw "iTop module: no configuration for environment '$($Environment)'"
		}
		
		$EnvSettings = $Script:iTopEnvironments."$Environment"
		$sExtensionPath = $EnvSettings.Extensions.Path
		
		if($Folder -ne $null) {
		
			$sExtensionPath += "\" + $Folder
			
			# Check if specified folder exists in order to suppress further warnings
			if((Test-Path -Path $sExtensionPath) -eq $False) {
				throw "Extension path: folder does not exist: $($sExtensionPath)"
			}
		}
        else {

            $confirmation = Read-Host "Warning: no specific subfolder specified. If you are sure you want to continue, enter Y"
            if ($confirmation -ne "y") {
                exit
            }

        }
		
		$sVersionTimeStamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
		$sVersionExtensions = $($EnvSettings.Extensions.VersionMin -Replace "\.[0-9]$", "") + '.' + (Get-Date -Format "yyMMdd")
		
		# Either add code to do more proper filtering or just make sure it's only applied to a subset of extenions.
		$Files = Get-ChildItem -Path $sExtensionPath -File -Recurse | Where-Object { $_.DirectoryName -notmatch '\\template$' }

		$Files | Where-Object { $_.Name -eq "datamodel.*.xml" } | Foreach-Object {

			$Content = Get-Content $_.FullName
			$Content = $Content -Replace '<itop_design xmlns:xsi="http:\/\/www\.w3\.org\/2001\/XMLSchema-instance" version="1.[0-9]"', "<itop_design xmlns:xsi=`"http://www.w3.org/2001/XMLSchema-instance`" version=`"$($EnvSettings.Extensions.VersionDataModel)`"" 
			$Content | Set-Content $_.FullName

		}

		$Files | Where-Object { $_.Name -eq "extension.xml" } | Foreach-Object {

			$Content = Get-Content $_.FullName
			
			# General iTop extension release info
			$Content = $Content -Replace "<version>.*<\/version>", "<version>$($sVersionExtensions)</version>" 
			$Content = $Content -Replace "<company>.*<\/company>", "<company>$($SCompany)</company>" 
			$Content = $Content -Replace "<release_date>.*<\/release_date>", "<release_date>$(Get-Date -Format 'yyyy-MM-dd')</release_date>" 
			$Content = $Content -Replace "<itop_version_min>.*<\/itop_version_min>", "<itop_version_min>$($EnvSettings.Extensions.VersionMin)</itop_version_min>"
			
			$Content | Set-Content $_.FullName
			
		}

		# Update module files
		$Files | Where-Object { $_.Name -like  "module.*.php" } | Foreach-Object {

			$Unused_but_surpress_output = $_.Name -match "^(.*)\.(.*)\.(.*)$"
			$SModuleShortName = $Matches[2]; # magic
			$Content = Get-Content $_.FullName
			$Content = $Content -Replace "'$($SModuleShortName)\/(.*)',", "'$($SModuleShortName)/$($sVersionExtensions)',"
			$Content | Set-Content $_.FullName

		}


		# Update any PHP or XML file
		$Files | Where-Object { $_.Name -like "*.php" -Or $_.Name -like "*.xml" }| Foreach-Object {

			$Content = Get-Content $_.FullName
			$Content = $Content -Replace "^([\s]{0,})\* @version([\s]{1,}).*", "`${1}* @version`${2}$($sVersionExtensions)"
			$Content = $Content -Replace "^([\s]{0,})\* @copyright([\s]{1,})Copyright \((C|c)\) (20[0-9]{2})(((\-| \- )20[0-9]{2})|).+?([A-Za-z0-9 \-]{1,})", "`${1}* @copyright`${2}Copyright (c) `${4}-$($(Get-Date).ToString("yyyy")) `${8}"
			$Content | Set-Content $_.FullName


		}
		
		
		# Script files

		# Update any BAT file
		$Files | Where-Object { $_.Name -like "*.bat" } | Foreach-Object {

			$Content = Get-Content $_.FullName
			$Content = $Content -Replace "^REM version[\s]{1,}.*", "REM version     $($sVersionTimeStamp)"			
			$Content | Set-Content $_.FullName
		}
		
		# Update any PS1/PSM1 file
		$Files | Where-Object { $_.Name -like "*.ps1" -or $_.Name -like "*.psm1" } | Foreach-Object {

			$Content = Get-Content $_.FullName
			$Content = $Content -Replace "^# version[\s]{1,}.*", "# version     $($sVersionTimeStamp)"			
			$Content | Set-Content $_.FullName
		}

		# Update any SH file
		$Files | Where-Object { $_.Name -like "*.sh" } | Foreach-Object {

			$Content = Get-Content $_.FullName
			$Content = $Content -Replace "^# version[\s]{1,}.*", "# version     $($sVersionTimeStamp)"			
			$Content | Set-Content $_.FullName
		}

		# Update any MarkDown (.md) file
		$Files | Where-Object { $_.Name -like "*.md" } | Foreach-Object {

			$Content = Get-Content $_.FullName
			$Content = $Content -Replace "Copyright \((C|c)\) (20[0-9]{2})((\-| \- )20[0-9]{2}).+?([A-Za-z0-9 \-]{1,})", "Copyright (c) `${2}-$($(Get-Date).ToString("yyyy")) `${5}"
			$Content = $Content -Replace "Copyright \((C|c)\) (2019|202[012]) (.+|)?([A-Za-z0-9 \-]{1,})", "Copyright (c) `${2}-$($(Get-Date).ToString("yyyy")) `${3}" # Don't match if after the year a new year is specified

			$Content | Set-Content $_.FullName
		}

	}
	
#endregion
  
#region iTop features

	function Start-iTopCron {
	<#
	 .Synopsis
	 Starts iTop Cron jobs

	 .Description
	 Starts iTop Cron jobs
	 
	 .Parameter Environment
	 Environment name
	 
	 .Example
	 Start-iTopCron

	 .Notes
	 2020-04-01: added parameter Environment (optional)
	#>
		param(
			[iTopEnvironment] $Environment
		)

		if($Script:iTopEnvironments.PSObject.Properties.Name -notcontains $Environment) {
			throw "iTop module: no configuration for environment '$($Environment)'"
		}
		
		$EnvSettings = $Script:iTopEnvironments."$Environment"

        $CLIArgs = "" +
			" --auth_user=$($EnvSettings.Cron.User)" +
			" --auth_pwd=$($EnvSettings.Cron.Password)" +
			" --verbose=1"

        If($EnvSettings.Variables.Environment -ne $null) {
            $CLIArgs += " --switch_env=$($EnvSettings.Variables.Environment)"
        }

		# c:\xampp\php\php.exe c:\xampp\htdocs\itop\web\webservices\cron.php --auth_user=admin --auth_pwd=admin --verbose=1
		$Expression = "$($EnvSettings.PHP.Path) $($EnvSettings.App.Path)\webservices\cron.php" + $CLIArgs
        Write-Host $Expression
		Invoke-Expression $Expression
		
	}
	
#endregion

#region iTop REST/JSON API

    function Invoke-iTopRestMethod {
	<#
	 .Synopsis
	 Supporting function to make POST requests to the iTop API

	 .Description
	 Supporting function to make POST requests to the iTop API
	 
	 .Parameter Environment
	 Environment name
	 
	 .Parameter JsonData
     JSON Data
     	 
	 .Example
	 Invoke-iTopRestMethod -Environment "name" -JsonData $JSONData

	#>
        param(
			[Parameter(Mandatory=$true)][Hashtable] $JsonData,
            [iTopEnvironment] $Environment
        )

  
		    if($Script:iTopEnvironments.PSObject.Properties.Name -notcontains $Environment) {
			    throw "iTop module: no configuration for environment '$($Environment)'"
		    }
		
		    $EnvSettings = $Script:iTopEnvironments."$Environment"

		    $ArgData = @{
			    "version" = $EnvSettings.API.Version;
			    "auth_user" = $EnvSettings.API.User;
			    "auth_pwd" = $EnvSettings.API.Password;
			    "json_data" = (ConvertTo-JSON $JsonData -Depth 10)
		    }
		
		    $SecurePassword = ConvertTo-SecureString $EnvSettings.API.Password -AsPlainText -Force
		    $Credential = New-Object System.Management.Automation.PSCredential($EnvSettings.API.User, $SecurePassword)

            Switch -Regex ($EnvSettings.API.Url) {
                "login_mode=url" {
                    $Content = Invoke-RestMethod $EnvSettings.API.Url -Method "POST" -Body $ArgData -Headers @{"Cache-Control"="no-cache"}
                    break
                }
                "login_mode=basic" {
                    # Only in PowerShell 6 there seems to be support for -Authentication Basic
                    # For Basic Authentication:
                    $Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $EnvSettings.API.User,$EnvSettings.API.Password)))
                    $Content = Invoke-RestMethod $EnvSettings.API.Url -Method "POST" -Body $ArgData -Headers @{"Cache-Control"="no-cache";"Authorization"=("Basic {0}" -f $Base64AuthInfo)}
                    break
                }
                default {
                    throw "Currently only basic and URL login modes are supported. Please add the login_mode parameter to the URL $($EnvSettings.API.Url)"
                }
            }

            return $Content

    }


	function Get-iTopObject {
	<#
	 .Synopsis
	 Uses iTop REST/JSON API to get object (core/get)

	 .Description
	 Uses iTop REST/JSON API to get object (core/get)
	 
	 .Parameter Class
	 Name of class. Can be ommitted if parameter "key" is a valid OQL-query.
	 
	 .Parameter Environment
	 Environment name
	 
	 .Parameter Key
	 ID of iTop object or OQL-query
	 
	 .Parameter Limit
	 Maximum umber of objects to return. Defaults to 0 (unlimited). From iTop 2.6.1 onwards.
	 
	 .Parameter Page
	 Number of pages to return. Defaults to 1. From iTop 2.6.1 onwards.
	 
	 .Parameter OutputFields
	 Comma separated list of attributes; or * (return all attributes for specified class); or *+ (all attributes - might be more for subclasses)
	 
	 .Example
	 Get-iTopObject -key 123 -class "UserRequest"
	 
	 .Example
	 Get-iTopObject -key "SELECT UserRequest" -OutputFields "id,ref,title"

	 .Notes
	 2020-04-01: added parameter Environment (optional)
	#>
		param(
			[Parameter(Mandatory=$true)][String] $Key,
			[Parameter(Mandatory=$False)][String] $Class = "",
			[Parameter(Mandatory=$False)][String] $OutputFields = "",
			[Parameter(Mandatory=$False)][Int64] $Limit = 0,
			[Parameter(Mandatory=$False)][Int64] $Page = 1,
			[iTopEnvironment] $Environment
		)
		
		if($Script:iTopEnvironments.PSObject.Properties.Name -notcontains $Environment) {
			throw "iTop module: no configuration for environment '$($Environment)'"
		}
		
		$EnvSettings = $Script:iTopEnvironments."$Environment"
		
		# Shortcut, if possible.
		if($Class -eq "") {
		
			$matched = ($Key -match 'SELECT (.*?)( |$)');
			
			if($matched -eq $true) {
				$Class = $matches[1]
			}
			else {
				throw "Specify parameter 'class' if parameter 'key' is not a valid OQL-query"
			}
		
		}
		
		# Output fields
		if($OutputFields -eq "") {
			$OutputFields = $EnvSettings.API.Output_Fields;
		}
			
			
		$JsonData = @{
			"operation"='core/get';
			"key"=$Key;
			"class"=$Class;
			"output_fields"=$OutputFields;
			"limit"=$Limit;
			"page"=$Page
		};
		
		$Content = Invoke-iTopRestMethod -Environment $Environment -JsonData $JsonData

	
		# iTop API did not return an error
		If($Content.code -eq $null) {
            throw "iTop API did not return expected data: $($Content)"
        }
        ElseIf($Content.code -eq 0) {
	
			[Array]$Objects = @()
		
			if($Content.objects -ne $Null) {
				$Content.objects | Get-Member -MemberType NoteProperty | ForEach-Object {
					# Gets the properties for each object
					$Object = ($Content.objects | Select-Object -ExpandProperty $_.Name)
				
					# Cast 'fields' to System.Collections.Hashtable 
					$RecastedFields = [System.Collections.Hashtable]@{};
				
					$Object.fields | Get-Member -MemberType NoteProperty | ForEach-Object {
						$RecastedFields."$($_.Name)" = $Object.fields."$($_.Name)"
					}
				
					$Object.fields = $RecastedFields
				
					$Objects += $Object
				}
			}

			return ,$Objects
		
		}
		# iTop API did return an error
		else {
			throw "iTop API returned an error: $($Content.code) - $($Content.message)"
		}
		
	}

	function New-iTopObject {
	<#
	 .Synopsis
	 Uses iTop REST/JSON API to create object (core/create)

	 .Description
	 Uses iTop REST/JSON API to create object (core/create)
	 
	 .Parameter Class
	 Name of class.
	 
	 .Parameter Environment
	 Environment name
	 
	 .Parameter Fields
	 HashTable of fields
	 
	 .Parameter OutputFields
	 Comma separated list of attributes; or * (return all attributes for specified class); or *+ (all attributes - might be more for subclasses)
	 	 
	 .Example
	 New-iTopObject -class "UserRequest" -Fields @{'title'='something', 'description'='some description', 'caller_id'="SELECT Organization WHERE name = 'demo'", 'org_id'=1} -OutputFields "*"

	 .Notes
	 2020-04-01: added parameter Environment (optional)
	#>
		param(
			[Parameter(Mandatory=$true)][String] $Class = "",
			[Parameter(Mandatory=$true)][HashTable] $Fields = $Null,
			[Parameter(Mandatory=$False)][String] $OutputFields = "",
			[Parameter(Mandatory=$False)][String] $Comment = "",
			[iTopEnvironment] $Environment
		)
		
		if($Script:iTopEnvironments.PSObject.Properties.Name -notcontains $Environment) {
			throw "iTop module: no configuration for environment '$($Environment)'"
		}
		
		$EnvSettings = $Script:iTopEnvironments."$Environment"
		
		# Fields
		if($Fields.keys.count -lt 1) {
			throw "Specify fields for object"
		}
		
		# Output fields
		if($OutputFields -eq "") {
			$OutputFields = $EnvSettings.API.Output_Fields
		}
		
		# Comment
		if($Comment -eq "") {
			$Comment = $EnvSettings.API.Comment
		}
			
		$JsonData = @{
			"operation"='core/create';
			"class"=$Class;
			'fields'=$Fields;
			"output_fields"=$OutputFields;
			'comment'=$Comment
		};
		
		$Content = Invoke-iTopRestMethod -Environment $Environment -JsonData $JsonData
	
		
		# iTop API did not return an error
		If($Content.code -eq $null) {
            throw "iTop API did not return expected data: $($Content)"
        }
        ElseIf($Content.code -eq 0) {
		
			[Array]$Objects = @()
			
			if($Content.objects -ne $Null) {
				$Content.objects | Get-Member -MemberType NoteProperty | ForEach-Object {
					# Gets the properties for each object
					$Object = ($Content.objects | Select-Object -ExpandProperty $_.Name)
					
					# Cast 'fields' to System.Collections.Hashtable 
					$RecastedFields = [System.Collections.Hashtable]@{};
					
					$Object.fields | Get-Member -MemberType NoteProperty | ForEach-Object {
						$RecastedFields."$($_.Name)" = $Object.fields."$($_.Name)"
					}
					
					$Object.fields = $RecastedFields
					
					$Objects += $Object
				}
			}

			return ,$Objects
			
		}
		# iTop API did return an error
		else {
			throw "iTop API returned an error: $($Content.code) - $($Content.message)"
		}
		 
		
	}
	
	
	function Set-iTopObject {
	<#
	 .Synopsis
	 Uses iTop REST/JSON API to update object (core/update)

	 .Description
	 Uses iTop REST/JSON API to update object (core/update)
	
	 .Parameter Batch
	 Boolean, defaults to $false. If $true: allows to update multiple objects at once.
	 Note: this launches multiple HTTP requests, since iTop only supports updating one iTop object at a time.
	 If an error occurs, any further updating is halted.
	 
	 .Parameter Class
	 Name of class. Can be ommitted if parameter "key" is a valid OQL-query.
	 
	 .Parameter Environment
	 Environment name
	 
	 .Parameter Fields
	 HashTable of fields
	 
	 .Parameter Key
	 ID of iTop object or OQL-query
	 	 
	 .Parameter OutputFields
	 Comma separated list of attributes; or * (return all attributes for specified class); or *+ (all attributes - might be more for subclasses)
	 	 
	 .Example
	 Set-iTopObject -Key 1 -Class "UserRequest" -Fields @{'title'='something', 'description'='some description', 'caller_id'="SELECT Organization WHERE name = 'demo'", 'org_id'=1} -OutputFields "*"

	 .Notes
	 2020-04-01: added parameter Environment (optional)
	 2020-05-14: added parameter Batch (optional) - boolean to allow batch updates through PS1.
	#>
		param(
			[Parameter(Mandatory=$true)][String] $Key,
			[Parameter(Mandatory=$False)][String] $Class = "",
			[Parameter(Mandatory=$true)][HashTable] $Fields = $Null,
			[Parameter(Mandatory=$False)][String] $OutputFields = "",
			[Parameter(Mandatory=$False)][String] $Comment = "",
			[Parameter(Mandatory=$False)][Boolean] $Batch = $False,
			[iTopEnvironment] $Environment
		)
		
		if($Script:iTopEnvironments.PSObject.Properties.Name -notcontains $Environment) {
			throw "iTop module: no configuration for environment '$($Environment)'"
		}
		
		$EnvSettings = $Script:iTopEnvironments."$Environment"
		
		# Shortcut, if possible.
		if($Class -eq "") {
		
			$matched = ($Key -match 'SELECT (.*?)( |$)');
			
			if($matched -eq $true) {
				$Class = $matches[1]
			}
			else {
				throw "Specify parameter 'class' if parameter 'key' is not a valid OQL-query"
			}
		
		}
		
		# Fields
		if($Fields.keys.count -lt 1) {
			throw "Specify fields for object"
		}
		
		# Output fields
		if($OutputFields -eq "") {
			$OutputFields = $EnvSettings.API.Output_Fields
		}
		
		# Comment
		if($Comment -eq "") {
			$Comment = $EnvSettings.API.Comment
		}	
		
		# Batch (must be after "key"/"class" check)
		if($Batch -eq $True) {
			
			$Objects = Get-iTopObject -Environment $Environment -Key $Key -Class $Class
			$Objects | ForEach-Object {
				Set-iTopObject -environment $Environment -key "SELECT $($_.Class) WHERE id = $($_.Key)" -fields $Fields -outputFields $OutputFields -comment $Comment
			}
			
			Return
			
		}
		
		$JsonData = @{
			"operation"='core/update';
			"key"=$Key;
			"class"=$Class;
			'fields'=$Fields;
			"output_fields"=$OutputFields;
			'comment'=$Comment
		};
		
		$Content = Invoke-iTopRestMethod -Environment $Environment -JsonData $JsonData

		# Valid HTTP response
		
		# iTop API did not return an error
		If($Content.code -eq $null) {
            throw "iTop API did not return expected data: $($Content)"
        }
        ElseIf($Content.code -eq 0) {
		
			[Array]$Objects = @()
			
			if($Content.objects -ne $Null) {
				$Content.objects | Get-Member -MemberType NoteProperty | ForEach-Object {
					# Gets the properties for each object
					$Object = ($Content.objects | Select-Object -ExpandProperty $_.Name)
					
					# Cast 'fields' to System.Collections.Hashtable 
					$RecastedFields = [System.Collections.Hashtable]@{};
					
					$Object.fields | Get-Member -MemberType NoteProperty | ForEach-Object {
						$RecastedFields."$($_.Name)" = $Object.fields."$($_.Name)"
					}
					
					$Object.fields = $RecastedFields
					
					$Objects += $Object
				}
			}

			return ,$Objects
			
		}
		# iTop API did return an error
		elseif($Content.code -gt 0) {
			throw "iTop API returned an error: $($Content.code) - $($Content.message)"
		}
		 
		
	}
	
	function Remove-iTopObject {
	<#
	 .Synopsis
	 Uses iTop REST/JSON API to delete object (core/delete)

	 .Description
	 Uses iTop REST/JSON API to delete object (core/delete)
	 Warning: might delete related objects automatically (just as a normal iTop delete operation would do).
	 
	 .Parameter Batch
	 Boolean, defaults to $false. If $true: allows to update multiple objects at once.
	 Note: this launches multiple HTTP requests, since iTop only supports updating one iTop object at a time.
	 If an error occurs, any further updating is halted.
	 
	 .Parameter Class
	 Name of class. Can be ommitted if parameter "key" is a valid OQL-query.
	 	 
	 .Parameter Environment
	 Environment name
	 
	 .Parameter Key
	 ID of iTop object or OQL-query
	 
	 .Example
	 Remove-iTopObject -key 1 -class "UserRequest"

	 .Notes
	 2020-04-01: added parameter Environment (optional)
	 2020-05-14: added parameter Batch (optional) - boolean to allow batch deleting through PS1.
	#>
		param(
			[Parameter(Mandatory=$true)][String] $Key,
			[Parameter(Mandatory=$False)][String] $Class = "",
			[Parameter(Mandatory=$False)][String] $Comment = "",
			[Parameter(Mandatory=$False)][Boolean] $Batch = $False,
			[iTopEnvironment] $Environment
		)
		
		if($Script:iTopEnvironments.PSObject.Properties.Name -notcontains $Environment) {
			throw "iTop module: no configuration for environment '$($Environment)'"
		}
		
		$EnvSettings = $Script:iTopEnvironments."$Environment"
		
		# Shortcut, if possible.
		if($Class -eq "") {
		
			$matched = ($Key -match 'SELECT (.*?)( |$)');
			
			if($matched -eq $true) {
				$Class = $matches[1]
			}
			else {
				throw "Specify parameter 'class' if parameter 'key' is not a valid OQL-query"
			}
		
		}
		
		# Comment
		if($Comment -eq "") {
			$Comment = $EnvSettings.API.Comment
		}	
		
		
		# Batch
		if($Batch -eq $True) {
			
			$Objects = Get-iTopObject -Environment $Environment -Key $Key -Class $Class
			$Objects | ForEach-Object {
				Remove-iTopObject -environment $Environment -key "SELECT $($_.Class) WHERE id = $($_.Key)" -comment $Comment
			}
			
			Return
			
		}
		
		$JsonData = @{
			"operation"='core/delete';
			"key"=$Key;
			"class"=$Class;
			'comment'=$Comment
		};

		
		
		$Content = Invoke-iTopRestMethod -Environment $Environment -JsonData $JsonData
 
	
		
		# iTop API did not return an error
		If($Content.code -eq $null) {
            throw "iTop API did not return expected data: $($Content)"
        }
        ElseIf($Content.code -eq 0) {
		
			[Array]$Objects = @()
			
			if($Content.objects -ne $Null) {
				$Content.objects | Get-Member -MemberType NoteProperty | ForEach-Object {
					# Gets the properties for each object
					$Object = ($Content.objects | Select-Object -ExpandProperty $_.Name)
					
					# Cast 'fields' to System.Collections.Hashtable 
					$RecastedFields = [System.Collections.Hashtable]@{};
					
					$Object.fields | Get-Member -MemberType NoteProperty | ForEach-Object {
						$RecastedFields."$($_.Name)" = $Object.fields."$($_.Name)"
					}
					
					$Object.fields = $RecastedFields
					
					$Objects += $Object
				}
			}

			return ,$Objects
			
		}
		# iTop API did return an error
		else {
			throw "iTop API returned an error: $($Content.code) - $($Content.message)"
		}

	 }
	
#endregion


#region iTop Datamodel

	<#
	 .Synopsis
	 Gets iTop classes from datamodel-production.xml

	 .Description
	 Gets iTop classes from datamodel-production.xml
	 
	 .Parameter Class
	 Get specific class
	 
	 .Parameter Environment
	 Environment name
	 
	 .Parameter Recurse
	 Process child classes. Defaults to $true.
	 
	 .Example
	 Get-iTopClassesFromNode -recurse $False

	 .Notes
	 2019-08-16: added function
	 2020-04-01: added parameter Environment (optional)
	#>
	function Get-iTopClass() { 

		param(
			 [Parameter(Mandatory=$False)][Boolean]$Recurse = $true,
			 [Parameter(Mandatory=$False)][String]$Class = "",
			[iTopEnvironment] $Environment
		)

		if($Script:iTopEnvironments.PSObject.Properties.Name -notcontains $Environment) {
			throw "iTop module: no configuration for environment '$($Environment)'"
		}
		
		$EnvSettings = $Script:iTopEnvironments."$Environment"
		
		[Xml]$xmlDoc = Get-Content ($EnvSettings.App.Path + "\data\datamodel-production.xml")
		return (Get-iTopClassFromNode -Recurse $Recurse -XmlNode $xmlDoc.itop_design.classes.class -class $Class)

	}

	<#
	 .Synopsis
	 Gets iTop classes from XML Node. Avoid using this, it's meant as a sub function.

	 .Description
	 Gets iTop classes from XML Node. Avoid using this, it's meant as a sub function.
	 
	 .Parameter Class
	 Get specific class
	 
	 .Parameter Recurse
	 Process child classes. Defaults to $true.
	 
	 .Parameter XmlNode
	 XML-node to process
	 
	 .Example
	 Get-iTopClassesFromNode -xmlNode $xmlNode -recurse $False

	 .Notes
	 2019-08-16: added function
	 2020-04-01: added parameter Environment (optional)
	#>
	function Get-iTopClassFromNode() { 

		param(
			 [Parameter(Mandatory=$true)][System.Array]$xmlNode,
			 [Parameter(Mandatory=$False)][Boolean]$Recurse = $true,
			 [Parameter(Mandatory=$False)][String]$Class = ""
		)
		
		[System.Collections.ArrayList]$Results = @()

		# For each class
		$xmlNode | ForEach-Object {

			if($Class -eq "" -or $_.id -eq $Class) {
				$Results += ($_ | Select-Object -Property id, _created_in, _altered_in, _alteration, parent, properties, fields, presentation)
			}

			if($_.class) {
				$SubResults = Get-iTopClassFromNode -xmlNode $_.class -recurse $Recurse -class $Class
				$Results = $Results + $SubResults
			}

		}
		
		return $Results | Sort-Object Id

	}

#endregion
