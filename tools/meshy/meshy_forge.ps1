#requires -Version 5.1
<#
.SYNOPSIS
  Manifest-driven Meshy.ai text-to-3D batch generator for THE BIG NAP
  (soft_landing). Ported from the proven sibling pipeline at
  D:\Projects\un_party_game\tools\meshy_forge.ps1 (18/18 KEEP rate across
  four batches) — same request shapes, same failure/retry handling, same
  PowerShell footguns documented inline. Adapted paths/manifest schema/
  house style only.

.DESCRIPTION
  Reads tools/meshy/manifest.json (array of {id, category, prompt,
  target_height_hint}), submits a text-to-3D PREVIEW per asset (model
  meshy-6, lowpoly/triangle/target_polycount 8000/should_remesh true, ART
  _BIBLE.md house-style suffix appended), polls to completion, submits a
  REFINE for every asset whose preview succeeded (enable_pbr false — house
  style is flat, matte, no textures), polls those, and downloads the
  finished GLBs to assets/models/meshy/generated/<id>.glb (the D10 import
  seam every ModelSlot reads from).

  Writes tools/meshy/forge_report.json: one entry per manifest id with
  {id, category, prompt, full_prompt, preview_task, preview_status,
  refine_task, refine_status, credits, served_model, status, glb_path,
  error}, plus a summary block. `served_model` is whatever model identifier
  the API itself echoes back on the task object (checked across a few
  plausible field names since the current text-to-3d docs, per
  docs/research/pipeline.md, do not show one in the sample response) — if
  the API never echoes one, the field says so explicitly rather than
  silently assuming the request was honored.

  Windows PowerShell 5.1+ / PowerShell 7. Never writes the API key to any
  file, log, or report; it is read from the .env at runtime into a process
  variable only.

.PARAMETER DryRun
  Parse the manifest, build the full prompts and batch plan, and print what
  WOULD be submitted — no HTTP calls, no credits spent. For verifying the
  script before spending the real budget.

.PARAMETER PreviewOnly
  Stop after preview (download the untextured preview GLB instead of
  refining). Useful for a fast geometry-only sanity pass.

.PARAMETER Resume
  Skip any id whose GLB already exists in the output directory. Prior
  report entries for skipped ids are carried forward into the new report.

.PARAMETER Only
  Comma-separated list of manifest ids to process (everything else is
  skipped as if -Resume had already downloaded it). Used for a targeted
  single-asset retry after a failure.

.PARAMETER BatchSize
  Max tasks in flight at once per phase (preview phase, then refine
  phase). Kept well under the paid-tier queued-task cap (10-20+; see
  docs/research/pipeline.md §1.2 UNVERIFIED note on tier-cap flux).

.EXAMPLE
  pwsh -File tools\meshy\meshy_forge.ps1 -DryRun
  pwsh -File tools\meshy\meshy_forge.ps1
  pwsh -File tools\meshy\meshy_forge.ps1 -Only lantern
  pwsh -File tools\meshy\meshy_forge.ps1 -Resume
#>
[CmdletBinding()]
param(
    [string]$ManifestPath = '',
    [string]$OutDir       = '',
    [string]$ReportPath   = '',
    [string]$EnvPath      = 'D:\Projects\soft_landing\.env',
    [switch]$DryRun,
    [switch]$PreviewOnly,
    [switch]$Resume,
    [string]$Only = '',
    [int]$BatchSize = 5,
    [int]$PollIntervalSec = 5,
    [int]$TaskTimeoutMin = 15
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# $PSScriptRoot can come back empty depending on how the script was invoked
# (e.g. nested inside another PowerShell host); fall back to the invocation
# path so relative default paths always resolve. (Sibling-proven pattern.)
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $ScriptDir) { $ScriptDir = Split-Path -Parent (Resolve-Path '.\tools\meshy\meshy_forge.ps1' -ErrorAction SilentlyContinue) }
if (-not $ScriptDir) { throw 'Could not resolve tools/meshy script directory; run from the project root or pass -ManifestPath/-OutDir/-ReportPath explicitly.' }
if (-not $ManifestPath) { $ManifestPath = Join-Path $ScriptDir 'manifest.json' }
if (-not $OutDir)       { $OutDir       = Join-Path (Split-Path -Parent (Split-Path -Parent $ScriptDir)) 'assets\models\meshy\generated' }
if (-not $ReportPath)   { $ReportPath   = Join-Path $ScriptDir 'forge_report.json' }

