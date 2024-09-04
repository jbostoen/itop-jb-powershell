Using module iTop.Environments

#region Functions which can be used when iTop is installed locally.

	<#
	 .Synopsis
	 Installs iTop unattended.

	 .Description
	 Installs iTop unattended.
	 
	 .Parameter Environment
	 Environment name
			
	 .Parameter Clean
	 Switch. Installs clean environment. Warning: drops database!

	 .Parameter Force
	 Switch. Forces removal of .maintenance and .readonly files if present (which block new setup executions), unsets read-only flag of configuration file.
	 
	 .Example
	 Install-iTopUnattended

	#>
	function Install-iTopUnattended { 

		param(
			[Parameter(Mandatory=$True)][ValidateSet([iTopEnvironment])][string] $Environment,
			[Switch] $Clean,
            [Switch] $Force
		)
		
		$EnvSettings = Get-iTopEnvironment -Environment $Environment
		
		$InstallScript = $EnvSettings.App.UnattendedInstall.Script
        $UpgradeXML = $EnvSettings.App.UnattendedInstall.UpgradeXML
		$InstallXML = $EnvSettings.App.UnattendedInstall.InstallXML
		$PhpExe = $EnvSettings.PHP.Path
		
		If((Test-Path -Path $InstallScript) -eq $False) {
			throw "Unattended install script not found: $($InstallScript). Download the script from a Combodo source (iTop Wiki or GitHub), or specify a correct location."
		}
		If($Clean.IsPresent -eq $false -and (Test-Path -Path $UpgradeXML) -eq $False) {
			throw "Unattended upgrade install XML not found: $($UpgradeXML). Specify correct location"
		}
		If($Clean.IsPresent -eq $true -and $null -ne $InstallXML -and (Test-Path -Path $InstallXML) -eq $False) {
			throw "Unattended clean install XML not found: $($InstallXML). Specify correct location"
		}
		If((Test-Path -Path $PhpExe) -eq $False) {
			throw "PHP.exe not found: $($PhpExe). Specify correct location"
		}
		
		
		
		# PHP.exe: require statements etc relate to current working directory. 
		# Need to temporarily change this!
		$OriginalDir = (Get-Item -Path ".\").FullName
		$ScriptDir = (Get-Item -Path $InstallScript).Directory.FullName
		
		Set-Location -Path $ScriptDir
		

        If($Force.IsPresent) {

			# Unblock iTop setup.
			Unblock-iTopSetup -Environment $Environment

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
		
		Set-Location -Path $OriginalDir
		
		Write-Host ""
		Write-Host "$('*' * 25)"
		Write-Host "Ran unattended installation. See above for details."
		Write-Host "Finish: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
		

	}


	function Unblock-iTopSetup {
	<#
	 .Synopsis
			Unblocks the iTop setup.

	 .Description
			Unblocks the iTop setup: 
			1) Makes iTop configuration file writable.
			2) Deletes .readonly and .maintenance files.

	 .Parameter Environment
	 Environment name.

	 .Example
	 Unblock-iTopSetup

	#>   
		param(
			[Parameter(Mandatory=$True)][ValidateSet([iTopEnvironment])][string] $Environment
		)
		
		$EnvSettings = Get-iTopEnvironment -Environment $Environment
		
	

		If((Test-Path -Path $EnvSettings.App.ConfigFile) -eq $True) {
			Get-Item -Path $EnvSettings.App.ConfigFile | Set-ItemProperty -Name IsReadOnly -Value $False
			Write-Host "Unsetting the read-only flag of the iTop configuration file ($($EnvSettings.App.ConfigFile))"
		}
		Else {
			Write-Warning "iTop configuration file not found: ($($EnvSettings.App.ConfigFile))"
		}
		
			
		$FileReadOnly = "$($EnvSettings.App.Path)\data\.readonly"
		$FileMaintenance = "$($EnvSettings.App.Path)\data\.maintenance"
		If((Test-Path -Path $FileReadOnly) -eq $true) {
			Remove-Item -Path $FileReadOnly
		}
		If((Test-Path -Path $FileMaintenance) -eq $true) {
			Remove-Item -Path $FileMaintenance
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

	#>
		param(
			[Boolean] $Confirm = $False,
			[Parameter(Mandatory=$True)][ValidateSet([iTopEnvironment])][string] $Environment
		)

		$EnvSettings = Get-iTopEnvironment -Environment $Environment
		
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
			Warning "Warning: performed simulation. Did NOT remove languages. Use -Confirm `$true"

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

	#>
		param(
			[Parameter(Mandatory=$true)][String] $Name,
			[Parameter(Mandatory=$False)][String] $Description = '',
			[Parameter(Mandatory=$False)][String] $Label = 'Category name: Some short name',
			[Parameter(Mandatory=$True)][ValidateSet([iTopEnvironment])][string] $Environment
		)

		$EnvSettings = Get-iTopEnvironment -Environment $Environment
		
		# Prevent issues with filename
		# This may be more limiting than what Combodo allows
		If( $Name -notmatch "^[A-z][A-z0-9\-]{1,}$" ) {
			throw "The extension's name preferably starts with an alphabetical character. Furthermore, it preferably consists of alphanumerical characters or hyphens (-) only."
		}

		$Extension_Source = "$PSScriptRoot\data\template"
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

	#>
		param(
			[Parameter(Mandatory=$true)][String] $From,
			[Parameter(Mandatory=$true)][String] $To,
			[Parameter(Mandatory=$True)][ValidateSet([iTopEnvironment])][string] $Environment
		
		)
		
		
		$EnvSettings = Get-iTopEnvironment -Environment $Environment
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

	#>
		param(
			[Parameter(Mandatory=$True)][ValidateSet([iTopEnvironment])][string] $Environment,
			[Parameter(Mandatory=$False)][String] $Folder = $null
		)
		
		$EnvSettings = Get-iTopEnvironment -Environment $Environment
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

			$_.Name -match "^(.*)\.(.*)\.(.*)$" | Out-Null
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

		# Update any MarkDown (.md) or Twig file
		$Files | Where-Object { $_.Name -like "*.md" -or $_.Name -like "*.twig" } | Foreach-Object {

			$Content = Get-Content $_.FullName
			$Content = $Content -Replace "Copyright \((C|c)\) (20[0-9]{2})((\-| \- )20[0-9]{2}).+?([A-Za-z0-9 \-]{1,})", "Copyright (c) `${2}-$($(Get-Date).ToString("yyyy")) `${5}"
			$Content = $Content -Replace "Copyright \((C|c)\) (2019|202[\d]) (.+|)?([A-Za-z0-9 \-]{1,})", "Copyright (c) `${2}-$($(Get-Date).ToString("yyyy")) `${3}" # Don't match if after the year a new year is specified

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

	#>
		param(
			[Parameter(Mandatory=$True)][ValidateSet([iTopEnvironment])][string] $Environment
		)

		$EnvSettings = Get-iTopEnvironment -Environment $Environment

        $CLIArgs = "" +
			" --auth_user=$($EnvSettings.Cron.User)" +
			" --auth_pwd=$($EnvSettings.Cron.Password)" +
			" --verbose=1"

        If($null -ne $EnvSettings.Variables.Environment) {
            $CLIArgs += " --switch_env=$($EnvSettings.Variables.Environment)"
        }

		# c:\xampp\php\php.exe c:\xampp\htdocs\itop\web\webservices\cron.php --auth_user=admin --auth_pwd=admin --verbose=1
		$Expression = "$($EnvSettings.PHP.Path) $($EnvSettings.App.Path)\webservices\cron.php" + $CLIArgs
        Write-Host $Expression
		Invoke-Expression $Expression
		
	}
	
#endregion



#region iTop Datamodel

	<#
	 .Synopsis
	 Gets iTop classes from datamodel-xxx.xml

	 .Description
	 Gets iTop classes from datamodel-xxx.xml
	 
	 .Parameter Class
	 Get specific class
	 
	 .Parameter Environment
	 Environment name
	 
	 .Parameter Recurse
	 Process child classes. Defaults to $true.
	 
	 .Example
	 Get-iTopClassesFromNode -recurse $False

	#>
	function Get-iTopClass() { 

		param(
			 [Parameter(Mandatory=$False)][Boolean]$Recurse = $true,
			 [Parameter(Mandatory=$False)][String]$Class = "",
			 [Parameter(Mandatory=$True)][ValidateSet([iTopEnvironment])][string] $Environment
		)

		$EnvSettings = Get-iTopEnvironment -Environment $Environment
		
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
