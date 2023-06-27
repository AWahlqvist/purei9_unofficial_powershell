function AddTlsSecurityProtocolSupport {
    <#
    .SYNOPSIS
    This helper function adds support for TLS protocol 1.1 and/or TLS 1.2

    .DESCRIPTION
    This helper function adds support for TLS protocol 1.1 and/or TLS 1.2

    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [Bool] $EnableTls11 = $true,
        [Parameter(Mandatory=$false)]
        [Bool] $EnableTls12 = $true
    )

    # Add support for TLS 1.1 and TLS 1.2
    if (-not [Net.ServicePointManager]::SecurityProtocol.HasFlag([Net.SecurityProtocolType]::Tls11) -AND $EnableTls11) {
        [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls11
    }

    if (-not [Net.ServicePointManager]::SecurityProtocol.HasFlag([Net.SecurityProtocolType]::Tls12) -AND $EnableTls12) {
        [Net.ServicePointManager]::SecurityProtocol += [Net.SecurityProtocolType]::Tls12
    }
}
function GetApiErrorResponse {
    <#
    .SYNOPSIS
    This helper function retrieves the returned error message from the API

    .DESCRIPTION
    This helper function retrieves the returned error message from the API

    Because of the way Invoke-RestMethod works, the error message would
    otherwise be "hidden" and only the http code would be returned

    #>

    [CmdletBinding()]
    [OutputType([String])]
    param(
        $ExceptionResponse
    )

    try {
        $errorResponseStream = $ExceptionResponse.GetResponseStream()
        $errorResponseStreamReader = New-Object System.IO.StreamReader($errorResponseStream)
        $errorResponseStreamReader.BaseStream.Position = 0
        $errorResponseStreamReader.DiscardBufferedData()
        $errorResponse = $errorResponseStreamReader.ReadToEnd()

        $errorResponse
    }
    catch {
        $ExceptionResponse
    }
}
function GetApiObjectEncoded {
    <#
    .SYNOPSIS
    This helper function converts the responses from the API
    so the encoding is correct

    .DESCRIPTION
    This helper function converts the responses from the API
    so the encoding is correct

    (Related to an encoding bug in Invoke-RestMethod)

    #>

    [CmdletBinding(DefaultParameterSetName='Response')]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Response')]
        [System.Object[]] $ApiObject,

        [Parameter(Mandatory = $true, ParameterSetName = 'Payload')]
        [System.Object[]] $RequestPayload
    )

    $utf8 = [System.Text.Encoding]::GetEncoding(65001)
    $iso88591 = [System.Text.Encoding]::GetEncoding(28591) #ISO 8859-1 ,Latin-1

    if ($ApiObject) {
        $SerializedObject = ConvertTo-Json -Depth 10 -InputObject $ApiObject -Compress
        $bytesArray = [System.Text.Encoding]::Convert($utf8, $iso88591, $utf8.GetBytes($SerializedObject))
    }
    else {
        $SerializedObject = ConvertTo-Json -Depth 10 -InputObject $RequestPayload -Compress
        $bytesArray = [System.Text.Encoding]::Convert($iso88591, $utf8, $utf8.GetBytes($SerializedObject))
    }

    # Write the first results to the pipline
    $EncodedJsonString = $utf8.GetString($bytesArray)

    $EncodedObject = ConvertFrom-Json -InputObject $EncodedJsonString
    Write-Output $EncodedObject
}
function GetApiRequestSplattingHash {
    <#
        .SYNOPSIS
        This helper function creates a hashtable containing the basic properties needed
        Electrolux Cloud API

        .DESCRIPTION
        This helper function creates a hashtable containing the basic properties needed
        Electrolux Cloud API
    #>

    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [String] $UriEnding,

        [Parameter(Mandatory = $false)]
        [ValidateSet(
            'Default',
            'Delete',
            'Get',
            'Head',
            'Merge',
            'Options',
            'Patch',
            'Post',
            'Put',
            'Trace'
        )]
        [String] $Method = 'Get'
    )

    $hashToReturn = @{
        Headers     = @{
            Authorization = ''
        }
        Uri         = 'https://api.ocp.electrolux.one' + $UriEnding
        ContentType = 'application/json'
        Method      = $Method
        ErrorAction = 'Stop'
        TimeoutSec  = 120
        Verbose     = $false
    }

    $hashToReturn
}
function InvokeApiRequest {
    <#
    .SYNOPSIS
    This helper function does the actual API call.

    .DESCRIPTION
    This helper function does the actual API call and authorizes the request

    #>

    [CmdletBinding(DefaultParameterSetName = 'NoRequestPayload')]
    param(
        [Parameter(Mandatory=$true)]
        [PSCredential] $Credential,

        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable] $RequestSplattingHash,

        [Parameter(Mandatory = $true, ParameterSetName = 'ObjectRequestPayload')]
        [System.Collections.Hashtable] $RequestPayload
    )

    begin {
        AddTlsSecurityProtocolSupport
    }

    process {
        if ($RequestPayload) {
            try {
                $encodedString = GetApiObjectEncoded -RequestPayload $RequestPayload
                $encodedPayload = ConvertTo-Json -Depth 10 -InputObject $encodedString
            }
            catch {
                throw "Failed to encode the request payload. The error was: $($_.Exception.Message)"
            }

            $RequestSplattingHash.Add('Body', $encodedPayload)
        }

        $setApiAuthorizationHeaderParams = @{
            Credential = $Credential
            RequestHash  = $RequestSplattingHash
        }

        SetApiAuthorizationHeader @setApiAuthorizationHeaderParams

        try {
            $response = Invoke-RestMethod @RequestSplattingHash
        }
        catch {
            $errorMessage = GetApiErrorResponse -ExceptionResponse $_.Exception.Response
            throw "API call failed! The error was: $($_.Exception.Message) $errorMessage"
        }

        $response
    }

    end { }
}
function SetApiAuthorizationHeader {
    <#
        .SYNOPSIS
        This helper function contains the logic for setting the authorization header

        .DESCRIPTION
        This helper function contains the logic for setting the authorization header
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCredential] $Credential,

        [Parameter(Mandatory=$true)]
        [System.Collections.Hashtable] $RequestHash
    )
    $xApiKey = '2AMqwEV5MqVhTKrRCyYfVF8gmKrd2rAmp7cUsfky'
    $clientId = 'ElxOneApp'
    $clientSecret = '8UKrsKD7jH9zvTV7rz5HeCLkit67Mmj68FvRVTlYygwJYy4dW6KF2cVLPKeWzUQUd6KJMtTifFf4NkDnjI7ZLdfnwcPtTSNtYvbP7OzEkmQD9IjhMOf5e1zeAQYtt2yN'

    if ($Script:AuthToken.Expires -le (Get-Date)) {
        Write-Verbose "Requesting access token..."

        $tokenExpires = (Get-Date).AddSeconds(600)
        
        $tokenRequestHash = GetApiRequestSplattingHash -UriEnding "/one-account-authorization/api/v1/token" -Method Post
        $tokenRequestHash.Headers.Remove('Authorization')
        $tokenRequestHash.Headers.Add('x-api-key', $xApiKey)


        $body = @{
            clientId = $clientId
            clientSecret = $clientSecret
            grantType = "client_credentials"
        } | ConvertTo-Json

        $clientAccessToken = Invoke-RestMethod @tokenRequestHash -Body $body
    
        $body = @{
            username = $Credential.UserName
            password = $Credential.GetNetworkCredential().Password
        } | ConvertTo-Json
        
        $tokenRequestHash = GetApiRequestSplattingHash -UriEnding "/one-account-authentication/api/v1/authenticate" -Method Post
        $tokenRequestHash.Headers.Authorization = "Bearer $($clientAccessToken.accessToken)"
        $tokenRequestHash.Headers.Add('x-api-key', $xApiKey)
    
        $userAccessToken = Invoke-RestMethod @tokenRequestHash -Body $body
        
        $body = @{
            clientId = $clientId
            idToken = $userAccessToken.idToken
            grantType = 'urn:ietf:params:oauth:grant-type:token-exchange'
        } | ConvertTo-Json

        $tokenRequestHash = GetApiRequestSplattingHash -UriEnding "/one-account-authorization/api/v1/token" -Method Post
        $tokenRequestHash.Headers.Add('Origin-Country-Code', $userAccessToken.countryCode)

        $userAccessToken = Invoke-RestMethod @tokenRequestHash -Body $body

        $Script:AuthToken = @{
            Header = "Bearer $($userAccessToken.accessToken)"
            Expires = $tokenExpires
        }

    }
    else {
        Write-Verbose "Reusing existing auth token..."
    }

    $RequestHash.Headers.Authorization = $Script:AuthToken.Header
    $RequestHash.Headers.Remove('x-api-key')
    $RequestHash.Headers.Add('x-api-key', $xApiKey)
}
function Get-Purei9VacuumMap {
    <#
        .SYNOPSIS
        Get maps associated with the specified credentials from the Electrolux cloud

        .DESCRIPTION
        Get maps associated with the specified credentials from the Electrolux cloud

        Also includes zones

        .PARAMETER Credential
        The credential to use to authenticate the request

        .PARAMETER RobotId
        The vaccuum robot id associated with the map. Can be omitted (the function
        will then fetch the robots assocaited with the account automatically)

        .PARAMETER RobotName
        The vaccuum robot name associated with the map. Can be omitted (the function
        will then fetch the robots assocaited with the account automatically)

        .EXAMPLE
        Get-Purei9VacuumMap -Credential $MyCredential

        Fetches maps associated with $MyCredential

        .EXAMPLE
        Get-Purei9VacuumMap -Credential $MyCredential -RobotId 912345678901234567890123

        Fetches maps associated with $MyCredential and robot with id 912345678901234567890123

        .EXAMPLE
        Get-Purei9VacuumMap -Credential $MyCredential -RobotName MyVacuumRobot

        Fetches maps associated with $MyCredential and robot with name MyVacuumRobot
    #>

    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory=$true)]
        [PSCredential] $Credential,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ById')]
        [Alias('applianceId')]
        [String[]] $RobotId,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByName')]
        [Alias('applianceName')]
        [String[]] $RobotName
    )

    begin { }

    process {
        if (-not $RobotId) {
            $vacuumRobots = Get-Purei9VacuumRobot -Credential $Credential

            if ($RobotName) {
                $vacuumRobots = Get-Purei9VacuumRobot -Credential $Credential | Where-Object { $_.applianceData.applianceName -in $RobotName }
            }

            $RobotId = $vacuumRobots.applianceId
        }

        foreach ($vacId in $RobotId) {
            $uriEnding = "/purei/api/v2/appliances/$vacId/interactive-maps"
            $requestHash = GetApiRequestSplattingHash -UriEnding $uriEnding
    
            $invokeApiRequestSplat = @{
                Credential = $Credential
                RequestSplattingHash = $requestHash
            }
    
            InvokeApiRequest @invokeApiRequestSplat
        }
    }

    end { }
}
function Get-Purei9VacuumRobot {
    <#
        .SYNOPSIS
        Get robots associated with the specified credentials from the Electrolux cloud

        .DESCRIPTION
        Get robots associated with the specified credentials from the Electrolux cloud

        .PARAMETER Credential
        The credential to use to authenticate the request

        .EXAMPLE
        Get-Purei9VacuumRobot -Credential $MyCredential

        Fetches robots associated with the credential $MyCredential
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCredential] $Credential
    )

    begin { }

    process {
        $uriEnding = "/appliance/api/v2/appliances"
        $requestHash = GetApiRequestSplattingHash -UriEnding $uriEnding

        $invokeApiRequestSplat = @{
            Credential = $Credential
            RequestSplattingHash = $requestHash
        }
        $appliances = InvokeApiRequest @invokeApiRequestSplat

        foreach ($appliance in $appliances) {
            $uriEnding = $uriEnding + "/$($appliance.applianceId)/info"
            $requestHash = GetApiRequestSplattingHash -UriEnding $uriEnding
            
            $invokeApiRequestSplat = @{
                Credential = $Credential
                RequestSplattingHash = $requestHash
            }
            $applianceInfo = InvokeApiRequest @invokeApiRequestSplat
        
            $uriEnding = "/appliance/api/v2/appliances/$($appliance.applianceId)"
            $requestHash = GetApiRequestSplattingHash -UriEnding $uriEnding
            $invokeApiRequestSplat.RequestSplattingHash = $requestHash
            $applianceDetails = InvokeApiRequest @invokeApiRequestSplat
            
            $batteryLevel = switch ($applianceDetails.properties.reported.batteryStatus) {
                1 { "Dead" }
                2 { "CriticalLow" }
                3 { "Low" }
                4 { "Medium" }
                5 { "Normal" }
                6 { "High" }
                Default { "Unknown" }
            }

            $powerMode = switch ($applianceDetails.properties.reported.powerMode) {
                1 { "Low" }
                2 { "Medium/Smart" }
                3 { "High" }
                Default { "Unknown" }
            }

            $robotStatus = switch ($applianceDetails.properties.reported.robotStatus) {
                 1 { "Cleaning" }
                 2 { "Paused_Cleaning" }
                 3 { "Spot_Cleaning" }
                 4 { "Paused_Spot_Cleaning" }
                 5 { "Return" }
                 6 { "Paused_Return" }
                 7 { "Return_for_Pitstop" }
                 8 { "Paused_Return_for_Pitstop" }
                 9 { "Charging" }
                10 { "Sleeping" }
                11 { "Error" }
                12 { "Pitstop" }
                13 { "Manual_Steering" }
                14 { "Firmware_Upgrade" }
                Default { "Unknown" }
            }

            if ($applianceInfo.deviceType -eq 'ROBOTIC_VACUUM_CLEANER') {
                $appliance | Add-Member -MemberType NoteProperty -Name BatteryLevel -Value $batteryLevel
                $appliance | Add-Member -MemberType NoteProperty -Name RobotStatus -Value $robotStatus
                $appliance | Add-Member -MemberType NoteProperty -Name DustbinStatus -Value $applianceDetails.properties.reported.dustbinStatus
                $appliance | Add-Member -MemberType NoteProperty -Name PowerMode -Value $powerMode
                $appliance | Add-Member -MemberType NoteProperty -Name info -Value $applianceInfo
                $appliance | Add-Member -MemberType NoteProperty -Name details -Value $applianceDetails
                $appliance
            }
        }
    }

    end { }
}
function Get-Purei9VacuumRobotSession {
    <#
        .SYNOPSIS
        Gets cleaning sessions associated with the specified robot from the Electrolux cloud

        .DESCRIPTION
        Gets cleaning sessions associated with the specified robot from the Electrolux cloud

        .PARAMETER Credential
        The credential to use to authenticate the request

        .PARAMETER RobotId
        The vaccuum robot id associated with the cleaning sessions. Can be omitted if only one robot 
        is associated with the account (the function will then fetch the robot id automatically)

        .PARAMETER RobotName
        The vaccuum robot name associated with the cleaning sessions. Can be omitted if only one robot 
        is associated with the account (the function will then fetch the robot name automatically)

        .EXAMPLE
        Get-Purei9VacuumRobotSession -RobotName MrDusty -Credential $MyCredential

        Fetches the cleaning session history associated with the credential $MyCredential and the robot MrDusty
    #>

    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory=$true)]
        [PSCredential] $Credential,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ById')]
        [Alias('applianceId')]
        [String[]] $RobotId,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByName')]
        [Alias('applianceName')]
        [String[]] $RobotName
    )

    begin { }

    process {
        if (-not $RobotId) {
            $vacuumRobots = Get-Purei9VacuumRobot -Credential $Credential

            if ($RobotName) {
                $vacuumRobots = Get-Purei9VacuumRobot -Credential $Credential | Where-Object { $_.applianceName -in $RobotName }
            }

            $RobotId = $vacuumRobots.applianceId
        }

        foreach ($vacId in $RobotId) {
            $uriEnding = "/purei/api/v2/appliances/$vacId/history"
            $requestHash = GetApiRequestSplattingHash -UriEnding $uriEnding
    
            $invokeApiRequestSplat = @{
                Credential = $Credential
                RequestSplattingHash = $requestHash
            }
    
            InvokeApiRequest @invokeApiRequestSplat
        }
    }

    end { }
}
function Get-Purei9VacuumZoneStatus {
    <#
        .SYNOPSIS
        Get zones associated with the credential/robot and when they were last cleaned

        .DESCRIPTION
        Get zones associated with the credential/robot and when they were last cleaned

        .PARAMETER Credential
        The credential to use to authenticate the request

        .PARAMETER RobotId
        The vaccuum robot id associated with the map. Can be omitted (the function
        will then fetch the robots associated with the account automatically)

        .PARAMETER RobotName
        The vaccuum robot name associated with the map. Can be omitted (the function
        will then fetch the robots associated with the account automatically)

        .EXAMPLE
        Get-Purei9VacuumMap -Credential $MyCredential

        Fetches maps associated with the $MyCredential

        .EXAMPLE
        Get-Purei9VacuumMap -Credential $MyCredential -RobotId 912345678901234567890123

        Fetches maps associated with the $MyCredential and robot with id 912345678901234567890123

        .EXAMPLE
        Get-Purei9VacuumMap -Credential $MyCredential -RobotName MyVacuumRobot

        Fetches maps associated with the $MyCredential and robot with name MyVacuumRobot
    #>

    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    param(
        [Parameter(Mandatory=$true)]
        [PSCredential] $Credential,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ById')]
        [Alias('applianceId')]
        [String[]] $RobotId,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByName')]
        [Alias('applianceName')]
        [String[]] $RobotName,

        [Parameter(Mandatory=$false)]
        [Int] $IncludeSessionsSinceDays = 30
    )

    begin { }

    process {
        $vacuumRobots = Get-Purei9VacuumRobot -Credential $Credential

        if (-not $RobotId) {

            if ($RobotName) {
                $vacuumRobots = $vacuumRobots | Where-Object { $_.applianceName -in $RobotName }
            }

            $Robots = $vacuumRobots
        }
        else {
            $Robots = $vacuumRobots | Where-Object { $_.applianceId -eq $RobotId }
        }

        foreach ($vac in $Robots) {
            $vacuumMaps = Get-Purei9VacuumMap -Credential $Credential -RobotId $vac.applianceId
            $vacuumSessions = Get-Purei9VacuumRobotSession -Credential $Credential -RobotId $vac.applianceId | Where-Object { $_.timestamp -ge (Get-Date).AddDays(-$IncludeSessionsSinceDays) }

            foreach ($vacuumMap in $vacuumMaps) {

                foreach ($zone in $vacuumMaps.zones) {
                    foreach ($vacuumSession in $vacuumSessions) {
                        $zoneCleanedThisSession = $vacuumSession.cleaningSession.zoneStatus | Where-Object { $_.id -eq $zone.id -and $_.status -eq 'finished' }

                        if ($zoneCleanedThisSession) {
                            $latestSession = $vacuumSession
                            break
                        }
                        else {
                            $latestSession = $null
                        }
                    }

                    if ($latestSession.cleaningSession.eventTime) {
                        try {
                            $latestSessionDateTime = Get-Date $latestSession.cleaningSession.eventTime
                        }
                        catch {
                            $latestSessionDateTime = $latestSession.cleaningSession.eventTime
                            Write-Warning "Failed to parse date $($latestSession.cleaningSession.eventTime)"
                        }
                    }
                    else {
                        $latestSessionDateTime = ""
                    }
    
                    [PSCustomObject] @{
                        RobotId = $vac.applianceId
                        RobotName = $vac.applianceData.applianceName
                        MapId = $vacuumMap.id
                        MapName = $vacuumMap.name
                        ZoneId = $zone.id
                        ZoneName = $zone.name
                        LastCleaned = $latestSessionDateTime
                    }
                }
            }
        }
    }

    end { }
}
function Resume-Purei9VacuumRobot {
    <#
        .SYNOPSIS
        Resumes a ongoing cleaning session

        .DESCRIPTION
        Resumes a ongoing cleaning session

        .PARAMETER Credential
        The credential to use to authenticate the request

        .EXAMPLE
        Resume-Purei9VacuumRobot -Credential $MyCredential -RobotName MyRobot

        Resumes the cleaning session for robot MyRobot and asks it to return to the charging base

        .EXAMPLE
        Resume-Purei9VacuumRobot -Credential $MyCredential -RobotId 912345678901234567890123

        Resumes the cleaning session for robot with id 912345678901234567890123 and asks it to return to the charging base
    #>

    [CmdletBinding(DefaultParameterSetName = 'ByRobotName')]
    param(
        [Parameter(Mandatory=$true)]
        [PSCredential] $Credential,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByRobotId')]
        [Alias('applianceId')]
        [String[]] $RobotId,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByRobotName')]
        [Alias('applianceName')]
        [String[]] $RobotName
    )

    begin { }

    process {
        if (-not $RobotId) {
            $vacuumRobots = Get-Purei9VacuumRobot -Credential $Credential

            if ($RobotName) {
                $vacuumRobots =  $vacuumRobots | Where-Object { $_.applianceName -eq $RobotName }
            }

            if ($vacuumRobots.Count -gt 1) {
                throw "Multiple robots detected, please specify robot using RobotId or a unique RobotName"
            }

            $RobotId = $vacuumRobots.applianceId
        }

        $uriEnding = "/appliance/api/v2/appliances/$RobotId/command"
        $requestHash = GetApiRequestSplattingHash -UriEnding $uriEnding -Method Put

        $body = @{
            CleaningCommand = 'Play'
        }

        $invokeApiRequestSplat = @{
            Credential = $Credential
            RequestSplattingHash = $requestHash
            RequestPayload = $body
        }

        InvokeApiRequest @invokeApiRequestSplat
    }

    end { }
}
function Start-Purei9VacuumRobot {
    <#
        .SYNOPSIS
        Starts a cleaning session with the specified robot

        .DESCRIPTION
        Starts a cleaning session with the specified robot

        The robot can be instructed to clean all reachable areas or the specified zone(s)

        .PARAMETER Credential
        The credential to use to authenticate the request

        .PARAMETER RobotId
        The vaccuum robot id associated with the map. Can be omitted (the function
        will then fetch the robots assocaited with the account automatically)

        .PARAMETER RobotName
        The vaccuum robot name associated with the map. Can be omitted (the function
        will then fetch the robots assocaited with the account automatically)

        .PARAMETER MapId
        The id of the map where the zone(s) you want to clean are located
        
        .PARAMETER MapName
        The name of the map where the zone(s) you want to clean are located

        .PARAMETER ZoneId
        The id(s) of the zone(s) you want to clean
        
        .PARAMETER ZoneName
        The name(s) of the zone(s) you want to clean

        .PARAMETER CleanEverywhere
        To clean everywhere the robot can reach, specify this switch

        .PARAMETER CleanAllZonesOrderedByNeed
        If you want to clean all defined zones in the order they need to be cleaned
        (based on when they were last cleaned), specify this switch

        .PARAMETER SkipCleaningIfCleanedWithinHours
        When specifying the CleanAllZonesOrderedByNeed-switch, you can also specify
        how long zones should be excluded since the last time they were cleaned.

        Useful if you for example want to trigger the vacuum cleaner each time everyone
        leaves, and allow it to stop whenever someone gets home. Using this switch, the
        vacuum will clean all zones on the map until finished (if triggered enough times
        or allowed to clean for long enough)

        .EXAMPLE
        Start-Purei9VacuumRobot -Credential $MyCredential -RobotName MyRobot -CleanEverywhere

        Instructs the vacuum robot "MyRobot" to clean all available areas

        .EXAMPLE
        Start-Purei9VacuumRobot -Credential $MyCredential -RobotName MyRobot -MapName MyMap -ZoneName Bathroom

        Instructs the vacuum robot "MyRobot" to clean the zone "Bathroom" in the map "MyMap"

        .EXAMPLE
        Start-Purei9VacuumRobot -Credential $MyCredential -RobotId 912345678901234567890123 -MapId 912345678901234567890123 -ZoneId 912345678901234567890123

        Instructs the vacuum robot with id "912345678901234567890123" to clean the zone with id "912345678901234567890123" in the map with id "912345678901234567890123"
    #>

    [CmdletBinding(DefaultParameterSetName = 'CleanEverywhereByRobotName')]
    param(
        [Parameter(Mandatory=$true)]
        [PSCredential] $Credential,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'InSpecificZoneById')]
        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CleanEverywhereByRobotId')]
        [Parameter(Mandatory=$false, ParameterSetName = 'CleanAllZonesOrderedByNeed')]
        [Alias('applianceId')]
        [String] $RobotId,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'InSpecificZoneByName')]
        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CleanEverywhereByRobotName')]
        [Parameter(Mandatory=$false, ParameterSetName = 'CleanAllZonesOrderedByNeed')]
        [Alias('applianceName')]
        [String] $RobotName,

        [Parameter(Mandatory=$true, ParameterSetName = 'InSpecificZoneById')]
        [Parameter(Mandatory=$false, ParameterSetName = 'CleanAllZonesOrderedByNeed')]
        [String] $MapId,

        [Parameter(Mandatory=$true, ParameterSetName = 'InSpecificZoneByName')]
        [Parameter(Mandatory=$false, ParameterSetName = 'CleanAllZonesOrderedByNeed')]
        [String] $MapName,

        [Parameter(Mandatory=$true, ParameterSetName = 'InSpecificZoneById')]
        [String[]] $ZoneId,

        [Parameter(Mandatory=$true, ParameterSetName = 'InSpecificZoneByName')]
        [String[]] $ZoneName,

        [Parameter(Mandatory=$true, ParameterSetName = 'CleanEverywhereByRobotId')]
        [Parameter(Mandatory=$true, ParameterSetName = 'CleanEverywhereByRobotName')]
        [Switch] $CleanEverywhere,

        [Parameter(Mandatory=$false, ParameterSetName = 'CleanAllZonesOrderedByNeed')]
        [Switch] $CleanAllZonesOrderedByNeed,

        [Parameter(Mandatory=$false, ParameterSetName = 'CleanAllZonesOrderedByNeed')]
        [Int] $SkipCleaningIfCleanedWithinHours = 16
    )

    begin { }

    process {
        if (-not $RobotId) {
            $vacuumRobots = Get-Purei9VacuumRobot -Credential $Credential

            if ($RobotName) {
                $vacuumRobots =  $vacuumRobots | Where-Object { $_.applianceName -eq $RobotName }
            }

            if ($vacuumRobots.Count -gt 1) {
                throw "Multiple robots detected, please specify robot using RobotId or a unique RobotName"
            }

            $RobotId = $vacuumRobots.applianceId
        }

        $uriEnding = "/appliance/api/v2/appliances/$RobotId/command"
        $requestHash = GetApiRequestSplattingHash -UriEnding $uriEnding -Method Put

        $invokeApiRequestSplat = @{
            Credential = $Credential
            RequestSplattingHash = $requestHash
        }

        if ($PSCmdlet.ParameterSetName -notin 'CleanEverywhereByRobotId', 'CleanEverywhereByRobotName') {
            if ($CleanAllZonesOrderedByNeed.IsPresent) {
                $zoneStatus = Get-Purei9VacuumZoneStatus -Credential $Credential -RobotId $RobotId
            }

            if (-not $MapId) {
                if ($CleanAllZonesOrderedByNeed.IsPresent) {
                    $vacuumMaps = $zoneStatus | Sort-Object MapId -Unique | Select-Object @{Name='Id';Expression={$_.MapId}}, @{Name='name';Expression={$_.MapName}}
                }
                else {
                    $vacuumMaps = Get-Purei9VacuumMap -Credential $Credential -RobotId $RobotId
                }
    
                if ($MapName) {
                    $vacuumMaps = $vacuumMaps | Where-Object { $_.name -eq $MapName }
                }

                if ($vacuumMaps.Count -gt 1) {
                    throw "Multiple maps detected, please specify which map you want to work with using MapId or a unique MapName"
                }
    
                $MapId = $vacuumMaps.id
            }
    
            if ($CleanAllZonesOrderedByNeed.IsPresent) {
                $ZoneId = ($zoneStatus |
                Where-Object { $_.LastCleaned -lt (Get-Date).AddHours(-$SkipCleaningIfCleanedWithinHours)} |
                Sort-Object LastCleaned).ZoneId

                if (-not $ZoneId) {
                    Write-Verbose "No zones need cleaning right now!"
                    return
                }
            }
            elseif (-not $ZoneId) {
    
                if ($ZoneName) {
                    $vacuumZones = $vacuumMaps.zones | Where-Object { $_.name -in $ZoneName }
                }
    
                $ZoneId = $vacuumZones.id
            }

            $zones = @()
            foreach ($zone in $ZoneId) {
                $zones += @{ ZoneId = $zone }
            }
    
            $body = @{
                CustomPlay = @{
                    PersistentMapId = $MapId
                    Zones = @(
                        $zones
                    )
                }
            }

            $invokeApiRequestSplat.RequestPayload = $body
        }
        else {
            $body = @{
                CleaningCommand = 'Play'
            }

            $invokeApiRequestSplat.RequestPayload = $body
        }

        InvokeApiRequest @invokeApiRequestSplat
    }

    end { }
}
function Stop-Purei9VacuumRobot {
    <#
        .SYNOPSIS
        Stops a ongoing cleaning session and ask the specified robot to return to the charging base

        .DESCRIPTION
        Stops a ongoing cleaning session and ask the specified robot to return to the charging base

        .PARAMETER Credential
        The credential to use to authenticate the request

        .EXAMPLE
        Stop-Purei9VacuumRobot -Credential $MyCredential -RobotName MyRobot

        Stops the cleaning session for robot MyRobot and asks it to return to the charging base

        .EXAMPLE
        Stop-Purei9VacuumRobot -Credential $MyCredential -RobotId 912345678901234567890123

        Stops the cleaning session for robot with id 912345678901234567890123 and asks it to return to the charging base
    #>

    [CmdletBinding(DefaultParameterSetName = 'ByRobotName')]
    param(
        [Parameter(Mandatory=$true)]
        [PSCredential] $Credential,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByRobotId')]
        [Alias('applianceId')]
        [String[]] $RobotId,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByRobotName')]
        [Alias('applianceName')]
        [String[]] $RobotName
    )

    begin { }

    process {
        if (-not $RobotId) {
            $vacuumRobots = Get-Purei9VacuumRobot -Credential $Credential

            if ($RobotName) {
                $vacuumRobots =  $vacuumRobots | Where-Object { $_.applianceName -eq $RobotName }
            }

            if ($vacuumRobots.Count -gt 1) {
                throw "Multiple robots detected, please specify robot using RobotId or a unique RobotName"
            }

            $RobotId = $vacuumRobots.applianceId
        }

        $uriEnding = "/appliance/api/v2/appliances/$RobotId/command"
        $requestHash = GetApiRequestSplattingHash -UriEnding $uriEnding -Method Put

        $body = @{
            CleaningCommand = 'Home'
        }

        $invokeApiRequestSplat = @{
            Credential = $Credential
            RequestSplattingHash = $requestHash
            RequestPayload = $body
        }

        InvokeApiRequest @invokeApiRequestSplat
    }

    end { }
}
function Suspend-Purei9VacuumRobot {
    <#
        .SYNOPSIS
        Pauses a ongoing cleaning session

        .DESCRIPTION
        Pauses a ongoing cleaning session

        .PARAMETER Credential
        The credential to use to authenticate the request

        .EXAMPLE
        Suspend-Purei9VacuumRobot -Credential $MyCredential -RobotName MyRobot

        Pauses the cleaning session for robot MyRobot and asks it to return to the charging base

        .EXAMPLE
        Suspend-Purei9VacuumRobot -Credential $MyCredential -RobotId 912345678901234567890123

        Pauses the cleaning session for robot with id 912345678901234567890123 and asks it to return to the charging base
    #>

    [CmdletBinding(DefaultParameterSetName = 'ByRobotName')]
    param(
        [Parameter(Mandatory=$true)]
        [PSCredential] $Credential,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByRobotId')]
        [Alias('applianceId')]
        [String[]] $RobotId,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByRobotName')]
        [Alias('applianceName')]
        [String[]] $RobotName
    )

    begin { }

    process {
        if (-not $RobotId) {
            $vacuumRobots = Get-Purei9VacuumRobot -Credential $Credential

            if ($RobotName) {
                $vacuumRobots =  $vacuumRobots | Where-Object { $_.applianceName -eq $RobotName }
            }

            if ($vacuumRobots.Count -gt 1) {
                throw "Multiple robots detected, please specify robot using RobotId or a unique RobotName"
            }

            $RobotId = $vacuumRobots.applianceId
        }

        $uriEnding = "/appliance/api/v2/appliances/$RobotId/command"
        $requestHash = GetApiRequestSplattingHash -UriEnding $uriEnding -Method Put

        $body = @{
            CleaningCommand = 'Pause'
        }

        $invokeApiRequestSplat = @{
            Credential = $Credential
            RequestSplattingHash = $requestHash
            RequestPayload = $body
        }

        InvokeApiRequest @invokeApiRequestSplat
    }

    end { }
}
