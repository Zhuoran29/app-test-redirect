# Usage: run this from inside your GitHub Pages repo directory (PowerShell)
#   .\update_tunnel.ps1
#
# If you get "running scripts is disabled" error, run this once:
#   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

$StreamlitPort = 8501
$RepoDir = Get-Location
$LogFile = "$env:TEMP\cloudflared.log"
$ErrFile = "$env:TEMP\cloudflared.err"

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

$txtPath = Join-Path $RepoDir "current_url.txt"

# overwrite current_url.txt with just the URL, no trailing newline issues
Set-Content -Path $txtPath -Value $url -NoNewline -Encoding UTF8

Write-Host "current_url.txt updated."

git add current_url.txt
git commit -m "Update tunnel URL to $url"
git push

Write-Host ""
Write-Host "Done. cloudflared is running in the background (PID: $($process.Id))"
Write-Host "To stop it later, run:"
Write-Host "  Stop-Process -Id $($process.Id)"

Wait-Process -Id $process.Id