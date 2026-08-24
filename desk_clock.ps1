<# 
  Desk Clock - YClock風デスクトップ時計
  PowerShell + WPF版
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# ===== 設定ファイルパス =====
$settingsDir = Join-Path $env:APPDATA "DeskClock"
$settingsFile = Join-Path $settingsDir "settings.json"

# ===== デフォルト設定 =====
$script:Settings = @{
    Mode         = "analog"
    Theme        = "dark"
    Opacity      = 0.85
    ShowSeconds  = $true
    HourWidth    = 4.0
    HourLength   = 45
    MinuteWidth  = 4.0
    MinuteLength = 65
    DigitalSize  = 64
    Width        = 300
    Height       = 300
    Left         = -1
    Top          = -1
}

# ===== テーマ定義 =====
$script:Themes = @{
    dark = @{
        Face            = "#E6181820"
        FaceBorder      = "#59646482"
        TickMajor       = "#D9BEBED7"
        TickMinor       = "#7382829B"
        HandHour        = "#F2DCDCF0"
        HandMinute      = "#E6B4B4D2"
        HandSecond      = "#B3A0A0B9"
        CenterDot       = "#E6B4B4D2"
        DigitalColor    = "#F2DCDCF0"
    }
    light = @{
        Face            = "#E6EBEBF0"
        FaceBorder      = "#668C8CA5"
        TickMajor       = "#CC28283C"
        TickMinor       = "#73505069"
        HandHour        = "#F21E1E32"
        HandMinute      = "#E637374E"
        HandSecond      = "#A65A464B"
        CenterDot       = "#E637374E"
        DigitalColor    = "#F21E1E32"
    }
    blue = @{
        Face            = "#E60E1428"
        FaceBorder      = "#66325591"
        TickMajor       = "#D978A5E1"
        TickMinor       = "#734B699B"
        HandHour        = "#F28CBEF5"
        HandMinute      = "#E6699BD7"
        HandSecond      = "#B35A8CB9"
        CenterDot       = "#E6699BD7"
        DigitalColor    = "#F28CBEF5"
    }
}

# ===== 設定の読み込み・保存 =====
function Load-Settings {
    if (Test-Path $settingsFile) {
        try {
            $json = Get-Content $settingsFile -Raw | ConvertFrom-Json
            if ($json.Mode) { $script:Settings.Mode = $json.Mode }
            if ($json.Theme) { $script:Settings.Theme = $json.Theme }
            if ($null -ne $json.Opacity) { $script:Settings.Opacity = [double]$json.Opacity }
            if ($null -ne $json.ShowSeconds) { $script:Settings.ShowSeconds = [bool]$json.ShowSeconds }
            if ($null -ne $json.HourWidth) { $script:Settings.HourWidth = [double]$json.HourWidth }
            if ($null -ne $json.HourLength) { $script:Settings.HourLength = [int]$json.HourLength }
            if ($null -ne $json.MinuteWidth) { $script:Settings.MinuteWidth = [double]$json.MinuteWidth }
            if ($null -ne $json.MinuteLength) { $script:Settings.MinuteLength = [int]$json.MinuteLength }
            if ($null -ne $json.DigitalSize) { $script:Settings.DigitalSize = [double]$json.DigitalSize }
            if ($null -ne $json.Width) { $script:Settings.Width = [int]$json.Width }
            if ($null -ne $json.Height) { $script:Settings.Height = [int]$json.Height }
            if ($null -ne $json.Left) { $script:Settings.Left = [double]$json.Left }
            if ($null -ne $json.Top) { $script:Settings.Top = [double]$json.Top }
        } catch {}
    }
}

function Save-Settings {
    try {
        if (-not (Test-Path $settingsDir)) { 
            New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null 
        }
        $script:Settings | ConvertTo-Json | Set-Content $settingsFile -Encoding UTF8
    } catch {}
}

