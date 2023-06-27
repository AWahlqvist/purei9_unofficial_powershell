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
