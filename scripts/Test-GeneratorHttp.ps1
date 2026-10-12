#requires -Version 7.0
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Username, [Parameter(Mandatory)][string]$Password,
      [string]$BaseUrl = 'http://127.0.0.1:8080', [string]$TenantId = '000000',
      [string]$ClientId = 'e5cd7e4891bf95d1d19206ce24a7b32e')
. "$PSScriptRoot/Common.ps1"
if (!([Uri]$BaseUrl).IsLoopback) { throw 'Preparation checks require a loopback backend.' }
$headers = @{clientid=$ClientId}
$loginBody = @{tenantId=$TenantId;username=$Username;password=$Password;grantType='password';clientId=$ClientId} | ConvertTo-Json -Compress
$login = Invoke-RestMethod "$BaseUrl/auth/login" -Method Post -ContentType 'application/json' -Body $loginBody
if ($login.code -ne 200 -or !$login.data.access_token) { throw "Framework login failed: $($login.code)" }
$headers.Authorization = "Bearer $($login.data.access_token)"
$importedIds = @()
$names = @('asp_sport','asp_organization')
function Assert-Response($response, [string]$action) {
    if ($response.code -ne 200) { throw "$action failed: code $($response.code)" }
}
try {
    foreach ($name in $names) {
        $existing = Invoke-RestMethod "$BaseUrl/tool/gen/list?dataName=master&tableName=$name&pageNum=1&pageSize=10" -Headers $headers
        Assert-Response $existing 'Existing metadata check'
        if (@($existing.rows | Where-Object tableName -EQ $name).Count) { throw "Metadata already exists for $name; preserve it and use an isolated test database." }
        $database = Invoke-RestMethod "$BaseUrl/tool/gen/db/list?dataName=master&tableName=$name&pageNum=1&pageSize=10" -Headers $headers
        Assert-Response $database 'PostgreSQL metadata query'
        if (!@($database.rows | Where-Object tableName -EQ $name).Count) { throw "Table $name absent from PostgreSQL generator metadata" }
    }
    $import = Invoke-RestMethod "$BaseUrl/tool/gen/importTable" -Method Post -Headers $headers -Body @{tables=($names -join ',');dataName='master'}
    Assert-Response $import 'Metadata import'
    foreach ($name in $names) {
        $tableList = Invoke-RestMethod "$BaseUrl/tool/gen/list?dataName=master&tableName=$name&pageNum=1&pageSize=10" -Headers $headers
        $id = ($tableList.rows | Where-Object tableName -EQ $name).tableId
        if (!$id) { throw "Imported table missing: $name" }
        $importedIds += $id
    }
    $details = Invoke-RestMethod "$BaseUrl/tool/gen/$($importedIds[0])" -Headers $headers
    Assert-Response $details 'Generator detail'
    $info = $details.data.info
    if ($info.mcpEnabled) { throw 'MCP option must default to false' }
    if ($info.functionName.Length -gt 50) { throw 'Model comment overflowed the short function name' }
    $info | Add-Member -NotePropertyName columns -NotePropertyValue $details.data.rows -Force
    $info | Add-Member -NotePropertyName params -NotePropertyValue @{mcpEnabled=$true;parentMenuId='3'} -Force
    $update = Invoke-RestMethod "$BaseUrl/tool/gen" -Method Put -Headers $headers -ContentType 'application/json' -Body ($info | ConvertTo-Json -Depth 20 -Compress)
    Assert-Response $update 'MCP option persistence'
    $updated = Invoke-RestMethod "$BaseUrl/tool/gen/$($importedIds[0])" -Headers $headers
    # Upstream protects even this GET with @RepeatSubmit; observe its short cooldown.
    if ($updated.code -eq 500 -and $updated.msg -like '*重复提交*') {
        Start-Sleep -Milliseconds 5200
        $updated = Invoke-RestMethod "$BaseUrl/tool/gen/$($importedIds[0])" -Headers $headers
    }
    Assert-Response $updated 'Generator detail round-trip'
    if (!$updated.data.info.mcpEnabled) {
        throw 'MCP option did not round-trip through options JSON'
    }
    $preview = Invoke-RestMethod "$BaseUrl/tool/gen/preview/$($importedIds[0])" -Headers $headers
    Assert-Response $preview 'Velocity preview'
    if (!$preview.data.'vm/java/controller.java.vm'.Contains('@Tool(')) { throw 'No opt-in tool in actual preview' }
    if (!$preview.data.'vm/docs/module.md.vm') { throw 'Generated module documentation missing' }
    New-Item -ItemType Directory -Path "$WorkspaceRoot/.local/verification" -Force | Out-Null
    $zipPath = "$WorkspaceRoot/.local/verification/generated-crud.zip"
    Invoke-WebRequest "$BaseUrl/tool/gen/batchGenCode?tableIdStr=$($importedIds -join ',')" -Headers $headers -OutFile $zipPath
    $zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $styleCount = @($zip.Entries | Where-Object FullName -EQ 'vue/assets/styles/generated-crud.scss').Count
        $docCount = @($zip.Entries | Where-Object FullName -Like 'docs/generated/*').Count
        if ($styleCount -ne 1 -or $docCount -ne 2) { throw 'Batch ZIP shared style/document counts failed' }
        Write-Host "PASS: actual PostgreSQL metadata/import, MCP false→true round-trip, preview and batch ZIP: $($zip.Entries.Count) entries / 1 shared style / 2 documents."
    } finally { $zip.Dispose() }
} finally {
    if ($importedIds.Count) {
        $cleanup = Invoke-RestMethod "$BaseUrl/tool/gen/$($importedIds -join ',')" -Method Delete -Headers $headers
        Assert-Response $cleanup 'Synthetic generator metadata cleanup'
    }
    Invoke-RestMethod "$BaseUrl/auth/logout" -Method Post -Headers $headers | Out-Null
    $headers.Clear(); $login=$null; $loginBody=$null
}