$BaseUri = 'https://api.meshy.ai/openapi/v2/text-to-3d'

# ART_BIBLE.md "Meshy house prompt" — appended verbatim to every prompt so
# Pip/Otto/dreamlings/props never develop a style seam against each other.
$HouseStyleSuffix = 'soft plush low poly, rounded chunky toddler-toy proportions, flat colors, matte, no textures needed, game asset, clean silhouette, single object, gentle and friendly, Kenney/KayKit style'

# --- helpers -------------------------------------------------------------

function Get-MeshyApiKey {
    param([string]$Path)
    if (-not (Test-Path $Path)) { throw "Meshy env file not found: $Path" }
    foreach ($line in (Get-Content -Path $Path)) {
        if ($line -match '^\s*MESHY_API_KEY\s*=\s*(.+?)\s*$') { return $Matches[1] }
    }
    throw "MESHY_API_KEY not found in $Path"
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    $enc = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $enc)
}

# Best-effort extraction of whatever model identifier the API echoes back on
# a task object. The current text-to-3d docs (pipeline.md §1.2) do not show
# a model field in the sample response shape, so this checks a few
# plausible names and honestly records when none was found rather than
# assuming the requested ai_model was silently honored.
function Get-ServedModel {
    param($Task, [string]$Requested)
    foreach ($prop in @('ai_model', 'model', 'model_version', 'served_model')) {
        if ($Task.PSObject.Properties.Match($prop).Count -gt 0 -and $Task.$prop) {
            return [PSCustomObject]@{ value = [string]$Task.$prop; source = $prop }
        }
    }
    return [PSCustomObject]@{ value = $Requested; source = 'not_reported_by_api_echoing_requested' }
}

# Retrying wrapper. Never logs $Headers (would leak the bearer token).
function Invoke-MeshyRequest {
    param(
        [string]$Method,
        [string]$Uri,
        [hashtable]$Headers,
        $BodyObj = $null
    )
    $delays = @(5, 10, 20)
    $attempt = 0
    while ($true) {
        try {
            if ($null -ne $BodyObj) {
                $json = $BodyObj | ConvertTo-Json -Depth 6 -Compress
                return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers -ContentType 'application/json' -Body $json -TimeoutSec 60
            } else {
                return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $Headers -TimeoutSec 60
            }
        } catch {
            $statusCode = $null
            if ($_.Exception.Response) {
                try { $statusCode = [int]$_.Exception.Response.StatusCode } catch { $statusCode = $null }
            }
            $isRetryable = $false
            if ($null -eq $statusCode) { $isRetryable = $true }
            elseif ($statusCode -eq 429) { $isRetryable = $true }
            elseif ($statusCode -ge 500) { $isRetryable = $true }

            if (-not $isRetryable -or $attempt -ge $delays.Count) {
                $bodyText = ''
                if ($_.Exception.Response) {
                    try {
                        $stream = $_.Exception.Response.GetResponseStream()
                        $reader = New-Object System.IO.StreamReader($stream)
                        $bodyText = $reader.ReadToEnd()
                    } catch {}
                }
                throw ("Meshy API error (status=$statusCode): " + $_.Exception.Message + ' body=' + $bodyText)
            }
            $delay = $delays[$attempt]
            Write-Host ('    [retry] status=' + $statusCode + ", waiting ${delay}s...")
            Start-Sleep -Seconds $delay
            $attempt += 1
        }
    }
}

function Submit-Preview {
    param([string]$Prompt, [hashtable]$Headers)
    $body = [ordered]@{
        mode              = 'preview'
        prompt            = $Prompt
        ai_model          = 'meshy-6'
        model_type        = 'lowpoly'
        topology          = 'triangle'
        target_polycount  = 8000
        should_remesh     = $true
        moderation        = $false
        target_formats    = @('glb')
        origin_at         = 'bottom'
    }
    $resp = Invoke-MeshyRequest -Method Post -Uri $BaseUri -Headers $Headers -BodyObj $body
    return $resp.result
}

function Submit-Refine {
    param([string]$PreviewTaskId, [hashtable]$Headers)
    $body = [ordered]@{
        mode            = 'refine'
        preview_task_id = $PreviewTaskId
        ai_model        = 'meshy-6'
        enable_pbr      = $false
        moderation      = $false
        target_formats  = @('glb')
        origin_at       = 'bottom'
    }
    $resp = Invoke-MeshyRequest -Method Post -Uri $BaseUri -Headers $Headers -BodyObj $body
    return $resp.result
}