# ===== XAML =====
$xaml = @"
<Window 
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Desk Clock"
    WindowStyle="None"
    AllowsTransparency="True"
    Background="Transparent"
    Topmost="True"
    ShowInTaskbar="True"
    ResizeMode="CanResizeWithGrip"
    MinWidth="120" MinHeight="120"
    Width="300" Height="300">

    <Grid x:Name="MainGrid" Background="#01000000">
        <!-- Analog Clock Canvas -->
        <Canvas x:Name="AnalogCanvas" 
                HorizontalAlignment="Stretch" 
                VerticalAlignment="Stretch"/>
        
        <!-- Digital Clock -->
        <Border x:Name="DigitalBorder" 
                CornerRadius="16" 
                Padding="24,16"
                HorizontalAlignment="Center"
                VerticalAlignment="Center"
                Visibility="Collapsed">
            <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
                <TextBlock x:Name="DigitalTime" 
                           Text="00:00"
                           FontSize="64"
                           FontWeight="Medium"
                           FontFamily="Segoe UI, Consolas"
                           HorizontalAlignment="Center"/>
            </StackPanel>
        </Border>
    </Grid>
</Window>
"@

# ===== ウィンドウ作成 =====
$window = [System.Windows.Markup.XamlReader]::Parse($xaml)

# コントロール取得
$mainGrid = $window.FindName("MainGrid")
$analogCanvas = $window.FindName("AnalogCanvas")
$digitalBorder = $window.FindName("DigitalBorder")
$digitalTime = $window.FindName("DigitalTime")

# ===== ヘルパー関数 =====
function Get-BrushFromHex([string]$hex) {
    try {
        $color = [System.Windows.Media.ColorConverter]::ConvertFromString($hex)
        return New-Object System.Windows.Media.SolidColorBrush($color)
    } catch {
        return [System.Windows.Media.Brushes]::Transparent
    }
}

function Get-CurrentTheme {
    $themeName = $script:Settings.Theme
    if ($script:Themes.ContainsKey($themeName)) {
        return $script:Themes[$themeName]
    }
    return $script:Themes["dark"]
}

