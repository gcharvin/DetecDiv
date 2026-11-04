param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputPath = ''
)
$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
if (-not $OutputPath) { $OutputPath = Join-Path $RepoRoot 'docs/DETECTIVE_UI_SCORE_SOURCE_INVENTORY.csv' }
$sourcePath = Join-Path $RepoRoot 'structure/GUI/score/private/score_runtime_code.m'
$source = [IO.File]::ReadAllText($sourcePath)
$sourceRel = 'structure/GUI/score/private/score_runtime_code.m'
$rows = [Collections.Generic.List[object]]::new()
function Add-Row($kind,$name,$file,$line,$bindings,$note) {
    $rows.Add([pscustomobject][ordered]@{Kind=$kind; Name=$name; Source=$file; Line=$line; Bindings=$bindings; StaticNote=$note})
}
function Source-Line($text,$offset) { 1 + ([regex]::Matches($text.Substring(0,$offset),"`n")).Count }
$bindings = @{}
$bindingPattern = 'app\.(\w+)\.(\w+)\s*=\s*createCallbackFcn\(app,\s*@(\w+)'
foreach ($match in [regex]::Matches($source,$bindingPattern)) {
    $callback = $match.Groups[3].Value
    if (-not $bindings.ContainsKey($callback)) { $bindings[$callback] = @() }
    $bindings[$callback] += $match.Groups[1].Value+'.'+$match.Groups[2].Value
}
$pattern = '(?m)^\s*function\s+(?:(?:\[[^\]\r\n]+\]|\w+)\s*=\s*)?(\w+)\s*\('
$functions = [regex]::Matches($source,$pattern)
for ($i=0; $i -lt $functions.Count; $i++) {
    $match = $functions[$i]; $name = $match.Groups[1].Value
    $end = $source.Length
    if ($i+1 -lt $functions.Count) { $end = $functions[$i+1].Index }
    $body = $source.Substring($match.Index,$end-$match.Index)
    $lines = $body -split '\r?\n' | Where-Object {
        $_ -notmatch '^\s*(%.*)?$' -and $_ -notmatch '^\s*(function\b.*|end\s*;?|methods\b.*)\s*$'
    }
    $note = 'Source declaration; not a runtime validation'
    if (-not $lines) { $note = 'Empty body (comments/terminators only)' }
    Add-Row 'Function' $name $sourceRel (Source-Line $source $match.Groups[1].Index) ($bindings[$name] -join '; ') $note
}
foreach ($match in [regex]::Matches($source,'(?m)^\s*(\w+)\s+(matlab\.ui\.[\w.]+)\s*$')) {
    Add-Row 'Component' $match.Groups[1].Value $sourceRel (Source-Line $source $match.Groups[1].Index) '' $match.Groups[2].Value
}
# Runtime anonymous callbacks include generated controls, dynamic menus and Movie* binding loops.
foreach ($match in [regex]::Matches($source,'(?m)^.*(?:Fcn|Callback)\s*=\s*@.*$')) {
    Add-Row 'DynamicBinding' '' $sourceRel (Source-Line $source $match.Index) '' $match.Value.Trim()
}
$scoreFolder = Join-Path $RepoRoot 'structure/GUI/score'
foreach ($file in (Get-ChildItem -LiteralPath $scoreFolder -Filter '*.m' -File | Sort-Object Name)) {
    $text = [IO.File]::ReadAllText($file.FullName)
    $match = [regex]::Match($text,$pattern)
    if ($match.Success) {
        Add-Row 'Helper' $match.Groups[1].Value ('structure/GUI/score/'+$file.Name) (Source-Line $text $match.Groups[1].Index) '' 'Top-level helper; may still depend on a Score app handle'
    }
}
foreach ($file in (Get-ChildItem -LiteralPath (Join-Path $scoreFolder 'tests') -Filter '*.m' -File | Sort-Object Name)) {
    Add-Row 'TestFile' $file.BaseName ('structure/GUI/score/tests/'+$file.Name) 1 '' 'Existing regression source; not executed by this audit'
}
Add-Row 'SourceHash' 'SHA256' $sourceRel 1 '' (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash
$rows | Export-Csv -LiteralPath $OutputPath -NoTypeInformation -Encoding utf8
$rows | Group-Object Kind | Select-Object Name,Count | Format-Table -AutoSize
Write-Output "Inventory written: $OutputPath"