function Get-Batches {
    param([array]$Items, [int]$Size)
    $batches = @()
    # NOTE: `return $batches` (no leading comma) would let PowerShell enumerate
    # the outer array onto the output pipeline and re-collect it one level
    # flattened, silently turning "N batches of up to $Size" into "N*Size
    # batches of 1". The unary comma suppresses that one level of unrolling.
    if (-not $Items -or $Items.Count -eq 0) { return , $batches }
    for ($i = 0; $i -lt $Items.Count; $i += $Size) {
        $end = [Math]::Min($i + $Size, $Items.Count) - 1
        $batches += ,@($Items[$i..$end])
    }
    return , $batches
}

function Save-Report {
    param($StateMap, [array]$OrderedIds, [string]$Path, [bool]$PreviewOnlyMode)
    $items = @()
    foreach ($id in $OrderedIds) {
        $st = $StateMap[$id]
        $consumed = 0
        if ($st.preview_credits) { $consumed += [int]$st.preview_credits }
        if ($st.refine_credits)  { $consumed += [int]$st.refine_credits }
        if ($st.PSObject.Properties.Match('carried_credits').Count -gt 0 -and $st.carried_credits) {
            $consumed = [int]$st.carried_credits
        }
        $items += [PSCustomObject]@{
            id                 = $st.id
            category           = $st.category
            prompt             = $st.prompt
            full_prompt        = $st.full_prompt
            status             = $st.status
            preview_task       = $st.preview_task_id
            preview_status     = $st.preview_status
            refine_task        = $st.refine_task_id
            refine_status      = $st.refine_status
            credits            = $consumed
            served_model       = $st.served_model
            served_model_source = $st.served_model_source
            glb_path           = $st.glb_path
            error              = $st.error
        }
    }
    # @() wraps every Where-Object result below: a filter that matches exactly
    # one item returns a bare scalar (no .Count property) instead of a
    # 1-element array — the same footgun documented on Get-Batches above.
    $summary = [PSCustomObject]@{
        total            = $items.Count
        ok               = (@($items | Where-Object { $_.status -eq 'ok' })).Count
        preview_only     = (@($items | Where-Object { $_.status -eq 'preview_only' })).Count
        failed           = (@($items | Where-Object { $_.status -eq 'failed' })).Count
        resumed_skip     = (@($items | Where-Object { $_.status -eq 'resumed_skip' })).Count
        total_credits    = ($items | Measure-Object -Property credits -Sum).Sum
    }
    $report = [PSCustomObject]@{
        generated_at = (Get-Date).ToString('o')
        model_requested = 'meshy-6'
        preview_only = $PreviewOnlyMode
        batch_size   = $BatchSize
        items        = $items
        summary      = $summary
    }
    $json = $report | ConvertTo-Json -Depth 8
    Write-Utf8NoBom -Path $Path -Text $json
}

# --- setup -----------------------------------------------------------------

Write-Host 'Meshy Forge — reading API key (never printed)...'
$ApiKey = Get-MeshyApiKey -Path $EnvPath
$Headers = @{ Authorization = ('Bearer ' + $ApiKey) }
Write-Host 'Meshy Forge — API key loaded into memory only.'

if (-not (Test-Path $ManifestPath)) { throw "Manifest not found: $ManifestPath" }
# Two-step, NOT `@(... | ConvertFrom-Json)` directly: ConvertFrom-Json writes
# a parsed JSON array to the pipeline with -NoEnumerate semantics (one array
# object, not one emission per element), so wrapping the live pipeline call
# in @() re-collects that single array-object as ONE element of a NEW outer
# array — silently turning a 4-item manifest into a 1-item manifest whose
# sole "item" is the whole array. Assigning first captures the array as-is;
# @() on the now-plain variable is safe and only kicks in to fix the true
# scalar case. (Sibling-proven footgun, documented there empirically.)
$manifest = Get-Content -Raw -Path $ManifestPath | ConvertFrom-Json
$manifest = @($manifest)
Write-Host ("Manifest: {0} assets from {1}" -f $manifest.Count, $ManifestPath)

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$OnlyList = @()
if ($Only.Trim().Length -gt 0) {
    $OnlyList = @($Only -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 })
}

