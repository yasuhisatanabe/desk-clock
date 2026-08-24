<# 
  Desk Clock - YClock風デスクトップ時計
  PowerShell + WPF版
  使い方: powershell -ExecutionPolicy Bypass -File desk_clock.ps1
  または start_clock.bat をダブルクリック
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# ===== 設定ファイルパス =====
$settingsDir = Join-Path $env:APPDATA "DeskClock"
$settingsFile = Join-Path $settingsDir "settings.json"

# ===== デフォルト設定 =====
$script:Settings = @{
    Mode        = "analog"
    Theme       = "dark"
    Opacity     = 0.85
    ShowSeconds = $true
    Width       = 300
    Height      = 300
    Left        = -1
    Top         = -1
}

# ===== テーマ定義 =====
$script:Themes = @{
    dark = @{
        Face            = "#E0181820"
        FaceBorder      = "#40505064"
        TickMajor       = "#9996969A"
        TickMinor       = "#4D646478"
        NumOuter        = "#B38C8CA0"
        NumInner        = "#66646478"
        HandHour        = "#CCA0A0B4"
        HandMinute      = "#B382829B"
        HandSecond      = "#998C8CA0"
        CenterDot       = "#B38C8CA0"
        DigitalColor    = "#CCA0A0B4"
        MenuBg          = "#F514141C"
        MenuText        = "#FFA0A0B8"
        MenuHover       = "#663C3C50"
        MenuBorder      = "#4046465A"
    }
    light = @{
        Face            = "#E0E1E1E6"
        FaceBorder      = "#4D9696AA"
        TickMajor       = "#803C3C50"
        TickMinor       = "#40646478"
        NumOuter        = "#99323246"
        NumInner        = "#66505064"
        HandHour        = "#B3323246"
        HandMinute      = "#9946465A"
        HandSecond      = "#80645055"
        CenterDot       = "#9946465A"
        DigitalColor    = "#B328283C"
        MenuBg          = "#F7E6E6EB"
        MenuText        = "#FF404058"
        MenuHover       = "#1A646482"
        MenuBorder      = "#409696AA"
    }
    blue = @{
        Face            = "#E00E1428"
        FaceBorder      = "#4D284678"
        TickMajor       = "#995A78AA"
        TickMinor       = "#403C5078"
        NumOuter        = "#A6648CBE"
        NumInner        = "#663C5A82"
        HandHour        = "#B3648CBE"
        HandMinute      = "#995073A5"
        HandSecond      = "#80466E96"
        CenterDot       = "#995073A5"
        DigitalColor    = "#B36496C8"
        MenuBg          = "#F70A1024"
        MenuText        = "#FF6890B8"
        MenuHover       = "#4D1E3C6E"
        MenuBorder      = "#40284164"
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
[xml]$xaml = @"
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

    <Window.Resources>
        <Style x:Key="MenuItemStyle" TargetType="MenuItem">
            <Setter Property="Foreground" Value="#D0D0E0"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="FontFamily" Value="Segoe UI, Yu Gothic UI, Meiryo"/>
            <Setter Property="Padding" Value="8,6"/>
        </Style>
    </Window.Resources>

    <Grid x:Name="MainGrid">
        <!-- Analog Clock Canvas -->
        <Canvas x:Name="AnalogCanvas" 
                HorizontalAlignment="Stretch" 
                VerticalAlignment="Stretch"/>
        
        <!-- Digital Clock -->
        <Border x:Name="DigitalBorder" 
                CornerRadius="16" 
                Padding="20,14"
                HorizontalAlignment="Center"
                VerticalAlignment="Center"
                Visibility="Collapsed">
            <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
                <TextBlock x:Name="DigitalTime" 
                           Text="00:00"
                           FontSize="64"
                           FontWeight="Light"
                           FontFamily="Segoe UI, Consolas"
                           HorizontalAlignment="Center"/>
            </StackPanel>
        </Border>

        <!-- Resize Grip (bottom-right corner) -->
        <ResizeGrip x:Name="ResizeGrip" 
                    HorizontalAlignment="Right" 
                    VerticalAlignment="Bottom"
                    Opacity="0.3"/>
    </Grid>
</Window>
"@

# ===== ウィンドウ作成 =====
$reader = New-Object System.Xml.XmlNodeReader $xaml
$window = [Windows.Markup.XamlReader]::Load($reader)

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

    $cx = $w / 2
    $cy = $h / 2
    $r = [Math]::Min($cx, $cy) - 4

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
        $angle = ($i * 6 - 90) * [Math]::PI / 180
        $isMajor = ($i % 5 -eq 0)
        $outerTR = $r * 0.92
        $innerTR = if ($isMajor) { $r * 0.82 } else { $r * 0.87 }
        
        $line = New-Object System.Windows.Shapes.Line
        $line.X1 = $cx + $outerTR * [Math]::Cos($angle)
        $line.Y1 = $cy + $outerTR * [Math]::Sin($angle)
        $line.X2 = $cx + $innerTR * [Math]::Cos($angle)
        $line.Y2 = $cy + $innerTR * [Math]::Sin($angle)
        $line.Stroke = if ($isMajor) { Get-BrushFromHex $theme.TickMajor } else { Get-BrushFromHex $theme.TickMinor }
        $line.StrokeThickness = if ($isMajor) { 2.5 } else { 1 }
        $line.StrokeStartLineCap = "Round"
        $line.StrokeEndLineCap = "Round"
        $analogCanvas.Children.Add($line) | Out-Null
    }

    # Hour hand
    $hourAngle = (($hours % 12) * 30 + $minutes * 0.5 - 90) * [Math]::PI / 180
    $hLine = New-Object System.Windows.Shapes.Line
    $hLine.X1 = $cx; $hLine.Y1 = $cy
    $hLine.X2 = $cx + $r * 0.45 * [Math]::Cos($hourAngle)
    $hLine.Y2 = $cy + $r * 0.45 * [Math]::Sin($hourAngle)
    $hLine.Stroke = Get-BrushFromHex $theme.HandHour
    $hLine.StrokeThickness = 2.5
    $hLine.StrokeStartLineCap = "Round"
    $hLine.StrokeEndLineCap = "Round"
    $analogCanvas.Children.Add($hLine) | Out-Null

    # Minute hand
    $minAngle = ($minutes * 6 + $seconds * 0.1 - 90) * [Math]::PI / 180
    $mLine = New-Object System.Windows.Shapes.Line
    $mLine.X1 = $cx; $mLine.Y1 = $cy
    $mLine.X2 = $cx + $r * 0.65 * [Math]::Cos($minAngle)
    $mLine.Y2 = $cy + $r * 0.65 * [Math]::Sin($minAngle)
    $mLine.Stroke = Get-BrushFromHex $theme.HandMinute
    $mLine.StrokeThickness = 2.5
    $mLine.StrokeStartLineCap = "Round"
    $mLine.StrokeEndLineCap = "Round"
    $analogCanvas.Children.Add($mLine) | Out-Null

    # Second hand (conditional)
    if ($script:Settings.ShowSeconds) {
        $secAngle = ($seconds * 6 - 90) * [Math]::PI / 180
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
    $centerDot.Width = 10
    $centerDot.Height = 10
    $centerDot.Fill = Get-BrushFromHex $theme.CenterDot
    [System.Windows.Controls.Canvas]::SetLeft($centerDot, $cx - 5)
    [System.Windows.Controls.Canvas]::SetTop($centerDot, $cy - 5)
    $analogCanvas.Children.Add($centerDot) | Out-Null

    # Inner center dot
    $innerDot = New-Object System.Windows.Shapes.Ellipse
    $innerDot.Width = 4
    $innerDot.Height = 4
    $innerDot.Fill = Get-BrushFromHex $theme.Face
    [System.Windows.Controls.Canvas]::SetLeft($innerDot, $cx - 2)
    [System.Windows.Controls.Canvas]::SetTop($innerDot, $cy - 2)
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

# --- 表示モードヘッダー ---
$headerMode = New-Object System.Windows.Controls.MenuItem
$headerMode.Header = "━━ 表示モード ━━"
$headerMode.IsEnabled = $false
$headerMode.FontSize = 11
$contextMenu.Items.Add($headerMode) | Out-Null

$menuAnalog = New-Object System.Windows.Controls.MenuItem
$menuAnalog.Header = "🕐 アナログ"
$menuAnalog.Add_Click({
    $script:Settings.Mode = "analog"
    Apply-Mode
    Tick-Handler
    Save-Settings
})
$contextMenu.Items.Add($menuAnalog) | Out-Null

$menuDigital = New-Object System.Windows.Controls.MenuItem
$menuDigital.Header = "🔢 デジタル"
$menuDigital.Add_Click({
    $script:Settings.Mode = "digital"
    Apply-Mode
    Tick-Handler
    Save-Settings
})
$contextMenu.Items.Add($menuDigital) | Out-Null

$contextMenu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null

# --- 秒針表示トグル ---
$headerDisplay = New-Object System.Windows.Controls.MenuItem
$headerDisplay.Header = "━━ 表示設定 ━━"
$headerDisplay.IsEnabled = $false
$headerDisplay.FontSize = 11
$contextMenu.Items.Add($headerDisplay) | Out-Null

$script:menuSeconds = New-Object System.Windows.Controls.MenuItem
$script:menuSeconds.Header = "⏲ 秒針を表示"
$script:menuSeconds.IsCheckable = $true
$script:menuSeconds.IsChecked = $true
$script:menuSeconds.Add_Click({
    $script:Settings.ShowSeconds = $script:menuSeconds.IsChecked
    Tick-Handler
    Save-Settings
})
$contextMenu.Items.Add($script:menuSeconds) | Out-Null

$contextMenu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null

# --- テーマヘッダー ---
$headerTheme = New-Object System.Windows.Controls.MenuItem
$headerTheme.Header = "━━ カラーテーマ ━━"
$headerTheme.IsEnabled = $false
$headerTheme.FontSize = 11
$contextMenu.Items.Add($headerTheme) | Out-Null

$menuDark = New-Object System.Windows.Controls.MenuItem
$menuDark.Header = "⬛ ダーク"
$menuDark.Add_Click({
    $script:Settings.Theme = "dark"
    Apply-Mode
    Tick-Handler
    Save-Settings
})
$contextMenu.Items.Add($menuDark) | Out-Null

$menuLight = New-Object System.Windows.Controls.MenuItem
$menuLight.Header = "⬜ ライト"
$menuLight.Add_Click({
    $script:Settings.Theme = "light"
    Apply-Mode
    Tick-Handler
    Save-Settings
})
$contextMenu.Items.Add($menuLight) | Out-Null

$menuBlue = New-Object System.Windows.Controls.MenuItem
$menuBlue.Header = "🔵 ブルー"
$menuBlue.Add_Click({
    $script:Settings.Theme = "blue"
    Apply-Mode
    Tick-Handler
    Save-Settings
})
$contextMenu.Items.Add($menuBlue) | Out-Null

$contextMenu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null

# --- 透明度ヘッダー ---
$headerOpacity = New-Object System.Windows.Controls.MenuItem
$headerOpacity.Header = "━━ 透明度 ━━"
$headerOpacity.IsEnabled = $false
$headerOpacity.FontSize = 11
$contextMenu.Items.Add($headerOpacity) | Out-Null

# 透明度メニュー項目
$opacityValues = @(
    @{ Label = "100%"; Value = 1.0 },
    @{ Label = "85%"; Value = 0.85 },
    @{ Label = "70%"; Value = 0.70 },
    @{ Label = "50%"; Value = 0.50 },
    @{ Label = "30%"; Value = 0.30 }
)

foreach ($ov in $opacityValues) {
    $mi = New-Object System.Windows.Controls.MenuItem
    $mi.Header = $ov.Label
    $mi.Tag = $ov.Value
    $mi.Add_Click({
        param($sender, $e)
        $script:Settings.Opacity = [double]$sender.Tag
        $window.Opacity = $script:Settings.Opacity
        Save-Settings
    })
    $contextMenu.Items.Add($mi) | Out-Null
}

$contextMenu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null

# --- リセット ---
$menuReset = New-Object System.Windows.Controls.MenuItem
$menuReset.Header = "🔄 設定リセット"
$menuReset.Add_Click({
    $script:Settings.Mode = "analog"
    $script:Settings.Theme = "dark"
    $script:Settings.Opacity = 0.85
    $script:Settings.ShowSeconds = $true
    if ($script:menuSeconds) { $script:menuSeconds.IsChecked = $true }
    Apply-Mode
    Tick-Handler
    Save-Settings
})
$contextMenu.Items.Add($menuReset) | Out-Null

$contextMenu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null

# --- 終了 ---
$menuExit = New-Object System.Windows.Controls.MenuItem
$menuExit.Header = "✕ 終了"
$menuExit.Add_Click({
    # 現在位置とサイズを保存
    $script:Settings.Width = [int]$window.ActualWidth
    $script:Settings.Height = [int]$window.ActualHeight
    $script:Settings.Left = $window.Left
    $script:Settings.Top = $window.Top
    Save-Settings
    $window.Close()
})
$contextMenu.Items.Add($menuExit) | Out-Null

$window.ContextMenu = $contextMenu

# ===== ドラッグ移動 =====
$window.Add_MouseLeftButtonDown({
    param($sender, $e)
    $window.DragMove()
})

# ===== ウィンドウイベント =====
$window.Add_Loaded({
    # 設定読み込み
    Load-Settings
    
    # ウィンドウサイズ復元
    $window.Width = $script:Settings.Width
    $window.Height = $script:Settings.Height
    
    # 位置復元
    if ($script:Settings.Left -ge 0 -and $script:Settings.Top -ge 0) {
        $window.Left = $script:Settings.Left
        $window.Top = $script:Settings.Top
    } else {
        $window.WindowStartupLocation = "CenterScreen"
    }
    
    Apply-Mode
    # 秒針チェックボックスを設定に合わせる
    if ($script:menuSeconds) { $script:menuSeconds.IsChecked = $script:Settings.ShowSeconds }
    Tick-Handler
    
    # タイマー開始（1秒間隔）
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
    # 位置とサイズを保存
    $script:Settings.Width = [int]$window.ActualWidth
    $script:Settings.Height = [int]$window.ActualHeight
    $script:Settings.Left = $window.Left
    $script:Settings.Top = $window.Top
    Save-Settings
})

# ===== 起動 =====
$window.ShowDialog() | Out-Null
