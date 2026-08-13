<#
.SYNOPSIS
  Baut jede aktive GottFA1_PLuS-Variante und legt die Artefakte nach bin\<BinFolder>\.

.DESCRIPTION
  Ein Release ist EINE Version ueber alle Boards: die Software-Ziffern stehen in
  rtl\common\version_pkg.vhd (SW_SUB), die Board-Kennung je Variante in
  variants\<n>\variant_pkg.vhd. Jedes hier gebaute Board zeigt auf seiner
  Boot-Anzeige "V <BoardId><SW_SUB> ".

  Genau das war vorher das Problem: die Ziffer stand in jeder der vier Kopien des
  Top-Levels, und die Kopien liefen auseinander - CycloneIV_v3 zeigte "V 901",
  hatte aber nur den 8.01-Code, und kollidierte damit mit dem ausgelieferten
  Cyclone-10-Build gleicher Nummer.

  Der Dateiname traegt die Version, der Ordner das Board. Nichts wird stillschweigend
  ueberschrieben: eine schon vorhandene Datei gleichen Namens bricht den Lauf ab,
  ausser mit -Force.

  Das changelog wird nur angehaengt und ist der Ort fuer das, was NICHT getestet ist -
  hw21x_cyclone_iv_v3 lief noch nie auf Hardware.

.PARAMETER Note
  Eine Zeile, die dieses Release beschreibt. Geht nach bin\changelog.txt. Pflicht.

.PARAMETER Variants
  Auf diese Varianten beschraenken. Default: alle, die nicht Dormant sind.

.PARAMETER Force
  Artefakte ueberschreiben, die es in bin\ schon gibt.

.EXAMPLE
  .\release.ps1 -Note "gemeinsamer Sourcebaum, alle Boards auf SW .03"
#>
param(
    [Parameter(Mandatory=$true)]
    [string]  $Note,
    [string[]]$Variants,
    [switch]  $Force
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir
$VarRoot   = Join-Path $RepoRoot 'variants'
$BinRoot   = Join-Path $RepoRoot 'bin'
$Project   = 'SYS1'

# Die gemeinsame Software-Ziffer aus version_pkg.vhd lesen - keine zweite Stelle,
# die synchron gehalten werden muss, und ein Tippfehler dort faellt als falscher
# Dateiname auf, bevor etwas ausgeliefert wird.
$vpkg = Get-Content (Join-Path $RepoRoot 'rtl\common\version_pkg.vhd') -Raw
if ($vpkg -notmatch 'SW_SUB\s*:\s*string\(1 to 2\)\s*:=\s*"(\d{2})"') {
    throw 'SW_SUB nicht in rtl\common\version_pkg.vhd gefunden'
}
$sub = $Matches[1]

$folders = @(Get-ChildItem $VarRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'variant.psd1') })
if ($Variants) { $folders = @($folders | Where-Object { $Variants -contains $_.Name }) }
else           { $folders = @($folders | Where-Object { -not (Import-PowerShellDataFile (Join-Path $_.FullName 'variant.psd1')).Dormant }) }
if (-not $folders) { throw "nichts zu releasen unter $VarRoot" }

New-Item -ItemType Directory -Force $BinRoot | Out-Null
$made = @()

foreach ($dir in $folders) {
    $meta = Import-PowerShellDataFile (Join-Path $dir.FullName 'variant.psd1')

    # Gegenprobe: die BoardId aus variant.psd1 muss zu der Konstante im variant_pkg.vhd
    # passen, das tatsaechlich mitkompiliert wird. Sonst traegt die Datei eine Nummer,
    # die das Board gar nicht anzeigt.
    $vp = Get-Content (Join-Path $dir.FullName 'variant_pkg.vhd') -Raw
    if ($vp -notmatch "BOARD_ID\s*:\s*character\s*:=\s*'(.)'") {
        throw "BOARD_ID nicht in variants\$($meta.Name)\variant_pkg.vhd gefunden"
    }
    if ($Matches[1] -ne $meta.BoardId) {
        throw "BoardId '$($meta.BoardId)' in variant.psd1 passt nicht zu BOARD_ID '$($Matches[1])' in variant_pkg.vhd ($($meta.Name))"
    }

    $ver = "$($meta.BoardId)$sub"                     # z. B. 903 fuer Board 9, Version .03

    & (Join-Path $ScriptDir 'build.ps1') $meta.Name
    if ($LASTEXITCODE -ne 0) { throw "Build fehlgeschlagen fuer $($meta.Name)" }

    $ext = $meta.ReleaseArtifact                      # 'jic' oder 'sof'
    $src = Join-Path $dir.FullName "output_files\$Project.$ext"
    if (-not (Test-Path $src)) { throw "Artefakt fehlt: $src" }

    $outDir = Join-Path $BinRoot $meta.BinFolder
    New-Item -ItemType Directory -Force $outDir | Out-Null
    $dst = Join-Path $outDir "GottFA1_PLuS_v$ver.$ext"
    if ((Test-Path $dst) -and -not $Force) { throw "$dst existiert bereits - SW_SUB in rtl\common\version_pkg.vhd erhoehen oder -Force" }
    Copy-Item $src $dst -Force

    $hash = (Get-FileHash $dst -Algorithm SHA256).Hash.Substring(0,16)
    $made += [pscustomobject]@{
        Variant = $meta.Name
        Version = "$($meta.BoardId).$sub"
        Bytes   = (Get-Item $dst).Length
        File    = $dst
        SHA256  = $hash
    }
}

# Die .jic-Groesse ist geraetetypisch (EP4CE6 = 2.097.375, 10CL006Y = 2.097.377).
# Wenn zwei Varianten unterschiedlicher Familie dieselbe Groesse liefern, zeigen ihre
# .cof auf dasselbe Board - genau der Fehler, den v3 vor dem Umbau hatte.
$byFamily = $made | Group-Object Bytes
if (@($byFamily).Count -eq 1 -and @($made).Count -gt 1) {
    Write-Host 'WARNUNG: alle Artefakte sind gleich gross. Bei gemischten Chipfamilien pruefen, ob die .cof auf das richtige Board zeigen.' -ForegroundColor Yellow
}

$log = Join-Path $BinRoot 'changelog.txt'
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
$lines = @('', "$stamp  Version .$sub", "  $Note")
foreach ($m in $made) { $lines += ("  {0,-22} {1,-6} {2,-28} {3,10:N0} B  sha256:{4}" -f $m.Variant, $m.Version, (Split-Path $m.File -Leaf), $m.Bytes, $m.SHA256) }
Add-Content -Path $log -Value $lines -Encoding UTF8

$made | Format-Table Variant, Version, Bytes, File, SHA256 -AutoSize
Write-Host "changelog: $log" -ForegroundColor Green
Write-Host 'In VARIANTEN.md eintragen, welches dieser Boards tatsaechlich auf Hardware war.' -ForegroundColor Yellow
