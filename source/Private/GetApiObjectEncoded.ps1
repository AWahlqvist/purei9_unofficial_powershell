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
