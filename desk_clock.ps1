<# 
  Desk Clock - 軽量・ミニマル デスクトップ時計
  PowerShell + WPF版
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# ===== Win32 API (Click-Through) =====
$win32Code = @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    public const int GWL_EXSTYLE = -20;
    public const int WS_EX_TRANSPARENT = 0x00000020;
    public const int WS_EX_LAYERED = 0x00080000;

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    public static void SetClickThrough(IntPtr hWnd, bool enable) {
        int style = GetWindowLong(hWnd, GWL_EXSTYLE);
        if (enable) {
            SetWindowLong(hWnd, GWL_EXSTYLE, style | WS_EX_TRANSPARENT | WS_EX_LAYERED);
        } else {
            SetWindowLong(hWnd, GWL_EXSTYLE, style & ~WS_EX_TRANSPARENT);
        }
    }
}
"@
try { Add-Type -TypeDefinition $win32Code -Language CSharp } catch {}

# ===== 設定ファイルパス =====
$settingsDir = Join-Path $env:APPDATA "DeskClock"
$settingsFile = Join-Path $settingsDir "settings.json"
$startupLnk = Join-Path ([Environment]::GetFolderPath("Startup")) "DeskClock.lnk"

# ===== デフォルト設定 =====
$script:Settings = @{
    Mode            = "analog"      # "analog" or "digital"
    Theme           = "dark"        # "dark", "light", "blue"
    Opacity         = 0.85          # 0.30 - 1.00
    ShowSeconds     = $false        # $true / $false (秒針表示)
    SmartOpacity    = $false        # $true / $false (スマート透過: 平常時半透明、ホバー時100%)
    ClickThrough    = $false        # $true / $false (クリックすり抜け)
    Topmost         = $true         # $true / $false (最前面固定)
    ShowDate        = $false        # $true / $false (デジタル時日付・曜日表示)
    Scale           = 100           # 40 - 360 (%) 表示倍率。アナログ・デジタル共通
    HourWidth       = 4.0           # 1.5 - 6.0
    HourLength      = 45            # 35 - 55 (%)
    MinuteWidth     = 4.0           # 1.5 - 6.0
    MinuteLength    = 82            # 55 - 80 (%)
    SecondWidth     = 1.5           # 1.0 - 4.0
    SecondLength    = 72            # 60 - 85 (%)
    DigitalSize     = 64.0          # 36 - 128 (px)
    Width           = 220
    Height          = 220
    Left            = -1            # -1 = CenterScreen
    Top             = -1
}

# 表示倍率 100% のときのアナログ時計ウィンドウの一辺 (px)
$script:BaseAnalogSize = 220.0

