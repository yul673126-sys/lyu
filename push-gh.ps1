# push-gh.ps1 —— 在 DSH 沙箱里向 GitHub 推送当前分支。
#
# 为什么不能用普通的 git push / git-gh.cmd：
#   沙箱禁止创建命名管道，而 git 与凭据助手（store / manager 都一样）之间
#   正是通过管道通信的。助手起不来 → git 取不到密码 → 回退到交互式提问
#   → 这里没有终端 → 报错：
#     sh.exe: *** fatal error - couldn't create signal pipe, Win32 error 5
#     fatal: could not read Username for 'https://github.com'
#
# 绕法：把 token 直接拼进推送 URL，完全绕开凭据助手。
# token 在脚本内部从 .github-token 读出，不会打印到屏幕或命令行参数里。
#
# 用法：
#   .\push-gh.ps1
#   .\push-gh.ps1 --force-with-lease      # 额外参数原样转发给 git push

$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$git  = 'C:\Program Files\Git\cmd\git.exe'

# 沙箱内直连被 reset，必须走本机代理；schannel 取不到 TLS 凭证，必须用 OpenSSL 后端
$env:HTTP_PROXY          = 'http://127.0.0.1:7897'
$env:HTTPS_PROXY         = $env:HTTP_PROXY
$env:GIT_TERMINAL_PROMPT = '0'

$tokenFile = Join-Path $root '.github-token'
if (-not (Test-Path -LiteralPath $tokenFile)) { throw "找不到 $tokenFile" }
$token = (Get-Content -Raw -LiteralPath $tokenFile).Trim() -replace "^\uFEFF", ''
if ([string]::IsNullOrWhiteSpace($token)) { throw '.github-token 是空的' }

$origin = (& $git -C $root remote get-url origin 2>$null)
if (-not $origin) { throw '当前仓库没有配置 origin' }
$origin = $origin.Trim()
if ($origin -notmatch '^https://github\.com/') {
    throw "origin 不是 GitHub HTTPS 地址，无法注入 token：$origin"
}

$authUrl = $origin -replace '^https://', "https://x-access-token:$token@"
$branch  = (& $git -C $root rev-parse --abbrev-ref HEAD).Trim()

Write-Host "推送 $branch -> $origin" -ForegroundColor Cyan

& $git -C $root -c http.sslBackend=openssl -c credential.helper= push $authUrl "HEAD:$branch" @args
if ($LASTEXITCODE -ne 0) { throw "push 失败 (exit=$LASTEXITCODE)" }

Write-Host ''
Write-Host '复核远端引用：' -ForegroundColor Cyan
& $git -C $root -c http.sslBackend=openssl -c credential.helper= ls-remote origin "refs/heads/$branch"
Write-Host "本地 HEAD: $(& $git -C $root rev-parse HEAD)"
