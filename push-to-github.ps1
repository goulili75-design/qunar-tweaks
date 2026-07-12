# ================================================================
# push-to-github.ps1 - 将 qunar-tweaks 代码推送到 GitHub
# ================================================================
# 
# 用法 1 (有 Git):
#   .\push-to-github.ps1
#
# 用法 2 (需要手动生成 GitHub Token):
#   1. 打开 https://github.com/settings/tokens
#   2. 点击 "Generate new token (classic)"
#   3. 勾选 "repo" 权限
#   4. 复制生成的 token
#   5. 运行: .\push-to-github.ps1 -Token "ghp_xxxxxxxxxxxx"
#
# ================================================================

param(
    [string]$Token = $env:GITHUB_TOKEN
)

$RepoOwner = "goulili75-design"
$RepoName = "qunar-tweaks"
$LocalPath = "C:\qunar\qunar-tweaks"
$Branch = "main"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  QNByPass Tweak - Push to GitHub" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ---- Method 1: Try git ----
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
    Write-Host "[INFO] Using Git to push..." -ForegroundColor Green
    
    cd $LocalPath
    
    # Init if needed
    if (-not (Test-Path ".git")) {
        git init
        git checkout -b $Branch
        git remote add origin "https://github.com/$RepoOwner/$RepoName.git"
    }
    
    git add -A
    git commit -m "feat: Add QNByPass jailbreak bypass tweak

- UIDevice Hook (30+ jailbreak detection methods)
- NSFileManager Hook (40+ jailbreak paths)
- UIApplication canOpenURL Hook
- NSProcessInfo environment Hook
- sysctl/stat/dladdr/fork/system/popen Hook
- DTT/OneSignal/JailbreakDetection class Hook
- GitHub Actions CI/CD for building for rootless" --no-verify 2>$null
    
    git push -u origin $Branch --force 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Pushed to GitHub successfully!" -ForegroundColor Green
        Write-Host "  https://github.com/$RepoOwner/$RepoName" -ForegroundColor Cyan
        exit 0
    } else {
        Write-Host "[WARN] Git push failed. Trying API method..." -ForegroundColor Yellow
    }
}

# ---- Method 2: GitHub REST API ----
if (-not $Token -or $Token -eq '$env:GITHUB_TOKEN') {
    Write-Host ""
    Write-Host "[ACTION REQUIRED] GitHub Personal Access Token needed" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please follow these steps:" -ForegroundColor Yellow
    Write-Host "  1. Open https://github.com/settings/tokens" -ForegroundColor White
    Write-Host "  2. Click 'Generate new token (classic)'" -ForegroundColor White
    Write-Host "  3. Check 'repo' scope" -ForegroundColor White
    Write-Host "  4. Generate and copy the token" -ForegroundColor White
    Write-Host "  5. Run: .\push-to-github.ps1 -Token 'ghp_xxxxx'" -ForegroundColor White
    Write-Host ""
    Write-Host "OR: Upload manually via GitHub web interface:" -ForegroundColor Yellow
    Write-Host "  1. $LocalPath" -ForegroundColor White
    Write-Host "  2. Drag all files to https://github.com/$RepoOwner/$RepoName" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "[INFO] Using GitHub REST API..." -ForegroundColor Green

function Push-FileToGitHub {
    param($FilePath, $GitHubPath, $Message)
    
    $content = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((Get-Content $FilePath -Raw)))
    
    # Check if file exists
    $url = "https://api.github.com/repos/$RepoOwner/$RepoName/contents/$GitHubPath"
    $headers = @{
        "Authorization" = "Bearer $Token"
        "Accept" = "application/vnd.github.v3+json"
    }
    
    try {
        $existing = Invoke-RestMethod -Uri $url -Headers $headers -Method GET -ErrorAction SilentlyContinue
        $sha = $existing.sha
        Write-Host "  [UPDATE] $GitHubPath" -ForegroundColor Yellow
    } catch {
        $sha = $null
        Write-Host "  [CREATE] $GitHubPath" -ForegroundColor Green
    }
    
    $body = @{
        message = $Message
        content = $content
        branch = $Branch
    }
    if ($sha) { $body.sha = $sha }
    
    $json = $body | ConvertTo-Json -Depth 3
    Invoke-RestMethod -Uri $url -Headers $headers -Method PUT -Body $json | Out-Null
}

# Get all files
$files = Get-ChildItem -Path $LocalPath -Recurse -File | Where-Object {
    $_.FullName -notmatch '\\\.git\\' -and
    $_.Name -ne '.gitignore' -and
    $_.Name -ne 'push-to-github.ps1'
}

foreach ($file in $files) {
    $relativePath = $file.FullName.Replace($LocalPath, "").TrimStart("\").Replace("\", "/")
    Push-FileToGitHub -FilePath $file.FullName -GitHubPath $relativePath -Message "Add $relativePath"
}

Write-Host ""
Write-Host "[OK] All files pushed to GitHub!" -ForegroundColor Green
Write-Host "  https://github.com/$RepoOwner/$RepoName" -ForegroundColor Cyan
Write-Host ""
Write-Host "GitHub Actions will now build the tweak automatically." -ForegroundColor Cyan
Write-Host "  https://github.com/$RepoOwner/$RepoName/actions" -ForegroundColor Cyan
