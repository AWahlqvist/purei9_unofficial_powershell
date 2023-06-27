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
