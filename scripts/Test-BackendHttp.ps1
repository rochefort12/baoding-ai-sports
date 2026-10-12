#requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Username, [Parameter(Mandatory)][string]$Password,
      [string]$BaseUrl = 'http://127.0.0.1:8080', [string]$TenantId = '000000',
      [string]$ClientId = 'e5cd7e4891bf95d1d19206ce24a7b32e')
. "$PSScriptRoot/Common.ps1"
# Use a local verification backend with MCP enabled and captcha temporarily disabled.
# This checks framework plumbing, not public-user business acceptance.
$baseUri = [Uri]$BaseUrl
if (!$baseUri.IsLoopback) { throw 'Preparation smoke test is restricted to a loopback backend.' }
function Read-Rpc($response) {
    $content = $response.Content
    if ($content -match '(?m)^data:\s*(.+)$') { $content = $Matches[1] }
    $decoded = $content | ConvertFrom-Json
    if ($decoded.error) { throw "MCP JSON-RPC error code $($decoded.error.code)" }
    return $decoded
}
$rpcHeaders = @{ Accept = 'application/json, text/event-stream' }
$initialize = @{jsonrpc='2.0';id=1;method='initialize';params=@{protocolVersion='2025-03-26';capabilities=@{};clientInfo=@{name='aisports-preparation-check';version='0.1.0'}}} | ConvertTo-Json -Depth 8 -Compress
$unauthorized = Invoke-WebRequest "$BaseUrl/mcp" -Method Post -Headers $rpcHeaders -ContentType 'application/json' -Body $initialize -SkipHttpErrorCheck
if ($unauthorized.StatusCode -ne 401) { throw "Unauthenticated MCP expected HTTP401, got $($unauthorized.StatusCode)" }
$loginBody = @{tenantId=$TenantId;username=$Username;password=$Password;grantType='password';clientId=$ClientId} | ConvertTo-Json -Compress
$login = Invoke-RestMethod "$BaseUrl/auth/login" -Method Post -ContentType 'application/json' -Body $loginBody
if ($login.code -ne 200 -or !$login.data.access_token) { throw "Framework login failed: code $($login.code)" }
try {
    $rpcHeaders.Authorization = "Bearer $($login.data.access_token)"
    $rpcHeaders.clientid = $ClientId
    $badClientHeaders = $rpcHeaders.Clone()
    $badClientHeaders.clientid = 'invalid-client'
    $badClient = Invoke-WebRequest "$BaseUrl/mcp" -Method Post -Headers $badClientHeaders -ContentType 'application/json' -Body $initialize -SkipHttpErrorCheck
    if ($badClient.StatusCode -ne 401) { throw 'MCP accepted a mismatched clientid' }
    $untrustedHeaders = $rpcHeaders.Clone()
    $untrustedHeaders.Origin = 'https://untrusted.invalid'
    $untrusted = Invoke-WebRequest "$BaseUrl/mcp" -Method Post -Headers $untrustedHeaders -ContentType 'application/json' -Body $initialize -SkipHttpErrorCheck
    if ($untrusted.StatusCode -ne 403) { throw 'MCP accepted an untrusted Origin' }
    $response = Invoke-WebRequest "$BaseUrl/mcp" -Method Post -Headers $rpcHeaders -ContentType 'application/json' -Body $initialize
    $rpc = Read-Rpc $response
    if (!$rpc.result.protocolVersion) { throw 'No negotiated MCP protocol version' }
    $rpcHeaders.'MCP-Protocol-Version' = $rpc.result.protocolVersion
    $listBody = @{jsonrpc='2.0';id=2;method='tools/list';params=@{}} | ConvertTo-Json -Depth 4 -Compress
    $list = Read-Rpc (Invoke-WebRequest "$BaseUrl/mcp" -Method Post -Headers $rpcHeaders -ContentType 'application/json' -Body $listBody)
    Write-Host "PASS: framework login, MCP401/clientid401/Origin403, initialize $($rpc.result.protocolVersion), tools/list count=$(@($list.result.tools).Count)."
    Write-Host 'Evidence uses an upstream administrator fixture; no business acceptance or real identity/payment is claimed.'
} finally {
    Invoke-RestMethod "$BaseUrl/auth/logout" -Method Post -Headers $rpcHeaders | Out-Null
    $login = $null; $loginBody = $null; $rpcHeaders.Clear()
}
