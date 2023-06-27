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
    $xApiKey = '2AMqwEV5MqVhTKrRCyYfVF8gmKrd2rAmp7cUsfky'
    $clientId = 'ElxOneApp'
    $clientSecret = '8UKrsKD7jH9zvTV7rz5HeCLkit67Mmj68FvRVTlYygwJYy4dW6KF2cVLPKeWzUQUd6KJMtTifFf4NkDnjI7ZLdfnwcPtTSNtYvbP7OzEkmQD9IjhMOf5e1zeAQYtt2yN'

    if ($Script:AuthToken.Expires -le (Get-Date)) {
        Write-Verbose "Requesting access token..."

        $tokenExpires = (Get-Date).AddSeconds(600)
        
        $tokenRequestHash = GetApiRequestSplattingHash -UriEnding "/one-account-authorization/api/v1/token" -Method Post
        $tokenRequestHash.Headers.Remove('Authorization')
        $tokenRequestHash.Headers.Add('x-api-key', $xApiKey)


        $body = @{
            clientId = $clientId
            clientSecret = $clientSecret
            grantType = "client_credentials"
        } | ConvertTo-Json

        $clientAccessToken = Invoke-RestMethod @tokenRequestHash -Body $body
    
        $body = @{
            username = $Credential.UserName
            password = $Credential.GetNetworkCredential().Password
        } | ConvertTo-Json
        
        $tokenRequestHash = GetApiRequestSplattingHash -UriEnding "/one-account-authentication/api/v1/authenticate" -Method Post
        $tokenRequestHash.Headers.Authorization = "Bearer $($clientAccessToken.accessToken)"
        $tokenRequestHash.Headers.Add('x-api-key', $xApiKey)
    
        $userAccessToken = Invoke-RestMethod @tokenRequestHash -Body $body
        
        $body = @{
            clientId = $clientId
            idToken = $userAccessToken.idToken
            grantType = 'urn:ietf:params:oauth:grant-type:token-exchange'
        } | ConvertTo-Json

        $tokenRequestHash = GetApiRequestSplattingHash -UriEnding "/one-account-authorization/api/v1/token" -Method Post
        $tokenRequestHash.Headers.Add('Origin-Country-Code', $userAccessToken.countryCode)

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
    $RequestHash.Headers.Remove('x-api-key')
    $RequestHash.Headers.Add('x-api-key', $xApiKey)
}
