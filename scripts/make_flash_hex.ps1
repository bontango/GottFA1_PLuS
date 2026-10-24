<#
.SYNOPSIS
  Builds the Intel HEX file with the game ROMs for the configuration flash
  (rtl/common/Flash_ROM.vhd, since x.30).

.DESCRIPTION
  The SD card stays the one source of the game data. This script takes an image of
  the whole card (GottFA1_SD_Image_v200.img and later, written by make_sd_v200.bat)
  and copies every game slot byte for byte into the flash:

      card    sector 660 + n * 32     game n, 16 KByte
      flash   080000h + n * 4000h     game n, 16 KByte  -> games 0..15 up to 0BFFFFh

  16 games, because the game is selected with the four sw1 DIPs. Games whose U5 part
  is completely FF or 00 are left out, so that part of the flash stays erased -
  Flash_ROM.vhd then shows ERROR for that game instead of running it.

  No CRC, neither on the card nor in the flash.

  THE RESULT CONTAINS COPYRIGHTED GAME ROMS. variants\<name>\gottfa1_roms.cof expects
  it at output_files\gottfa1_roms.hex (ignored by git). The .jic made from it may lie
  in bin\ as *_roms.jic for local use - .gitignore keeps it away from GitHub.

.PARAMETER Image
  Image of a GottFA1 SD card (raw sectors).

.PARAMETER Out
  The .hex file to write (for quartus_cpf -> *_roms.jic).

.PARAMETER Bin
  Also (or instead) write the ROM area as a raw binary: flash 080000h..0BFFFFh, all
  16 slots, left-out games as FF like erased flash. This is what the ESP32 on the
  Cyclone IV board v7 writes into the EPCS (FA_Control, tile 09 FPGA, address
  0x080000, bits NOT reversed - unlike a .rbf). At least one of -Out / -Bin.

.PARAMETER Games
  How many games at most. Default 16.

.EXAMPLE
  .\make_flash_hex.ps1 -Image "N:\Projekte\FPGA System1\GottFA1_SD_Image_v200.img" -Out ..\variants\hw21x_cyclone_10\output_files\gottfa1_roms.hex

.EXAMPLE
  .\make_flash_hex.ps1 -Image "N:\Projekte\FPGA System1\GottFA1_SD_Image_v200.img" -Bin ..\variants\hw20x_cyclone_iv_v7\output_files\gottfa1_roms.bin
#>
param(
    [Parameter(Mandatory = $true)][string]$Image,
    [string]$Out,
    [string]$Bin,
    [int]$Games = 16
)
if (-not $Out -and -not $Bin) { throw 'Give -Out (Intel HEX) and/or -Bin (raw ROM area).' }

$ErrorActionPreference = 'Stop'

# card layout, see rtl/common/SD_Card.vhd (selection * 32 + 660)
$FirstSector = 660
$SlotBytes   = 16384      # 32 sectors
# flash layout, see rtl/common/Flash_ROM.vhd
$FlashBase   = 0x080000
$FlashSlot   = 0x4000

Add-Type -TypeDefinition @'
using System;
using System.Text;
public static class GottFAFlash {
    public static bool Blank(byte[] d, int off, int len) {
        byte f = d[off];
        if (f != 0xFF && f != 0x00) return false;
        for (int i = 1; i < len; i++) if (d[off + i] != f) return false;
        return true;
    }
    static void Rec(StringBuilder sb, int type, int addr, byte[] d, int off, int len) {
        int sum = len + ((addr >> 8) & 0xFF) + (addr & 0xFF) + type;
        sb.AppendFormat(":{0:X2}{1:X4}{2:X2}", len, addr & 0xFFFF, type);
        for (int i = 0; i < len; i++) { sb.AppendFormat("{0:X2}", d[off + i]); sum += d[off + i]; }
        sb.AppendFormat("{0:X2}\r\n", (-sum) & 0xFF);
    }
    // Intel HEX with type 04 records for the upper address half, absolute addresses.
    public static void Data(StringBuilder sb, int addr, byte[] d, int off, int len) {
        int upper = -1;
        for (int p = 0; p < len; p += 16) {
            int a = addr + p;
            if ((a >> 16) != upper) {
                upper = a >> 16;
                Rec(sb, 4, 0, new byte[] { (byte)(upper >> 8), (byte)upper }, 0, 2);
            }
            Rec(sb, 0, a, d, off + p, Math.Min(16, len - p));
        }
    }
    public static void End(StringBuilder sb) { Rec(sb, 1, 0, new byte[0], 0, 0); }
}
'@

$img = [System.IO.File]::ReadAllBytes((Resolve-Path $Image))
$sb = New-Object System.Text.StringBuilder
$written = 0
# raw ROM area for -Bin: 16 slots, erased (FF) unless a game goes there
$raw = New-Object byte[] (16 * $FlashSlot)
for ($i = 0; $i -lt $raw.Length; $i++) { $raw[$i] = 0xFF }
for ($n = 0; $n -lt $Games; $n++) {
    $off = ($FirstSector * 512) + ($n * $SlotBytes)
    if ($off + $SlotBytes -gt $img.Length) { break }
    $addr = $FlashBase + $n * $FlashSlot
    if ([GottFAFlash]::Blank($img, $off, 2048)) {
        Write-Host ('game {0,2}: empty, left out' -f $n) -ForegroundColor DarkGray
        continue
    }
    if ($img[$off] -eq 0xFF) {
        Write-Host ('game {0,2}: first byte FF - Flash_ROM would report ERROR, left out' -f $n) -ForegroundColor Yellow
        continue
    }
    Write-Host ('game {0,2}: {1:X6}  first bytes {2:X2}{3:X2}' -f $n, $addr, $img[$off], $img[$off + 1])
    [GottFAFlash]::Data($sb, $addr, $img, $off, $SlotBytes)
    [Array]::Copy($img, $off, $raw, $n * $FlashSlot, $SlotBytes)
    $written++
}
[GottFAFlash]::End($sb)
if ($written -eq 0) { throw 'No game found.' }

function Get-OutPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) { $full = $Path }
    else { $full = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $Path)) }
    $dir = Split-Path $full
    if (-not (Test-Path $dir)) { $null = New-Item -ItemType Directory -Path $dir }
    return $full
}
if ($Out) {
    $outFull = Get-OutPath $Out
    [System.IO.File]::WriteAllText($outFull, $sb.ToString(), (New-Object System.Text.ASCIIEncoding))
    Write-Host ('{0} games written to {1}' -f $written, $outFull)
}
if ($Bin) {
    $binFull = Get-OutPath $Bin
    [System.IO.File]::WriteAllBytes($binFull, $raw)
    Write-Host ('{0} games written to {1} ({2:N0} bytes, flash 0x{3:X6}..0x{4:X6})' -f `
        $written, $binFull, $raw.Length, $FlashBase, ($FlashBase + $raw.Length - 1))
}