$oldMap = @{}
if (Test-Path $ReportPath) {
    try {
        $oldReport = Get-Content -Raw -Path $ReportPath | ConvertFrom-Json
        foreach ($it in @($oldReport.items)) { $oldMap[$it.id] = $it }
    } catch {
        Write-Host ('  (could not parse existing report, ignoring: ' + $_.Exception.Message + ')')
    }
}

$toProcess = @()
foreach ($m in $manifest) {
    if ($OnlyList.Count -gt 0 -and ($OnlyList -notcontains $m.id)) { continue }
    $toProcess += $m
}
$orderedIds = @($toProcess | ForEach-Object { $_.id })

$state = @{}
foreach ($m in $toProcess) {
    $glbPath = Join-Path $OutDir ($m.id + '.glb')
    $alreadyDone = $Resume -and (Test-Path $glbPath)
    $obj = [PSCustomObject]@{
        id                  = $m.id
        category            = $m.category
        prompt              = $m.prompt
        target_height_hint  = $m.target_height_hint
        full_prompt         = ($m.prompt + ', ' + $HouseStyleSuffix)
        preview_task_id     = $null
        preview_status      = $null
        preview_credits     = 0
        preview_glb_url     = $null
        preview_retried     = $false
        refine_task_id      = $null
        refine_status       = $null
        refine_credits      = 0
        served_model        = $null
        served_model_source = $null
        status              = $null
        error               = $null
        glb_path            = $null
        carried_credits     = $null
    }
    if ($alreadyDone) {
        $obj.status = 'resumed_skip'
        $obj.glb_path = $glbPath
        if ($oldMap.ContainsKey($m.id)) { $obj.carried_credits = $oldMap[$m.id].credits }
    }
    $state[$m.id] = $obj
}

$active = @($toProcess | Where-Object { $state[$_.id].status -ne 'resumed_skip' })
Write-Host ("Processing {0} assets ({1} resumed-skipped)." -f $active.Count, ($toProcess.Count - $active.Count))

if ($DryRun) {
    Write-Host ''
    Write-Host '================ DRY RUN — nothing submitted, no credits spent ================'
    foreach ($m in $active) {
        $st = $state[$m.id]
        Write-Host ("[{0}] ({1}) height_hint={2}" -f $st.id, $st.category, $st.target_height_hint)
        Write-Host ("  full_prompt: {0}" -f $st.full_prompt)
    }
    Write-Host ("Batches of {0}: preview phase then refine phase, sequential." -f $BatchSize)
    Write-Host ("Output dir: {0}" -f $OutDir)
    Write-Host ("Report path: {0}" -f $ReportPath)
    Write-Host '=================================================================================='
    exit 0
}

# --- phase 1: preview --------------------------------------------------------

