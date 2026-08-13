<#
.SYNOPSIS
  Erzeugt variants\<name>\SYS1.qsf aus den gemeinsamen und den boardspezifischen Teilen.

.DESCRIPTION
  Die .qsf wurde frueher je Variante von Hand gepflegt. Bei vier Varianten sind das
  vier Stellen, an denen jede neue .vhd eingetragen werden muss - in zwei von ihnen
  standen deshalb zwei Zeilen fuer Dateien, die es gar nicht mehr gab. Die Datei
  wird jetzt zusammengesetzt aus:

    scripts\common_header.tcl   globale Assignments, in jeder Variante gleich
    variants\<n>\device.tcl     FAMILY, DEVICE, LAST_QUARTUS_VERSION
    variants\<n>\pins.tcl       die set_location_assignment-Zeilen
    scripts\files_common.tcl    Quellen, die jede Variante braucht, inkl. top\SYS1.vhd
    scripts\files_<family>.tcl  die Megafunctions, ausgewaehlt ueber RtlFamily
    scripts\files_<option>.tcl  je Eintrag in Options (heute keiner definiert)

  RtlFamily, Options und VirtualPins kommen aus variants\<n>\variant.psd1.

  Optionale Top-Level-Ports, die ein Board nicht hat, bekommen VIRTUAL_PIN. Das ist
  keine Kosmetik: fuer Quartus ist ein deklarierter Ausgangsport ohne Location ein
  BENUTZTER Pin, RESERVE_ALL_UNUSED_PINS greift nicht, und er wird auf einem echten,
  womoeglich beschalteten Pin platziert und getrieben. Bei GottFA1 betrifft das
  LED_Test, USB_Rx und USB_Tx - die gibt es nur auf der HW-v2.0x-Platine.

.PARAMETER Variants
  Welche Varianten erzeugt werden. Default: alle Ordner unter variants\ mit variant.psd1.

.PARAMETER Check
  Nicht schreiben. Den erzeugten Inhalt gegen die .qsf auf der Platte halten und den
  Unterschied melden. Exitcode 1, wenn etwas abweicht.

.PARAMETER Quiet
  Schreiben wie sonst, aber nur die Varianten melden, deren .qsf vorher NICHT
  uebereinstimmte - also die, in die etwas ausserhalb von gen_qsf hineingeschrieben
  hat. In der Praxis heisst das: Quartus, weil das Projekt in der IDE offen war.
  Fuer die Aufrufe am Kopf von check.ps1 / build.ps1, wo die normale Liste nur Laerm ist.

.EXAMPLE
  .\gen_qsf.ps1

.EXAMPLE
  .\gen_qsf.ps1 -Check
#>
param(
    [string[]]$Variants,
    [switch]  $Check,
    [switch]  $Quiet
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir
$VarRoot   = Join-Path $RepoRoot 'variants'
$Project   = 'SYS1'
$enc       = New-Object System.Text.UTF8Encoding($false)

function Read-Fragment([string]$Path) {
    if (-not (Test-Path $Path)) { throw "Fragment fehlt: $Path" }
    # Den eigenen Kopfkommentar des Fragments verwerfen - die erzeugte Datei
    # bekommt ihren eigenen.
    return @(Get-Content $Path | Where-Object { $_ -notmatch '^\s*#' -and $_.Trim() -ne '' })
}

$folders = @(Get-ChildItem $VarRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'variant.psd1') })
if ($Variants) { $folders = @($folders | Where-Object { $Variants -contains $_.Name }) }
# Eine Variante mit eigenem Top-Level oder eigenen eingefrorenen Modulkopien passt
# nicht in dieses Modell; ihre .qsf bleibt von Hand gepflegt und wird mit
# Generated = $false markiert. Heute ist keine in diesem Zustand - der Notausgang
# steht fuer das naechste unfertige Board bereit.
$folders = @($folders | Where-Object {
    $meta = Import-PowerShellDataFile (Join-Path $_.FullName 'variant.psd1')
    -not ($meta.ContainsKey('Generated') -and -not $meta.Generated)
})
if (-not $folders) { throw "keine erzeugbaren Varianten unter $VarRoot gefunden" }

$common = Read-Fragment (Join-Path $ScriptDir 'common_header.tcl')
$fail   = $false

