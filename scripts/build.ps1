<#
.SYNOPSIS
  Vollstaendiger Compile EINER GottFA1_PLuS-Variante, plus die .jic fuer den seriellen
  Konfigurationsbaustein.

.DESCRIPTION
  Laesst quartus_sh --flow compile in variants\<name>\ laufen und danach quartus_cpf
  gegen die SYS1.cof der Variante. Die .sof kommt aus dem Flow, die .jic NICHT - sie
  muss konvertiert werden, und genau das beschreibt die .cof.

  quartus_cpf laeuft mit dem Variantenordner als Arbeitsverzeichnis, die Pfade in der
  .cof muessen also relativ dazu sein (output_files/SYS1.sof). Sie waren frueher
  absolut, und die .cof von CycloneIV_v3 zeigte damit auf die .sof von v4 - ein
  quartus_cpf dort haette stillschweigend das Bitfile des falschen Boards verpackt.
  Quartus die Pfade nicht wieder absolut schreiben lassen.

  Gegenprobe nach dem Lauf: die .jic-Groesse ist geraetetypisch. Cyclone IV (EP4CE6)
  liefert 2.097.375 Byte, Cyclone 10 (10CL006Y) 2.097.377 Byte. Gleiche Groesse bei
  ungleicher Familie hiesse, zwei .cof zeigen auf dasselbe Board.

  ExtraArtifacts in variant.psd1 (heute nur 'rbf' bei hw20x_cyclone_iv_v7) erzeugt
  Quartus selbst, ueber eine Assignment-Zeile in device.tcl. Hier wird nur geprueft,
  dass die Datei da ist und aus DIESEM Compile stammt - eine alte .rbf neben einer
  neuen .sof waere ein falsches Release.

.PARAMETER Variant
  Ordnername unter variants\, z. B. hw21x_cyclone_10.

.PARAMETER NoGen
  Die .qsf vorher nicht neu erzeugen.

.PARAMETER NoJic
  Nach dem Compile aufhoeren, kein quartus_cpf.

.EXAMPLE
  .\build.ps1 hw21x_cyclone_10
#>
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string] $Variant,
    [switch] $NoGen,
    [switch] $NoJic
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir
$VarDir    = Join-Path (Join-Path $RepoRoot 'variants') $Variant
if (-not (Test-Path $VarDir)) { throw "unbekannte Variante: $Variant (gesucht in $RepoRoot\variants)" }

$QuartusBin = 'C:\intelFPGA_lite\22.1std\quartus\bin64'
$Project    = 'SYS1'

if (-not $NoGen) { & (Join-Path $ScriptDir 'gen_qsf.ps1') -Variants $Variant -Quiet }

$meta = Import-PowerShellDataFile (Join-Path $VarDir 'variant.psd1')
Write-Host "Baue $($meta.Name) - $($meta.Title)" -ForegroundColor Cyan

Push-Location $VarDir
try {
    $sh = Join-Path $QuartusBin 'quartus_sh.exe'
    if (-not (Test-Path $sh)) { throw "quartus_sh nicht gefunden: $sh" }
    $compileStart = Get-Date
    & $sh --flow compile $Project
    if ($LASTEXITCODE -ne 0) { throw "Compile fehlgeschlagen fuer $Variant (Exit $LASTEXITCODE)" }

    $sof = Join-Path $VarDir "output_files\$Project.sof"
    if (-not (Test-Path $sof)) { throw "Compile meldet Erfolg, aber $sof fehlt" }
    Write-Host '  .sof ok' -ForegroundColor Green

    foreach ($ext in @($meta.ExtraArtifacts)) {
        if (-not $ext) { continue }
        $extra = Join-Path $VarDir "output_files\$Project.$ext"
        if (-not (Test-Path $extra)) { throw "ExtraArtifacts nennt '$ext', aber $extra fehlt (Assignment in device.tcl?)" }
        if ((Get-Item $extra).LastWriteTime -lt $compileStart) { throw "$extra ist aelter als dieser Compile - nicht aus diesem Lauf" }
        Write-Host ("  .{0} ok ({1:N0} Byte)" -f $ext, (Get-Item $extra).Length) -ForegroundColor Green
    }

    if (-not $NoJic -and $meta.ReleaseArtifact -eq 'jic') {
        $cpf = Join-Path $QuartusBin 'quartus_cpf.exe'
        if (-not (Test-Path $cpf)) { throw "quartus_cpf nicht gefunden: $cpf" }
        & $cpf -c "$Project.cof"
        if ($LASTEXITCODE -ne 0) { throw "quartus_cpf fehlgeschlagen fuer $Variant (Exit $LASTEXITCODE)" }
        $jic = Join-Path $VarDir "output_files\$Project.jic"
        if (-not (Test-Path $jic)) { throw "quartus_cpf meldet Erfolg, aber $jic fehlt" }
        Write-Host ("  .jic ok ({0:N0} Byte)" -f (Get-Item $jic).Length) -ForegroundColor Green
    }
}
finally { Pop-Location }

Write-Host "Fertig: variants\$Variant\output_files\" -ForegroundColor Green
