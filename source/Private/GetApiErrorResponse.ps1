function GetApiErrorResponse {
    <#
    .SYNOPSIS
    This helper function retrieves the returned error message from the API

    .DESCRIPTION
    This helper function retrieves the returned error message from the API

    Because of the way Invoke-RestMethod works, the error message would
    otherwise be "hidden" and only the http code would be returned

    #>

    [CmdletBinding()]
    [OutputType([String])]
    param(
        $ExceptionResponse
    )

    try {
        $errorResponseStream = $ExceptionResponse.GetResponseStream()
        $errorResponseStreamReader = New-Object System.IO.StreamReader($errorResponseStream)
        $errorResponseStreamReader.BaseStream.Position = 0
        $errorResponseStreamReader.DiscardBufferedData()
        $errorResponse = $errorResponseStreamReader.ReadToEnd()

        $errorResponse
    }
    catch {
        $ExceptionResponse
    }
}