foreach ($dir in $folders) {
    $meta = Import-PowerShellDataFile (Join-Path $dir.FullName 'variant.psd1')

    $out = New-Object System.Collections.Generic.List[string]
    $out.Add('# ---------------------------------------------------------------------------')
    $out.Add('# ERZEUGTE DATEI - nicht von Hand aendern.')
    $out.Add('#')
    $out.Add("# Variante: $($meta.Name) - $($meta.Title)")
    $out.Add('# Erzeugt : scripts\gen_qsf.ps1')
    $out.Add('# Quellen : scripts\common_header.tcl, device.tcl, pins.tcl,')
    $out.Add('#           scripts\files_common.tcl + files_<family>.tcl + files_<option>.tcl')
    $out.Add('#')
    $out.Add('# device.tcl / pins.tcl / variant.psd1 oder die Dateilisten aendern, dann')
    $out.Add('# gen_qsf.ps1 erneut laufen lassen. Aenderungen direkt in dieser Datei sind')
    $out.Add('# beim naechsten Lauf weg - und Quartus schreibt selbst hinein, sobald das')
    $out.Add('# Projekt in der IDE offen ist. Deshalb erzeugen check.ps1 und build.ps1 die')
    $out.Add('# Datei neu, bevor sie bauen.')
    $out.Add('# ---------------------------------------------------------------------------')
    $out.Add('')
    $out.Add('# --- Board -----------------------------------------------------------------')
    # Welche Entity das Top-Level ist. Alle vier GottFA1-Boards benutzen das
    # gemeinsame Top-Level; der Schluessel TopEntity existiert fuer ein Board, das
    # eine Huelle darum braucht (WillFA7 brauchte eine fuer Cyclone II, wo Quartus 13
    # VIRTUAL_PIN ignoriert).
    $topEntity = $Project
    if ($meta.TopEntity) { $topEntity = $meta.TopEntity }
    $out.Add("set_global_assignment -name TOP_LEVEL_ENTITY $topEntity")
    Read-Fragment (Join-Path $dir.FullName 'device.tcl') | ForEach-Object { $out.Add($_) }
    $out.Add('')
    $out.Add('# --- gemeinsame globale Assignments -----------------------------------------')
    $common | ForEach-Object { $out.Add($_) }

    if ($meta.VirtualPins -and @($meta.VirtualPins).Count -gt 0) {
        $out.Add('')
        $out.Add('# --- optionale Top-Level-Ports, die dieses Board nicht hat -------------------')
        $out.Add('# Sie bleiben in der Portliste, damit alle Varianten EIN Top-Level teilen.')
        $out.Add('# VIRTUAL_PIN haelt Quartus davon ab, sie auf einen echten Pin zu legen und')
        $out.Add('# zu treiben.')
        foreach ($p in @($meta.VirtualPins)) {
            $out.Add("set_instance_assignment -name VIRTUAL_PIN ON -to $p")
        }
    }

    $out.Add('')
    $out.Add('# --- Pins -------------------------------------------------------------------')
    Read-Fragment (Join-Path $dir.FullName 'pins.tcl') | ForEach-Object { $out.Add($_) }

    $out.Add('')
    $out.Add('# --- Quellen ----------------------------------------------------------------')
    Read-Fragment (Join-Path $ScriptDir 'files_common.tcl') | ForEach-Object { $out.Add($_) }
    Read-Fragment (Join-Path $ScriptDir "files_$($meta.RtlFamily).tcl") | ForEach-Object { $out.Add($_) }
    foreach ($opt in @($meta.Options)) {
        if (-not $opt) { continue }
        Read-Fragment (Join-Path $ScriptDir "files_$opt.tcl") | ForEach-Object { $out.Add($_) }
    }

    $text = ($out -join "`r`n") + "`r`n"
    $qsf  = Join-Path $dir.FullName "$Project.qsf"

    if ($Check) {
        $have = if (Test-Path $qsf) { [System.IO.File]::ReadAllText($qsf) } else { '' }
        if ($have -eq $text) {
            Write-Host ("  {0,-22} aktuell" -f $meta.Name) -ForegroundColor Green
        } else {
            Write-Host ("  {0,-22} WEICHT AB" -f $meta.Name) -ForegroundColor Red
            $fail = $true
            $d = Compare-Object ($have -split "`r`n") ($text -split "`r`n")
            $d | ForEach-Object { Write-Host ("      {0} {1}" -f $_.SideIndicator, $_.InputObject) }
        }
    } else {
        $had = if (Test-Path $qsf) { [System.IO.File]::ReadAllText($qsf) } else { '' }
        [System.IO.File]::WriteAllText($qsf, $text, $enc)
        if ($Quiet) {
            # Eine Zeile wert: die Datei auf der Platte war nicht das, was dieses
            # Skript erzeugt - jemand, in der Praxis Quartus, hat in eine erzeugte
            # Datei hineingeschrieben.
            if ($had -ne $text) {
                Write-Host ("  {0,-22} .qsf neu geschrieben, sie war ausserhalb von gen_qsf geaendert worden" -f $meta.Name) -ForegroundColor Yellow
            }
        } else {
            Write-Host ("  {0,-22} geschrieben ({1} Zeilen)" -f $meta.Name, $out.Count) -ForegroundColor Green
        }
    }
}

if ($fail) { exit 1 }