# ===== アナログ時計描画 =====
function Draw-AnalogClock {
    $analogCanvas.Children.Clear()

    $w = $analogCanvas.ActualWidth
    $h = $analogCanvas.ActualHeight
    if ($w -le 0 -or $h -le 0) { return }

    $cx = $w / 2.0
    $cy = $h / 2.0
    $r = [Math]::Min($cx, $cy) - 4.0

    $now = Get-Date
    $hours = $now.Hour
    $minutes = $now.Minute
    $seconds = $now.Second

    $theme = Get-CurrentTheme

    # Face background circle
    $faceEllipse = New-Object System.Windows.Shapes.Ellipse
    $faceEllipse.Width = $r * 2
    $faceEllipse.Height = $r * 2
    $faceEllipse.Fill = Get-BrushFromHex $theme.Face
    $faceEllipse.Stroke = Get-BrushFromHex $theme.FaceBorder
    $faceEllipse.StrokeThickness = 2
    [System.Windows.Controls.Canvas]::SetLeft($faceEllipse, $cx - $r)
    [System.Windows.Controls.Canvas]::SetTop($faceEllipse, $cy - $r)
    $analogCanvas.Children.Add($faceEllipse) | Out-Null

    # Inner ring
    $innerRing = New-Object System.Windows.Shapes.Ellipse
    $innerR = $r * 0.92
    $innerRing.Width = $innerR * 2
    $innerRing.Height = $innerR * 2
    $innerRing.Stroke = Get-BrushFromHex $theme.FaceBorder
    $innerRing.StrokeThickness = 0.5
    [System.Windows.Controls.Canvas]::SetLeft($innerRing, $cx - $innerR)
    [System.Windows.Controls.Canvas]::SetTop($innerRing, $cy - $innerR)
    $analogCanvas.Children.Add($innerRing) | Out-Null

    # Tick marks
    for ($i = 0; $i -lt 60; $i++) {
        $angle = ($i * 6 - 90) * [Math]::PI / 180.0
        $isMajor = ($i % 5 -eq 0)
        $outerTR = $r * 0.92
        $innerTR = if ($isMajor) { $r * 0.82 } else { $r * 0.87 }
        
        $line = New-Object System.Windows.Shapes.Line
        $line.X1 = $cx + $outerTR * [Math]::Cos($angle)
        $line.Y1 = $cy + $outerTR * [Math]::Sin($angle)
        $line.X2 = $cx + $innerTR * [Math]::Cos($angle)
        $line.Y2 = $cy + $innerTR * [Math]::Sin($angle)
        $line.Stroke = if ($isMajor) { Get-BrushFromHex $theme.TickMajor } else { Get-BrushFromHex $theme.TickMinor }
        $line.StrokeThickness = if ($isMajor) { 3.5 } else { 1.8 }
        $line.StrokeStartLineCap = "Round"
        $line.StrokeEndLineCap = "Round"
        $analogCanvas.Children.Add($line) | Out-Null
    }

    # Hour hand
    $hourAngle = (($hours % 12) * 30 + $minutes * 0.5 - 90) * [Math]::PI / 180.0
    $hLen = $r * ($script:Settings.HourLength / 100.0)
    $hLine = New-Object System.Windows.Shapes.Line
    $hLine.X1 = $cx; $hLine.Y1 = $cy
    $hLine.X2 = $cx + $hLen * [Math]::Cos($hourAngle)
    $hLine.Y2 = $cy + $hLen * [Math]::Sin($hourAngle)
    $hLine.Stroke = Get-BrushFromHex $theme.HandHour
    $hLine.StrokeThickness = $script:Settings.HourWidth
    $hLine.StrokeStartLineCap = "Round"
    $hLine.StrokeEndLineCap = "Round"
    $analogCanvas.Children.Add($hLine) | Out-Null

    # Minute hand
    $minAngle = ($minutes * 6 + $seconds * 0.1 - 90) * [Math]::PI / 180.0
    $mLen = $r * ($script:Settings.MinuteLength / 100.0)
    $mLine = New-Object System.Windows.Shapes.Line
    $mLine.X1 = $cx; $mLine.Y1 = $cy
    $mLine.X2 = $cx + $mLen * [Math]::Cos($minAngle)
    $mLine.Y2 = $cy + $mLen * [Math]::Sin($minAngle)
    $mLine.Stroke = Get-BrushFromHex $theme.HandMinute
    $mLine.StrokeThickness = $script:Settings.MinuteWidth
    $mLine.StrokeStartLineCap = "Round"
    $mLine.StrokeEndLineCap = "Round"
    $analogCanvas.Children.Add($mLine) | Out-Null

    # Second hand (conditional)
    if ($script:Settings.ShowSeconds) {
        $secAngle = ($seconds * 6 - 90) * [Math]::PI / 180.0
        $sLine = New-Object System.Windows.Shapes.Line
        $sLine.X1 = $cx; $sLine.Y1 = $cy
        $sLine.X2 = $cx + $r * 0.72 * [Math]::Cos($secAngle)
        $sLine.Y2 = $cy + $r * 0.72 * [Math]::Sin($secAngle)
        $sLine.Stroke = Get-BrushFromHex $theme.HandSecond
        $sLine.StrokeThickness = 1.2
        $sLine.StrokeStartLineCap = "Round"
        $sLine.StrokeEndLineCap = "Round"
        $analogCanvas.Children.Add($sLine) | Out-Null

        # Counterweight
        $counterAngle = $secAngle + [Math]::PI
        $cLine = New-Object System.Windows.Shapes.Line
        $cLine.X1 = $cx; $cLine.Y1 = $cy
        $cLine.X2 = $cx + $r * 0.15 * [Math]::Cos($counterAngle)
        $cLine.Y2 = $cy + $r * 0.15 * [Math]::Sin($counterAngle)
        $cLine.Stroke = Get-BrushFromHex $theme.HandSecond
        $cLine.StrokeThickness = 1.2
        $cLine.StrokeStartLineCap = "Round"
        $cLine.StrokeEndLineCap = "Round"
        $analogCanvas.Children.Add($cLine) | Out-Null
    }

    # Center dot
    $centerDot = New-Object System.Windows.Shapes.Ellipse
    $centerDot.Width = 13
    $centerDot.Height = 13
    $centerDot.Fill = Get-BrushFromHex $theme.CenterDot
    [System.Windows.Controls.Canvas]::SetLeft($centerDot, $cx - 6.5)
    [System.Windows.Controls.Canvas]::SetTop($centerDot, $cy - 6.5)
    $analogCanvas.Children.Add($centerDot) | Out-Null

    # Inner center dot
    $innerDot = New-Object System.Windows.Shapes.Ellipse
    $innerDot.Width = 5
    $innerDot.Height = 5
    $innerDot.Fill = Get-BrushFromHex $theme.Face
    [System.Windows.Controls.Canvas]::SetLeft($innerDot, $cx - 2.5)
    [System.Windows.Controls.Canvas]::SetTop($innerDot, $cy - 2.5)
    $analogCanvas.Children.Add($innerDot) | Out-Null
}

