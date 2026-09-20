# build_windows.ps1 — SCSS Survey Windows 端一键编译打包
# 用法:双击同目录的 build_windows.bat(或在 PowerShell 里运行本脚本)。
# 产物:grid_app\dist\SCSS-Survey-win64-<日期时间>\(免安装绿色版)及同名 .zip。
# 必须在 Windows 上运行;Flutter 不支持交叉编译。

param(
    [switch]$SkipPubGet   # 已经拉过依赖、只想重编译时可加
)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}
Set-Location $PSScriptRoot

function Step($msg) { Write-Host ""; Write-Host "==> $msg" -ForegroundColor Cyan }
function Warn($msg) { Write-Host "  警告:$msg" -ForegroundColor Yellow }
function Fail($msg) {
    Write-Host ""
    Write-Host "✗ $msg" -ForegroundColor Red
    exit 1
}

Write-Host "SCSS Survey — Windows 端编译打包" -ForegroundColor White
Write-Host ("工程目录:" + $PSScriptRoot)

# ---------------------------------------------------------------- 环境检查
Step "检查环境"
if (-not (Test-Path (Join-Path $PSScriptRoot 'pubspec.yaml'))) {
    Fail "当前目录不是 grid_app 工程(缺 pubspec.yaml)。请把脚本放在 grid_app 目录下运行。"
}
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "  未找到 flutter 命令。请先安装 Flutter SDK:" -ForegroundColor Red
    Write-Host "    1. 下载 https://docs.flutter.dev/get-started/install/windows"
    Write-Host "    2. 解压到如 C:\src\flutter,把 C:\src\flutter\bin 加入系统 PATH"
    Write-Host "    3. 重新打开本脚本"
    Fail "缺少 Flutter"
}
$fv = (& flutter --version 2>$null | Select-Object -First 1)
Write-Host ("  " + $fv)

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (Test-Path $vswhere) {
    $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property displayName 2>$null
    if ($vs) { Write-Host ("  " + $vs) }
    else { Warn "已装 Visual Studio 但缺「使用 C++ 的桌面开发」工作负载,编译会失败。请在 Visual Studio Installer 里勾选后重试。" }
} else {
    Warn "未检测到 Visual Studio / Build Tools。需要安装 Build Tools for Visual Studio 2022 并勾选「使用 C++ 的桌面开发」:"
    Write-Host "    https://aka.ms/vs/17/release/vs_BuildTools.exe"
}
if (-not (Get-Command nuget -ErrorAction SilentlyContinue)) {
    Warn "未找到 nuget.exe,编译时会临时下载(需联网)。建议一次性安装:winget install Microsoft.NuGet"
}

# ---------------------------------------------------------------- 依赖
if (-not $SkipPubGet) {
    Step "拉取依赖(flutter pub get)"
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { Fail "flutter pub get 失败。多为网络问题,请检查网络后重试。" }
}

# ---------------------------------------------------------------- 编译
Step "编译 Release(flutter build windows --release),首次约 3-10 分钟"
& flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Fail "编译失败。请把上方红色报错整段截图发给开发者。常见原因:未装 C++ 工作负载、nuget 下载失败(需联网)、磁盘空间不足。"
}
$release = Join-Path $PSScriptRoot 'build\windows\x64\runner\Release'
$exe = Join-Path $release 'scss_grid.exe'
if (-not (Test-Path $exe)) { Fail "编译看似成功但未找到产物:$exe" }

# ---------------------------------------------------------------- 打包
Step "打包"
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$name  = "SCSS-Survey-win64-$stamp"
$dist  = Join-Path $PSScriptRoot 'dist'
$out   = Join-Path $dist $name
New-Item -ItemType Directory -Force -Path $dist | Out-Null
if (Test-Path $out) { Remove-Item -Recurse -Force $out }
Copy-Item -Path $release -Destination $out -Recurse

$readme = @"
SCSS Survey(Windows 版)使用说明
================================

1. 运行:双击本目录里的 scss_grid.exe。整个文件夹就是程序,请整个文件夹一起复制/移动,
   单独复制 exe 运行不起来。
2. 放置位置:请放在可写的位置(桌面、D 盘等)。放进 C:\Program Files 会导致数据无法
   保存在程序旁,程序会在启动时弹出提示并告知数据实际保存到了哪里。
3. 数据:全部在本目录的 userdata\ 文件夹(数据库 + 图片)。备份 = 复制 userdata\;
   迁移到别的电脑 = 复制整个文件夹。
4. 首次运行:Windows SmartScreen 可能提示「未知发布者」,点「更多信息」→「仍要运行」。
5. 与手机同步:打开程序里的「同步」页,首次会弹出防火墙授权,请勾选「专用网络」允许。
   手机与电脑需在同一 Wi-Fi 下,手机端按电脑显示的 IP 和配对码连接(端口 17423)。
   若错过了防火墙弹窗,到「Windows 安全中心 → 防火墙 → 允许应用通过防火墙」里勾上 scss_grid。

构建时间:$(Get-Date -Format 'yyyy-MM-dd HH:mm')
"@
$readme | Set-Content -Path (Join-Path $out '使用说明.txt') -Encoding UTF8

$zip = "$out.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path $out -DestinationPath $zip

$size = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Host ""
Write-Host "✓ 完成" -ForegroundColor Green
Write-Host ("  发布目录:" + $out)
Write-Host ("  压缩包:  " + $zip + "  (" + $size + " MB)")
Write-Host "  把压缩包发给使用者,解压后双击 scss_grid.exe 即可运行。"
try { Start-Process explorer.exe $dist } catch {}
exit 0