$previewBatches = Get-Batches -Items $active -Size $BatchSize
$batchNum = 0
foreach ($batch in $previewBatches) {
    $batchNum += 1
    Write-Host ("`nPREVIEW batch {0}/{1}: {2}" -f $batchNum, $previewBatches.Count, (($batch | ForEach-Object { $_.id }) -join ', '))
    foreach ($m in $batch) {
        $st = $state[$m.id]
        try {
            $taskId = Submit-Preview -Prompt $st.full_prompt -Headers $Headers
            $st.preview_task_id = $taskId
            Write-Host ('  submitted preview ' + $m.id + ' -> ' + $taskId)
        } catch {
            $st.status = 'failed'
            $st.error = 'preview submit: ' + $_.Exception.Message
            Write-Host ('  SUBMIT FAILED ' + $m.id + ': ' + $_.Exception.Message)
        }
        Start-Sleep -Milliseconds 400
    }

    # @() wrap: a batch where exactly one item still needs polling would
    # otherwise collapse to a bare object with no .Count, silently skipping
    # the poll loop below entirely.
    $pending = @($batch | Where-Object { $state[$_.id].preview_task_id -and -not $state[$_.id].status })
    $deadline = (Get-Date).AddMinutes($TaskTimeoutMin)
    while ($pending.Count -gt 0 -and (Get-Date) -lt $deadline) {
        Start-Sleep -Seconds $PollIntervalSec
        $stillPending = @()
        foreach ($m in $pending) {
            $st = $state[$m.id]
            try {
                $task = Invoke-MeshyRequest -Method Get -Uri ($BaseUri + '/' + $st.preview_task_id) -Headers $Headers
            } catch {
                Write-Host ('  POLL ERROR ' + $m.id + ': ' + $_.Exception.Message)
                $stillPending += $m
                continue
            }
            $status = $task.status
            if ($status -eq 'SUCCEEDED') {
                $st.preview_status = 'SUCCEEDED'
                $st.preview_credits = [int]$task.consumed_credits
                $st.preview_glb_url = $task.model_urls.glb
                $served = Get-ServedModel -Task $task -Requested 'meshy-6'
                $st.served_model = $served.value
                $st.served_model_source = $served.source
                Write-Host ('  preview SUCCEEDED ' + $m.id + ' credits=' + $st.preview_credits + ' served_model=' + $served.value + ' (' + $served.source + ')')
            } elseif ($status -eq 'FAILED' -or $status -eq 'CANCELED') {
                $errMsg = $null
                if ($task.task_error -and $task.task_error.message) { $errMsg = $task.task_error.message }
                if (-not $st.preview_retried) {
                    Write-Host ('  preview ' + $status + ' ' + $m.id + ' (' + $errMsg + ') -- retrying once with adjusted prompt')
                    $st.preview_retried = $true
                    $retryPrompt = $st.full_prompt + ', simple clean geometry, single distinct object'
                    try {
                        $newTaskId = Submit-Preview -Prompt $retryPrompt -Headers $Headers
                        $st.preview_task_id = $newTaskId
                        $stillPending += $m
                    } catch {
                        $st.status = 'failed'
                        $st.error = 'preview retry submit: ' + $_.Exception.Message
                    }
                } else {
                    $st.preview_status = $status
                    $st.status = 'failed'
                    $st.error = 'preview ' + $status + ': ' + $errMsg
                    Write-Host ('  preview FAILED (final) ' + $m.id + ': ' + $errMsg)
                }
            } else {
                $stillPending += $m
            }
        }
        $pending = $stillPending
    }
    foreach ($m in $pending) {
        $st = $state[$m.id]
        if (-not $st.status) {
            $st.status = 'failed'
            $st.error = 'preview timeout'
            Write-Host ('  PREVIEW TIMEOUT ' + $m.id)
        }
    }
    Save-Report -StateMap $state -OrderedIds $orderedIds -Path $ReportPath -PreviewOnlyMode ([bool]$PreviewOnly)
}

# --- preview-only mode: download preview GLBs and stop ----------------------

