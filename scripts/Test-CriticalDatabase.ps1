#requires -Version 7.0
<# .SYNOPSIS 真实 PostgreSQL 存储集成；仅在本轮创建的无用户数据临时库写入。 #>
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
Import-LocalEnvironment
$docker=Get-DockerCommand
$db='aisports_verify_critical_'+[guid]::NewGuid().ToString('N')
if($db -notmatch '^aisports_verify_critical_[a-f0-9]{32}$' -or $db -eq $env:POSTGRES_DB){throw 'Unsafe test database name'}
$dump='/tmp/'+$db+'.sql'; $created=$false; $completed=$false; $workers=[System.Collections.Generic.List[System.Diagnostics.Process]]::new()
$outDir=Join-Path $WorkspaceRoot '.local/critical-tests'; New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$checks=[System.Collections.Generic.List[string]]::new()
function Sql([string]$text){
    $output=$text | & $docker exec -i aisports-dev-postgres psql -U $env:POSTGRES_USER -d $db -v ON_ERROR_STOP=1 -qAt 2>&1
    if($LASTEXITCODE -ne 0){throw "Isolated database SQL failed: $output"}
    return ($output -join "`n")
}
function Worker([string]$commands){
    $info=[System.Diagnostics.ProcessStartInfo]::new($docker)
    foreach($argument in @('exec','-i','aisports-dev-postgres','psql','-U',$env:POSTGRES_USER,'-d',$db,'-v','ON_ERROR_STOP=1','-qAt')){$info.ArgumentList.Add($argument)}
    $info.UseShellExecute=$false; $info.CreateNoWindow=$true
    $info.RedirectStandardInput=$true; $info.RedirectStandardOutput=$true; $info.RedirectStandardError=$true
    $process=[System.Diagnostics.Process]::Start($info); $workers.Add($process)
    $process.StandardInput.WriteLine($commands); $process.StandardInput.Flush()
    return $process
}
function Ready($process){
    while($true){
        $line=$process.StandardOutput.ReadLineAsync()
        if(!$line.Wait(10000)){throw 'Holder readiness timed out'}
        if($line.Result -eq 'HOLDER_READY'){return}
        if($null -eq $line.Result){throw 'Holder exited before acquiring lock'}
    }
}
function Wait-Lock([string]$name){
    $deadline=[DateTime]::UtcNow.AddSeconds(10)
    do {
        if((Sql "SELECT count(*) FROM pg_stat_activity WHERE datname='$db' AND application_name='$name' AND wait_event_type='Lock';").Trim() -eq '1'){return}
        Start-Sleep -Milliseconds 100
    } while([DateTime]::UtcNow -lt $deadline)
    throw 'Competing transaction did not reach the expected PostgreSQL lock'
}
function Finish($process){
    $process.StandardInput.Close()
    if(!$process.WaitForExit(10000)){throw 'Competing transaction timed out'}
    $output=$process.StandardOutput.ReadToEnd(); $err=$process.StandardError.ReadToEnd()
    if($process.ExitCode -ne 0){throw "Isolated worker failed: $err"}
    return $output
}
try {
    & $docker exec aisports-dev-postgres pg_dump -U $env:POSTGRES_USER -d $env:POSTGRES_DB --schema-only --no-owner --no-privileges -f $dump
    Assert-NativeExit 'Schema-only export'
    & $docker exec aisports-dev-postgres createdb -U $env:POSTGRES_USER -T template0 $db
    Assert-NativeExit 'Temporary database creation'; $created=$true
    $restore=& $docker exec aisports-dev-postgres psql -U $env:POSTGRES_USER -d $db -v ON_ERROR_STOP=1 -q -f $dump 2>&1
    if($LASTEXITCODE -ne 0){throw "Isolated schema restore failed: $restore"}
    $result=Sql (Get-Content -LiteralPath (Join-Path $WorkspaceRoot 'database/verification/critical-risk.sql') -Raw)
    foreach($line in $result -split "`n"){if($line -match 'PASS (.+)'){$checks.Add($Matches[1]); Write-Host $line}}
    if($checks.Count -ne 7){throw 'Expected seven storage assertions'}
    # A持有最后名额行锁；B明确进入数据库锁等待后才允许A提交。
    $a=Worker "BEGIN; SELECT id FROM asp_capacity_pool WHERE id=401 FOR UPDATE;`n\echo HOLDER_READY"
    Ready $a
    $b=Worker "BEGIN; SET application_name='critical_capacity_contender'; UPDATE asp_capacity_pool SET used_count=used_count+1 WHERE id=401 AND used_count<limit_count RETURNING 'ALLOCATED'; COMMIT;"
    Wait-Lock 'critical_capacity_contender'
    $a.StandardInput.WriteLine("UPDATE asp_capacity_pool SET used_count=used_count+1 WHERE id=401 AND used_count<limit_count RETURNING 'ALLOCATED'; COMMIT;")
    $a.StandardInput.Flush(); $allocation=(Finish $a)+(Finish $b)
    if(([regex]::Matches($allocation,'ALLOCATED')).Count -ne 1 -or (Sql 'SELECT used_count FROM asp_capacity_pool WHERE id=401;').Trim() -ne '1'){throw 'Last seat was allocated incorrectly'}
    $checks.Add('last-seat-competing-transactions'); Write-Host 'PASS last-seat-competing-transactions'
    # 同请求键的第二次插入必须等待第一次提交，之后只能有一条实收记录。
    $columns='id,tenant_id,payee_subject,amount,currency,status,evidence,request_key,payer_presence,payment_mode,confirmation_source'
    $a=Worker "BEGIN; INSERT INTO asp_payment($columns) VALUES(1001,'critical','Synthetic payee',10,'CNY','confirmed','{}','same-request','external','offline','manual') RETURNING 'RECORDED';`n\echo HOLDER_READY"
    Ready $a
    $b=Worker "BEGIN; SET application_name='critical_payment_contender'; INSERT INTO asp_payment($columns) VALUES(1002,'critical','Synthetic payee',10,'CNY','confirmed','{}','same-request','external','offline','manual') ON CONFLICT(tenant_id,request_key) DO NOTHING RETURNING 'RECORDED'; COMMIT;"
    Wait-Lock 'critical_payment_contender'
    $a.StandardInput.WriteLine('COMMIT;'); $a.StandardInput.Flush(); $payments=Finish $a
    $payments+=Finish $b
    # Holder Ready 消费了首次 RETURNING，最终行数才是权威断言。
    if((Sql "SELECT count(*) FROM asp_payment WHERE tenant_id='critical' AND request_key='same-request';").Trim() -ne '1' -or $payments.Contains('RECORDED')){throw 'Duplicate request created another payment'}
    $checks.Add('payment-request-competing-transactions'); Write-Host 'PASS payment-request-competing-transactions'; $completed=$true
} finally {
    foreach($worker in $workers){if(!$worker.HasExited){$worker.Kill($true); $worker.WaitForExit(5000) | Out-Null}; $worker.Dispose()}
    if($created){
        & $docker exec aisports-dev-postgres dropdb -U $env:POSTGRES_USER --force $db
        Assert-NativeExit 'Temporary database cleanup'
    }
    & $docker exec aisports-dev-postgres rm -f $dump
    Assert-NativeExit 'Schema dump cleanup'
    @{scope='Real PostgreSQL storage tests, not complete service acceptance';completed=$completed;checks=$checks.ToArray();temporaryDatabaseRemoved=$created;time=[DateTimeOffset]::Now.ToString('o')} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $outDir 'database-results.json') -Encoding utf8
}
Write-Host "DATABASE PASS $($checks.Count) checks; temporary database removed"
