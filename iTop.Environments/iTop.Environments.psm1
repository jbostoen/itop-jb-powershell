
# Read configuration from JSON-file.
# Let's make it available in the entire scope of this module so it can easily be altered or used for different purposes.
$Script:iTopEnvironments = [PSCustomObject]@{}


If($PsISE) {

    # Workaround for PowerShell ISE
    $Environments = @()
    $Paths = @(
		# PowerShell 5.x
        "$($env:USERPROFILE)\OneDrive\Documents\WindowsPowerShell\Modules\iTop\environments", 
        "$($env:USERPROFILE)\OneDrive\Documents\WindowsPowerShell\Modules\iTop\environments", 
        "$($env:USERPROFILE)\Documents\WindowsPowerShell\Modules\iTop\environments",
		# PowerShell 7.x
        "$($env:USERPROFILE)\OneDrive\Documents\PowerShell\Modules\iTop\environments", 
        "$($env:USERPROFILE)\Documents\PowerShell\Modules\iTop\environments"
    )

}
else {

    $Paths = @(
        "$($PSScriptRoot)\environments"
    )

}


$Paths | ForEach-Object {

    $EnvironmentPath = $_

    if((Test-Path -Path $EnvironmentPath) -eq $true -And $Environments.Count -eq 0) {

        $Environments = Get-ChildItem -Path $EnvironmentPath -Include "*.json" -Recurse

		# Do not scan the other folders anymore.
        return

    }

}



if($Environments.Count -eq 0) {
        
    Write-Host "Warning: iTop module loaded, but no configuration of iTop environments found in:`n$($Paths -Join ",`n")" -ForegroundColor Yellow

}


function merge ($target, $source) {
    $source.psobject.Properties | ForEach-Object {
        if ($_.TypeNameOfValue -eq 'System.Management.Automation.PSCustomObject' -and $target."$($_.Name)" ) {
            merge $target."$($_.Name)" $_.Value
        }
        else {
            $target | Add-Member -MemberType $_.MemberType -Name $_.Name -Value $_.Value -Force
        }
    }
}

# Perform actions on several environments
$Environments | ForEach-Object {

	$EnvName = $_.Name -Replace ".json", ""

    # The environment name must be compatible with values in a PowerShell enum.
    # For that reason, unfortunately for example hyphens are not allowed.
    If($EnvName -notmatch "^[A-Za-z0-9_]{1,}$" -or $EnvName -eq "default") {
        Write-Error "Invalid name for JSON file: $($EnvName)"
    }

    $SettingsJSON = Get-Content -Path $_.FullName -Raw
    $UnmodifiedSettings = $SettingsJSON | ConvertFrom-Json
    
    # Inheritance
    If($UnmodifiedSettings.PSObject.Properties.Name -contains "InheritFrom") {

        $ParentJSON = Get-Content -Path "$($_.DirectoryName)\$($UnmodifiedSettings.InheritFrom).json"
        $ParentSettings = $ParentJSON | ConvertFrom-Json
        $FinalSettings = $ParentSettings

        merge $FinalSettings $UnmodifiedSettings

        $SettingsJSON = $FinalSettings | ConvertTo-Json


    }
    else {

        $FinalSettings = $UnmodifiedSettings

    }


    # Replace variables
    If($FinalSettings.Variables -ne $null) {


        # Replace variables
        $FinalSettings.Variables.PSObject.Properties | ForEach-Object {
        
            # Still needs to be converted to JSON, so escape backslash again
            $SettingsJSON = $SettingsJSON -Replace "%$($_.Name)%", $($_.Value -replace "\\", "\\")

        }

	    
	}

    
    Add-Member -InputObject $Script:iTopEnvironments -NotePropertyName $EnvName -NotePropertyValue ($SettingsJSON | ConvertFrom-Json)
    

    # For debugging only:
	# Write-Host "📃 Processed config file: $EnvName"

}



$Expression = "Add-Type -TypeDefinition @`"
    public enum iTopEnvironment {
$($Script:iTopEnvironments.PSObject.Properties.Name -Join ",`n" | Out-String)}
`"@"


try {

    Invoke-Expression $Expression

}  
catch {

    Write-Error "Invalid filename for one of the environment files. Avoid using reserved words in PowerShell such as 'default'. Hint: the filename of your JSON file does not need to match the iTop environment's name."
 

}

#region iTop environments


	function Set-iTopEnvironment {
	<#
	 .Synopsis
	 Create/edit an iTop environment in the current session.
	 
	 .Description
	 Create/edit an iTop environment in the current session.
	 
	 .Parameter Environment
	 Environment name.
	 
	 .Parameter Settings
	 Environment settings (object).
	 
	 .Parameter Persistent
	 Optional. Save settings to the configuration file (JSON). Defaults to $False.
	 
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
	 Get iTop environment settings in the current session.
	 
	 .Description
	 Get iTop environment settings in the current session.
	 
	 .Parameter Environment
	 Optional. If specified, only this environment will be returned.
	 
	#>
		param(
			[Parameter(Mandatory=$false)][iTopEnvironment]$Environment
		)
	 
		$Environments = $Script:iTopEnvironments
		
		# Return specific environment, not the whole list?
		If($null -ne $Environment) {

			$FoundEnvironment = $Environments."$Environment"
			
			if($null -eq $FoundEnvironment) {
				throw "Environment $($Environment) was not defined (case sensitive!)"
			}

			return $FoundEnvironment

		}
			
		
		return $Environments
	 
	}
	
#endregion iTop environments


