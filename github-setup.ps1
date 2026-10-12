# github-setup.ps1
# 把工作区里的 .github-token 转换成 git 能直接读取的 .git-credentials，
# 然后用真实的 ls-remote 验证这个 token 到底有没有权限访问目标仓库。
#
# 用法（在你自己的 PowerShell 里）：
#   .\github-setup.ps1 -Repo 你的用户名/仓库名
#
# 全程不会回显 token。

param(
    [Parameter(Mandatory = $true)]
    [string]$Repo   # 形如 owner/repo
)

$ErrorActionPreference = 'Stop'
$root      = $PSScriptRoot
$tokenFile = Join-Path $root '.github-token'
$credFile  = Join-Path $root '.git-credentials'
$gitGh     = Join-Path $root 'git-gh.cmd'

# --- 1. 读 token（容忍 BOM / 首尾空白 / 末尾换行） ---
if (-not (Test-Path -LiteralPath $tokenFile)) {
    Write-Host "[x] 找不到 $tokenFile" -ForegroundColor Red
    Write-Host "    请先把 PAT 存进去，例如：" -ForegroundColor Yellow
    Write-Host "    Set-Content `"$tokenFile`" -Value `"github_pat_xxx`" -NoNewline -Encoding ascii"
    exit 1
}
$token = (Get-Content -Raw -LiteralPath $tokenFile).Trim() -replace "^\uFEFF", ''

if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host "[x] token 文件是空的" -ForegroundColor Red
    exit 1
}
if ($token -notmatch '^(github_pat_|ghp_|gho_|ghu_|ghs_)') {
    Write-Host "[!] 警告：这不像标准 GitHub token 前缀，仍继续尝试。" -ForegroundColor Yellow
}

# --- 2. 生成 .git-credentials（store helper 的格式） ---
"https://x-access-token:$token@github.com" |
    Set-Content -LiteralPath $credFile -NoNewline -Encoding ascii

Write-Host "[ok] 已写入 $credFile" -ForegroundColor Green
Write-Host "     token 指纹: $($token.Substring(0, [Math]::Min(11, $token.Length)))...（长度 $($token.Length)，其余不回显）"

# --- 3. 用真实请求验证授权 ---
Write-Host ""
Write-Host "正在验证 https://github.com/$Repo.git ..." -ForegroundColor Cyan
$out = & $gitGh ls-remote "https://github.com/$Repo.git" HEAD 2>&1
$code = $LASTEXITCODE

if ($code -eq 0) {
    Write-Host "[ok] 授权有效，远端可读。" -ForegroundColor Green
    if ($out) { Write-Host "     远端 HEAD: $out" }
    Write-Host ""
    Write-Host "下一步（推送到该仓库）：" -ForegroundColor Cyan
    Write-Host "  .\git-gh.cmd push -u origin main"
} else {
    Write-Host "[x] 验证失败（exit=$code）：" -ForegroundColor Red
    Write-Host $out
    Write-Host ""
    Write-Host "常见原因：" -ForegroundColor Yellow
    Write-Host "  - 404 → 仓库名拼错，或 token 没有被授权访问这个仓库"
    Write-Host "  - 401 → token 无效 / 已过期 / 复制时被截断"
    Write-Host "  - 需要 Permissions: Contents = Read and write"
    exit 1
}
