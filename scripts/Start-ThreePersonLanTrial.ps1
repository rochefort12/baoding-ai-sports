#requires -Version 7.0
<#
.SYNOPSIS
Starts only the isolated LAN frontend on 192.168.1.236:5193, preserving the loopback demo.
.DESCRIPTION
-FirewallOnly creates/verifies only the exact Private + LocalSubnet TCP 5193 rule.
It never starts another service, changes network categories or writes business records.
Run the firewall-only mode in elevated PowerShell 7 when Windows requests permission.
#>
[CmdletBinding()]
param([switch]$FirewallOnly)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/Common.ps1"
$taskAddress = '192.168.1.236'
$taskPort = 5193
$taskBackendPort = 8082
$taskRuleName = 'AISports-ThreePersonTrial-Private-5193'
$taskNodePath = [IO.Path]::GetFullPath('D:/dev/nodejs/node.exe')
$taskDatabase = 'aisports_verify_phase1_242ded43673246699be6bb0f596aa59b'
$taskRunId = [Guid]::NewGuid().ToString()
$taskOutput = Join-Path $WorkspaceRoot ".local/three-person-lan-20261012/$taskRunId"
New-Item -ItemType Directory -Path $taskOutput | Out-Null
$taskReceiptPath = Join-Path $taskOutput 'receipt.json'
$taskReceipt = [ordered]@{
    startedAt = [DateTimeOffset]::Now.ToString('o'); mode = $(if ($FirewallOnly) { 'firewall-only' } else { 'start-lan-frontend' })
    runId = $taskRunId; entry = "http://${taskAddress}:$taskPort/portal/home"; login = "http://${taskAddress}:$taskPort/portal/login"
    port = $taskPort; binding = $taskAddress; backendProxy = "http://127.0.0.1:$taskBackendPort"
    database = $taskDatabase; checks = @(); firewall = $null; status = 'PREPARING'; passed = $false
    secondDevice = @{ status = 'NOT_RUN'; reason = 'A second physical LAN device must open the entry and complete ordinary-role actions.' }
    scope = 'Existing isolated synthetic trial. One additional frontend and one narrowly scoped firewall rule; no business mutation, backend restart or other exposure.'
}
function Save-TaskReceipt {
    [IO.File]::WriteAllText($taskReceiptPath, ($taskReceipt | ConvertTo-Json -Depth 12), [Text.UTF8Encoding]::new($false))
}
function Add-TaskCheck([string]$Name, [bool]$Passed, $Details = $null) {
    $taskReceipt.checks += [pscustomobject]@{ name = $Name; passed = $Passed; details = $Details }
    Save-TaskReceipt
}
function Get-TaskListeners {
    @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
        Where-Object LocalPort -in @(5192,5193,8080,8082,8091,5190,25432,26379,29000,29001) |
        Sort-Object LocalPort,LocalAddress |
        Select-Object LocalAddress,LocalPort,OwningProcess)
}
function Get-TaskFirewall {
    $taskRule = Get-NetFirewallRule -Name $taskRuleName -ErrorAction SilentlyContinue
    if (!$taskRule) { return $null }
    $taskPortFilter = $taskRule | Get-NetFirewallPortFilter
    $taskAddressFilter = $taskRule | Get-NetFirewallAddressFilter
    $taskInterfaceFilter = $taskRule | Get-NetFirewallInterfaceFilter
    $taskApplicationFilter = $taskRule | Get-NetFirewallApplicationFilter
    [pscustomobject]@{
        name = $taskRule.Name; enabled = $taskRule.Enabled.ToString(); direction = $taskRule.Direction.ToString()
        action = $taskRule.Action.ToString(); profile = $taskRule.Profile.ToString(); protocol = $taskPortFilter.Protocol
        localPort = @($taskPortFilter.LocalPort); localAddress = @($taskAddressFilter.LocalAddress)
        remoteAddress = @($taskAddressFilter.RemoteAddress); interfaceAlias = @($taskInterfaceFilter.InterfaceAlias)
        program = $taskApplicationFilter.Program
    }
}
function Test-TaskFirewall($Rule) {
    $Rule -and $Rule.enabled -eq 'True' -and $Rule.direction -eq 'Inbound' -and $Rule.action -eq 'Allow' -and
    $Rule.profile -eq 'Private' -and $Rule.protocol -eq 'TCP' -and ($Rule.localPort -join ',') -eq "$taskPort" -and
    ($Rule.localAddress -join ',') -eq $taskAddress -and ($Rule.remoteAddress -join ',') -eq 'LocalSubnet' -and
    ($Rule.interfaceAlias -join ',') -eq $taskInterfaceAlias -and
    [IO.Path]::GetFullPath($Rule.program) -eq [IO.Path]::GetFullPath($taskNodePath)
}
function Set-TaskFirewall {
    $taskExistingRule = Get-TaskFirewall
    if ($taskExistingRule) {
        if (!(Test-TaskFirewall $taskExistingRule)) { throw 'Existing trial firewall rule has a different scope; no automatic widening or replacement.' }
        return @{ status = 'READY'; created = $false; rule = $taskExistingRule }
    }
    try {
        New-NetFirewallRule -Name $taskRuleName -DisplayName 'AI Sports three-person LAN trial TCP 5193' -Direction Inbound -Action Allow -Enabled True -Protocol TCP -LocalPort $taskPort -LocalAddress $taskAddress -RemoteAddress LocalSubnet -Profile Private -InterfaceAlias $taskInterfaceAlias -Program $taskNodePath -EdgeTraversalPolicy Block -ErrorAction Stop | Out-Null
    } catch {
        # No raw exception/header/command payload is copied to the receipt.
        return @{ status = 'BLOCKED'; created = $false; reason = 'Windows denied firewall-rule creation in this non-elevated session. Run this script with -FirewallOnly in elevated PowerShell 7.'; errorType = $_.Exception.GetType().Name; rule = $null }
    }
    $taskCreatedRule = Get-TaskFirewall
    if (!(Test-TaskFirewall $taskCreatedRule)) { throw 'Created firewall scope did not match the exact Private/LocalSubnet frontend boundary.' }
    return @{ status = 'READY'; created = $true; rule = $taskCreatedRule }
}
function Read-TaskHttp([string]$Route, $Headers = @{}) {
    Invoke-WebRequest -Uri ("http://${taskAddress}:$taskPort" + $Route) -Headers $Headers -TimeoutSec 30 -SkipHttpErrorCheck
}
function Add-TaskHttp([string]$Name, [string]$Route, $Headers = @{}, [string]$Kind = '') {
    $taskResponse = Read-TaskHttp $Route $Headers
    $taskBytes = $taskResponse.RawContentStream.ToArray()
    $taskContentType = ($taskResponse.Headers['Content-Type'] -join ',')
    $taskOk = [int]$taskResponse.StatusCode -eq 200 -and $taskBytes.Length -gt 0
    if ($Kind) { $taskOk = $taskOk -and $taskContentType -match $Kind }
    Add-TaskCheck $Name $taskOk @{ status = [int]$taskResponse.StatusCode; bytes = $taskBytes.Length; contentType = $taskContentType; sha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($taskBytes)).ToLowerInvariant() }
    if (!$taskOk) { throw 'A required LAN frontend/proxy read failed; inspect the sanitized receipt.' }
    $taskResponse
}
function Read-TaskBusiness([string]$Route, $Headers) {
    $taskResponse = Read-TaskHttp $Route $Headers
    if ([int]$taskResponse.StatusCode -ne 200) { throw 'Read-only proxy API returned a non-success status.' }
    $taskValue = $taskResponse.Content | ConvertFrom-Json
    if ($taskValue.code -ne 200) { throw 'Read-only proxy API returned a non-success business code.' }
    $taskValue.data
}
Save-TaskReceipt
try {
    $taskIp = @(Get-NetIPAddress -AddressFamily IPv4 -IPAddress $taskAddress -ErrorAction SilentlyContinue | Where-Object AddressState -eq 'Preferred')
    if ($taskIp.Count -ne 1) { throw 'The fixed LAN IPv4 address is unavailable or ambiguous; do not bind another interface.' }
    $taskNetwork = Get-NetConnectionProfile -InterfaceIndex $taskIp[0].InterfaceIndex
    $taskAdapter = Get-NetAdapter -InterfaceIndex $taskIp[0].InterfaceIndex
    $taskInterfaceAlias = $taskAdapter.Name
    $taskReceipt.network = @{ address = $taskAddress; prefixLength = $taskIp[0].PrefixLength; interfaceIndex = $taskIp[0].InterfaceIndex; interfaceAlias = $taskInterfaceAlias; category = $taskNetwork.NetworkCategory.ToString(); hardware = $taskAdapter.HardwareInterface }
    if ($taskNetwork.NetworkCategory -ne 'Private' -or !$taskAdapter.HardwareInterface -or $taskAdapter.Status -ne 'Up') { throw 'The selected LAN adapter must already be an active Private hardware network. Its category will not be changed.' }
    Add-TaskCheck 'Fixed LAN address belongs to active Private physical network' $true $taskReceipt.network
    if (!(Test-Path -LiteralPath $taskNodePath)) { throw 'Expected project Node runtime is unavailable.' }
    $taskReceipt.scriptSha256 = (Get-FileHash -LiteralPath $PSCommandPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $taskReceipt.listenersBefore = Get-TaskListeners
    $taskReceipt.firewall = Set-TaskFirewall
    Add-TaskCheck 'Only exact Private + LocalSubnet TCP 5193 rule is permitted' ($taskReceipt.firewall.status -eq 'READY') $taskReceipt.firewall
    if ($FirewallOnly) {
        $taskReceipt.listenersAfter = Get-TaskListeners
        Add-TaskCheck 'Firewall-only mode did not start or stop a service' (($taskReceipt.listenersBefore | ConvertTo-Json -Compress) -eq ($taskReceipt.listenersAfter | ConvertTo-Json -Compress))
        $taskReceipt.status = $(if ($taskReceipt.firewall.status -eq 'READY') { 'FIREWALL_READY_SECOND_DEVICE_NOT_RUN' } else { 'FIREWALL_BLOCKED' })
        $taskReceipt.passed = $taskReceipt.firewall.status -eq 'READY'
    } else {
        $taskRuntime = Get-Content -LiteralPath (Join-Path $WorkspaceRoot '.local/phase1-implementation/verification-runtime.json') -Raw | ConvertFrom-Json
        if ($taskRuntime.database -ne $taskDatabase -or $taskRuntime.port -ne $taskBackendPort) { throw 'Only the exact existing isolated verification backend may be proxied.' }
        $taskSavedDemo = Get-Content -LiteralPath (Join-Path $WorkspaceRoot '.local/demo-20261011/frontend-runtime.json') -Raw | ConvertFrom-Json
        $taskDemoProcess = Get-CimInstance Win32_Process -Filter "ProcessId=$($taskSavedDemo.pid)"
        $taskDemoListener = @(Get-NetTCPConnection -State Listen -LocalPort 5192 | Where-Object { $_.LocalAddress -eq '127.0.0.1' -and $_.OwningProcess -eq $taskSavedDemo.pid })
        if (!$taskDemoProcess -or !$taskDemoProcess.CommandLine.Contains($taskSavedDemo.wrapper) -or $taskDemoListener.Count -ne 1) { throw 'Existing loopback demo ownership could not be verified; it will not be changed.' }
        $taskReceipt.preservedDemoPid = $taskSavedDemo.pid
        foreach ($taskProtectedPort in @(8082,8091,25432,26379)) {
            $taskProtectedListeners = @(Get-NetTCPConnection -State Listen -LocalPort $taskProtectedPort -ErrorAction SilentlyContinue)
            if (!$taskProtectedListeners.Count -or @($taskProtectedListeners | Where-Object LocalAddress -ne '127.0.0.1').Count) { throw 'A required isolated backend dependency is missing or is not loopback-only.' }
        }
        if (Get-NetTCPConnection -State Listen -LocalPort $taskPort -ErrorAction SilentlyContinue) { throw 'LAN frontend port is occupied; no unverified process will be replaced.' }
        $taskUiRoot = Join-Path $WorkspaceRoot 'plus-ui'
        $taskWrapperPath = Join-Path $taskOutput 'vite-lan-trial.mjs'
        $taskCachePath = Join-Path $taskOutput 'vite-cache'
        $taskViteEntry = ([Uri](Join-Path $taskUiRoot 'node_modules/vite/dist/node/index.js')).AbsoluteUri
        $taskConfigPath = Join-Path $taskUiRoot 'vite.config.ts'
        $taskReceipt.sourceHashes = @{}
        foreach ($taskSource in @('scripts/Start-DemoFrontend.ps1','plus-ui/vite.config.ts','plus-ui/src/api/sports/media.ts','plus-ui/src/api/sports/avatar.ts','plus-ui/src/utils/requestKey.ts')) {
            $taskReceipt.sourceHashes[$taskSource] = (Get-FileHash -LiteralPath (Join-Path $WorkspaceRoot $taskSource) -Algorithm SHA256).Hash.ToLowerInvariant()
        }
        $taskJsConfig = $taskConfigPath | ConvertTo-Json -Compress
        $taskJsCache = $taskCachePath | ConvertTo-Json -Compress
        $taskJsUi = $taskUiRoot | ConvertTo-Json -Compress
        $taskJsVite = $taskViteEntry | ConvertTo-Json -Compress
        $taskWrapper = @"
import {createServer} from $taskJsVite;
const privateBoundary = {name:'lan-trial-private-files',configureServer(instance){instance.middlewares.use((request,response,next)=>{let pathname;try{pathname=decodeURIComponent(new URL(request.url,'http://localhost').pathname);}catch{response.statusCode=400;response.end('Bad request');return;}if(pathname.split('/').some(segment=>segment.startsWith('.env')||segment==='.git')){response.statusCode=403;response.end('Forbidden');return;}next();});}};
const server = await createServer({configFile:$taskJsConfig,cacheDir:$taskJsCache,plugins:[privateBoundary],server:{host:'$taskAddress',port:$taskPort,strictPort:true,open:false,fs:{strict:true,allow:[$taskJsUi,$taskJsCache],deny:['**/.env*','*.{crt,pem}','**/.git/**']},proxy:{'/dev-api':{target:'http://127.0.0.1:$taskBackendPort',changeOrigin:true,ws:true,rewrite:path=>path.replace(/^\/dev-api/,'')}}}});
await server.listen();
console.log('Private LAN trial frontend ready; existing isolated API proxy only.');
"@
        [IO.File]::WriteAllText($taskWrapperPath,$taskWrapper,[Text.UTF8Encoding]::new($false))
        $taskProcess = Start-Process -FilePath $taskNodePath -ArgumentList @('"'+$taskWrapperPath+'"') -WorkingDirectory $taskUiRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskOutput 'frontend.out.log') -RedirectStandardError (Join-Path $taskOutput 'frontend.err.log')
        $taskReceipt.frontend = @{ pid = $taskProcess.Id; wrapper = $taskWrapperPath; cache = $taskCachePath; wrapperSha256 = (Get-FileHash -LiteralPath $taskWrapperPath -Algorithm SHA256).Hash.ToLowerInvariant() }
        Save-TaskReceipt
        $taskStarted = $false
        for ($taskAttempt = 0; $taskAttempt -lt 40; $taskAttempt++) {
            if (@(Get-NetTCPConnection -State Listen -LocalPort $taskPort -ErrorAction SilentlyContinue | Where-Object { $_.LocalAddress -eq $taskAddress -and $_.OwningProcess -eq $taskProcess.Id }).Count -eq 1) { $taskStarted = $true; break }
            if ($taskProcess.HasExited) { throw 'LAN frontend exited during startup; protected logs retain diagnostics.' }
            Start-Sleep -Milliseconds 500
        }
        if (!$taskStarted) { throw 'LAN frontend did not establish its exact address listener in time.' }
        Add-TaskCheck 'Only new LAN address/5193 frontend listener was started' $true $taskReceipt.frontend
        foreach ($taskRoute in @('/portal/home','/portal/login','/portal/organization')) { $null = Add-TaskHttp "LAN SPA route $taskRoute" $taskRoute @{} 'text/html' }
        $null = Add-TaskHttp 'LAN static assistant asset' '/images/sports/assistant-orb-v2.webp' @{} 'image/'
        $null = Add-TaskHttp 'LAN static cover fallback' '/images/sports/badminton-hero-v1.webp' @{} 'image/'
        $taskPrivateRoute = '/@fs/' + (Join-Path $WorkspaceRoot '.local/phase1-implementation/verification-session.json').Replace('\','/')
        foreach ($taskDeniedRoute in @($taskPrivateRoute, ('/@fs/' + (Join-Path $taskUiRoot '.env.development.local').Replace('\','/')))) {
            $taskDenied = Read-TaskHttp $taskDeniedRoute
            Add-TaskCheck 'Vite denies private file access via LAN frontend' ([int]$taskDenied.StatusCode -eq 403) @{ status = [int]$taskDenied.StatusCode }
            if ([int]$taskDenied.StatusCode -ne 403) { throw 'Private frontend file boundary did not return forbidden.' }
        }
        # Anonymous public API and existing authenticated material reads; tokens never leave process memory.
        $taskPrivateContext = Get-Content -LiteralPath (Join-Path $WorkspaceRoot '.local/business-regression-20261011/a006561dd66540c2b383415b02480f2c/context.private.json') -Raw | ConvertFrom-Json
        if ($taskPrivateContext.database -ne $taskDatabase -or $taskPrivateContext.backend -ne 'http://127.0.0.1:8082') { throw 'Private ordinary-role context does not match this isolated trial.' }
        $taskHeaders = @{ clientid = $taskPrivateContext.clientId }
        $taskPublic = Read-TaskBusiness '/dev-api/sports/public/events' $taskHeaders
        Add-TaskCheck 'Anonymous public-events API works through LAN frontend proxy' $true @{ businessCode = 200; backend = '127.0.0.1:8082'; eventCount = @($taskPublic).Count }
        $taskSession = Get-Content -LiteralPath (Join-Path $WorkspaceRoot '.local/phase1-implementation/verification-session.json') -Raw | ConvertFrom-Json
        $taskLoginBody = @{ username = $taskSession.people[0].phone; password = $taskSession.password; grantType = 'platform'; tenantId = '900001'; clientId = $taskPrivateContext.clientId } | ConvertTo-Json -Compress
        $taskLoginResponse = Invoke-RestMethod -Uri "http://${taskAddress}:$taskPort/dev-api/auth/login" -Method Post -ContentType 'application/json' -Headers $taskHeaders -Body $taskLoginBody -TimeoutSec 30
        if ($taskLoginResponse.code -ne 200 -or !$taskLoginResponse.data.access_token) { throw 'Ordinary account login through LAN proxy did not succeed.' }
        $taskHeaders.Authorization = 'Bearer ' + $taskLoginResponse.data.access_token
        $taskIdentity = Read-TaskBusiness '/dev-api/sports/c/identity' $taskHeaders
        Add-TaskCheck 'Ordinary account login and own identity work through LAN proxy' $true @{ businessCode = 200; dataCopiedToReceipt = $false }
        $taskAvatarResponse = Read-TaskHttp "/dev-api/sports/display/avatar/$($taskIdentity.accountId)" $taskHeaders
        $taskAvatarOk = [int]$taskAvatarResponse.StatusCode -eq 200 -and ($taskAvatarResponse.Headers['Content-Type'] -join ',') -match 'image/'
        $taskReceipt.avatar = @{ status = $(if ($taskAvatarOk) { 'PASS' } else { 'NOT_RUN_EXISTING_AVATAR_UNAVAILABLE' }); httpStatus = [int]$taskAvatarResponse.StatusCode; reason = 'No avatar is uploaded or changed by this script.' }
        $taskEnterResponse = Invoke-RestMethod -Uri "http://${taskAddress}:$taskPort/dev-api/auth/organization/enter" -Method Post -ContentType 'application/json' -Headers $taskHeaders -Body '{}' -TimeoutSec 30
        if ($taskEnterResponse.code -ne 200 -or !$taskEnterResponse.data.access_token) { throw 'Ordinary organization entry through LAN proxy did not succeed.' }
        $taskHeaders.Authorization = 'Bearer ' + $taskEnterResponse.data.access_token
        $taskOriginalCandidate = Read-TaskBusiness '/dev-api/sports/b/ai/tasks/2109468287808057346' $taskHeaders
        if ($taskOriginalCandidate.files.Count) {
            $taskFileId = $taskOriginalCandidate.files[0].fileId
            $null = Add-TaskHttp 'Existing authorized material downloads through LAN proxy' "/dev-api/sports/b/ai/tasks/2109468287808057346/files/$taskFileId" $taskHeaders
        } else { $taskReceipt.material = @{ status = 'NOT_RUN'; reason = 'Original candidate has no attached file; no new material is created.' } }
        $taskEvents = Read-TaskBusiness '/dev-api/sports/b/events' $taskHeaders
        $taskEventRows = $(if ($taskEvents -is [Array]) { $taskEvents } elseif ($taskEvents.rows) { $taskEvents.rows } elseif ($taskEvents.records) { $taskEvents.records } else { @() })
        $taskCoverEvent = @($taskEventRows | Where-Object { $_.bannerFileId -and $_.publicationStatus -eq 'published' } | Select-Object -First 1)
        if ($taskCoverEvent.Count) {
            $null = Add-TaskHttp 'Existing published cover loads through anonymous LAN proxy' "/dev-api/sports/public/events/$($taskCoverEvent[0].id)/media/banner" @{ clientid = $taskPrivateContext.clientId } 'image/'
            $taskReceipt.uploadedCover = @{ status = 'PASS' }
        } else { $taskReceipt.uploadedCover = @{ status = 'NOT_RUN_EXISTING_COVER_UNAVAILABLE'; reason = 'No published event with an uploaded cover was available. Static cover fallback was read successfully; no event was edited.' } }
        $taskHeaders.Remove('Authorization'); $taskLoginBody = $null; $taskLoginResponse = $null; $taskEnterResponse = $null; $taskSession = $null
        $taskReceipt.listenersAfter = Get-TaskListeners
        $taskProtectedBefore = @($taskReceipt.listenersBefore | Where-Object LocalPort -ne 5193) | ConvertTo-Json -Compress
        $taskProtectedAfter = @($taskReceipt.listenersAfter | Where-Object LocalPort -ne 5193) | ConvertTo-Json -Compress
        Add-TaskCheck 'Old frontend and every backend/storage listener remain unchanged' ($taskProtectedBefore -eq $taskProtectedAfter)
        if ($taskProtectedBefore -ne $taskProtectedAfter) { throw 'A protected listener changed during LAN setup.' }
        $taskReceipt.status = $(if ($taskReceipt.firewall.status -eq 'READY') { 'LOCAL_LAN_READY_SECOND_DEVICE_NOT_RUN' } else { 'LOCAL_LAN_READY_FIREWALL_BLOCKED_SECOND_DEVICE_NOT_RUN' })
        $taskReceipt.passed = $taskReceipt.firewall.status -eq 'READY'
    }
} catch {
    $taskReceipt.status = 'BLOCKED'
    $taskReceipt.failure = @{ errorType = $_.Exception.GetType().Name; errorId = $_.FullyQualifiedErrorId; atLine = $_.InvocationInfo.ScriptLineNumber; reason = 'Setup or read-only verification failed. Inspect checks and the private per-run process logs; no raw exception containing credentials is exported.' }
} finally {
    $taskReceipt.finishedAt = [DateTimeOffset]::Now.ToString('o')
    Save-TaskReceipt
    $taskReceiptHash = (Get-FileHash -LiteralPath $taskReceiptPath -Algorithm SHA256).Hash.ToLowerInvariant()
    [pscustomobject]@{ status = $taskReceipt.status; entry = $taskReceipt.entry; evidence = $taskOutput; receiptSha256 = $taskReceiptHash; secondDevice = 'NOT_RUN'; firewall = $taskReceipt.firewall.status } | ConvertTo-Json -Compress | Write-Output
}
