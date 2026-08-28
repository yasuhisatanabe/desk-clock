<# 
  Desk Clock - 軽量・ミニマル デスクトップ時計
  PowerShell + WPF版
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# ===== Win32 API (モニタ情報の取得) =====
$win32Code = @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }

    [StructLayout(LayoutKind.Sequential)]
    public struct POINT { public int X, Y; }

    [StructLayout(LayoutKind.Sequential)]
    public struct MONITORINFO {
        public int cbSize;
        public RECT rcMonitor;
        public RECT rcWork;
        public uint dwFlags;
    }

    public const uint MONITOR_DEFAULTTONEAREST = 2;

    [DllImport("user32.dll")]
    public static extern IntPtr MonitorFromPoint(POINT pt, uint dwFlags);

    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern bool GetMonitorInfo(IntPtr hMonitor, ref MONITORINFO lpmi);

    // 指定した点が乗っているモニタの作業領域（タスクバーを除く）をピクセルで返す。
    // どのモニタにも乗っていない場合は最も近いモニタを返す
    public static RECT GetWorkAreaFromPoint(int x, int y) {
        POINT p; p.X = x; p.Y = y;
        IntPtr h = MonitorFromPoint(p, MONITOR_DEFAULTTONEAREST);
        MONITORINFO mi = new MONITORINFO();
        mi.cbSize = Marshal.SizeOf(typeof(MONITORINFO));
        if (GetMonitorInfo(h, ref mi)) { return mi.rcWork; }
        RECT r; r.Left = 0; r.Top = 0; r.Right = 0; r.Bottom = 0;
        return r;
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
    Opacity         = 0.85          # 0.15 - 0.90
    ShowSeconds     = $false        # $true / $false (秒針表示)
    SmartOpacity    = $false        # $true / $false (スマート透過: 平常時半透明、ホバー時100%)
    ShowDate        = $false        # $true / $false (デジタル時日付・曜日表示)
    ShowPlate       = $false        # $true / $false (デジタル時の背景板)
    Scale           = 100           # 40 - 360 (%) 表示倍率。アナログ・デジタル共通
    HourWidth       = 4.0           # 1.5 - 6.0
    HourLength      = 45            # 20 - 70 (%) 分針より必ず短く保たれる
    MinuteWidth     = 4.0           # 1.5 - 6.0
    MinuteLength    = 82            # 30 - 90 (%)
    SecondWidth     = 1.5           # 1.0 - 4.0
    SecondLength    = 72            # 60 - 90 (%)
    DigitalSize     = 64.0          # 36 - 128 (px) 実効サイズは Scale を掛けた値
    Width           = 220           # Scale から算出されるため、保存用の控え
    Height          = 220
    Left            = $null         # $null = 未設定（初回は画面右上）。負の値も正当な座標
    Top             = $null
}

# ===== 寸法・範囲の定数 =====
# 表示倍率 100% のときのアナログ時計ウィンドウの一辺 (px)
$script:BaseAnalogSize = 220.0
# ウィンドウの最小の一辺 (px)
$script:MinWindowSide = 60
# アナログはウィンドウ下限より小さくできないため、実際に効かない倍率を
# レンジから外して「回しても変わらない」帯をなくす
$script:MinAnalogScale = [Math]::Max(40, [int][Math]::Ceiling($script:MinWindowSide / $script:BaseAnalogSize * 100))

# デジタルはウィンドウを文字にぴったり合わせる。
# 余白を持たせると、画面の隅にスナップしても文字が隅から離れてしまう
$script:HitPadX = 8
$script:HitPadY = 8
$script:MinDigitalW = 60
$script:MinDigitalH = 60

# クリック・右クリック・ドラッグを受け付ける範囲（文字／文字盤に対する比率）。
# ウィンドウ全面で受けると背後のアプリケーションを選択できなくなるため中央だけに絞る
$script:HitRatio = 0.45

# 透明度の範囲と、時針・分針を見分けるための最小の長さ差 (%)
$script:OpacityMin = 0.15
$script:OpacityMax = 0.90
$script:MinHandGap = 10

# スマート透過の減光率と、減光時に守る不透明度の下限
$script:SmartOpacityFactor = 0.45
$script:SmartOpacityMin = 0.25

