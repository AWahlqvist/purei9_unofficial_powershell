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
        [Alias('pncId')]
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

            $RobotId = $vacuumRobots.pncId
        }

        foreach ($vacId in $RobotId) {
            $uriEnding = "/robots/$vacId/history"
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
