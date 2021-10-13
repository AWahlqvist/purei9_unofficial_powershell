function InvokeApiRequest {
    <#
    .SYNOPSIS
    This helper function does the actual API call.

    .DESCRIPTION
    This helper function does the actual API call and authorizes the request

    #>

    [CmdletBinding(DefaultParameterSetName = 'NoRequestPayload')]
    param(
        [Parameter(Mandatory=$true)]
        [PSCredential] $Credential,

        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable] $RequestSplattingHash,

        [Parameter(Mandatory = $true, ParameterSetName = 'ObjectRequestPayload')]
        [System.Collections.Hashtable] $RequestPayload
    )

    begin {
        AddTlsSecurityProtocolSupport
    }

    process {
        if ($RequestPayload) {
            try {
                $encodedString = GetApiObjectEncoded -RequestPayload $RequestPayload
                $encodedPayload = ConvertTo-Json -Depth 10 -InputObject $encodedString
            }
            catch {
                throw "Failed to encode the request payload. The error was: $($_.Exception.Message)"
            }

            $RequestSplattingHash.Add('Body', $encodedPayload)
        }

        $setApiAuthorizationHeaderParams = @{
            Credential = $Credential
            RequestHash  = $RequestSplattingHash
        }

        SetApiAuthorizationHeader @setApiAuthorizationHeaderParams

        try {
            $response = Invoke-RestMethod @RequestSplattingHash
        }
        catch {
            $errorMessage = GetApiErrorResponse -ExceptionResponse $_.Exception.Response
            throw "API call failed! The error was: $($_.Exception.Message) $errorMessage"
        }

        $response
    }

    end { }
}
