# 用法: 在你的 app-test-redirect 仓库目录下用 PowerShell 运行这个脚本
# 它会启动 cloudflared，抓取新 URL，写入 index.html，然后自动 push 到 GitHub
#
# 运行方式（在仓库目录下打开 PowerShell）:
#   .\update_tunnel.ps1
#
# 如果提示"无法加载文件，因为在此系统上禁止运行脚本"，先执行一次（仅需一次）:
#   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

$StreamlitPort = 8501          # 你的 streamlit 端口，按需修改
$RepoDir = Get-Location        # 假设脚本就在仓库根目录下运行
$LogFile = "$env:TEMP\cloudflared.log"

Write-Host "启动 cloudflared tunnel..."

# 后台启动 cloudflared，把输出重定向到日志文件
$process = Start-Process -FilePath "cloudflared" `
    -ArgumentList "tunnel --url http://localhost:$StreamlitPort" `
    -RedirectStandardOutput $LogFile `
    -RedirectStandardError "$LogFile.err" `
    -NoNewWindow -PassThru

Write-Host "等待 tunnel URL 生成..."

$url = $null
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 1
    if (Test-Path $LogFile) {
        $content = Get-Content $LogFile -Raw -ErrorAction SilentlyContinue
    } else {
        $content = ""
    }
    if (Test-Path "$LogFile.err") {
        $content += Get-Content "$LogFile.err" -Raw -ErrorAction SilentlyContinue
    }

    $match = [regex]::Match($content, 'https://[a-zA-Z0-9.-]*\.trycloudflare\.com')
    if ($match.Success) {
        $url = $match.Value
        break
    }
}

if (-not $url) {
    Write-Host "没抓到 URL，检查 $LogFile 和 $LogFile.err 看看 cloudflared 是否正常启动"
    exit 1
}

Write-Host "拿到新 URL: $url"

# 替换 index.html 里的 URL
$indexPath = Join-Path $RepoDir "index.html"
$indexContent = Get-Content $indexPath -Raw
$indexContent = $indexContent -replace 'const currentUrl = ".*?";', "const currentUrl = `"$url`";"
Set-Content -Path $indexPath -Value $indexContent -NoNewline

# git 提交并推送
git add index.html
git commit -m "Update tunnel URL to $url"
git push

Write-Host "已更新并推送到 GitHub Pages，稍等几十秒生效。"
Write-Host "cloudflared 正在后台运行 (PID: $($process.Id))。"
Write-Host "测试结束后，运行下面这行来停止它:"
Write-Host "  Stop-Process -Id $($process.Id)"

# 等待 cloudflared 进程结束（Ctrl+C 会中断这个等待，但 cloudflared 进程仍在后台运行）
Wait-Process -Id $process.Id
