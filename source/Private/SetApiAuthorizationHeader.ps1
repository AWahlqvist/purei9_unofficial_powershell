function SetApiAuthorizationHeader {
    <#
        .SYNOPSIS
        This helper function contains the logic for setting the authorization header

        .DESCRIPTION
        This helper function contains the logic for setting the authorization header
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCredential] $Credential,

        [Parameter(Mandatory=$true)]
        [System.Collections.Hashtable] $RequestHash
    )

    if ($Script:AuthToken.Expires -le (Get-Date)) {
        Write-Verbose "Requesting access token..."

        $tokenExpires = (Get-Date).AddSeconds(60)
        
        $tokenRequestHash = GetApiRequestSplattingHash -UriEnding "/Clients/Wellbeing" -Method Post
        $tokenRequestHash.Headers.Remove('Authorization')
    
        $body = @{
            ClientSecret = "vIpsOBEenIvjbawqL4HA29"
        } | ConvertTo-Json
        
        $clientAccessToken = Invoke-RestMethod @tokenRequestHash -Body $body
    
        $body = @{
            Username = $Credential.UserName
            Password = $Credential.GetNetworkCredential().Password
        } | ConvertTo-Json
        
        $tokenRequestHash = GetApiRequestSplattingHash -UriEnding "/Users/Login" -Method Post
        $tokenRequestHash.Headers.Authorization = "Bearer $($clientAccessToken.accessToken)"
    
        $userAccessToken = Invoke-RestMethod @tokenRequestHash -Body $body

        $Script:AuthToken = @{
            Header = "Bearer $($userAccessToken.accessToken)"
            Expires = $tokenExpires
        }
    }
    else {
        Write-Verbose "Reusing existing auth token..."
    }

    $RequestHash.Headers.Authorization = $Script:AuthToken.Header
}
