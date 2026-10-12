#requires -Version 7.0
. "$PSScriptRoot/Common.ps1"
Import-LocalEnvironment
$docker = Get-DockerCommand
& $docker compose up -d minio
Assert-NativeExit 'Start MinIO'
& $docker rm -f aisports-dev-minio-init 2>$null | Out-Null

function Get-Hmac([byte[]]$key, [string]$data) {
    $hmac = [System.Security.Cryptography.HMACSHA256]::new($key)
    try { return $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($data)) }
    finally { $hmac.Dispose() }
}
function Get-Hex([byte[]]$bytes) { return ([BitConverter]::ToString($bytes) -replace '-', '').ToLowerInvariant() }

$user = if ($env:MINIO_ROOT_USER) { $env:MINIO_ROOT_USER } else { 'ruoyi' }
$password = if ($env:MINIO_ROOT_PASSWORD) { $env:MINIO_ROOT_PASSWORD } else { 'ruoyi123' }
$now = [DateTime]::UtcNow
$amzDate = $now.ToString('yyyyMMddTHHmmssZ')
$dateStamp = $now.ToString('yyyyMMdd')
$payload = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
$canonical = "PUT`n/ruoyi`n`nhost:127.0.0.1:9000`nx-amz-content-sha256:$payload`nx-amz-date:$amzDate`n`nhost;x-amz-content-sha256;x-amz-date`n$payload"
$sha = [System.Security.Cryptography.SHA256]::Create()
try { $canonicalHash = Get-Hex ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($canonical))) }
finally { $sha.Dispose() }
$scope = "$dateStamp/us-east-1/s3/aws4_request"
$stringToSign = "AWS4-HMAC-SHA256`n$amzDate`n$scope`n$canonicalHash"
$signing = Get-Hmac (Get-Hmac (Get-Hmac (Get-Hmac ([Text.Encoding]::UTF8.GetBytes("AWS4$password")) $dateStamp) 'us-east-1') 's3') 'aws4_request'
$signature = Get-Hex (Get-Hmac $signing $stringToSign)
$client = [System.Net.Http.HttpClient]::new()
try {
    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Put, 'http://127.0.0.1:9000/ruoyi')
    $request.Headers.TryAddWithoutValidation('x-amz-date', $amzDate) | Out-Null
    $request.Headers.TryAddWithoutValidation('x-amz-content-sha256', $payload) | Out-Null
    $request.Headers.TryAddWithoutValidation('Authorization', "AWS4-HMAC-SHA256 Credential=$user/$scope, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=$signature") | Out-Null
    $response = $client.Send($request)
    if ([int]$response.StatusCode -eq 409) {
        Write-Host 'MinIO bucket ruoyi already exists.'
        return
    }
    if (-not $response.IsSuccessStatusCode) {
        throw "Create bucket failed: $([int]$response.StatusCode)"
    }
} finally {
    $client.Dispose()
}
Write-Host 'MinIO bucket ruoyi is ready.'
