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
        The vaccuum robot associated with the map. Can be omitted if only one robot 
        is associated with the account (the function will then fetch the robot id
         automatically)

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

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ById')]
        [Alias('pncId')]
        [String[]] $RobotId,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName = $true, ParameterSetName = 'ByName')]
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

            $RobotId = $vacuumRobots.pncId
        }

        foreach ($vacId in $RobotId) {
            $uriEnding = "/robots/$vacId/interactivemaps"
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
