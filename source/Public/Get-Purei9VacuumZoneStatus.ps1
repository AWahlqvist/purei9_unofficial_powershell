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
        [Alias('pncId')]
        [String[]] $RobotId,

        [Parameter(Mandatory=$false, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByName')]
        [Alias('applianceName')]
        [String[]] $RobotName,

        [Parameter(Mandatory=$false)]
        [Int] $IncludeSessionsSinceDays = 30
    )

    begin { }

    process {
        if (-not $RobotId) {
            $vacuumRobots = Get-Purei9VacuumRobot -Credential $Credential

            if ($RobotName) {
                $vacuumRobots = Get-Purei9VacuumRobot -Credential $Credential | Where-Object { $_.applianceName -in $RobotName }
            }

            $Robots = $vacuumRobots
        }

        foreach ($vac in $Robots) {
            $vacuumMaps = Get-Purei9VacuumMap -Credential $Credential -RobotId $vac.pncId
            $vacuumSessions = Get-Purei9VacuumRobotSession -Credential $Credential -RobotId $vac.pncId | Where-Object { $_.timestamp -ge (Get-Date).AddDays(-$IncludeSessionsSinceDays) }

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
                        RobotId = $vac.pncId
                        RobotName = $vac.applianceName
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
