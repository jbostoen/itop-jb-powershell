
# Examples


Execute `Get-Help Get-iTopobject` to get a full list and explanation of each parameter.

Mind that the structure is based on [iTop's REST/JSON API](https://www.itophub.io/wiki/page?id=latest%3Aadvancedtopics%3Arest_json).


Retrieving user requests of a certain person (with ID 1).
```
$tickets = Get-iTopObject -env "production" -key "SELECT UserRequest WHERE caller = 1"
```


Creating a new organization. This will give you access to the ID (key) created for this organization.
```
$ClientOrg = New-iTopObject -Environment "production" -Class "Organization" -Fields @{
	"name"="Demo Portal Org #1";
	"deliverymodel_id"=$DeliveryModel.key;
}

# Print ID of the newly created object
$ClientOrg.key

# Print fields
$ClientOrg.fields
```

Deleting an organization.
```
Remove-iTopObject -env "production" -key "SELECT Organization WHERE id = 1"
```


Updating an organization.
```
Set-iTopObject -env "production" -key "SELECT Organization WHERE id = 1" -Fields @{
	"name"="Demo 2"
}
```

By default, iTop will currently not allow to update/delete multiple objects at once.  
There must be one HTTP request per update/delete. To facilitate this, a `-Batch:$true` parameter exists.

Updating an organization for multiple persons.
```
Set-iTopObject -env "production" -key "SELECT Person WHERE org_id = 999" -Batch:$true -Fields @{
	"org_id"=1000
}
```


Concrete example: create user accounts for every active person with an e-mail address.  
```
# Retrieve all persons from the "personal" iTop environment
$persons = Get-iTopObject -env personal -key "SELECT Person AS p WHERE p.id NOT IN (SELECT Person AS p2 JOIN UserLocal AS ul ON ul.contactid = p2.id) AND p.status = 'active' AND p.email != ''"

# Create UserLocal account. 
# The login name is the e-mail address, the password is set randomly and never expires. 
# The user account is limited to the person's organization and receives 2 profiles (portal user, power portal user)
$persons | ForEach-Object {

	$f = $_.fields
	
	# Create a UserLocal object
	New-iTopObject -env personal -Class "UserLocal" -Fields @{
		"contactid"=$_.key;
		"login"=$f.email;
		"expiration"="never_expire";
		"password"=(new-guid);
		"profile_list"=@( @{"profileid"=2}, @{"profileid"=12} );
		"allowed_org_list"=@( @{"allowed_org_id"=$f.org_id}  );
	}

}
```