if ($PreviewOnly) {
    foreach ($m in $active) {
        $st = $state[$m.id]
        if ($st.preview_status -eq 'SUCCEEDED' -and -not $st.status) {
            $dest = Join-Path $OutDir ($m.id + '.glb')
            try {
                Invoke-WebRequest -Uri $st.preview_glb_url -OutFile $dest -TimeoutSec 120 -UseBasicParsing
                $st.status = 'preview_only'
                $st.glb_path = $dest
                Write-Host ('  downloaded preview-only GLB: ' + $m.id)
            } catch {
                $st.status = 'failed'
                $st.error = 'preview download failed: ' + $_.Exception.Message
            }
        }
    }
    Save-Report -StateMap $state -OrderedIds $orderedIds -Path $ReportPath -PreviewOnlyMode $true
} else {

    # --- phase 2: refine -----------------------------------------------------

    $readyForRefine = @($active | Where-Object { $state[$_.id].preview_status -eq 'SUCCEEDED' -and -not $state[$_.id].status })
    $refineBatches = Get-Batches -Items $readyForRefine -Size $BatchSize
    $batchNum = 0
    foreach ($batch in $refineBatches) {
        $batchNum += 1
        Write-Host ("`nREFINE batch {0}/{1}: {2}" -f $batchNum, $refineBatches.Count, (($batch | ForEach-Object { $_.id }) -join ', '))
        foreach ($m in $batch) {
            $st = $state[$m.id]
            try {
                $taskId = Submit-Refine -PreviewTaskId $st.preview_task_id -Headers $Headers
                $st.refine_task_id = $taskId
                Write-Host ('  submitted refine ' + $m.id + ' -> ' + $taskId)
            } catch {
                $st.status = 'failed'
                $st.error = 'refine submit: ' + $_.Exception.Message
                Write-Host ('  SUBMIT FAILED ' + $m.id + ': ' + $_.Exception.Message)
            }
            Start-Sleep -Milliseconds 400
        }

        $pending = @($batch | Where-Object { $state[$_.id].refine_task_id -and -not $state[$_.id].status })
        $deadline = (Get-Date).AddMinutes($TaskTimeoutMin)
        while ($pending.Count -gt 0 -and (Get-Date) -lt $deadline) {
            Start-Sleep -Seconds $PollIntervalSec
            $stillPending = @()
            foreach ($m in $pending) {
                $st = $state[$m.id]
                try {
                    $task = Invoke-MeshyRequest -Method Get -Uri ($BaseUri + '/' + $st.refine_task_id) -Headers $Headers
                } catch {
                    Write-Host ('  POLL ERROR ' + $m.id + ': ' + $_.Exception.Message)
                    $stillPending += $m
                    continue
                }
                $status = $task.status
                if ($status -eq 'SUCCEEDED') {
                    $st.refine_status = 'SUCCEEDED'
                    $st.refine_credits = [int]$task.consumed_credits
                    $served = Get-ServedModel -Task $task -Requested 'meshy-6'
                    $st.served_model = $served.value
                    $st.served_model_source = $served.source
                    $dest = Join-Path $OutDir ($m.id + '.glb')
                    try {
                        # model_urls.glb is a presigned, EXPIRING URL — download
                        # immediately on SUCCEEDED, never cache it.
                        Invoke-WebRequest -Uri $task.model_urls.glb -OutFile $dest -TimeoutSec 120 -UseBasicParsing
                        $st.status = 'ok'
                        $st.glb_path = $dest
                        Write-Host ('  refine SUCCEEDED + downloaded ' + $m.id + ' credits=' + $st.refine_credits + ' total=' + ($st.preview_credits + $st.refine_credits))
                    } catch {
                        $st.status = 'failed'
                        $st.error = 'download failed: ' + $_.Exception.Message
                        Write-Host ('  DOWNLOAD FAILED ' + $m.id + ': ' + $_.Exception.Message)
                    }
                } elseif ($status -eq 'FAILED' -or $status -eq 'CANCELED') {
                    $st.refine_status = $status
                    $errMsg = $null
                    if ($task.task_error -and $task.task_error.message) { $errMsg = $task.task_error.message }
                    $st.status = 'failed'
                    $st.error = 'refine ' + $status + ': ' + $errMsg
                    Write-Host ('  refine FAILED ' + $m.id + ': ' + $errMsg)
                } else {
                    $stillPending += $m
                }
            }
            $pending = $stillPending
        }
        foreach ($m in $pending) {
            $st = $state[$m.id]
            if (-not $st.status) {
                $st.status = 'failed'
                $st.error = 'refine timeout'
                Write-Host ('  REFINE TIMEOUT ' + $m.id)
            }
        }
        Save-Report -StateMap $state -OrderedIds $orderedIds -Path $ReportPath -PreviewOnlyMode $false
    }
}

# --- final summary -----------------------------------------------------------

Save-Report -StateMap $state -OrderedIds $orderedIds -Path $ReportPath -PreviewOnlyMode ([bool]$PreviewOnly)
$finalReport = Get-Content -Raw -Path $ReportPath | ConvertFrom-Json

Write-Host ''
Write-Host '================ MESHY FORGE SUMMARY ================'
$byCat = @($finalReport.items) | Group-Object category
foreach ($g in $byCat) {
    $okCount = (@($g.Group | Where-Object { $_.status -eq 'ok' -or $_.status -eq 'preview_only' -or $_.status -eq 'resumed_skip' })).Count
    Write-Host ("[{0}] {1}/{2} ok" -f $g.Name, $okCount, $g.Count)
    foreach ($it in @($g.Group)) {
        Write-Host ("  - {0,-14} {1,-14} credits={2,-4} served_model={3}" -f $it.id, $it.status, $it.credits, $it.served_model)
    }
}
Write-Host ''
Write-Host ('TOTAL: ' + $finalReport.summary.total + '  ok=' + $finalReport.summary.ok + '  preview_only=' + $finalReport.summary.preview_only + '  failed=' + $finalReport.summary.failed + '  resumed_skip=' + $finalReport.summary.resumed_skip)
Write-Host ('TOTAL CREDITS CONSUMED: ' + $finalReport.summary.total_credits)
Write-Host ('Report: ' + $ReportPath)
Write-Host '======================================================='
