<#
  repro-traps: deliberately triggers each "breaks without an error" trap on this machine
  and prints whether it reproduced. Read-only except for files under tmp\traps next to this script.
    powershell -NoProfile -ExecutionPolicy Bypass -File .\repro-traps.ps1 [-SkipClaude] [-SkipSlow]
  REPRODUCED = the trap happened here (a workaround is needed on this machine).
  NOT REPRODUCED = this machine behaves differently (write down your versions).
  ASCII-only file; non-ASCII text is built from code points.
#>
param([switch]$SkipClaude, [switch]$SkipSlow)

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$tmp = Join-Path $here 'tmp\traps'
if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
New-Item -ItemType Directory -Path $tmp | Out-Null
$jp = [string][char]0x65E5 + [char]0x672C      # two kanji
# this Windows' default console code page (932 on Japanese, 437 on US English); the Claude Code
# Bash tool and some terminals switch to 65001, which hides T05 and T09, so use the default instead
$oem = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.OEMCodePage
$rows = @()
# T04-T07 and T13 run python. Without a real interpreter (none on PATH, or only the Microsoft Store
# stub, which prints nothing and exits 9009) their verdicts mean nothing: T05 used to say REPRODUCED.
$pyVer = ''
try { $pyVer = [string]((& python -c "import sys; print('%d.%d.%d' % sys.version_info[:3])" 2>$null) | Select-Object -First 1) } catch {}
$pyIds = @('T04', 'T05', 'T06', 'T07', 'T13')
function Add([string]$id, [string]$trap, [bool]$repro, [string]$evidence) {
    $res = $(if ($repro) { 'REPRODUCED' } else { 'NOT REPRODUCED' })
    if (($pyIds -contains $id) -and [string]::IsNullOrEmpty($pyVer)) { $res = 'CANNOT CHECK'; $evidence = 'no real python (not on PATH, or only the Store stub)' }
    $script:rows += [pscustomobject]@{ Id = $id; Trap = $trap; Result = $res; Evidence = $evidence }
}
function PS-File([string]$f, [string[]]$a = @()) { & powershell.exe @(@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $f) + $a) }

# T01 exit code collapses with -Command
$x = Join-Path $tmp 'exit2.ps1'; [IO.File]::WriteAllText($x, "exit 2`r`n")
PS-File $x | Out-Null; $a = $LASTEXITCODE
& powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '$x'" | Out-Null; $b = $LASTEXITCODE
Add 'T01' '-Command turns exit 2 into 1' ($a -eq 2 -and $b -eq 1) "-File=$a -Command=$b"

