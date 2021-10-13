function Start-Purei9VacuumRobot {
    <#
        .SYNOPSIS
        Starts a cleaning session with the specified robot

        .DESCRIPTION
        Starts a cleaning session with the specified robot

        The robot can be instructed to clean all reachable areas or the specified zone(s)

        .PARAMETER Credential
        The credential to use to authenticate the request

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

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'InSpecificZoneById')]
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CleanEverywhereByRobotId')]
        [Alias('pncId')]
        [String] $RobotId,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'InSpecificZoneByName')]
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'CleanEverywhereByRobotName')]
        [Alias('applianceName')]
        [String] $RobotName,

        [Parameter(Mandatory=$true, ParameterSetName = 'InSpecificZoneById')]
        [String] $MapId,

        [Parameter(Mandatory=$true, ParameterSetName = 'InSpecificZoneByName')]
        [String] $MapName,

        [Parameter(Mandatory=$true, ParameterSetName = 'InSpecificZoneById')]
        [String[]] $ZoneId,

        [Parameter(Mandatory=$true, ParameterSetName = 'InSpecificZoneByName')]
        [String[]] $ZoneName,

        [Parameter(Mandatory=$true, ParameterSetName = 'CleanEverywhereByRobotId')]
        [Parameter(Mandatory=$true, ParameterSetName = 'CleanEverywhereByRobotName')]
        [Switch] $CleanEverywhere
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

            $RobotId = $vacuumRobots.pncId
        }

        $uriEnding = "/Appliances/$RobotId/Commands"
        $requestHash = GetApiRequestSplattingHash -UriEnding $uriEnding -Method Put

        $invokeApiRequestSplat = @{
            Credential = $Credential
            RequestSplattingHash = $requestHash
        }

        if ($PSCmdlet.ParameterSetName -notin 'CleanEverywhereByRobotId', 'CleanEverywhereByRobotName') {
            if (-not $MapId) {
                $vacuumMaps = Get-Purei9VacuumMap -Credential $Credential -RobotId $RobotId
    
                if ($MapName) {
                    $vacuumMaps = $vacuumMaps | Where-Object { $_.name -eq $MapName }
                }
    
                if ($vacuumMaps.Count -gt 1) {
                    throw "Multiple maps detected, please specify which map you want to work with using MapId or a unique MapName"
                }
    
                $MapId = $vacuumMaps.id
            }
    
            if (-not $ZoneId) {
    
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