# ===== テーマ定義 =====
$script:Themes = @{
    dark = @{
        Face            = "#EB181820"
        TickMajor       = "#F2DCDCF0"
        TickMinor       = "#80DCDCF0"
        HandHour        = "#F2DCDCF0"
        HandMinute      = "#F2DCDCF0"
        HandSecond      = "#B3B4B4CF"
    }
    light = @{
        Face            = "#EBEBEBF0"
        TickMajor       = "#F21E1E32"
        TickMinor       = "#801E1E32"
        HandHour        = "#F21E1E32"
        HandMinute      = "#F21E1E32"
        HandSecond      = "#A65A464B"
    }
    blue = @{
        Face            = "#EB0E1428"
        TickMajor       = "#F28CBEF5"
        TickMinor       = "#808CBEF5"
        HandHour        = "#F28CBEF5"
        HandMinute      = "#F28CBEF5"
        HandSecond      = "#B36496C8"
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
            if ($null -ne $json.SmartOpacity) { $script:Settings.SmartOpacity = [bool]$json.SmartOpacity }
            if ($null -ne $json.ClickThrough) { $script:Settings.ClickThrough = [bool]$json.ClickThrough }
            if ($null -ne $json.Topmost) { $script:Settings.Topmost = [bool]$json.Topmost }
            if ($null -ne $json.ShowDate) { $script:Settings.ShowDate = [bool]$json.ShowDate }
            if ($null -ne $json.Scale) { $script:Settings.Scale = [int]$json.Scale }
            if ($null -ne $json.HourWidth) { $script:Settings.HourWidth = [double]$json.HourWidth }
            if ($null -ne $json.HourLength) { $script:Settings.HourLength = [int]$json.HourLength }
            if ($null -ne $json.MinuteWidth) { $script:Settings.MinuteWidth = [double]$json.MinuteWidth }
            if ($null -ne $json.MinuteLength) { $script:Settings.MinuteLength = [int]$json.MinuteLength }
            if ($null -ne $json.SecondWidth) { $script:Settings.SecondWidth = [double]$json.SecondWidth }
            if ($null -ne $json.SecondLength) { $script:Settings.SecondLength = [int]$json.SecondLength }
            if ($null -ne $json.DigitalSize) { $script:Settings.DigitalSize = [double]$json.DigitalSize }
            if ($null -ne $json.Width) { $script:Settings.Width = [int]$json.Width }
            if ($null -ne $json.Height) { $script:Settings.Height = [int]$json.Height }
            if ($null -ne $json.Left) { $script:Settings.Left = [double]$json.Left }
            if ($null -ne $json.Top) { $script:Settings.Top = [double]$json.Top }
            if ($null -eq $json.Scale -and $null -ne $json.Width) {
                # Scale 導入前の設定ファイルからの移行
                $script:Settings.Scale = [Math]::Max(40, [Math]::Min(360, [int][Math]::Round([int]$json.Width / $script:BaseAnalogSize * 100)))
            }
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

# ホイール等の連続操作で毎回ディスクへ書かないよう保存を 400ms 遅延させる
$script:saveTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:saveTimer.Interval = [TimeSpan]::FromMilliseconds(400)
$script:saveTimer.Add_Tick({
    $script:saveTimer.Stop()
    Save-Settings
})

function Request-Save {
    $script:saveTimer.Stop()
    $script:saveTimer.Start()
}

# ===== XAML =====
$xaml = @"
<Window 
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title=""
    WindowStyle="None"
    AllowsTransparency="True"
    Background="Transparent"
    Topmost="True"
    ShowInTaskbar="True"
    ResizeMode="CanResize"
    MinWidth="100" MinHeight="100"
    Width="220" Height="220">

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
                           FontWeight="SemiBold"
                           FontFamily="Segoe UI, Consolas"
                           HorizontalAlignment="Center"/>
                <TextBlock x:Name="DigitalDate" 
                           Text="1月1日 (日)"
                           FontSize="18"
                           FontWeight="Normal"
                           FontFamily="Segoe UI, Meiryo"
                           Opacity="0.7"
                           HorizontalAlignment="Center"
                           Margin="0,4,0,0"
                           Visibility="Collapsed"/>
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
$digitalDate = $window.FindName("DigitalDate")

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
    [System.Windows.Controls.Canvas]::SetLeft($faceEllipse, $cx - $r)
    [System.Windows.Controls.Canvas]::SetTop($faceEllipse, $cy - $r)
    $analogCanvas.Children.Add($faceEllipse) | Out-Null

    # Tick marks
    for ($i = 0; $i -lt 60; $i++) {
        $angle = ($i * 6 - 90) * [Math]::PI / 180.0
        $isMajor = ($i % 5 -eq 0)
        $outerTR = $r - 2.0
        $innerTR = if ($isMajor) { $outerTR - $r * 0.11 } else { $outerTR - $r * 0.055 }
        
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
        $sLen = $r * ($script:Settings.SecondLength / 100.0)
        $sLine = New-Object System.Windows.Shapes.Line
        $sLine.X1 = $cx; $sLine.Y1 = $cy
        $sLine.X2 = $cx + $sLen * [Math]::Cos($secAngle)
        $sLine.Y2 = $cy + $sLen * [Math]::Sin($secAngle)
        $sLine.Stroke = Get-BrushFromHex $theme.HandSecond
        $sLine.StrokeThickness = $script:Settings.SecondWidth
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
        $cLine.StrokeThickness = $script:Settings.SecondWidth
        $cLine.StrokeStartLineCap = "Round"
        $cLine.StrokeEndLineCap = "Round"
        $analogCanvas.Children.Add($cLine) | Out-Null
    }
}

# ===== デジタル時計更新 =====
$script:DaysJa = @("日", "月", "火", "水", "木", "金", "土")

function Update-DigitalClock {
    $now = Get-Date
    $digitalTime.Text = $now.ToString("HH:mm")
    if ($script:Settings.ShowDate) {
        # OS のロケールに依存しないよう曜日は自前で組み立てる
        $dow = $script:DaysJa[[int]$now.DayOfWeek]
        $digitalDate.Text = "$($now.Month)月$($now.Day)日 ($dow)"
    }
}

# ===== ウィンドウ透明度・クリック透過 =====
function Apply-WindowOpacity {
    if ($script:Settings.SmartOpacity) {
        $window.Opacity = $script:Settings.Opacity * 0.45
    } else {
        $window.Opacity = $script:Settings.Opacity
    }
}

function Apply-ClickThrough {
    try {
        $helper = New-Object System.Windows.Interop.WindowInteropHelper($window)
        $hwnd = $helper.Handle
        if ($hwnd -ne [IntPtr]::Zero) {
            [Win32]::SetClickThrough($hwnd, $script:Settings.ClickThrough)
        }
    } catch {}
}

# ===== スナップ配置 =====
function Snap-Window([string]$pos) {
    $workArea = [System.Windows.SystemParameters]::WorkArea
    $margin = 16.0
    # レイアウト前は ActualWidth が 0 のため、指定済みの Width を優先する
    $w = if ([double]::IsNaN($window.Width) -or $window.Width -le 0) { $window.ActualWidth } else { $window.Width }
    $h = if ([double]::IsNaN($window.Height) -or $window.Height -le 0) { $window.ActualHeight } else { $window.Height }
    
    switch ($pos) {
        "top-left" {
            $window.Left = $workArea.Left + $margin
            $window.Top = $workArea.Top + $margin
        }
        "top-center" {
            $window.Left = $workArea.Left + ($workArea.Width - $w) / 2.0
            $window.Top = $workArea.Top + $margin
        }
        "top-right" {
            $window.Left = $workArea.Right - $w - $margin
            $window.Top = $workArea.Top + $margin
        }
        "bottom-left" {
            $window.Left = $workArea.Left + $margin
            $window.Top = $workArea.Bottom - $h - $margin
        }
        "bottom-right" {
            $window.Left = $workArea.Right - $w - $margin
            $window.Top = $workArea.Bottom - $h - $margin
        }
        "center" {
            $window.Left = $workArea.Left + ($workArea.Width - $w) / 2.0
            $window.Top = $workArea.Top + ($workArea.Height - $h) / 2.0
        }
    }
    $script:Settings.Left = $window.Left
    $script:Settings.Top = $window.Top
    Save-Settings
}

# ===== デジタル表示のサイズ合わせ =====
# $exact = $false のときは「はみ出す場合のみ広げる」（ユーザーが決めたサイズを尊重）
function Fit-DigitalWindow([bool]$exact = $false) {
    if ($script:Settings.Mode -ne "digital") { return }
    try {
        $inf = New-Object System.Windows.Size -ArgumentList ([double]::PositiveInfinity), ([double]::PositiveInfinity)
        $digitalBorder.Measure($inf)
        $needW = [Math]::Ceiling($digitalBorder.DesiredSize.Width) + 4
        $needH = [Math]::Ceiling($digitalBorder.DesiredSize.Height) + 4
        $digitalBorder.InvalidateMeasure()
    } catch { return }
    if ($needW -le 0 -or $needH -le 0) { return }

    $curW = if ([double]::IsNaN($window.Width)) { $window.ActualWidth } else { $window.Width }
    $curH = if ([double]::IsNaN($window.Height)) { $window.ActualHeight } else { $window.Height }
    $newW = if ($exact) { $needW } else { [Math]::Max($curW, $needW) }
    $newH = if ($exact) { $needH } else { [Math]::Max($curH, $needH) }

    $window.Width  = [Math]::Max(100, [Math]::Min(800, $newW))
    $window.Height = [Math]::Max(100, [Math]::Min(800, $newH))
    $script:Settings.Width  = [int]$window.Width
    $script:Settings.Height = [int]$window.Height
}

# ===== 表示倍率 =====
function Apply-Scale {
    $ratio = [Math]::Max(40, [Math]::Min(360, [int]$script:Settings.Scale)) / 100.0
    if ($script:Settings.Mode -eq "analog") {
        $size = [Math]::Max(100, [Math]::Min(800, $script:BaseAnalogSize * $ratio))
        $window.Width  = $size
        $window.Height = $size
        $script:Settings.Width  = [int]$size
        $script:Settings.Height = [int]$size
    } else {
        $digitalTime.FontSize = [Math]::Max(16, [Math]::Round($script:Settings.DigitalSize * $ratio))
        $digitalDate.FontSize = [Math]::Max(11, [Math]::Round($digitalTime.FontSize * 0.28))
        Fit-DigitalWindow $true
    }
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
        $digitalBorder.Background = [System.Windows.Media.Brushes]::Transparent
        $digitalBorder.BorderBrush = [System.Windows.Media.Brushes]::Transparent
        $digitalBorder.BorderThickness = New-Object System.Windows.Thickness(0)
        $digitalTime.Foreground = Get-BrushFromHex $theme.HandHour
        $digitalDate.Foreground = Get-BrushFromHex $theme.HandHour
        $digitalDate.Visibility = if ($script:Settings.ShowDate) { "Visible" } else { "Collapsed" }
    }
    Apply-Scale

    $window.Topmost = $script:Settings.Topmost
    Apply-WindowOpacity
    Apply-ClickThrough
}

