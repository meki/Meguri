# 項目の右クリックメニュー (パス表示 + エクスプローラで表示) の E2E テスト。
# TrackPopupMenu が出しているポップアップ (クラス #32768) を外部プロセスから読み取り、
# フォルダ / ファイル名 / メニュー項目が並んでいることを検証する。
# 使い方: powershell -ExecutionPolicy Bypass -File scripts\e2e_context_menu_test.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $root

$cli = "build\vs2022\apps\meguri_cli\Release\Meguri_CLI.exe"
$gui = "build\vs2022\apps\meguri_gui\Release\Meguri.exe"
$testDir = Join-Path $root "tmp\e2e-context\sub"

foreach ($exe in @($cli, $gui)) {
    if (-not (Test-Path $exe)) { throw "先に Release ビルドしてください: $exe" }
}

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class MgWin {
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern IntPtr FindWindowExW(IntPtr parent, IntPtr after, string cls, string title);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr wp, IntPtr lp);
    [DllImport("user32.dll")] public static extern IntPtr SendMessageW(IntPtr h, uint msg, IntPtr wp, IntPtr lp);
    [DllImport("user32.dll")] public static extern int GetMenuItemCount(IntPtr menu);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetMenuStringW(IntPtr menu, uint item, StringBuilder text, int max, uint flags);
    [DllImport("user32.dll")] public static extern uint GetMenuState(IntPtr menu, uint item, uint flags);
}
"@

function Get-MenuItems([IntPtr]$menu) {
    $count = [MgWin]::GetMenuItemCount($menu)
    $items = @()
    for ($i = 0; $i -lt $count; $i++) {
        $sb = New-Object System.Text.StringBuilder 512
        [void][MgWin]::GetMenuStringW($menu, [uint32]$i, $sb, 512, 0x400)  # MF_BYPOSITION
        $state = [MgWin]::GetMenuState($menu, [uint32]$i, 0x400)
        $items += [pscustomobject]@{ Text = $sb.ToString(); Disabled = ($state -band 0x3) -ne 0 }
    }
    return $items
}

# 1. サンプル生成 (サブフォルダ配下に置き、フォルダ行の表示を確認する)
Get-Process Meguri -ErrorAction SilentlyContinue | Stop-Process -Force -Confirm:$false
if (Test-Path (Join-Path $root "tmp\e2e-context")) { Remove-Item (Join-Path $root "tmp\e2e-context") -Recurse -Force -Confirm:$false }
New-Item -ItemType Directory -Force $testDir | Out-Null
& $cli gensample $testDir --webp 4 | Out-Null
$sampleNames = Get-ChildItem $testDir -File | Select-Object -ExpandProperty Name
if (-not $sampleNames) { throw "サンプル生成に失敗しました" }

# 2. GUI を起動してグリッドの子ウィンドウを取得
$proc = Start-Process -FilePath $gui -ArgumentList $testDir -PassThru
try {
    $grid = [IntPtr]::Zero
    for ($i = 0; $i -lt 60 -and $grid -eq [IntPtr]::Zero; $i++) {
        Start-Sleep -Milliseconds 250
        $proc.Refresh()
        $main = $proc.MainWindowHandle
        if ($main -ne [IntPtr]::Zero) {
            $grid = [MgWin]::FindWindowExW($main, [IntPtr]::Zero, "MeguriGridView", $null)
        }
    }
    if ($grid -eq [IntPtr]::Zero) { throw "グリッドウィンドウが見つかりません" }
    Start-Sleep -Seconds 3  # プローブ完了・タイル配置待ち

    # 3. 左上のタイルを右クリックし、ポップアップメニュー (クラス #32768) が出るまで再試行する。
    #    タイル配置が終わる前だと当たり判定が外れてメニューが出ないため、数回試す
    $pos = [IntPtr](60 -bor (60 -shl 16))
    $popup = [IntPtr]::Zero
    for ($i = 0; $i -lt 10 -and $popup -eq [IntPtr]::Zero; $i++) {
        [void][MgWin]::PostMessageW($grid, 0x0204, [IntPtr]::Zero, $pos)  # WM_RBUTTONDOWN
        [void][MgWin]::PostMessageW($grid, 0x0205, [IntPtr]::Zero, $pos)  # WM_RBUTTONUP
        for ($j = 0; $j -lt 10 -and $popup -eq [IntPtr]::Zero; $j++) {
            Start-Sleep -Milliseconds 100
            $popup = [MgWin]::FindWindowExW([IntPtr]::Zero, [IntPtr]::Zero, "#32768", $null)
        }
    }
    if ($popup -eq [IntPtr]::Zero) { throw "コンテキストメニューが表示されませんでした" }

    $menu = [MgWin]::SendMessageW($popup, 0x01E1, [IntPtr]::Zero, [IntPtr]::Zero)  # MN_GETHMENU
    if ($menu -eq [IntPtr]::Zero) { throw "メニューハンドルを取得できませんでした" }
    $items = Get-MenuItems $menu
    [void][MgWin]::PostMessageW($popup, 0x0100, [IntPtr]0x1B, [IntPtr]::Zero)  # WM_KEYDOWN VK_ESCAPE

    $items | ForEach-Object { "menu: [{0}] disabled={1}" -f $_.Text, $_.Disabled }

    $folderItem = $items | Where-Object { $_.Text -eq $testDir }
    if (-not $folderItem) { throw "フォルダのパスがメニューに表示されていません: $testDir" }
    if (-not $folderItem.Disabled) { throw "フォルダ行が無効化されていません (表示専用のはず)" }
    $nameItem = $items | Where-Object { $sampleNames -contains $_.Text }
    if (-not $nameItem) { throw "ファイル名がメニューに表示されていません" }
    if (-not $nameItem.Disabled) { throw "ファイル名の行が無効化されていません (表示専用のはず)" }
    $reveal = $items | Where-Object { $_.Text -match "エクスプローラで表示|Show in Explorer" }
    if (-not $reveal) { throw "「エクスプローラで表示」が見つかりません" }
    if ($reveal.Disabled) { throw "「エクスプローラで表示」が選べません" }

    "PASS: 右クリックメニューにパスと「エクスプローラで表示」が表示された"
} finally {
    Start-Sleep -Milliseconds 300
    if (-not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -Confirm:$false }
}