# ===== デジタル時計更新 =====
function Update-DigitalClock {
    $now = Get-Date
    $digitalTime.Text = $now.ToString("HH:mm")
}

# ===== 表示モード切替 =====
function Apply-Mode {
    $theme = Get-CurrentTheme
    
    if ($script:Settings.Mode -eq "analog") {
        $analogCanvas.Visibility = "Visible"
        $digitalBorder.Visibility = "Collapsed"
    } else {
        $analogCanvas.Visibility = "Collapsed"
        $digitalBorder.Visibility = "Visible"
        $digitalBorder.Background = Get-BrushFromHex $theme.Face
        $digitalBorder.BorderBrush = Get-BrushFromHex $theme.FaceBorder
        $digitalBorder.BorderThickness = New-Object System.Windows.Thickness(1)
        $digitalTime.Foreground = Get-BrushFromHex $theme.DigitalColor
        $digitalTime.FontSize = $script:Settings.DigitalSize
    }

    $window.Opacity = $script:Settings.Opacity
}

# ===== タイマー =====
function Tick-Handler {
    if ($script:Settings.Mode -eq "analog") {
        Draw-AnalogClock
    } else {
        Update-DigitalClock
    }
}

# ===== コンテキストメニュー =====
$contextMenu = New-Object System.Windows.Controls.ContextMenu

# --- 表示モード ---
$menuAnalog = New-Object System.Windows.Controls.MenuItem
$menuAnalog.Header = "アナログ"
$menuAnalog.Add_Click({
    $script:Settings.Mode = "analog"
    Apply-Mode
    Tick-Handler
    Save-Settings
})
$contextMenu.Items.Add($menuAnalog) | Out-Null

$menuDigital = New-Object System.Windows.Controls.MenuItem
$menuDigital.Header = "デジタル"
$menuDigital.Add_Click({
    $script:Settings.Mode = "digital"
    Apply-Mode
    Tick-Handler
    Save-Settings
})
$contextMenu.Items.Add($menuDigital) | Out-Null

$contextMenu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null

# --- 秒針表示トグル ---
$script:menuSeconds = New-Object System.Windows.Controls.MenuItem
$script:menuSeconds.Header = "秒針を表示"
$script:menuSeconds.IsCheckable = $true
$script:menuSeconds.IsChecked = $true
$script:menuSeconds.Add_Click({
    $script:Settings.ShowSeconds = $script:menuSeconds.IsChecked
    Tick-Handler
    Save-Settings
})
$contextMenu.Items.Add($script:menuSeconds) | Out-Null

$contextMenu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null

# --- 針の設定 ---
$menuHands = New-Object System.Windows.Controls.MenuItem
$menuHands.Header = "針の設定"

$subHW = New-Object System.Windows.Controls.MenuItem
$subHW.Header = "時針 太さ"
foreach ($opt in @(@{L="極細 (1.5px)";V=1.5}, @{L="標準 (2.5px)";V=2.5}, @{L="太め (4.0px)";V=4.0}, @{L="極太 (6.0px)";V=6.0})) {
    $item = New-Object System.Windows.Controls.MenuItem
    $item.Header = $opt.L; $item.Tag = $opt.V
    $item.Add_Click({ param($s,$e) $script:Settings.HourWidth = [double]$s.Tag; Tick-Handler; Save-Settings })
    $subHW.Items.Add($item) | Out-Null
}
$menuHands.Items.Add($subHW) | Out-Null

