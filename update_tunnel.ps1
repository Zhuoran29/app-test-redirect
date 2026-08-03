# Usage: run this from inside your GitHub Pages repo directory (PowerShell)
#   .\update_tunnel.ps1
#
# If you get "running scripts is disabled" error, run this once:
#   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

$StreamlitPort = 8501
$RepoDir = Get-Location
$LogFile = "$env:TEMP\cloudflared.log"
$ErrFile = "$env:TEMP\cloudflared.err"

# clean up old logs so we don't match a stale URL
Remove-Item $LogFile -ErrorAction SilentlyContinue
Remove-Item $ErrFile -ErrorAction SilentlyContinue

Write-Host "Starting cloudflared tunnel..."

$process = Start-Process -FilePath "cloudflared" `
    -ArgumentList "tunnel --url http://localhost:$StreamlitPort" `
    -RedirectStandardOutput $LogFile `
    -RedirectStandardError $ErrFile `
    -NoNewWindow -PassThru

Write-Host "Waiting for tunnel URL..."

$url = $null
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 1

    $content = ""
    if (Test-Path $LogFile) { $content += Get-Content $LogFile -Raw -ErrorAction SilentlyContinue }
    if (Test-Path $ErrFile) { $content += Get-Content $ErrFile -Raw -ErrorAction SilentlyContinue }

    $match = [regex]::Match($content, 'https://[a-zA-Z0-9.-]*\.trycloudflare\.com')
    if ($match.Success) {
        $url = $match.Value
        break
    }
}

if (-not $url) {
    Write-Host "ERROR: could not find tunnel URL."
    Write-Host "Check these log files manually:"
    Write-Host "  $LogFile"
    Write-Host "  $ErrFile"
    exit 1
}

Write-Host "Got new URL: $url"

$indexPath = Join-Path $RepoDir "index.html"

if (-not (Test-Path $indexPath)) {
    Write-Host "ERROR: index.html not found at $indexPath"
    exit 1
}

$indexContent = Get-Content $indexPath -Raw
$newContent = [regex]::Replace($indexContent, 'const currentUrl = ".*?";', "const currentUrl = `"$url`";")

if ($newContent -eq $indexContent) {
    Write-Host "WARNING: index.html content did not change. Check that it contains a line like:"
    Write-Host '  const currentUrl = "https://...";'
} else {
    Set-Content -Path $indexPath -Value $newContent -NoNewline -Encoding UTF8
    Write-Host "index.html updated."
}

git add index.html
git commit -m "Update tunnel URL to $url"
git push

Write-Host ""
Write-Host "Done. cloudflared is running in the background (PID: $($process.Id))"
Write-Host "To stop it later, run:"
Write-Host "  Stop-Process -Id $($process.Id)"

Wait-Process -Id $process.Id
