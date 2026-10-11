# Render unit icons from system emoji font (offline, no CDN).
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$OutDir = Join-Path $Root "assets\sprites\units"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$Size = 128
$FontSize = 72

function Emoji([int]$codePoint) {
    return -join [char[]][char]::ConvertFromUtf32($codePoint)
}

$Units = @(
    @{ id = "ant";              text = (Emoji 0x1F41C) },
    @{ id = "cricket";          text = (Emoji 0x1F997) },
    @{ id = "horse";            text = (Emoji 0x1F434) },
    @{ id = "pig";              text = (Emoji 0x1F437) },
    @{ id = "otter";            text = (Emoji 0x1F9A6) },
    @{ id = "duck";             text = (Emoji 0x1F986) },
    @{ id = "beaver";           text = (Emoji 0x1F9AB) },
    @{ id = "fish";             text = (Emoji 0x1F41F) },
    @{ id = "pigeon";           text = (Emoji 0x1F426) },
    @{ id = "peacock";          text = (Emoji 0x1F99A) },
    @{ id = "spider";           text = (Emoji 0x1F577) },
    @{ id = "flamingo";         text = (Emoji 0x1F9A9) },
    @{ id = "hedgehog";         text = (Emoji 0x1F994) },
    @{ id = "crab";             text = (Emoji 0x1F980) },
    @{ id = "blowfish";         text = (Emoji 0x1F421) },
    @{ id = "sheep";            text = (Emoji 0x1F411) },
    @{ id = "hippo";            text = (Emoji 0x1F99B) },
    @{ id = "wolf";             text = (Emoji 0x1F43A) },
    @{ id = "bear";             text = (Emoji 0x1F43B) },
    @{ id = "leopard";          text = (Emoji 0x1F406) },
    @{ id = "zombie_cricket";   text = (Emoji 0x1F997); tint = @(0.55, 1.0, 0.55) },
    @{ id = "spider_hatchling"; text = (Emoji 0x1F577); scale = 0.72 },
    @{ id = "ram";              text = (Emoji 0x1F411); scale = 0.85 }
)

function Get-EmojiFont {
    $names = @("Segoe UI Emoji", "Noto Color Emoji", "Apple Color Emoji")
    foreach ($name in $names) {
        try {
            $f = New-Object System.Drawing.Font $name, $FontSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel
            return $f
        }
        catch { }
    }
    return New-Object System.Drawing.Font "Arial", $FontSize
}

function Save-EmojiIcon {
    param($Unit)

    $scale = if ($Unit.scale) { [double]$Unit.scale } else { 1.0 }
    $tint = $Unit.tint
    $text = [string]$Unit.text

    $bmp = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.Clear([System.Drawing.Color]::Transparent)
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
        $font = Get-EmojiFont
        try {
            $brushColor = if ($null -ne $tint) {
                [System.Drawing.Color]::FromArgb(255, [int](255 * $tint[0]), [int](255 * $tint[1]), [int](255 * $tint[2]))
            }
            else {
                [System.Drawing.Color]::Black
            }
            $brush = New-Object System.Drawing.SolidBrush $brushColor
            try {
                $format = New-Object System.Drawing.StringFormat
                $format.Alignment = [System.Drawing.StringAlignment]::Center
                $format.LineAlignment = [System.Drawing.StringAlignment]::Center
                $drawSize = [single]($Size * $scale)
                $offset = [single](($Size - $drawSize) / 2.0)
                $rect = New-Object System.Drawing.RectangleF $offset, $offset, $drawSize, $drawSize
                $g.DrawString($text, $font, $brush, $rect, $format)
            }
            finally { $brush.Dispose() }
        }
        finally { $font.Dispose() }
    }
    finally { $g.Dispose() }

    $outPath = Join-Path $OutDir "$($Unit.id).png"
    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "  wrote $($Unit.id).png"
}

Write-Host "Output: $OutDir (local emoji font)"
foreach ($unit in $Units) {
    Save-EmojiIcon -Unit $unit
}
Write-Host "Done: $($Units.Count) icons"
