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
        $uriEnding = "/Domains/Appliances"
        $requestHash = GetApiRequestSplattingHash -UriEnding $uriEnding

        $invokeApiRequestSplat = @{
            Credential = $Credential
            RequestSplattingHash = $requestHash
        }
        $appliances = InvokeApiRequest @invokeApiRequestSplat

        foreach ($appliance in $appliances) {
            $uriEnding = "/AppliancesInfo/$($appliance.pncId)"
            $requestHash = GetApiRequestSplattingHash -UriEnding $uriEnding
            
            $invokeApiRequestSplat = @{
                Credential = $Credential
                RequestSplattingHash = $requestHash
            }
            $applianceInfo = InvokeApiRequest @invokeApiRequestSplat
        
            if ($applianceInfo.device -eq 'ROBOTIC_VACUUM_CLEANER') {
                $appliance | Add-Member -MemberType NoteProperty -Name info -Value $applianceInfo
                $appliance
            }
        }
    }

    end { }
}