# ===== タイマー & 省電力制御 =====
function Adjust-TimerInterval {
    if (-not $script:timer) { return }
    if ($script:Settings.Mode -eq "analog" -and $script:Settings.ShowSeconds) {
        # Interval への代入は稼働中タイマーを再スタートさせるため、変化時のみ書き込む
        $oneSec = [TimeSpan]::FromSeconds(1)
        if ($script:timer.Interval -ne $oneSec) { $script:timer.Interval = $oneSec }
    } else {
        # 秒針OFF時は次の 00 秒までミリ秒単位で同期し、更新を毎分1回に抑える
        $now = Get-Date
        $msToNextMin = (60 - $now.Second) * 1000 - $now.Millisecond + 50
        # 直近の 00 秒を跨いでしまわないよう、下限は 1 秒に丸めるだけに留める
        if ($msToNextMin -lt 1000) { $msToNextMin = 1000 }
        $script:timer.Interval = [TimeSpan]::FromMilliseconds($msToNextMin)
    }
}

function Tick-Handler {
    if ($script:Settings.Mode -eq "analog") {
        Draw-AnalogClock
    } else {
        Update-DigitalClock
    }
    Adjust-TimerInterval
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

# --- 最前面固定 ---
$script:menuTopmost = New-Object System.Windows.Controls.MenuItem
$script:menuTopmost.Header = "最前面に固定 (Ctrl+Shift+T)"
$script:menuTopmost.IsCheckable = $true
$script:menuTopmost.IsChecked = $script:Settings.Topmost
$script:menuTopmost.Add_Click({
    $script:Settings.Topmost = $script:menuTopmost.IsChecked
    $window.Topmost = $script:Settings.Topmost
    Save-Settings
})
$contextMenu.Items.Add($script:menuTopmost) | Out-Null

# --- 秒針表示トグル ---
$script:menuSeconds = New-Object System.Windows.Controls.MenuItem
$script:menuSeconds.Header = "秒針を表示"
$script:menuSeconds.IsCheckable = $true
$script:menuSeconds.IsChecked = $false
$script:menuSeconds.Add_Click({
    $script:Settings.ShowSeconds = $script:menuSeconds.IsChecked
    Tick-Handler
    Save-Settings
})
$contextMenu.Items.Add($script:menuSeconds) | Out-Null

# --- スマート透過 (マウス連動) ---
$script:menuSmartOp = New-Object System.Windows.Controls.MenuItem
$script:menuSmartOp.Header = "スマート透過 (マウス連動)"
$script:menuSmartOp.IsCheckable = $true
$script:menuSmartOp.IsChecked = $false
$script:menuSmartOp.Add_Click({
    $script:Settings.SmartOpacity = $script:menuSmartOp.IsChecked
    Apply-WindowOpacity
    Save-Settings
})
$contextMenu.Items.Add($script:menuSmartOp) | Out-Null

# --- クリックすり抜けモード ---
$script:menuClickThrough = New-Object System.Windows.Controls.MenuItem
$script:menuClickThrough.Header = "クリックすり抜け (Ctrl+Shift+X)"
$script:menuClickThrough.IsCheckable = $true
$script:menuClickThrough.IsChecked = $false
$script:menuClickThrough.Add_Click({
    $script:Settings.ClickThrough = $script:menuClickThrough.IsChecked
    Apply-ClickThrough
    Save-Settings
})
$contextMenu.Items.Add($script:menuClickThrough) | Out-Null

# --- 日付・曜日表示トグル ---
$script:menuDate = New-Object System.Windows.Controls.MenuItem
$script:menuDate.Header = "日付・曜日を表示 (デジタル)"
$script:menuDate.IsCheckable = $true
$script:menuDate.IsChecked = $script:Settings.ShowDate
$script:menuDate.Add_Click({
    $script:Settings.ShowDate = $script:menuDate.IsChecked
    Apply-Mode
    Tick-Handler
    Save-Settings
})
$contextMenu.Items.Add($script:menuDate) | Out-Null

$contextMenu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null

# --- 配置スナップ ---
$menuSnap = New-Object System.Windows.Controls.MenuItem
$menuSnap.Header = "配置スナップ"

$snapOptions = @(
    @{L="左上"; V="top-left"},
    @{L="上中"; V="top-center"},
    @{L="右上"; V="top-right"},
    @{L="左下"; V="bottom-left"},
    @{L="中央"; V="center"},
    @{L="右下"; V="bottom-right"}
)
foreach ($opt in $snapOptions) {
    $item = New-Object System.Windows.Controls.MenuItem
    $item.Header = $opt.L; $item.Tag = $opt.V
    $item.Add_Click({ param($s,$e) Snap-Window $s.Tag })
    $menuSnap.Items.Add($item) | Out-Null
}
$contextMenu.Items.Add($menuSnap) | Out-Null

$contextMenu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null

# --- スタートアップ自動起動 ---
$script:menuStartup = New-Object System.Windows.Controls.MenuItem
$script:menuStartup.Header = "Windows起動時に自動起動"
$script:menuStartup.IsCheckable = $true
$script:menuStartup.IsChecked = (Test-Path $startupLnk)
$script:menuStartup.Add_Click({
    if ($script:menuStartup.IsChecked) {
        # 作成
        try {
            $wsh = New-Object -ComObject WScript.Shell
            $sc = $wsh.CreateShortcut($startupLnk)
            $vbsPath = Join-Path $PSScriptRoot "start_clock.vbs"
            if (Test-Path $vbsPath) {
                $sc.TargetPath = "wscript.exe"
                $sc.Arguments = "`"$vbsPath`""
                $sc.WorkingDirectory = $PSScriptRoot
            } else {
                $sc.TargetPath = "powershell.exe"
                $sc.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -NoProfile -File `"$PSCommandPath`""
                $sc.WorkingDirectory = $PSScriptRoot
            }
            $sc.WindowStyle = 7
            $sc.Description = "Desk Clock Startup Launcher"
            $sc.Save()
        } catch {}
    } else {
        # 削除
        if (Test-Path $startupLnk) { Remove-Item $startupLnk -Force -ErrorAction SilentlyContinue }
    }
})
$contextMenu.Items.Add($script:menuStartup) | Out-Null

$contextMenu.Items.Add((New-Object System.Windows.Controls.Separator)) | Out-Null

# --- 針の設定（ヘルパー関数でDRY化） ---
function New-OptionSubMenu {
    param([string]$Header, [hashtable[]]$Options, [string]$SettingsKey, [string]$ValueType, [scriptblock]$OnChange)
    $sub = New-Object System.Windows.Controls.MenuItem
    $sub.Header = $Header
    foreach ($opt in $Options) {
        $item = New-Object System.Windows.Controls.MenuItem
        $item.Header = $opt.L
        $item.Tag = $opt.V
        $item.Add_Click({
            param($s, $e)
            if ($ValueType -eq 'double') {
                $script:Settings[$SettingsKey] = [double]$s.Tag
            } else {
                $script:Settings[$SettingsKey] = [int]$s.Tag
            }
            if ($OnChange) { & $OnChange }
            Save-Settings
        }.GetNewClosure())
        $sub.Items.Add($item) | Out-Null
    }
    return $sub
}

$menuHands = New-Object System.Windows.Controls.MenuItem
$menuHands.Header = "針の設定"

$tickOnChange = { Tick-Handler }

$menuHands.Items.Add((New-OptionSubMenu -Header "時針 太さ" -Options @(
    @{L="極細 (1.5px)";V=1.5}, @{L="標準 (2.5px)";V=2.5}, @{L="太め (4.0px)";V=4.0}, @{L="極太 (6.0px)";V=6.0}
) -SettingsKey "HourWidth" -ValueType "double" -OnChange $tickOnChange)) | Out-Null

$menuHands.Items.Add((New-OptionSubMenu -Header "時針 長さ" -Options @(
    @{L="短め (35%)";V=35}, @{L="標準 (45%)";V=45}, @{L="長め (55%)";V=55}
) -SettingsKey "HourLength" -ValueType "int" -OnChange $tickOnChange)) | Out-Null

$menuHands.Items.Add((New-OptionSubMenu -Header "分針 太さ" -Options @(
    @{L="極細 (1.5px)";V=1.5}, @{L="標準 (2.5px)";V=2.5}, @{L="太め (4.0px)";V=4.0}, @{L="極太 (6.0px)";V=6.0}
) -SettingsKey "MinuteWidth" -ValueType "double" -OnChange $tickOnChange)) | Out-Null

$menuHands.Items.Add((New-OptionSubMenu -Header "分針 長さ" -Options @(
    @{L="短め (55%)";V=55}, @{L="標準 (65%)";V=65}, @{L="長め (80%)";V=80}
) -SettingsKey "MinuteLength" -ValueType "int" -OnChange $tickOnChange)) | Out-Null

$menuHands.Items.Add((New-OptionSubMenu -Header "秒針 太さ" -Options @(
    @{L="極細 (1.0px)";V=1.0}, @{L="標準 (1.5px)";V=1.5}, @{L="太め (2.5px)";V=2.5}, @{L="極太 (4.0px)";V=4.0}
) -SettingsKey "SecondWidth" -ValueType "double" -OnChange $tickOnChange)) | Out-Null

$menuHands.Items.Add((New-OptionSubMenu -Header "秒針 長さ" -Options @(
    @{L="短め (60%)";V=60}, @{L="標準 (72%)";V=72}, @{L="長め (85%)";V=85}
) -SettingsKey "SecondLength" -ValueType "int" -OnChange $tickOnChange)) | Out-Null

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
    @{ Label = "30%"; Value = 0.30 },
    @{ Label = "15%"; Value = 0.15 }
)
foreach ($ov in $opacityValues) {
    $mi = New-Object System.Windows.Controls.MenuItem
    $mi.Header = $ov.Label; $mi.Tag = $ov.Value
    $mi.Add_Click({
        param($sender, $e)
        $script:Settings.Opacity = [double]$sender.Tag
        Apply-WindowOpacity
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
    $script:Settings.ShowSeconds = $false
    $script:Settings.SmartOpacity = $false
    $script:Settings.ClickThrough = $false
    $script:Settings.Topmost = $true
    $script:Settings.ShowDate = $false
    $script:Settings.HourWidth = 4.0
    $script:Settings.HourLength = 45
    $script:Settings.MinuteWidth = 4.0
    $script:Settings.MinuteLength = 82
    $script:Settings.SecondWidth = 1.5
    $script:Settings.SecondLength = 72
    $script:Settings.DigitalSize = 64.0
    $script:Settings.Scale = 100
    # メニューのチェック状態を全て同期
    if ($script:menuTopmost) { $script:menuTopmost.IsChecked = $true }
    if ($script:menuSeconds) { $script:menuSeconds.IsChecked = $false }
    if ($script:menuSmartOp) { $script:menuSmartOp.IsChecked = $false }
    if ($script:menuClickThrough) { $script:menuClickThrough.IsChecked = $false }
    if ($script:menuDate) { $script:menuDate.IsChecked = $false }
    Apply-Mode
    Apply-ClickThrough
    Snap-Window "top-right"
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

# ===== マウスホイール操作 =====
$window.Add_PreviewMouseWheel({
    param($sender, $e)
    $e.Handled = $true
    $ctrlDown = ([System.Windows.Input.Keyboard]::Modifiers -band [System.Windows.Input.ModifierKeys]::Control) -ne 0

    if ($ctrlDown) {
        # Ctrl + ホイール: 表示倍率をアナログ・デジタル共通で 5% 刻み調整
        $step = if ($e.Delta -gt 0) { 5 } else { -5 }
        $script:Settings.Scale = [Math]::Max(40, [Math]::Min(360, [int]$script:Settings.Scale + $step))
        Apply-Scale
    } else {
        # 通常ホイール: 透明度 5% 刻み
        $step = if ($e.Delta -gt 0) { 0.05 } else { -0.05 }
        $newOp = [Math]::Max(0.15, [Math]::Min(1.0, $script:Settings.Opacity + $step))
        $script:Settings.Opacity = [Math]::Round($newOp, 2)
        # スマート透過ON時もホバー中は 1.0 に固定されるため、調整値を直接反映して手応えを出す
        $window.Opacity = $script:Settings.Opacity
    }
    Request-Save
})

# ===== ホバー & キーボードイベント =====
$window.Add_MouseEnter({
    if ($script:Settings.SmartOpacity) {
        $window.Opacity = 1.0
    }
})

$window.Add_MouseLeave({
    if ($script:Settings.SmartOpacity) {
        Apply-WindowOpacity
    }
})

$window.Add_KeyDown({
    param($sender, $e)
    # Ctrl + Shift + X: クリック透過トグル
    if (($e.KeyboardDevice.Modifiers -band [System.Windows.Input.ModifierKeys]::Control) -and 
        ($e.KeyboardDevice.Modifiers -band [System.Windows.Input.ModifierKeys]::Shift) -and 
        $e.Key -eq [System.Windows.Input.Key]::X) {
        $script:Settings.ClickThrough = -not $script:Settings.ClickThrough
        if ($script:menuClickThrough) { $script:menuClickThrough.IsChecked = $script:Settings.ClickThrough }
        Apply-ClickThrough
        Save-Settings
    }
    # Ctrl + Shift + T: 最前面固定トグル
    if (($e.KeyboardDevice.Modifiers -band [System.Windows.Input.ModifierKeys]::Control) -and 
        ($e.KeyboardDevice.Modifiers -band [System.Windows.Input.ModifierKeys]::Shift) -and 
        $e.Key -eq [System.Windows.Input.Key]::T) {
        $script:Settings.Topmost = -not $script:Settings.Topmost
        $window.Topmost = $script:Settings.Topmost
        if ($script:menuTopmost) { $script:menuTopmost.IsChecked = $script:Settings.Topmost }
        Save-Settings
    }
})

# ===== ウィンドウイベント =====
$window.Add_Loaded({
    Load-Settings
    
    $window.Width = $script:Settings.Width
    $window.Height = $script:Settings.Height
    
    # Apply-Mode (内部で Apply-Scale) がサイズを確定させてから位置を決める
    Apply-Mode
    
    if ($script:Settings.Left -ge 0 -and $script:Settings.Top -ge 0) {
        $window.Left = $script:Settings.Left
        $window.Top = $script:Settings.Top
    } else {
        # 初回起動は既定でアナログ時計を画面右上に置く
        Snap-Window "top-right"
    }

    if ($script:menuTopmost) { $script:menuTopmost.IsChecked = $script:Settings.Topmost }
    if ($script:menuSeconds) { $script:menuSeconds.IsChecked = $script:Settings.ShowSeconds }
    if ($script:menuSmartOp) { $script:menuSmartOp.IsChecked = $script:Settings.SmartOpacity }
    if ($script:menuClickThrough) { $script:menuClickThrough.IsChecked = $script:Settings.ClickThrough }
    if ($script:menuDate) { $script:menuDate.IsChecked = $script:Settings.ShowDate }
    if ($script:menuStartup) { $script:menuStartup.IsChecked = (Test-Path $startupLnk) }
    
    Tick-Handler
    
    $script:timer = New-Object System.Windows.Threading.DispatcherTimer
    $script:timer.Interval = [TimeSpan]::FromSeconds(1)
    $script:timer.Add_Tick({ Tick-Handler })
    $script:timer.Start()
    Adjust-TimerInterval
})

$window.Add_SizeChanged({
    if ($script:Settings.Mode -eq "analog") {
        # ドラッグでのリサイズと Ctrl+ホイールの倍率がずれないよう同期する
        $side = [Math]::Min($window.ActualWidth, $window.ActualHeight)
        if ($side -gt 0) {
            $script:Settings.Scale = [Math]::Max(40, [Math]::Min(360, [int][Math]::Round($side / $script:BaseAnalogSize * 100)))
        }
        Draw-AnalogClock
    }
})

$window.Add_Closing({
    if ($script:timer) {
        $script:timer.Stop()
    }
    if ($script:saveTimer) {
        $script:saveTimer.Stop()
    }
    $script:Settings.Width = [int]$window.ActualWidth
    $script:Settings.Height = [int]$window.ActualHeight
    $script:Settings.Left = $window.Left
    $script:Settings.Top = $window.Top
    Save-Settings
})

# ===== 起動 =====
$window.ShowDialog() | Out-Null
