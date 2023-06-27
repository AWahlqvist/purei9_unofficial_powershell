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