$subHL = New-Object System.Windows.Controls.MenuItem
$subHL.Header = "時針 長さ"
foreach ($opt in @(@{L="短め (35%)";V=35}, @{L="標準 (45%)";V=45}, @{L="長め (55%)";V=55})) {
    $item = New-Object System.Windows.Controls.MenuItem
    $item.Header = $opt.L; $item.Tag = $opt.V
    $item.Add_Click({ param($s,$e) $script:Settings.HourLength = [int]$s.Tag; Tick-Handler; Save-Settings })
    $subHL.Items.Add($item) | Out-Null
}
$menuHands.Items.Add($subHL) | Out-Null

$subMW = New-Object System.Windows.Controls.MenuItem
$subMW.Header = "分針 太さ"
foreach ($opt in @(@{L="極細 (1.5px)";V=1.5}, @{L="標準 (2.5px)";V=2.5}, @{L="太め (4.0px)";V=4.0}, @{L="極太 (6.0px)";V=6.0})) {
    $item = New-Object System.Windows.Controls.MenuItem
    $item.Header = $opt.L; $item.Tag = $opt.V
    $item.Add_Click({ param($s,$e) $script:Settings.MinuteWidth = [double]$s.Tag; Tick-Handler; Save-Settings })
    $subMW.Items.Add($item) | Out-Null
}
$menuHands.Items.Add($subMW) | Out-Null

$subML = New-Object System.Windows.Controls.MenuItem
$subML.Header = "分針 長さ"
foreach ($opt in @(@{L="短め (55%)";V=55}, @{L="標準 (65%)";V=65}, @{L="長め (80%)";V=80})) {
    $item = New-Object System.Windows.Controls.MenuItem
    $item.Header = $opt.L; $item.Tag = $opt.V
    $item.Add_Click({ param($s,$e) $script:Settings.MinuteLength = [int]$s.Tag; Tick-Handler; Save-Settings })
    $subML.Items.Add($item) | Out-Null
}
$menuHands.Items.Add($subML) | Out-Null

$contextMenu.Items.Add($menuHands) | Out-Null

# --- デジタル文字サイズ ---
$menuDigitalSize = New-Object System.Windows.Controls.MenuItem
$menuDigitalSize.Header = "デジタル文字サイズ"
foreach ($opt in @(@{L="小 (36px)";V=36}, @{L="標準 (64px)";V=64}, @{L="大 (96px)";V=96}, @{L="特大 (128px)";V=128})) {
    $item = New-Object System.Windows.Controls.MenuItem
    $item.Header = $opt.L; $item.Tag = $opt.V
    $item.Add_Click({ param($s,$e) $script:Settings.DigitalSize = [double]$s.Tag; Apply-Mode; Save-Settings })
    $menuDigitalSize.Items.Add($item) | Out-Null
}
$contextMenu.Items.Add($menuDigitalSize) | Out-Null

$contextMenu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null

# --- テーマ ---
$menuTheme = New-Object System.Windows.Controls.MenuItem
$menuTheme.Header = "カラーテーマ"

$menuDark = New-Object System.Windows.Controls.MenuItem
$menuDark.Header = "ダーク"
$menuDark.Add_Click({ $script:Settings.Theme = "dark"; Apply-Mode; Tick-Handler; Save-Settings })
$menuTheme.Items.Add($menuDark) | Out-Null

$menuLight = New-Object System.Windows.Controls.MenuItem
$menuLight.Header = "ライト"
$menuLight.Add_Click({ $script:Settings.Theme = "light"; Apply-Mode; Tick-Handler; Save-Settings })
$menuTheme.Items.Add($menuLight) | Out-Null

$menuBlue = New-Object System.Windows.Controls.MenuItem
$menuBlue.Header = "ブルー"
$menuBlue.Add_Click({ $script:Settings.Theme = "blue"; Apply-Mode; Tick-Handler; Save-Settings })
$menuTheme.Items.Add($menuBlue) | Out-Null

$contextMenu.Items.Add($menuTheme) | Out-Null

$contextMenu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null