# T02 -File drops extra args silently (no CmdletBinding) / errors (with CmdletBinding)
$p1 = Join-Path $tmp 'arr.ps1'; [IO.File]::WriteAllText($p1, "param([string[]]`$Path)`r`n`"count=`$(`$Path.Count) first=`$(`$Path[0])`"`r`n")
$o = (PS-File $p1 @('-Path', 'a', 'b') | Out-String).Trim(); $c1 = $LASTEXITCODE
# the same call against a script with [CmdletBinding()] should stop with an error instead
$p1b = Join-Path $tmp 'arr_cb.ps1'; [IO.File]::WriteAllText($p1b, "[CmdletBinding()]`r`nparam([string[]]`$Path)`r`n`"count=`$(`$Path.Count) first=`$(`$Path[0])`"`r`n")
PS-File $p1b @('-Path', 'a', 'b') 2>$null | Out-Null; $c1b = $LASTEXITCODE
Add 'T02' '-File drops the extra value b silently' ($o -eq 'count=1 first=a' -and $c1 -eq 0) "$o exit=$c1 (with CmdletBinding: exit=$c1b)"
$o2 = (PS-File $p1 @('-Path', 'a,b') | Out-String).Trim()
Add 'T03' '-File keeps a,b as one string' ($o2 -eq 'count=1 first=a,b') $o2

# T04 Japanese piped to a native program becomes ? (default $OutputEncoding)
$py = Join-Path $tmp 'hex.py'; [IO.File]::WriteAllText($py, "import sys`nprint(sys.stdin.buffer.read().strip().hex())`n")
$saved = $OutputEncoding
$global:OutputEncoding = [System.Text.Encoding]::ASCII
$h = ($jp | & python $py | Out-String).Trim()
$global:OutputEncoding = $saved
Add 'T04' 'Japanese piped to python arrives as ?' ($h -eq '3f3f') "bytes=$h"

# T05 UTF-8 output read with the default console encoding becomes mojibake
$py2 = Join-Path $tmp 'say.py'; [IO.File]::WriteAllText($py2, "import sys`nsys.stdout.buffer.write((chr(0x65e5)+chr(0x672c)).encode('utf-8'))`n")
$savedC = [Console]::OutputEncoding
[Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding($oem)
$s = (& python $py2 | Out-String).Trim()
[Console]::OutputEncoding = $savedC
Add 'T05' "UTF-8 output read as cp$oem is mojibake" ($s -ne $jp) ("got " + (($s.ToCharArray() | ForEach-Object { '{0:X4}' -f [int]$_ }) -join ' '))

# T06 redirected python output crashes without PYTHONIOENCODING
# U+2014 is outside cp932 but inside cp1252; U+2713 (check mark) is outside both, so print both
$py3 = Join-Path $tmp 'dash.py'; [IO.File]::WriteAllText($py3, "print('a'+chr(0x2014)+chr(0x2713)+'b')`n")
$savedPie = $env:PYTHONIOENCODING; $env:PYTHONIOENCODING = $null
& cmd.exe /c "python `"$py3`" > `"$tmp\dash.txt`" 2> `"$tmp\dash.err`""
$e6 = $LASTEXITCODE; $err6 = [IO.File]::ReadAllText("$tmp\dash.err")
Add 'T06' 'redirected print of U+2014/U+2713 crashes' ($e6 -ne 0 -and $err6 -match 'UnicodeEncodeError') "exit=$e6"

# T07 python -I ignores PYTHONIOENCODING
$env:PYTHONIOENCODING = 'utf-8'
& cmd.exe /c "python -I `"$py3`" > `"$tmp\dash2.txt`" 2> `"$tmp\dash2.err`""
$e7 = $LASTEXITCODE
& cmd.exe /c "python `"$py3`" > `"$tmp\dash3.txt`" 2> `"$tmp\dash3.err`""
$e7b = $LASTEXITCODE
$env:PYTHONIOENCODING = $savedPie
Add 'T07' 'python -I ignores PYTHONIOENCODING' ($e7 -ne 0 -and $e7b -eq 0) "with -I exit=$e7, without -I exit=$e7b"

# T08 .ps1 with Japanese and no BOM
$nb = Join-Path $tmp 'nobom.ps1'; [IO.File]::WriteAllText($nb, ("Write-Output `"" + $jp + "`"`r`n"), (New-Object Text.UTF8Encoding $false))
$o8 = (PS-File $nb 2>&1 | Out-String).Trim(); $e8 = $LASTEXITCODE
Add 'T08' 'BOM-less Japanese .ps1 fails or prints mojibake' ($o8 -ne $jp) ("exit=$e8")

# T09 .cmd saved with LF runs comment text as commands
$lf = Join-Path $tmp 'lf.cmd'
[IO.File]::WriteAllText($lf, ("@echo off`nrem " + $jp + $jp + $jp + " comment`nrem " + $jp + " more`necho START`necho END`n"), [Text.Encoding]::GetEncoding(932))
# cmd.exe reads the batch file with the console code page: the breakage showed under 932
# (default on Japanese Windows) and not under 65001, 437 or 1252, so run it under this
# machine's default and 65001 and report both
$savedC9 = [Console]::OutputEncoding
$r9 = @{}
foreach ($cp in @($oem, 65001 | Select-Object -Unique)) {
    [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding($cp)
    $o9 = (& cmd.exe /c $lf 2>&1 | Out-String)
    $r9[$cp] = (($LASTEXITCODE -ne 0) -or ($o9 -match 'cmd.exe :') -or ($o9 -notmatch 'START'))
}
[Console]::OutputEncoding = $savedC9
$ev9 = (@($r9.Keys | Sort-Object | ForEach-Object { "cp$_=" + $(if ($r9[$_]) { 'broken' } else { 'ok' }) })) -join ' '
Add 'T09' ".cmd with LF runs comment text (console code page $oem)" $r9[$oem] $ev9

# T10 one-liner: outer PowerShell expands $i first
# the caller expands $i (empty) before the child PowerShell sees it -> "foreach ( in 1..2)"
$o10 = (& powershell.exe -NoProfile -Command "foreach ($i in 1..2) { $i }" 2>&1 | Out-String); $e10 = $LASTEXITCODE
Add 'T10' 'one-liner: caller expands $i first, child gets a syntax error' ($e10 -ne 0) ("exit=$e10")

# T11 Get-ChildItem -LiteralPath ignores -Include on PS 5.1
$inc = Join-Path $tmp 'inc'; New-Item -ItemType Directory $inc | Out-Null
[IO.File]::WriteAllText("$inc\a.ps1", 'x'); [IO.File]::WriteAllText("$inc\b.md", 'x')
$n11 = @(Get-ChildItem -LiteralPath $inc -Recurse -File -Include *.ps1).Count
Add 'T11' 'Get-ChildItem -LiteralPath ignores -Include' ($n11 -eq 2) "matched $n11 files for -Include *.ps1 (expected 1)"

# T12 double-quoted here-string eats Markdown backtick spans
$t12 = "use `night-shift and `true."
Add 'T12' 'backtick n / t inside "..." become newline / tab' (($t12 -match "`n") -or ($t12 -match "`t")) ("length=" + $t12.Length + " contains newline=" + ($t12 -match "`n"))

# T13 directory listing shows 0 bytes for a file being written (under AppData)
if (-not $SkipSlow) {
    $ad = Join-Path $env:LOCALAPPDATA 'cc-win-kit-trap'
    New-Item -ItemType Directory $ad -Force | Out-Null
    $log = Join-Path $ad 'w.log'; [IO.File]::WriteAllText($log, '')
    $wpy = Join-Path $tmp 'writer.py'
    [IO.File]::WriteAllText($wpy, "import sys,time`nf=open(sys.argv[1],'a')`nf.write('x'*5000000)`nf.flush()`ntime.sleep(20)`nf.close()`n")
    $proc = Start-Process python -ArgumentList @("`"$wpy`"", "`"$log`"") -PassThru -WindowStyle Hidden
    Start-Sleep -Seconds 5
    $listed = (Get-ChildItem -LiteralPath $ad -Filter 'w.log').Length
    $fs = New-Object IO.FileStream($log, 'Open', 'Read', 'ReadWrite'); $real = $fs.Length; $fs.Close()
    $proc.WaitForExit()
    Remove-Item -LiteralPath $log -Force; Remove-Item -LiteralPath $ad -Force
    Add 'T13' 'listing shows a stale size while writing (AppData)' ($listed -ne $real) "listed=$listed real=$real"
}

# T14 claude: prompt after --allowedTools is swallowed
if (-not $SkipClaude) {
    $o14 = (& claude -p --allowedTools Read 'say hi' 2>&1 | Out-String)
    Add 'T14' 'claude -p --allowedTools X "prompt" swallows the prompt' ($o14 -match 'Input must be provided') (($o14.Trim() -split "`n")[0])
}

$rows | Format-Table -AutoSize -Wrap | Out-String -Width 220
'PowerShell ' + $PSVersionTable.PSVersion + ' / ' + ((& python --version) 2>&1) + ' / ' + (Get-Date -Format 'yyyy-MM-dd')