# ===== テーマ定義 =====
$script:Themes = @{
    dark = @{
        Face            = "#EB181820"
        TickMajor       = "#F2DCDCF0"
        TickMinor       = "#80DCDCF0"
        HandHour        = "#F2DCDCF0"
        HandMinute      = "#F2DCDCF0"
        HandSecond      = "#B3B4B4CF"
        DigitalHalo     = "#000000"     # デジタル文字の縁取り。文字と逆の明度にする
    }
    light = @{
        Face            = "#EBEBEBF0"
        TickMajor       = "#F21E1E32"
        TickMinor       = "#801E1E32"
        HandHour        = "#F21E1E32"
        HandMinute      = "#F21E1E32"
        HandSecond      = "#A65A464B"
        DigitalHalo     = "#FFFFFF"
    }
    blue = @{
        Face            = "#EB0E1428"
        TickMajor       = "#F28CBEF5"
        TickMinor       = "#808CBEF5"
        HandHour        = "#F28CBEF5"
        HandMinute      = "#F28CBEF5"
        HandSecond      = "#B36496C8"
        DigitalHalo     = "#020814"
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
            if ($null -ne $json.ShowDate) { $script:Settings.ShowDate = [bool]$json.ShowDate }
            if ($null -ne $json.ShowPlate) { $script:Settings.ShowPlate = [bool]$json.ShowPlate }
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

            # 範囲外の値を持ち込ませない（手編集・旧バージョンからの移行対策）
            $script:Settings.Opacity = [Math]::Max($script:OpacityMin, [Math]::Min($script:OpacityMax, $script:Settings.Opacity))
            $script:Settings.Scale   = [Math]::Max(40, [Math]::Min(360, $script:Settings.Scale))
            # 時針が分針と同じか長いと時刻を反対に読んでしまうため、時針を縮めて必ず差を確保する
            if ($script:Settings.HourLength + $script:MinHandGap -gt $script:Settings.MinuteLength) {
                $script:Settings.HourLength = $script:Settings.MinuteLength - $script:MinHandGap
            }
            # 旧形式の -1 センチネルを未設定へ移行する
            if ($script:Settings.Left -eq -1 -and $script:Settings.Top -eq -1) {
                $script:Settings.Left = $null
                $script:Settings.Top = $null
            }
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
    ResizeMode="NoResize"
    MinWidth="60" MinHeight="60"
    Width="220" Height="220">

    <!-- Background を持たせないことで、描画のない領域のクリックは背後のウィンドウへ抜ける -->
    <Grid x:Name="MainGrid">
        <!-- Analog Clock Canvas -->
        <Canvas x:Name="AnalogCanvas" 
                HorizontalAlignment="Stretch" 
                VerticalAlignment="Stretch"
                IsHitTestVisible="False"
                Visibility="Collapsed"/>
        
        <!-- Digital Clock -->
        <Border x:Name="DigitalBorder" 
                CornerRadius="16" 
                Padding="4"
                IsHitTestVisible="False"
                HorizontalAlignment="Center"
                VerticalAlignment="Center"
                Visibility="Collapsed">
            <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center">
                <TextBlock x:Name="DigitalTime" 
                           Text="00:00"
                           FontSize="64"
                           FontWeight="SemiBold"
                           FontFamily="Segoe UI, Consolas"
                           Typography.NumeralAlignment="Tabular"
                           HorizontalAlignment="Center"/>
                <TextBlock x:Name="DigitalDate" 
                           Text="1月1日 (日)"
                           FontSize="18"
                           FontWeight="Normal"
                           FontFamily="Segoe UI, Yu Gothic UI, Meiryo, MS Gothic"
                           Opacity="0.7"
                           HorizontalAlignment="Center"
                           Margin="0,4,0,0"
                           Visibility="Collapsed"/>
            </StackPanel>
        </Border>

        <!-- 操作を受け付ける領域。Fill のアルファ 1 でヒットテストだけ有効にし視覚的には不可視 -->
        <Ellipse x:Name="HitAnalog" Fill="#01000000"
                 HorizontalAlignment="Center" VerticalAlignment="Center"
                 Width="0" Height="0" Visibility="Collapsed"/>
        <Rectangle x:Name="HitDigital" Fill="#01000000"
                   HorizontalAlignment="Center" VerticalAlignment="Center"
                   Width="0" Height="0" Visibility="Collapsed"/>
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
$hitAnalog = $window.FindName("HitAnalog")
$hitDigital = $window.FindName("HitDigital")

# ===== ヘルパー関数 =====
function Get-BrushFromHex([string]$hex) {
    try {
        $color = [System.Windows.Media.ColorConverter]::ConvertFromString($hex)
        return New-Object System.Windows.Media.SolidColorBrush($color)
    } catch {
        return [System.Windows.Media.Brushes]::Transparent
    }
}

function Get-ColorFromHex([string]$hex) {
    try {
        return [System.Windows.Media.ColorConverter]::ConvertFromString($hex)
    } catch {
        return [System.Windows.Media.Colors]::Black
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
    # Clear より先に判定する。逆にすると、レイアウト未確定のときに
    # 消しただけで描き直さず、空の文字盤が残ってしまう
    $w = $analogCanvas.ActualWidth
    $h = $analogCanvas.ActualHeight
    if ($w -le 0 -or $h -le 0) { return }

    $analogCanvas.Children.Clear()

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
    # 秒針OFF時は更新が毎分1回。秒成分を混ぜるとリサイズ等の再描画時の秒が
    # 焼き付き、分針が目盛りの中間で最大5.9°ずれたまま固定される
    $secForMinute = if ($script:Settings.ShowSeconds) { $seconds } else { 0 }
    $minAngle = ($minutes * 6 + $secForMinute * 0.1 - 90) * [Math]::PI / 180.0
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
        # 減光しすぎると時計を見失い、復帰のためにホバーする場所が分からなくなる
        $window.Opacity = [Math]::Max($script:SmartOpacityMin, $script:Settings.Opacity * $script:SmartOpacityFactor)
    } else {
        $window.Opacity = $script:Settings.Opacity
    }
}

# ===== モニタ単位の作業領域 =====
# WPF は DIP、Win32 はピクセルで扱うため相互変換する。
# 注: 混在 DPI 環境ではウィンドウ側の倍率を使うため誤差が出る（Per-Monitor DPI V2 未対応）
function Get-DipScale {
    try {
        $src = [System.Windows.PresentationSource]::FromVisual($window)
        if ($src -and $src.CompositionTarget) {
            $m = $src.CompositionTarget.TransformToDevice
            if ($m.M11 -gt 0 -and $m.M22 -gt 0) {
                return @{ X = $m.M11; Y = $m.M22 }
            }
        }
    } catch {}
    return @{ X = 1.0; Y = 1.0 }
}

# 時計の中心が乗っているモニタの作業領域を DIP で返す。
# SystemParameters::WorkArea はプライマリモニタしか返さないため使わない
function Get-WorkArea {
    $s = Get-DipScale
    $w = if ([double]::IsNaN($window.Width))  { $script:Settings.Width }  else { $window.Width }
    $h = if ([double]::IsNaN($window.Height)) { $script:Settings.Height } else { $window.Height }
    $cx = if ($null -ne $script:Settings.Left) { $script:Settings.Left + $w / 2.0 } else { 0.0 }
    $cy = if ($null -ne $script:Settings.Top)  { $script:Settings.Top  + $h / 2.0 } else { 0.0 }
    try {
        $r = [Win32]::GetWorkAreaFromPoint([int]($cx * $s.X), [int]($cy * $s.Y))
        if ($r.Right -gt $r.Left -and $r.Bottom -gt $r.Top) {
            return [PSCustomObject]@{
                Left   = $r.Left   / $s.X
                Top    = $r.Top    / $s.Y
                Right  = $r.Right  / $s.X
                Bottom = $r.Bottom / $s.Y
                Width  = ($r.Right - $r.Left) / $s.X
                Height = ($r.Bottom - $r.Top) / $s.Y
            }
        }
    } catch {}
    # 取得できない場合のみプライマリへフォールバック
    $wa = [System.Windows.SystemParameters]::WorkArea
    return [PSCustomObject]@{
        Left = $wa.Left; Top = $wa.Top; Right = $wa.Right; Bottom = $wa.Bottom
        Width = $wa.Width; Height = $wa.Height
    }
}

# ===== スナップ配置 =====
function Snap-Window([string]$pos) {
    $workArea = Get-WorkArea
    $margin = 16.0
    # レイアウト前は ActualWidth が 0 になるため、確定済みの Settings を最終的な拠り所にする
    $w = if ([double]::IsNaN($window.Width)  -or $window.Width  -le 0) { [double]$script:Settings.Width }  else { $window.Width }
    $h = if ([double]::IsNaN($window.Height) -or $window.Height -le 0) { [double]$script:Settings.Height } else { $window.Height }
    
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

# ===== デジタル文字の縁取り =====
# 背景板を置かない設計のため、壁紙やテーマに関わらず読めるよう
# 文字と逆の明度のハローを回して輪郭を立てる
function Apply-DigitalHalo {
    $theme = Get-CurrentTheme
    $color = Get-ColorFromHex $theme.DigitalHalo
    foreach ($tb in @($digitalTime, $digitalDate)) {
        # 倍率変更のたびに生成し直さず、既存の Effect を更新する
        $eff = $tb.Effect
        if (-not ($eff -is [System.Windows.Media.Effects.DropShadowEffect])) {
            $eff = New-Object System.Windows.Media.Effects.DropShadowEffect
            $eff.ShadowDepth = 0
            $eff.Opacity = 1.0
            $tb.Effect = $eff
        }
        $eff.Color = $color
        # ぼかしを広げると輪郭が拡散して薄くなる。文字の縁に密度を集めて
        # 白背景・黒背景のどちらでも輪郭が立つようにする
        $eff.BlurRadius = [Math]::Max(2.5, $tb.FontSize * 0.07)
    }
}

# ===== デジタル表示のサイズ合わせ =====
# ウィンドウを文字にぴったり合わせる（画面の隅へ寄せられるようにするため）
function Fit-DigitalWindow {
    if ($script:Settings.Mode -ne "digital") { return }
    try {
        $inf = New-Object System.Windows.Size -ArgumentList ([double]::PositiveInfinity), ([double]::PositiveInfinity)
        $digitalBorder.Measure($inf)
        $rawW = $digitalBorder.DesiredSize.Width
        $rawH = $digitalBorder.DesiredSize.Height
        $script:DigitalRawW = $rawW
        $script:DigitalRawH = $rawH
        $digitalBorder.InvalidateMeasure()
    } catch { return }
    # 計測できていない (レイアウト未実行など) ときに極小ウィンドウへ潰さない
    if ($rawW -le 1 -or $rawH -le 1) { return }

    # 文字の外側にドラッグ・右クリック・ホイール用の余白を必ず残す
    $needW = [Math]::Ceiling($rawW) + $script:HitPadX
    $needH = [Math]::Ceiling($rawH) + $script:HitPadY

    $window.Width  = [Math]::Max($script:MinDigitalW, [Math]::Min(800, $needW))
    $window.Height = [Math]::Max($script:MinDigitalH, [Math]::Min(800, $needH))
    $script:Settings.Width  = [int]$window.Width
    $script:Settings.Height = [int]$window.Height
}

# ===== 当たり判定領域 =====
# 時計の実体より小さい範囲でだけクリックを受け付ける。
# ウィンドウ全面で受けると、時計に重なった背後のアプリケーションを選択できなくなる
function Apply-HitArea {
    if ($script:Settings.Mode -eq "analog") {
        $hitDigital.Visibility = "Collapsed"
        $side = if ($script:AnalogSide -gt 0) { $script:AnalogSide } else { [double]$script:Settings.Width }
        $d = [Math]::Max(24.0, $side * $script:HitRatio)
        $hitAnalog.Width = $d
        $hitAnalog.Height = $d
        $hitAnalog.Visibility = "Visible"
    } else {
        $hitAnalog.Visibility = "Collapsed"
        $w = if ($script:DigitalRawW -gt 0) { $script:DigitalRawW } else { [double]$script:Settings.Width }
        $h = if ($script:DigitalRawH -gt 0) { $script:DigitalRawH } else { [double]$script:Settings.Height }
        $hitDigital.Width  = [Math]::Max(24.0, $w * $script:HitRatio)
        $hitDigital.Height = [Math]::Max(24.0, $h * $script:HitRatio)
        $hitDigital.Visibility = "Visible"
    }
}

# ===== 表示倍率 =====
function Apply-Scale {
    if ($script:Settings.Mode -eq "analog" -and $script:Settings.Scale -lt $script:MinAnalogScale) {
        $script:Settings.Scale = $script:MinAnalogScale
    }
    $ratio = [Math]::Max(40, [Math]::Min(360, [int]$script:Settings.Scale)) / 100.0
    if ($script:Settings.Mode -eq "analog") {
        $size = [Math]::Max($script:MinWindowSide, [Math]::Min(800, $script:BaseAnalogSize * $ratio))
        $script:AnalogSide = $size
        $window.Width  = $size
        $window.Height = $size
        $script:Settings.Width  = [int]$size
        $script:Settings.Height = [int]$size
    } else {
        $digitalTime.FontSize = [Math]::Max(16, [Math]::Round($script:Settings.DigitalSize * $ratio))
        $digitalDate.FontSize = [Math]::Max(11, [Math]::Round($digitalTime.FontSize * 0.28))
        Apply-DigitalHalo
        Fit-DigitalWindow
    }
    Apply-HitArea
}

# ===== 位置の復元 =====
function Restore-WindowPosition {
    if ($null -eq $script:Settings.Left -or $null -eq $script:Settings.Top) {
        # 初回起動は画面右上
        Snap-Window "top-right"
        return
    }
    # 時計が乗っているモニタの作業領域内へ収める。
    # 別モニタに置いてあるものをプライマリへ引き戻さないこと
    $wa = Get-WorkArea
    $w = if ([double]::IsNaN($window.Width))  { [double]$script:Settings.Width }  else { $window.Width }
    $h = if ([double]::IsNaN($window.Height)) { [double]$script:Settings.Height } else { $window.Height }
    $window.Left = [Math]::Min([Math]::Max($script:Settings.Left, $wa.Left), [Math]::Max($wa.Left, $wa.Right - $w))
    $window.Top  = [Math]::Min([Math]::Max($script:Settings.Top,  $wa.Top),  [Math]::Max($wa.Top,  $wa.Bottom - $h))
    $script:Settings.Left = $window.Left
    $script:Settings.Top  = $window.Top
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
        if ($script:Settings.ShowPlate) {
            # 背後が白いウィンドウでも確実に読めるよう、文字盤と同じ色の板を敷く
            $digitalBorder.Background = Get-BrushFromHex $theme.Face
            $digitalBorder.Padding = New-Object System.Windows.Thickness(18, 12, 18, 12)
        } else {
            $digitalBorder.Background = [System.Windows.Media.Brushes]::Transparent
            $digitalBorder.Padding = New-Object System.Windows.Thickness(4)
        }
        $digitalBorder.BorderBrush = [System.Windows.Media.Brushes]::Transparent
        $digitalBorder.BorderThickness = New-Object System.Windows.Thickness(0)
        $digitalTime.Foreground = Get-BrushFromHex $theme.HandHour
        $digitalDate.Foreground = Get-BrushFromHex $theme.HandHour
        $digitalDate.Visibility = if ($script:Settings.ShowDate) { "Visible" } else { "Collapsed" }
    }
    Apply-Scale
    if ($script:Settings.Mode -eq "digital") { Apply-DigitalHalo }

    # モード専用の項目は、効かない側では選べないようにする
    if ($script:menuSeconds) { $script:menuSeconds.IsEnabled = ($script:Settings.Mode -eq "analog") }
    if ($script:menuDate)  { $script:menuDate.IsEnabled  = ($script:Settings.Mode -eq "digital") }
    if ($script:menuPlate) { $script:menuPlate.IsEnabled = ($script:Settings.Mode -eq "digital") }

    Apply-WindowOpacity
}

# ===== タイマー & 省電力制御 =====
function Adjust-TimerInterval {
    if (-not $script:timer) { return }
    $now = Get-Date
    if ($script:Settings.Mode -eq "analog" -and $script:Settings.ShowSeconds) {
        # 固定1000msだと tick の遅延が累積して秒針が停滞・飛びするため、
        # 毎回「次の秒境界までの残り」を計算し直して壁時計に追従させる
        $ms = 1000 - $now.Millisecond + 20
    } else {
        # 秒針OFF時は次の 00 秒へ同期し、更新を毎分1回に抑える
        $ms = (60 - $now.Second) * 1000 - $now.Millisecond + 20
    }
    if ($ms -lt 20) { $ms = 20 }
    $script:timer.Interval = [TimeSpan]::FromMilliseconds($ms)
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

# --- デジタルの背景板 ---
$script:menuPlate = New-Object System.Windows.Controls.MenuItem
$script:menuPlate.Header = "背景を敷く (デジタル)"
$script:menuPlate.IsCheckable = $true
$script:menuPlate.IsChecked = $script:Settings.ShowPlate
$script:menuPlate.Add_Click({
    $script:Settings.ShowPlate = $script:menuPlate.IsChecked
    Apply-Mode
    Tick-Handler
    Save-Settings
})
$contextMenu.Items.Add($script:menuPlate) | Out-Null

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
    @{L="短め (65%)";V=65}, @{L="標準 (82%)";V=82}, @{L="長め (90%)";V=90}
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
    @{ Label = "90%"; Value = 0.90 },
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
    $script:Settings.ShowDate = $false
    $script:Settings.ShowPlate = $false
    $script:Settings.HourWidth = 4.0
    $script:Settings.HourLength = 45
    $script:Settings.MinuteWidth = 4.0
    $script:Settings.MinuteLength = 82
    $script:Settings.SecondWidth = 1.5
    $script:Settings.SecondLength = 72
    $script:Settings.DigitalSize = 64.0
    $script:Settings.Scale = 100
    # メニューのチェック状態を全て同期
    if ($script:menuSeconds) { $script:menuSeconds.IsChecked = $false }
    if ($script:menuSmartOp) { $script:menuSmartOp.IsChecked = $false }
    if ($script:menuDate) { $script:menuDate.IsChecked = $false }
    if ($script:menuPlate) { $script:menuPlate.IsChecked = $false }
    Apply-Mode
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
        # 終了時だけの保存だと強制終了で位置が失われるため、都度（デバウンスして）保存する
        $script:Settings.Left = $window.Left
        $script:Settings.Top  = $window.Top
        Request-Save
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
        $lower = if ($script:Settings.Mode -eq "analog") { $script:MinAnalogScale } else { 40 }
        $script:Settings.Scale = [Math]::Max($lower, [Math]::Min(360, [int]$script:Settings.Scale + $step))
        Apply-Scale
        Restore-WindowPosition   # 拡大でモニタからはみ出さないようにする
    } else {
        # 通常ホイール: 透明度 5% 刻み
        $step = if ($e.Delta -gt 0) { 0.05 } else { -0.05 }
        $newOp = [Math]::Max($script:OpacityMin, [Math]::Min($script:OpacityMax, $script:Settings.Opacity + $step))
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

# ===== 起動前の初期化 =====
# ShowDialog より前に確定させることで、別モードが一瞬見えたり
# 既定位置に出てから移動したりするちらつきを防ぐ
Load-Settings

$window.Width  = $script:Settings.Width
$window.Height = $script:Settings.Height

# Apply-Mode (内部で Apply-Scale) でサイズを確定させる。
# 位置は DPI が判る SourceInitialized まで待つ（初回描画より前なのでちらつかない）
Apply-Mode

if ($script:menuSeconds) { $script:menuSeconds.IsChecked = $script:Settings.ShowSeconds }
if ($script:menuSmartOp) { $script:menuSmartOp.IsChecked = $script:Settings.SmartOpacity }
if ($script:menuDate) { $script:menuDate.IsChecked = $script:Settings.ShowDate }
if ($script:menuPlate) { $script:menuPlate.IsChecked = $script:Settings.ShowPlate }
if ($script:menuStartup) { $script:menuStartup.IsChecked = (Test-Path $startupLnk) }

Tick-Handler

# HWND 生成直後・初回描画前。ここで初めてモニタと DPI が判る
$window.Add_SourceInitialized({
    Restore-WindowPosition

    # 解像度変更・モニタ着脱に追従する (WM_DISPLAYCHANGE)
    try {
        $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($window)).Handle
        $src = [System.Windows.Interop.HwndSource]::FromHwnd($hwnd)
        if ($src) {
            $script:wndHook = [System.Windows.Interop.HwndSourceHook]{
                param($h, $msg, $wp, $lp, $handled)
                if ($msg -eq 0x007E) { Restore-WindowPosition }   # WM_DISPLAYCHANGE
                # スリープ復帰・時刻変更の直後は表示が古いままなので即座に描き直す
                if ($msg -eq 0x0218 -or $msg -eq 0x001E) { Tick-Handler }  # WM_POWERBROADCAST / WM_TIMECHANGE
                return [IntPtr]::Zero
            }
            $src.AddHook($script:wndHook)
        }
    } catch {}
})

$window.Add_Loaded({
    # レイアウト確定後にサイズを取り直し、位置と当たり判定を最終化する
    Apply-Scale
    Restore-WindowPosition
    Apply-WindowOpacity

    $script:timer = New-Object System.Windows.Threading.DispatcherTimer
    $script:timer.Interval = [TimeSpan]::FromSeconds(1)
    $script:timer.Add_Tick({ Tick-Handler })
    $script:timer.Start()
    Adjust-TimerInterval
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
