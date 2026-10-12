# token-check.ps1 —— 确认工作区里到底存的是哪个 token。
#
# 用途：轮换 PAT 之后，一眼看出值有没有真的变。
# 只打印长度和 SHA-256 指纹，绝不回显 token 本身。
#
# 用法：
#   .\token-check.ps1
#   .\token-check.ps1 -Compare "github_pat_新token"     # 顺便比对是不是同一个

param(
    [string]$Compare
)

$tokenFile = Join-Path $PSScriptRoot '.github-token'

if (-not (Test-Path -LiteralPath $tokenFile)) {
    Write-Host "[x] 找不到 $tokenFile" -ForegroundColor Red
    exit 1
}

$token = (Get-Content -Raw -LiteralPath $tokenFile).Trim() -replace "^\uFEFF", ''
if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host "[x] token 文件是空的" -ForegroundColor Red
    exit 1
}

$sha = [System.Security.Cryptography.SHA256]::Create()
function Get-Fingerprint([string]$s) {
    ($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($s)) | ForEach-Object { $_.ToString('x2') }) -join ''
}

$fp = Get-Fingerprint $token
Write-Host ''
Write-Host '工作区当前存储的 token：' -ForegroundColor Cyan
Write-Host "  长度      : $($token.Length)   (经典 ghp_ 约 40，细粒度 github_pat_ 为 93)"
Write-Host "  类型      : $(if ($token -match '^github_pat_') { 'fine-grained (github_pat_)' } elseif ($token -match '^ghp_') { 'classic (ghp_)' } else { '未知前缀' })"
Write-Host "  指纹      : $($fp.Substring(0, 32))..."
Write-Host "  文件时间  : $((Get-Item -LiteralPath $tokenFile).LastWriteTime)"
Write-Host ''

if ($Compare) {
    $cmp = $Compare.Trim() -replace "^\uFEFF", ''
    $same = (Get-Fingerprint $cmp) -eq $fp
    if ($same) {
        Write-Host '[!] 与 -Compare 传入的值完全相同 —— 值没有变化，不是新 token。' -ForegroundColor Yellow
    } else {
        Write-Host '[ok] 与 -Compare 传入的值不同 —— 确认是新 token。' -ForegroundColor Green
    }
    Write-Host "    -Compare 长度: $($cmp.Length)"
}
