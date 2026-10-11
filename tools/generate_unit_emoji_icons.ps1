# Render unit emoji icons via Twemoji CDN (no Pillow required).
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$OutDir = Join-Path $Root "assets\sprites\units"
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$TwemojiBase = "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72"
$Size = 128

$Units = @(
    @{ id = "ant";              hex = "1f41c"; scale = 1.0; tint = $null },
    @{ id = "cricket";          hex = "1f997"; scale = 1.0; tint = $null },
    @{ id = "horse";            hex = "1f434"; scale = 1.0; tint = $null },
    @{ id = "pig";              hex = "1f437"; scale = 1.0; tint = $null },
    @{ id = "otter";            hex = "1f9a6"; scale = 1.0; tint = $null },
    @{ id = "duck";             hex = "1f986"; scale = 1.0; tint = $null },
    @{ id = "beaver";           hex = "1f9ab"; scale = 1.0; tint = $null },
    @{ id = "fish";             hex = "1f41f"; scale = 1.0; tint = $null },
    @{ id = "pigeon";           hex = "1f426"; scale = 1.0; tint = $null },
    @{ id = "peacock";          hex = "1f99a"; scale = 1.0; tint = $null },
    @{ id = "spider";           hex = "1f577"; scale = 1.0; tint = $null },
    @{ id = "flamingo";         hex = "1f9a9"; scale = 1.0; tint = $null },
    @{ id = "hedgehog";         hex = "1f994"; scale = 1.0; tint = $null },
    @{ id = "crab";             hex = "1f980"; scale = 1.0; tint = $null },
    @{ id = "blowfish";         hex = "1f421"; scale = 1.0; tint = $null },
    @{ id = "sheep";            hex = "1f411"; scale = 1.0; tint = $null },
    @{ id = "hippo";            hex = "1f99b"; scale = 1.0; tint = $null },
    @{ id = "wolf";             hex = "1f43a"; scale = 1.0; tint = $null },
    @{ id = "bear";             hex = "1f43b"; scale = 1.0; tint = $null },
    @{ id = "leopard";          hex = "1f406"; scale = 1.0; tint = $null },
    @{ id = "zombie_cricket";   hex = "1f997"; scale = 1.0; tint = @(0.65, 1.0, 0.65) },
    @{ id = "spider_hatchling"; hex = "1f577"; scale = 0.75; tint = $null },
    @{ id = "ram";              hex = "1f411"; scale = 0.85; tint = $null }
)

function Save-TwemojiIcon {
    param(
        [string]$UnitId,
        [string]$Hex,
        [double]$Scale = 1.0,
        [double[]]$Tint = $null
    )

    $url = "$TwemojiBase/$Hex.png"
    $tempFile = [IO.Path]::Combine([IO.Path]::GetTempPath(), "$UnitId-$Hex.png")
    Invoke-WebRequest -Uri $url -OutFile $tempFile -UseBasicParsing

    $src = [System.Drawing.Image]::FromFile($tempFile)
    try {
        $bmp = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        try {
            $g.Clear([System.Drawing.Color]::Transparent)
            $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

            $drawSize = [int]($Size * $Scale)
            $offset = [int](($Size - $drawSize) / 2)
            $dest = New-Object System.Drawing.Rectangle $offset, $offset, $drawSize, $drawSize

            if ($null -ne $Tint) {
                $matrix = New-Object System.Drawing.Imaging.ColorMatrix
                $matrix.Matrix00 = $Tint[0]
                $matrix.Matrix11 = $Tint[1]
                $matrix.Matrix22 = $Tint[2]
                $matrix.Matrix33 = 1.0
                $matrix.Matrix44 = 1.0
                $attrs = New-Object System.Drawing.Imaging.ImageAttributes
                $attrs.SetColorMatrix($matrix)
                $g.DrawImage(
                    $src,
                    $dest,
                    0, 0, $src.Width, $src.Height,
                    [System.Drawing.GraphicsUnit]::Pixel,
                    $attrs
                )
            }
            else {
                $g.DrawImage($src, $dest)
            }
        }
        finally {
            $g.Dispose()
        }

        $outPath = Join-Path $OutDir "$UnitId.png"
        $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Host "  wrote $UnitId.png"
    }
    finally {
        $src.Dispose()
        Remove-Item -Force $tempFile -ErrorAction SilentlyContinue
    }
}

Write-Host "Output: $OutDir"
foreach ($unit in $Units) {
    Save-TwemojiIcon -UnitId $unit.id -Hex $unit.hex -Scale $unit.scale -Tint $unit.tint
}
Write-Host "Done: $($Units.Count) icons"
