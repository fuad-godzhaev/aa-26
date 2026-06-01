# Windows wrapper for Godot Web export. On first run (templates missing) it
# downloads + unpacks the .tpz from the upstream Godot release, then invokes
# godot.exe --headless to produce the .html/.js/.wasm/.pck bundle.
#
# Communicates with the editor via three files in the output dir:
#   state.json     atomic write per phase, polled by the JS store
#   manifest.json  written once after Godot succeeds
#   export.exit    integer exit code, written last
# export.log is for humans only.
#
# Both POSIX-style (--log-path) and PowerShell-style (-LogPath) flag names
# are accepted. Args are parsed manually so empty-string values pass through.
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments=$true)] [string[]] $Rest
)

$ErrorActionPreference = 'Stop'

$LogPath = ''
$ExitFile = ''
$OutputDir = ''
$WebTpl = ''
$TplDir = ''
$TpzPath = ''
$TpzExtractDir = ''
$Url = ''
$GodotBin = ''
$IndexHtml = ''
$ProjectPath = ''
$StateFile = ''
$ManifestFile = ''

if ($Rest) {
    for ($i = 0; $i -lt $Rest.Count; $i++) {
        $tok = $Rest[$i]
        if ($i + 1 -ge $Rest.Count) { break }
        $val = $Rest[$i + 1]
        switch ($tok) {
            '--log-path'        { $LogPath       = $val; $i++ }
            '--exit-file'       { $ExitFile      = $val; $i++ }
            '--output-dir'      { $OutputDir     = $val; $i++ }
            '--web-tpl'         { $WebTpl        = $val; $i++ }
            '--tpl-dir'         { $TplDir        = $val; $i++ }
            '--tpz-path'        { $TpzPath       = $val; $i++ }
            '--tpz-extract-dir' { $TpzExtractDir = $val; $i++ }
            '--url'             { $Url           = $val; $i++ }
            '--godot-bin'       { $GodotBin      = $val; $i++ }
            '--index-html'      { $IndexHtml     = $val; $i++ }
            '--project-path'    { $ProjectPath   = $val; $i++ }
            '--state-file'      { $StateFile     = $val; $i++ }
            '--manifest-file'   { $ManifestFile  = $val; $i++ }
            default { throw "Unknown flag: $tok" }
        }
    }
}

$requiredParams = @(
    @{Name='LogPath';       Val=$LogPath},
    @{Name='ExitFile';      Val=$ExitFile},
    @{Name='OutputDir';     Val=$OutputDir},
    @{Name='IndexHtml';     Val=$IndexHtml},
    @{Name='StateFile';     Val=$StateFile},
    @{Name='ManifestFile';  Val=$ManifestFile},
    @{Name='WebTpl';        Val=$WebTpl},
    @{Name='TplDir';        Val=$TplDir},
    @{Name='TpzPath';       Val=$TpzPath},
    @{Name='TpzExtractDir'; Val=$TpzExtractDir},
    @{Name='Url';           Val=$Url},
    @{Name='GodotBin';      Val=$GodotBin},
    @{Name='ProjectPath';   Val=$ProjectPath}
)
foreach ($pair in $requiredParams) {
    if ([string]::IsNullOrEmpty($pair.Val)) {
        throw ("Missing required parameter: " + $pair.Name)
    }
}

