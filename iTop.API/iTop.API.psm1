# copyright   Copyright (C) 2019-2024 Jeffrey Bostoen
# license     https://www.gnu.org/licenses/gpl-3.0.en.html

Using module iTop.Environments

#region cmdlets to interact with the iTop REST/JSON API


function Invoke-iTopRestMethod {
	<#
	 .Synopsis
	 Supporting function to make POST requests to the iTop API.

	 .Description
	 Supporting function to make POST requests to the iTop API.
	 
	 .Parameter Environment
	 Environment name
	 
	 .Parameter JsonData
     JSON Data
     	 
	 .Example
	 Invoke-iTopRestMethod -Environment "name" -JsonData $JSONData

	#>
        param(
			[Parameter(Mandatory=$true)][Hashtable] $JsonData,
			[Parameter(Mandatory=$True)][ValidateSet([iTopEnvironment])][string] $Environment
        )

		    $EnvSettings = Get-iTopEnvironment -Environment $Environment
		
		    # $SecurePassword = ConvertTo-SecureString $EnvSettings.API.Password -AsPlainText -Force
		    # $Credential = New-Object System.Management.Automation.PSCredential($EnvSettings.API.User, $SecurePassword)

            Switch -Regex ($EnvSettings.API.Url) {
                "login_mode=url" {
					
					$ArgData = @{
						"version" = $EnvSettings.API.Version;
						"auth_user" = $EnvSettings.API.User;
						"auth_pwd" = $EnvSettings.API.Password;
						"json_data" = (ConvertTo-JSON $JsonData -Depth 10)
					}

                    $Content = Invoke-RestMethod $EnvSettings.API.Url -Method "POST" -Body $ArgData -Headers @{"Cache-Control"="no-cache"}
                    break
                }
                "login_mode=basic" {
					
					$ArgData = @{
						"version" = $EnvSettings.API.Version;
						"json_data" = (ConvertTo-JSON $JsonData -Depth 10)
					}

                    # Only in PowerShell 6 there seems to be support for -Authentication Basic
                    # For Basic Authentication:
                    $Base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $EnvSettings.API.User,$EnvSettings.API.Password)))
                    $Content = Invoke-RestMethod $EnvSettings.API.Url -Method "POST" -Body $ArgData -Headers @{
						"Cache-Control"="no-cache";
						"Authorization"=("Basic {0}" -f $Base64AuthInfo)
					}
                    break
                }
                "login_mode=token" {
					
					$ArgData = @{
						"version" = $EnvSettings.API.Version;
						"json_data" = (ConvertTo-JSON $JsonData -Depth 10);
					}

                    $Content = Invoke-RestMethod $EnvSettings.API.Url -Method "POST" -Body $ArgData -Headers @{
						"Cache-Control"="no-cache";
						"Auth-Token"=$EnvSettings.API.Token
					}
                    break
                }
                default {
                    throw "Currently only basic and URL login modes are supported. Please add the login_mode parameter to the URL $($EnvSettings.API.Url)"
                }
            }

            return $Content

    }

	function Test-iTopCredential {
		<#
		 .Synopsis
		 Uses iTop REST/JSON API to test the configured credentials. Works only for username/password, not for tokens.
	
		 .Description
		 Uses iTop REST/JSON API to test the configured credentials. Works only for username/password, not for tokens.
		 
		 .Parameter Environment
		 Environment name.
		 
		 .Example
		 Test-iTopCredential -Environment SomeEnv
		#>
			param(
				[Parameter(Mandatory=$True)][ValidateSet([iTopEnvironment])][string] $Environment
			)

			$EnvSettings = Get-iTopEnvironment -Environment $Environment
			
			$JsonData = @{
				"operation"='core/check_credentials';
				"user"=$EnvSettings.API.User;
				"password"=$EnvSettings.API.Password;
			};
			
			$Content = Invoke-iTopRestMethod -Environment $Environment -JsonData $JsonData
	
			# iTop API did not return an error
			If($null -eq $Content.code) {
				throw "iTop API did not return expected data: $($Content)"
			}
			ElseIf($Content.code -eq 0) {
				
				return $Content
			
			}
			# iTop API did return an error
			else {
				throw "iTop API returned an error: $($Content.code) - $($Content.message)"
			}
			
		}

	function Get-iTopObject {
	<#
	 .Synopsis
	 Uses iTop REST/JSON API to get object (core/get).

	 .Description
	 Uses iTop REST/JSON API to get object (core/get).
	 
	 .Parameter Class
	 Name of class. Can be ommitted if parameter "key" is a valid OQL-query.
	 
	 .Parameter Environment
	 Environment name.
	 
	 .Parameter Key
	 ID of iTop object or OQL-query.
	 
	 .Parameter Limit
	 Maximum umber of objects to return. Defaults to 0 (unlimited). From iTop 2.6.1 onwards.
	 
	 .Parameter Page
	 Number of pages to return. Defaults to 1. From iTop 2.6.1 onwards.
	 
	 .Parameter OutputFields
	 Comma separated list of attributes; or * (return all attributes for specified class); or *+ (all attributes - might be more for subclasses).
	 
	 .Example
	 Get-iTopObject -key 123 -class "UserRequest".
	 
	 .Example
	 Get-iTopObject -key "SELECT UserRequest" -OutputFields "id,ref,title".
	 
	#>
		param(
			[Parameter(Mandatory=$true)][String] $Key,
			[Parameter(Mandatory=$False)][String] $Class = "",
			[Parameter(Mandatory=$False)][String] $OutputFields = "",
			[Parameter(Mandatory=$False)][Int64] $Limit = 0,
			[Parameter(Mandatory=$False)][Int64] $Page = 1,
			[Parameter(Mandatory=$True)][ValidateSet([iTopEnvironment])][string] $Environment
		)
		
		$EnvSettings = Get-iTopEnvironment -Environment $Environment
		
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
		If($null -eq $Content.code) {
            throw "iTop API did not return expected data: $($Content)"
        }
        ElseIf($Content.code -eq 0) {
	
			[Array]$Objects = @()
		
			if($null -ne $Content.objects) {
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
	 Uses iTop REST/JSON API to create object (core/create).

	 .Description
	 Uses iTop REST/JSON API to create object (core/create).
	 
	 .Parameter Class
	 Name of class.
	 
	 .Parameter Environment
	 Environment name.
	 
	 .Parameter Fields
	 HashTable of fields.
	 
	 .Parameter OutputFields
	 Comma separated list of attributes; or * (return all attributes for specified class); or *+ (all attributes - might be more for subclasses).
	 	 
	 .Example
	 New-iTopObject -class "UserRequest" -Fields @{'title'='something', 'description'='some description', 'caller_id'="SELECT Organization WHERE name = 'demo'", 'org_id'=1} -OutputFields "*"

	#>
		param(
			[Parameter(Mandatory=$true)][String] $Class,
			[Parameter(Mandatory=$true)][HashTable] $Fields,
			[Parameter(Mandatory=$False)][String] $OutputFields = "",
			[Parameter(Mandatory=$False)][String] $Comment = "",
			[Parameter(Mandatory=$True)][ValidateSet([iTopEnvironment])][string] $Environment
		)
		
		$EnvSettings = Get-iTopEnvironment -Environment $Environment
		
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
		If($null -eq $Content.code) {
            throw "iTop API did not return expected data: $($Content)"
        }
        ElseIf($Content.code -eq 0) {
		
			[Array]$Objects = @()
			
			if($null -ne $Content.objects) {
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
	 Uses iTop REST/JSON API to update object (core/update).

	 .Description
	 Uses iTop REST/JSON API to update object (core/update).
	
	 .Parameter Batch
	 Boolean, defaults to $false. If $true: allows to update multiple objects at once.
	 Note: this launches multiple HTTP requests, since iTop only supports updating one iTop object at a time.
	 If an error occurs, any further updating is halted.
	 
	 .Parameter Class
	 Name of class. Can be ommitted if parameter "key" is a valid OQL-query.
	 
	 .Parameter Environment
	 Environment name.
	 
	 .Parameter Fields
	 HashTable of fields.
	 
	 .Parameter Key
	 ID of iTop object or OQL-query.
	 	 
	 .Parameter OutputFields
	 Comma separated list of attributes; or * (return all attributes for specified class); or *+ (all attributes - might be more for subclasses).
	 	 
	 .Example
	 Set-iTopObject -Key 1 -Class "UserRequest" -Fields @{'title'='something', 'description'='some description', 'caller_id'="SELECT Organization WHERE name = 'demo'", 'org_id'=1} -OutputFields "*"

	#>
		param(
			[Parameter(Mandatory=$true)][String] $Key,
			[Parameter(Mandatory=$False)][String] $Class = "",
			[Parameter(Mandatory=$true)][HashTable] $Fields = $Null,
			[Parameter(Mandatory=$False)][String] $OutputFields = "",
			[Parameter(Mandatory=$False)][String] $Comment = "",
			[Parameter(Mandatory=$False)][Boolean] $Batch = $False,
			[Parameter(Mandatory=$True)][ValidateSet([iTopEnvironment])][string] $Environment
		)
		
		$EnvSettings = Get-iTopEnvironment -Environment $Environment
		
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
		If($null -eq $Content.code) {
            throw "iTop API did not return expected data. Response: $($Content)"
        }
        ElseIf($Content.code -eq 0) {
		
			[Array]$Objects = @()
			
			if($null -ne $Content.objects) {
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
	 Uses iTop REST/JSON API to delete object (core/delete).

	 .Description
	 Uses iTop REST/JSON API to delete object (core/delete).
	 Warning: might delete related objects automatically (just as a normal iTop delete operation would do).
	 
	 .Parameter Batch
	 Boolean, defaults to $false. If $true: allows to update multiple objects at once.
	 Note: this launches multiple HTTP requests, since iTop only supports updating one iTop object at a time.
	 If an error occurs, any further updating is halted.
	 
	 .Parameter Class
	 Name of class. Can be ommitted if parameter "key" is a valid OQL-query.
	 	 
	 .Parameter Environment
	 Environment name.
	 
	 .Parameter Key
	 ID of iTop object or OQL-query.
	 
	 .Example
	 Remove-iTopObject -key 1 -class "UserRequest".

	#>
		param(
			[Parameter(Mandatory=$true)][String] $Key,
			[Parameter(Mandatory=$False)][String] $Class = "",
			[Parameter(Mandatory=$False)][String] $Comment = "",
			[Parameter(Mandatory=$False)][Boolean] $Batch = $False,
			[Parameter(Mandatory=$True)][ValidateSet([iTopEnvironment])][string] $Environment
		)
		
		$EnvSettings = Get-iTopEnvironment -Environment $Environment
		
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
		If($null -eq $Content.code) {
            throw "iTop API did not return expected data: $($Content)"
        }
        ElseIf($Content.code -eq 0) {
		
			[Array]$Objects = @()
			
			if($null -ne $Content.objects) {
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

