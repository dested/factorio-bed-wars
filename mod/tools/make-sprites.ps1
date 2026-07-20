# Bed Wars sprite generator. Flat pixel-art via System.Drawing: no anti-aliasing,
# transparent backgrounds, every shape a filled rect/polygon with a 2px dark outline.
# Run:  pwsh -File tools/make-sprites.ps1   (from the mod/ directory or anywhere)
Add-Type -AssemblyName System.Drawing

$MODROOT = Split-Path -Parent $PSScriptRoot        # ...\mod
$OUT     = Join-Path $MODROOT "graphics"
New-Item -ItemType Directory -Force -Path $OUT | Out-Null

$OL_COLOR = [System.Drawing.Color]::FromArgb(180, 26, 26, 26)   # #1a1a1a alpha 180
$script:F = 1.0                                                # scale factor (beds)

function n([double]$v) { return [int][math]::Round($v * $script:F) }
function C([int]$r, [int]$g, [int]$b, [int]$a = 255) { return [System.Drawing.Color]::FromArgb($a, $r, $g, $b) }

# Pen(Color, Single) is ambiguous under PowerShell overload resolution; build from
# the single-arg Color constructor and set Width as a property instead.
function New-Pen($col, [single]$width) {
  $p = New-Object System.Drawing.Pen([System.Drawing.Color]$col)
  $p.Width = $width
  return $p
}

function New-Canvas([int]$w, [int]$h) {
  $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighSpeed
  $g.Clear([System.Drawing.Color]::Transparent)
  return , @($bmp, $g)
}

function Rect($g, $col, [int]$x, [int]$y, [int]$w, [int]$h, [bool]$outline = $true) {
  $brush = New-Object System.Drawing.SolidBrush($col)
  $g.FillRectangle($brush, $x, $y, $w, $h)
  $brush.Dispose()
  if ($outline) {
    $pen = New-Pen $OL_COLOR 2
    $g.DrawRectangle($pen, $x, $y, $w, $h)
    $pen.Dispose()
  }
}

function Poly($g, $col, $pts, [bool]$outline = $true) {
  $brush = New-Object System.Drawing.SolidBrush($col)
  $g.FillPolygon($brush, [System.Drawing.Point[]]$pts)
  $brush.Dispose()
  if ($outline) {
    $pen = New-Pen $OL_COLOR 2
    $g.DrawPolygon($pen, [System.Drawing.Point[]]$pts)
    $pen.Dispose()
  }
}

function Diamond($g, $col, [int]$cx, [int]$cy, [int]$hs, [bool]$outline = $true) {
  $pts = @(
    (New-Object System.Drawing.Point($cx, ($cy - $hs))),
    (New-Object System.Drawing.Point(($cx + $hs), $cy)),
    (New-Object System.Drawing.Point($cx, ($cy + $hs))),
    (New-Object System.Drawing.Point(($cx - $hs), $cy))
  )
  Poly $g $col $pts $outline
}

# Overwrite corner pixels with transparency (needs SourceCopy to actually erase).
function Clear-Rect($g, [int]$x, [int]$y, [int]$w, [int]$h) {
  $old = $g.CompositingMode
  $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
  $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::Transparent)
  $g.FillRectangle($brush, $x, $y, $w, $h)
  $brush.Dispose()
  $g.CompositingMode = $old
}

function Save-Png($bmp, $g, $path) {
  $g.Dispose()
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}

# --- Bed (top-down), rendered at size S, returns the bitmap ------------------
function Render-Bed($main, $fold, $crease, [int]$S) {
  $script:F = $S / 128.0
  $c = New-Canvas $S $S; $bmp = $c[0]; $g = $c[1]

  $frame = (C 107 74 43); $head = (C 85 56 31); $mat = (C 232 228 218); $white = (C 255 255 255)

  Rect $g $frame (n 6) (n 6) (n 116) (n 116)          # wooden frame (whole bed minus 6px margin)
  # corner notches for a rounded look
  Clear-Rect $g (n 6) (n 6) (n 6) (n 6)
  Clear-Rect $g (n 116) (n 6) (n 6) (n 6)
  Clear-Rect $g (n 6) (n 116) (n 6) (n 6)
  Clear-Rect $g (n 116) (n 116) (n 6) (n 6)

  Rect $g $head (n 16) (n 16) (n 96) (n 22)           # headboard strip inside frame
  Rect $g $mat  (n 16) (n 38) (n 96) (n 74)           # mattress fills the rest
  Rect $g $white (n 36) (n 40) (n 56) (n 28)          # pillow, inset 20px from inner sides
  Rect $g $main (n 16) (n 62) (n 96) (n 50)           # blanket
  Rect $g $fold (n 16) (n 62) (n 96) (n 5) $false     # darker fold stripe across blanket top
  Rect $g $crease (n 44) (n 70) (n 2) (n 38) $false   # crease lines
  Rect $g $crease (n 80) (n 70) (n 2) (n 38) $false

  $g.Dispose()
  return $bmp
}

# --- Resource generator (obelisk) -------------------------------------------
function Save-Generator($path) {
  $c = New-Canvas 64 96; $bmp = $c[0]; $g = $c[1]
  Rect $g (C 42 46 54) 8 78 48 18                     # plinth (bottom 18px)
  $col = @(                                           # tapered column
    (New-Object System.Drawing.Point(14, 80)),
    (New-Object System.Drawing.Point(50, 80)),
    (New-Object System.Drawing.Point(40, 10)),
    (New-Object System.Drawing.Point(24, 10))
  )
  Poly $g (C 58 63 74) $col
  Diamond $g (C 88 224 208) 32 38 11                  # floating core, outer
  Diamond $g (C 168 240 232) 32 38 5                  # inner
  Save-Png $bmp $g $path
}