# --- 透明度 ---
$menuOpacity = New-Object System.Windows.Controls.MenuItem
$menuOpacity.Header = "透明度"
$opacityValues = @(
    @{ Label = "100%"; Value = 1.0 },
    @{ Label = "85%"; Value = 0.85 },
    @{ Label = "70%"; Value = 0.70 },
    @{ Label = "50%"; Value = 0.50 },
    @{ Label = "30%"; Value = 0.30 }
)
foreach ($ov in $opacityValues) {
    $mi = New-Object System.Windows.Controls.MenuItem
    $mi.Header = $ov.Label; $mi.Tag = $ov.Value
    $mi.Add_Click({
        param($sender, $e)
        $script:Settings.Opacity = [double]$sender.Tag
        $window.Opacity = $script:Settings.Opacity
        Save-Settings
    })
    $menuOpacity.Items.Add($mi) | Out-Null
}
$contextMenu.Items.Add($menuOpacity) | Out-Null

$contextMenu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null

# --- リセット ---
$menuReset = New-Object System.Windows.Controls.MenuItem
$menuReset.Header = "設定リセット"
$menuReset.Add_Click({
    $script:Settings.Mode = "analog"
    $script:Settings.Theme = "dark"
    $script:Settings.Opacity = 0.85
    $script:Settings.ShowSeconds = $true
    $script:Settings.HourWidth = 2.5
    $script:Settings.HourLength = 45
    $script:Settings.MinuteWidth = 2.5
    $script:Settings.MinuteLength = 65
    $script:Settings.DigitalSize = 64
    if ($script:menuSeconds) { $script:menuSeconds.IsChecked = $true }
    Apply-Mode
    Tick-Handler
    Save-Settings
})
$contextMenu.Items.Add($menuReset) | Out-Null

$contextMenu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null

# --- 終了 ---
$menuExit = New-Object System.Windows.Controls.MenuItem
$menuExit.Header = "終了"
$menuExit.Add_Click({
    $script:Settings.Width = [int]$window.ActualWidth
    $script:Settings.Height = [int]$window.ActualHeight
    $script:Settings.Left = $window.Left
    $script:Settings.Top = $window.Top
    Save-Settings
    $window.Close()
})
$contextMenu.Items.Add($menuExit) | Out-Null

$window.ContextMenu = $contextMenu

# ===== ドラッグ移動 & ダブルクリック切替 =====
$window.Add_MouseLeftButtonDown({
    param($sender, $e)
    if ($e.ClickCount -eq 2) {
        $script:Settings.Mode = if ($script:Settings.Mode -eq "analog") { "digital" } else { "analog" }
        Apply-Mode
        Tick-Handler
        Save-Settings
    } else {
        try { $window.DragMove() } catch {}
    }
})

# ===== ウィンドウイベント =====
$window.Add_Loaded({
    Load-Settings
    
    $window.Width = $script:Settings.Width
    $window.Height = $script:Settings.Height
    
    if ($script:Settings.Left -ge 0 -and $script:Settings.Top -ge 0) {
        $window.Left = $script:Settings.Left
        $window.Top = $script:Settings.Top
    } else {
        $window.WindowStartupLocation = "CenterScreen"
    }
    
    Apply-Mode
    if ($script:menuSeconds) { $script:menuSeconds.IsChecked = $script:Settings.ShowSeconds }
    Tick-Handler
    
    $script:timer = New-Object System.Windows.Threading.DispatcherTimer
    $script:timer.Interval = [TimeSpan]::FromSeconds(1)
    $script:timer.Add_Tick({ Tick-Handler })
    $script:timer.Start()
})

$window.Add_SizeChanged({
    if ($script:Settings.Mode -eq "analog") {
        Draw-AnalogClock
    }
})

$window.Add_Closing({
    if ($script:timer) {
        $script:timer.Stop()
    }
    $script:Settings.Width = [int]$window.ActualWidth
    $script:Settings.Height = [int]$window.ActualHeight
    $script:Settings.Left = $window.Left
    $script:Settings.Top = $window.Top
    Save-Settings
})

# ===== 起動 =====
$window.ShowDialog() | Out-Null