# Atomic state writer. Writes a temp file then renames it to the target so
# the editor never observes a partially-written state.json. Move-Item -Force
# is atomic on NTFS for same-volume renames.
function Write-State {
    param(
        [Parameter(Mandatory=$true)] [string] $Phase,
        [Nullable[long]] $BytesDone = $null,
        [Nullable[long]] $BytesTotal = $null,
        [string] $ErrorMessage = $null
    )
    $obj = [ordered]@{
        phase = $Phase
        progress = $null
        error = $null
        updatedAt = ([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ'))
    }
    if ($null -ne $BytesDone -and $null -ne $BytesTotal) {
        $obj.progress = [ordered]@{
            bytesDone = [long]$BytesDone
            bytesTotal = [long]$BytesTotal
        }
    }
    if (-not [string]::IsNullOrEmpty($ErrorMessage)) {
        $obj.error = $ErrorMessage
    }
    $json = $obj | ConvertTo-Json -Compress -Depth 5
    $tmp = "$StateFile.tmp"
    [System.IO.File]::WriteAllText($tmp, $json)
    Move-Item -Force $tmp $StateFile
}

try {
    if (-not (Test-Path $WebTpl)) {
        Add-Content $LogPath 'Downloading Godot export templates (~750MB, one-time setup)...'
        Write-State -Phase 'download' -BytesDone 0 -BytesTotal 0
        New-Item -ItemType Directory -Force -Path $TplDir | Out-Null
        Add-Type -AssemblyName System.Net.Http
        $client = [System.Net.Http.HttpClient]::new()
        $client.Timeout = [TimeSpan]::FromMinutes(30)
        $resp = ($client.GetAsync($Url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead)).Result
        $resp.EnsureSuccessStatusCode() | Out-Null
        $total = $resp.Content.Headers.ContentLength
        if (-not $total) { $total = 0 }
        $stream = ($resp.Content.ReadAsStreamAsync()).Result
        $out = [System.IO.File]::Create($TpzPath)
        $buf = New-Object byte[] 1048576
        $sum = 0
        $lastLog = [DateTime]::UtcNow.AddSeconds(-2)
        while (($n = $stream.Read($buf, 0, $buf.Length)) -gt 0) {
            $out.Write($buf, 0, $n)
            $sum += $n
            if (([DateTime]::UtcNow - $lastLog).TotalSeconds -ge 1) {
                Write-State -Phase 'download' -BytesDone $sum -BytesTotal $total
                $lastLog = [DateTime]::UtcNow
            }
        }
        $out.Close()
        $stream.Close()
        $client.Dispose()
        Write-State -Phase 'extract'
        Add-Content $LogPath 'Extracting templates...'
        New-Item -ItemType Directory -Force -Path $TpzExtractDir | Out-Null
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($TpzPath, $TpzExtractDir)
        Get-ChildItem -Path (Join-Path $TpzExtractDir 'templates') | Move-Item -Destination $TplDir -Force
        Remove-Item -Recurse -Force $TpzExtractDir, $TpzPath
        Write-State -Phase 'installing'
        Add-Content $LogPath 'Templates installed.'
    }
} catch {
    Add-Content $LogPath $_.Exception.Message
    Write-State -Phase 'failed' -ErrorMessage $_.Exception.Message
    [System.IO.File]::WriteAllText($ExitFile, '90')
    exit 90
}

Write-State -Phase 'exporting'
Add-Content $LogPath 'Starting Godot export...'

# Godot ships as a GUI subsystem PE, which makes PowerShell's `&` operator
# return immediately for it (PS does not wait on GUI subsystem natives even
# with `*>>` redirection, even though the process keeps running detached).
# Use Start-Process -Wait + RedirectStandardOutput/Error to (a) guarantee a
# real synchronous wait and (b) capture stdout/stderr into a temp file we
# then append to the human-readable log.
$godotStdout = "$LogPath.godot.stdout.tmp"
$godotStderr = "$LogPath.godot.stderr.tmp"
$proc = Start-Process -FilePath $GodotBin `
    -ArgumentList @('--headless', '--export-release', 'Web', $IndexHtml, '--path', $ProjectPath) `
    -RedirectStandardOutput $godotStdout `
    -RedirectStandardError $godotStderr `
    -NoNewWindow -PassThru -Wait
$godotExit = $proc.ExitCode
foreach ($p in @($godotStdout, $godotStderr)) {
    if (Test-Path $p) {
        Get-Content -Raw $p | ForEach-Object { Add-Content -Path $LogPath -Value $_ }
        Remove-Item -Force $p
    }
}

if ($godotExit -ne 0) {
    Write-State -Phase 'failed' -ErrorMessage ("Godot export exited with code " + $godotExit)
    [System.IO.File]::WriteAllText($ExitFile, [string]$godotExit)
    exit $godotExit
}

Write-State -Phase 'verifying'

# Cross-process FS visibility race: index.html may not be flushed/visible to
# the editor process for a moment after Godot exits. Wait up to 15 s for it
# to appear before declaring failure.
$deadline = (Get-Date).AddSeconds(15)
while (-not (Test-Path $IndexHtml) -and (Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 200
}

if (-not (Test-Path $IndexHtml)) {
    $msg = "index.html not produced after 15s wait: $IndexHtml"
    Add-Content $LogPath $msg
    Write-State -Phase 'failed' -ErrorMessage $msg
    [System.IO.File]::WriteAllText($ExitFile, '91')
    exit 91
}

# Enumerate output files for the manifest. Excludes our own bookkeeping
# files plus any leftovers from the (already-cleaned) template install.
try {
    $excluded = @('export.log', 'export.exit', 'state.json', 'manifest.json', 'templates.tpz')
    $entries = @()
    Get-ChildItem -Path $OutputDir -File -Force | Where-Object { $excluded -notcontains $_.Name } | ForEach-Object {
        $entries += [ordered]@{
            name = $_.Name
            sizeBytes = [long]$_.Length
        }
    }
    $manifestObj = [ordered]@{ files = @($entries) }
    $manifestJson = $manifestObj | ConvertTo-Json -Compress -Depth 5
    $tmpManifest = "$ManifestFile.tmp"
    [System.IO.File]::WriteAllText($tmpManifest, $manifestJson)
    Move-Item -Force $tmpManifest $ManifestFile
} catch {
    Add-Content $LogPath ("Manifest write failed: " + $_.Exception.Message)
    Write-State -Phase 'failed' -ErrorMessage $_.Exception.Message
    [System.IO.File]::WriteAllText($ExitFile, '92')
    exit 92
}

Write-State -Phase 'done'
[System.IO.File]::WriteAllText($ExitFile, '0')
exit 0
