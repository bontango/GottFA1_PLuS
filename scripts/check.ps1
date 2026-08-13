<#
.SYNOPSIS
  Baut die GottFA1_PLuS-Varianten und stellt Ergebnis, Ressourcen und Timing in einer
  Tabelle gegenueber.

.DESCRIPTION
  Durchsucht variants\ nach Unterordnern mit einer *.qpf, waehlt die zur FAMILY-Zeile
  der *.qsf passende Quartus-Installation und laesst Analysis & Synthesis laufen,
  auf Wunsch zusaetzlich Fitter und Timing Analyzer. Danach werden map.rpt / fit.rpt /
  sta.rpt ausgewertet und - ausser bei -NoBaseline - gegen scripts\baseline.csv gehalten.

  Ohne Schalter laeuft nur quartus_map: schnell, faengt Syntax- und Elaborationsfehler.
  Ressourcen- und Timing-Zahlen brauchen -Fit.

  Varianten mit Dormant = $true in ihrer variant.psd1 werden uebersprungen. Heute ist
  keine dormant.

.PARAMETER Root
  Ordner mit den Variantenordnern. Default: variants\ neben diesem Skript.

.PARAMETER Variants
  Ordnernamen, die geprueft werden sollen. Default: alle aktiven.

.PARAMETER Fit
  Zusaetzlich Fitter und Timing Analyzer (liefert LE / Slack).

.PARAMETER Full
  Kompletter Flow (map+fit+asm+sta), erzeugt die .sof.

.PARAMETER All
  Auch die als Dormant markierten Varianten pruefen.

.PARAMETER NoBaseline
  Nicht gegen scripts\baseline.csv vergleichen.

.PARAMETER NoGen
  Die .qsf vorher nicht neu erzeugen. Nur zum absichtlichen Pruefen einer von Hand
  geaenderten - der naechste Lauf ohne den Schalter wirft die Aenderung wieder weg.

.EXAMPLE
  .\check.ps1 -Fit

.EXAMPLE
  .\check.ps1 -Variants hw21x_cyclone_10 -Fit