function Save-GeneratorIcon($path) {
  $c = New-Canvas 64 64; $bmp = $c[0]; $g = $c[1]
  Rect $g (C 42 46 54) 14 48 36 12                    # small plinth
  Diamond $g (C 88 224 208) 32 30 22                  # big core, outer 44px
  Diamond $g (C 168 240 232) 32 30 10                 # inner 20px
  Save-Png $bmp $g $path
}

# --- Market stall ------------------------------------------------------------
function Save-Market($stripeA, $stripeB, $counter, $counterEdge, $mode, $path) {
  $c = New-Canvas 192 192; $bmp = $c[0]; $g = $c[1]
  $legcol = (C 107 74 43)
  foreach ($lx in @(24, 60, 132, 168)) { Rect $g $legcol $lx 90 10 90 }   # four legs

  Rect $g $counter 12 110 168 40                      # counter top
  Rect $g $counterEdge 12 110 168 6 $false            # darker top edge

  # awning: vertical stripes across the canopy
  $x = 8; $i = 0
  while ($x -lt 184) {
    $w = [math]::Min(20, 184 - $x)
    $col = if ($i % 2 -eq 0) { $stripeA } else { $stripeB }
    Rect $g $col $x 28 $w 42 $false
    $x += 20; $i++
  }
  $pen = New-Pen $OL_COLOR 2
  $g.DrawRectangle($pen, 8, 28, 176, 42)
  $pen.Dispose()
  # scalloped bottom edge: row of 10px half-squares
  $x = 8; $i = 0
  while ($x -lt 184) {
    $w = [math]::Min(10, 184 - $x)
    $col = if ($i % 2 -eq 0) { $stripeA } else { $stripeB }
    Rect $g $col $x 70 $w 8 $false
    $x += 10; $i++
  }

  if ($mode -eq "items") {
    Rect $g (C 154 122 79) 44 86 24 24                # item crates on the counter
    Rect $g (C 154 122 79) 120 88 24 22
  }
  else {
    $anvil = (C 201 162 39)                           # gold anvil silhouette
    Rect $g $anvil 68 96 56 14                        # top
    Clear-Rect $g 68 96 12 6                          # horn notch
    Rect $g $anvil 88 110 16 10                       # waist
    Rect $g $anvil 74 120 44 12                       # base
  }
  Save-Png $bmp $g $path
}

function Save-MarketIcon($stripeA, $stripeB, $counter, $path) {
  $c = New-Canvas 64 64; $bmp = $c[0]; $g = $c[1]
  $x = 4; $i = 0
  while ($x -lt 60) {
    $w = [math]::Min(8, 60 - $x)
    $col = if ($i % 2 -eq 0) { $stripeA } else { $stripeB }
    Rect $g $col $x 8 $w 26 $false
    $x += 8; $i++
  }
  $pen = New-Pen $OL_COLOR 2
  $g.DrawRectangle($pen, 4, 8, 56, 26)
  $pen.Dispose()
  Rect $g $counter 6 40 52 14                         # counter bar
  Save-Png $bmp $g $path
}

# === Generate ================================================================
$blueMain = (C 61 111 214); $blueFold = (C 47 85 165); $blueCrease = (C 51 95 182)
$redMain = (C 214 64 64);  $redFold = (C 165 48 48);  $redCrease = (C 176 53 53)

# Beds (128) + icons (64)
$b = Render-Bed $blueMain $blueFold $blueCrease 128
$b.Save((Join-Path $OUT "bw-bed-blue.png"), [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose()
$b = Render-Bed $redMain $redFold $redCrease 128
$b.Save((Join-Path $OUT "bw-bed-red.png"), [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose()
$b = Render-Bed $blueMain $blueFold $blueCrease 64
$b.Save((Join-Path $OUT "bw-bed-icon-blue.png"), [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose()
$b = Render-Bed $redMain $redFold $redCrease 64
$b.Save((Join-Path $OUT "bw-bed-icon-red.png"), [System.Drawing.Imaging.ImageFormat]::Png); $b.Dispose()

# Generator + icon
Save-Generator (Join-Path $OUT "bw-generator.png")
Save-GeneratorIcon (Join-Path $OUT "bw-generator-icon.png")

# Markets: items (red/white awning) + upgrades (purple/white awning)
$white = (C 240 240 240)
Save-Market $redMain $white (C 138 106 63) (C 110 84 50) "items" (Join-Path $OUT "bw-market-items.png")
Save-Market (C 138 74 214) $white (C 74 74 85) (C 58 58 68) "upgrades" (Join-Path $OUT "bw-market-upgrades.png")
Save-MarketIcon $redMain $white (C 138 106 63) (Join-Path $OUT "bw-market-items-icon.png")
Save-MarketIcon (C 138 74 214) $white (C 74 74 85) (Join-Path $OUT "bw-market-upgrades-icon.png")

# Thumbnail (144): dark bg, blue bed upper-left, red bed lower-right, diagonal slash
$c = New-Canvas 144 144; $tb = $c[0]; $tg = $c[1]
$tg.Clear((C 34 38 46))
$blue = Render-Bed $blueMain $blueFold $blueCrease 64
$red = Render-Bed $redMain $redFold $redCrease 64
$tg.DrawImage($blue, 8, 8, 64, 64)
$tg.DrawImage($red, 72, 72, 64, 64)
$blue.Dispose(); $red.Dispose()
$slash = New-Pen (C 240 240 240) 6
$tg.DrawLine($slash, 16, 128, 128, 16)
$slash.Dispose()
Save-Png $tb $tg (Join-Path $MODROOT "thumbnail.png")

Write-Host "Sprites written to $OUT and thumbnail to $MODROOT"
