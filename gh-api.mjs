#!/usr/bin/env node
// gh-api.mjs —— 用工作区里的 .github-token 调 GitHub API。
//
// 为什么需要它：沙箱内 Windows schannel 拿不到 TLS 凭证，所以系统 curl /
// PowerShell 的 Invoke-WebRequest 全部失败。而 DSH 自带的 Node 24 用 OpenSSL，
// 配合 NODE_USE_ENV_PROXY=1 就能穿过本机代理正常访问 api.github.com。
//
// 用法（在 default-workspace 目录下）：
//   $env:HTTP_PROXY="http://127.0.0.1:7897"
//   $env:HTTPS_PROXY="http://127.0.0.1:7897"
//   $env:NODE_USE_ENV_PROXY="1"
//   node gh-api.mjs /user
//   node gh-api.mjs /repos/owner/repo
//   node gh-api.mjs /user/repos POST '{"name":"x","private":true}'
//
// 退出码：0 = HTTP 2xx，1 = 出错或非 2xx，2 = 参数错误。

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = dirname(fileURLToPath(import.meta.url));
const apiPath = process.argv[2];
const method = (process.argv[3] || 'GET').toUpperCase();
const bodyArg = process.argv[4];

if (!apiPath) {
  console.error('用法: node gh-api.mjs <path> [METHOD] [jsonBody]');
  process.exit(2);
}

let token = '';
try {
  token = readFileSync(join(root, '.github-token'), 'utf8')
    .replace(/^\uFEFF/, '')
    .trim();
} catch {
  console.error('[x] 找不到 .github-token —— 请先把 PAT 存进工作区');
  process.exit(1);
}
if (!token) {
  console.error('[x] .github-token 是空的');
  process.exit(1);
}

let res;
try {
  res = await fetch('https://api.github.com' + apiPath, {
    method,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: 'application/vnd.github+json',
      'X-GitHub-Api-Version': '2022-11-28',
      'User-Agent': 'dsh-workspace',
    },
    body: bodyArg || undefined,
  });
} catch (err) {
  console.error('[x] 请求失败:', err.message);
  console.error('    代理是否在跑？试试 Test-NetConnection 127.0.0.1 -Port 7897');
  process.exit(1);
}

console.log(`HTTP ${res.status} ${res.statusText}`);
const remaining = res.headers.get('x-ratelimit-remaining');
if (remaining !== null) console.log(`限流余额: ${remaining}`);

const text = await res.text();
try {
  console.log(JSON.stringify(JSON.parse(text), null, 2));
} catch {
  console.log(text);
}

process.exit(res.ok ? 0 : 1);
