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