#>
param(
    [string]  $Root,
    [string[]]$Variants,
    [switch]  $Fit,
    [switch]  $Full,
    [switch]  $All,
    [switch]  $NoBaseline,
    [switch]  $NoGen
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot  = Split-Path -Parent $ScriptDir
$Project   = 'SYS1'
$OwnRoot   = -not $Root
if (-not $Root) { $Root = Join-Path $RepoRoot 'variants' }

# Quartus schreibt die .qsf selbst um, sobald das Projekt in der IDE offen war. Die
# .qsf ist eine erzeugte Datei, also vor allem anderen neu erzeugen. Sonst
# beschreiben die Zahlen unten ein Projekt, das niemand aus device.tcl / pins.tcl /
# variant.psd1 reproduzieren kann. Still, solange nichts zurueckgesetzt werden musste.
if ($OwnRoot -and -not $NoGen) { & (Join-Path $ScriptDir 'gen_qsf.ps1') -Quiet }

# Ab welcher Slack-Drift gemeldet wird und unter welchem Absolutwert der Slack
# unabhaengig von der Baseline auffaellig ist.
#
# Slack haengt von der Platzierung ab; bei byte-gleichen Quellen wurden auf dieser
# Familie schon mehr als 1 ns Unterschied zwischen zwei Laeufen gemessen. Eine
# Toleranz darunter erzeugt nur Fehlalarme.
#
# SlackFloor ist an DIESEM Design gemessen, nicht aus AtariFA uebernommen. Verglichen
# wird der schlechteste Wert ueber alle Analysearten, und das ist hier ein HOLD-Wert:
# Hold ist eine Min-Delay-Pruefung, die der Fitter durch Einfuegen von Verzoegerung
# gerade eben erfuellt. Die Messung vom 13.08.2026 im alten Baum ergab 0,136 bis
# 0,151 ns Hold gegenueber 5,9 bis 7,0 ns Setup. Der AtariFA-Wert von 1,0 haette
# also bei JEDEM Lauf gefeuert und die Spalte wertlos gemacht.
$SlackTolerance = 1.5
$SlackFloor     = 0.05

# ---------------------------------------------------------------------------
# Quartus-Installationen. Schluessel = Teilstring des FAMILY-Werts der .qsf,
# DEFAULT gilt, wenn nichts passt. quartus_sh liegt hier nicht im PATH.
#
# Zwei Chipfamilien heissen NICHT zwei Quartus-Versionen: 22.1std baut Cyclone IV E
# und Cyclone 10 LP gleichermassen, deshalb genuegt hier eine Zeile. Die Tabellenform
# steht fuer den Fall, dass einmal eine Familie dazukommt, die die aktuelle Version
# nicht mehr kennt (Cyclone II braeuchte 13.0sp1). Die anderen Installationen auf
# dieser Maschine (C:\intelFPGA\23.1std) sind nur Programmer - nicht hierher zeigen.
# ---------------------------------------------------------------------------
$QuartusBin = [ordered]@{
    'DEFAULT' = 'C:\intelFPGA_lite\22.1std\quartus\bin64'
}

function Get-QuartusBin([string]$Family) {
    foreach ($key in $QuartusBin.Keys) {
        if ($key -eq 'DEFAULT') { continue }
        if ($Family -like "*$key*") { return $QuartusBin[$key] }
    }
    return $QuartusBin['DEFAULT']
}

# Erste Zahl aus Zeilen wie "; Total logic elements ; 5,458 / 6,272 ( 87 % ) ;"
function Get-ReportValue([string]$Path, [string]$Label) {
    if (-not (Test-Path $Path)) { return $null }
    $line = Select-String -Path $Path -Pattern ("^;\s+" + [regex]::Escape($Label) + "\s+;") -List
    if ($null -eq $line) { return $null }
    $parts = $line.Line -split ';'
    if ($parts.Count -lt 3) { return $null }
    if ($parts[2].Trim() -match '([\d,]+)') { return [int](($Matches[1]) -replace ',','') }
    return $null
}

# Die Netzliste, direkt aus Analysis & Synthesis: kombinatorische Funktionen,
# Register, Speicherbits. DIESE Zahlen sind eine Eigenschaft des Designs und muessen
# exakt zur Baseline passen.
#
# Die "Total logic elements" des Fitters duerfen dafuer NICHT benutzt werden. Ein
# einziger zusaetzlicher Knoten reicht, damit der Fitter die LEs anders packt - ein
# exakter Test darauf meldet eine Aenderung, die es nicht gibt. Die Zahl wird nur
# mitgefuehrt.
function Get-SynthNumbers([string]$MapPath) {
    $r = @{ Comb = $null; Reg = $null; Mem = $null }
    if (-not (Test-Path $MapPath)) { return $r }
    $m = Select-String -Path $MapPath -Pattern '^;\s+Total combinational functions\s+;\s+([\d,]+)' -List
    if ($m) { $r.Comb = [int](($m.Matches[0].Groups[1].Value) -replace ',','') }
    $m = Select-String -Path $MapPath -Pattern '^;\s+Total registers\s+;\s+([\d,]+)' -List
    if ($m) { $r.Reg  = [int](($m.Matches[0].Groups[1].Value) -replace ',','') }
    $m = Select-String -Path $MapPath -Pattern '^;\s+Total memory bits\s+;\s+([\d,]+)' -List
    if ($m) { $r.Mem  = [int](($m.Matches[0].Groups[1].Value) -replace ',','') }
    return $r
}

# Schlechtester Slack ueber alle Clocks, aus der jeweiligen Summary-Tabelle.
# Vorsicht: "... Model Setup Summary" steht auch im Inhaltsverzeichnis des .rpt, und
# direkt hinter der Tabelle folgen andere mit voellig anderen Zahlen. Die Tabelle
# wird deshalb streng begrenzt: nur Zeilen, die mit ';' oder '+' beginnen, die erste
# Zeile ohne dieses Muster beendet sie.
function Get-Slack([string]$StaPath, [string]$Kind) {
    if (-not (Test-Path $StaPath)) { return $null }
    $inTable = $false
    $worst   = $null
    foreach ($line in Get-Content $StaPath) {
        if (-not $inTable) {
            # Nur echte Abschnittsueberschriften, nicht die Inhaltsverzeichniszeile ("  12. Slow ...")
            if ($line -match "Model $Kind Summary" -and $line -notmatch '^\s*\d+\.\s') { $inTable = $true }
            continue
        }
        if ($line -notmatch '^\s*[;+]') { $inTable = $false; continue }
        # Datenzeile "; <clock> ; <slack> ; <tns> ;" - die Kopfzeile hat in Spalte 2
        # Text und faellt daher durch das Zahlenmuster.
        if ($line -match '^;\s+\S.*?;\s+(-?\d+(?:\.\d+)?)\s+;') {
            $val = [double]$Matches[1]
            if ($null -eq $worst -or $val -lt $worst) { $worst = $val }
        }
    }
    if ($null -eq $worst) { return $null }
    return $worst.ToString('0.000', [System.Globalization.CultureInfo]::InvariantCulture)
}

# Warnungs-FINGERABDRUCK statt einer Zeilenliste.
#
# AtariFA listet einzelne Warnungscodes als Klartextzeilen auf. Das geht dort, weil
# das Design fast warnungsfrei ist. GottFA1 ist gewachsener Bestand und erzeugt je
# Lauf 27 bis 31 Warnungen (Stand 13.08.2026: 8x 10036, 5x 10492, 6x 10920, ...) -
# eine Zeilenliste waere reines Rauschen, und eine Spalte, die bei jedem Lauf schreit,
# liest niemand mehr.
#
# Stattdessen wird ein Abzug "code:anzahl,code:anzahl,..." gebildet und gegen die
# Baseline gehalten. Eine NEUE Warnungsklasse oder eine geaenderte Anzahl faellt damit
# sofort auf, ohne dass der bekannte Altbestand jedes Mal ausgedruckt wird.
function Get-WarnFingerprint([string]$RptPath) {
    if (-not (Test-Path $RptPath)) { return '' }
    $codes = @(Select-String -Path $RptPath -Pattern '^(?:Critical )?Warning \((\d+)\)' |
               ForEach-Object { $_.Matches[0].Groups[1].Value })
    if (-not $codes) { return '' }
    return (($codes | Group-Object | Sort-Object Name | ForEach-Object { "$($_.Name):$($_.Count)" }) -join ',')
}

# "22.1std" aus dem Installationspfad
function Get-QuartusLabel([string]$BinPath) {
    if ($BinPath -match '\\([^\\]+)\\quartus\\bin') { return $Matches[1] }
    return $BinPath
}

# ---------------------------------------------------------------------------

if (-not (Test-Path $Root)) { throw "Root nicht gefunden: $Root" }

$found = @(Get-ChildItem -Path $Root -Directory | Where-Object {
    Get-ChildItem -Path $_.FullName -Filter '*.qpf' -File -ErrorAction SilentlyContinue
})
if ($Variants) {
    $found = @($found | Where-Object { $Variants -contains $_.Name })
}
elseif (-not $All) {
    $found = @($found | Where-Object {
        $meta = Join-Path $_.FullName 'variant.psd1'
        if (-not (Test-Path $meta)) { return $true }
        -not (Import-PowerShellDataFile $meta).Dormant
    })
}
if (-not $found) { throw "Keine Variantenordner mit *.qpf unter $Root" }

$baseline = @{}
$baselineFile = Join-Path $ScriptDir 'baseline.csv'
if (-not $NoBaseline -and (Test-Path $baselineFile)) {
    foreach ($row in (Import-Csv $baselineFile -Delimiter ';')) { $baseline[$row.Variant] = $row }
}

$mode = 'map'
if ($Fit)  { $mode = 'fit'  }
if ($Full) { $mode = 'full' }
Write-Host "Modus: $mode - $($found.Count) Variante(n) unter $Root" -ForegroundColor Cyan

$results = @()

foreach ($dir in $found) {
    $qsf = Join-Path $dir.FullName "$Project.qsf"

    $family = ''
    $device = ''
    if (Test-Path $qsf) {
        $fLine = Select-String -Path $qsf -Pattern '-name FAMILY\s+"?([^"\r\n]+)"?' -List
        if ($fLine) { $family = $fLine.Matches[0].Groups[1].Value.Trim().Trim('"') }
        $dLine = Select-String -Path $qsf -Pattern '-name DEVICE\s+(\S+)' -List
        if ($dLine) { $device = $dLine.Matches[0].Groups[1].Value.Trim() }
    }

    $bin = Get-QuartusBin $family
    Write-Host ("  {0,-22} {1,-16} {2}" -f $dir.Name, $family, (Get-QuartusLabel $bin))

    $status = 'ok'
    $firstError = ''

    Push-Location $dir.FullName
    try {
        $steps = @()
        switch ($mode) {
            'map'  { $steps = @(@{exe='quartus_map.exe'; args=@($Project)}) }
            'fit'  { $steps = @(@{exe='quartus_map.exe'; args=@($Project)},
                                @{exe='quartus_fit.exe'; args=@($Project)},
                                @{exe='quartus_sta.exe'; args=@($Project)}) }
            'full' { $steps = @(@{exe='quartus_sh.exe';  args=@('--flow','compile',$Project)}) }
        }

        foreach ($step in $steps) {
            $exe = Join-Path $bin $step.exe
            if (-not (Test-Path $exe)) { $status = 'quartus fehlt'; $firstError = $exe; break }
            # KEIN 2>&1: in Windows PowerShell 5.1 verpackt das jede stderr-Zeile eines
            # nativen Programms in einen ErrorRecord und setzt $? auf $false, auch bei
            # Exitcode 0 - und Quartus schreibt dort eine harmlose TBBmalloc-Notiz hin.
            # $LASTEXITCODE ist die verlaessliche Auskunft, die Error-Zeilen stehen
            # ohnehin auch auf stdout.
            $out = & $exe $step.args
            if ($LASTEXITCODE -ne 0) {
                $status = "FEHLER ($($step.exe))"
                $err = $out | Select-String -Pattern '^Error \(' | Select-Object -First 1
                if ($err) { $firstError = $err.Line.Trim() }
                break
            }
        }
    }
    finally { Pop-Location }

    # Die Berichte nur auswerten, wenn der Lauf sauber war. Sonst stammen die Zahlen
    # aus einem frueheren Build und behaupten etwas ueber Code, der sich gerade nicht
    # einmal uebersetzen liess.
    $le = $null; $mem = $null; $slk = $null; $hold = $null; $pins = $null; $wfp = ''
    $syn = @{ Comb = $null; Reg = $null; Mem = $null }
    if ($status -eq 'ok') {
        $of  = Join-Path $dir.FullName 'output_files'
        $map = Join-Path $of "$Project.map.rpt"
        $wfp = Get-WarnFingerprint $map
        # Die Netzlistenzahlen kommen aus dem Mapper und stehen in jedem Modus bereit.
        $syn = Get-SynthNumbers $map
        $mem = $syn.Mem
        if ($mode -ne 'map') {
            $le   = Get-ReportValue (Join-Path $of "$Project.fit.rpt") 'Total logic elements'
            $pins = Get-ReportValue (Join-Path $of "$Project.fit.rpt") 'Total pins'
            $slk  = Get-Slack (Join-Path $of "$Project.sta.rpt") 'Setup'
            $hold = Get-Slack (Join-Path $of "$Project.sta.rpt") 'Hold'
        }
    }

    # Baseline-Vergleich. Comb/Reg/Mem sind das Design und werden in jedem Modus
    # geprueft; Slack braucht den Timing Analyzer, also nur mit -Fit / -Full. Die
    # LE-Zahl des Fitters wird gemeldet, aber bewusst NICHT verglichen.
    $delta = ''
    if ($status -eq 'ok' -and $baseline.ContainsKey($dir.Name)) {
        $b = $baseline[$dir.Name]
        $bits = @()
        if ($null -ne $syn.Comb -and $syn.Comb -ne [int]$b.Comb) { $bits += ("Comb {0:+#;-#;0}" -f ($syn.Comb - [int]$b.Comb)) }
        if ($null -ne $syn.Reg  -and $syn.Reg  -ne [int]$b.Reg)  { $bits += ("Reg {0:+#;-#;0}"  -f ($syn.Reg  - [int]$b.Reg))  }
        if ($null -ne $syn.Mem  -and $syn.Mem  -ne [int]$b.Mem)  { $bits += ("Mem {0:+#;-#;0}"  -f ($syn.Mem  - [int]$b.Mem))  }
        if ($slk) {
            $d = [double]$slk - [double]$b.Slack
            if ([math]::Abs($d) -gt $SlackTolerance) { $bits += ("Slack {0:+0.000;-0.000}" -f $d) }
        }
        # Absolutwert getrennt pruefen: der schlechteste Slack ist hier ein Hold-Wert.
        if ($hold -and [double]$hold -lt $SlackFloor) { $bits += ("Hold nur $hold ns") }
        if ($b.PSObject.Properties.Name -contains 'Warn' -and $b.Warn -and $wfp -ne $b.Warn) {
            $bits += 'Warnungen geaendert'
        }
        if ($bits) { $delta = $bits -join ', ' } else { $delta = '=' }
    }

    if ($status -ne 'ok')               { Write-Host "       -> $status" -ForegroundColor Red }
    elseif ($delta -and $delta -ne '=') { Write-Host "       -> ok, aber Baseline-Abweichung: $delta" -ForegroundColor Yellow }
    else                                { Write-Host '       -> ok' -ForegroundColor Green }
    # Den Fingerabdruck nur zeigen, wenn er sich bewegt hat - dann aber vollstaendig,
    # damit sichtbar ist, WELCHE Warnungsklasse dazukam oder verschwand.
    if ($delta -like '*Warnungen geaendert*') {
        Write-Host ("          Baseline: {0}" -f $baseline[$dir.Name].Warn) -ForegroundColor DarkYellow
        Write-Host ("          jetzt   : {0}" -f $wfp) -ForegroundColor DarkYellow
    }

    $results += [pscustomobject]@{
        Variant = $dir.Name
        Device  = $device
        Status  = $status
        Comb    = $syn.Comb
        Reg     = $syn.Reg
        Memory  = $mem
        LEfit   = $le
        Pins    = $pins
        Slack   = $slk
        Hold    = $hold
        Delta   = $delta
        Warn    = $wfp
        Error   = $firstError
    }
}

Write-Host ''
$results | Format-Table Variant, Device, Status, Comb, Reg, Memory, LEfit, Pins, Slack, Hold, Delta -AutoSize

$bad = @($results | Where-Object { $_.Status -ne 'ok' })
if ($bad) {
    Write-Host 'Fehler:' -ForegroundColor Red
    $bad | ForEach-Object { Write-Host "  $($_.Variant): $($_.Error)" }
    exit 1
}
$drift = @($results | Where-Object { $_.Delta -and $_.Delta -ne '=' })
if ($drift) {
    Write-Host 'Baseline-Abweichung:' -ForegroundColor Yellow
    $drift | ForEach-Object { Write-Host "  $($_.Variant): $($_.Delta)" }
    exit 2
}
Write-Host 'Alle Varianten sauber.' -ForegroundColor Green
