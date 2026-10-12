// set-ds-key.mjs —— 把 DeepSeek API Key 写入 DSH 凭据文件的 refs 段。
//
// 为什么这么写：
//   DSH 的凭据存储 (~/.dsh/.credentials.yaml) 是分层里"可写的受管层"，
//   简单密钥存放在顶层 `refs:` 映射（CredentialRef -> 字符串），
//   官方 credentials.set() 写的就是这个位置。该文件被 fs 监听，
//   外部编辑会热发布，所以插件无需重启即可读到新 key。
//
// 安全性：
//   - 写入前备份到工作区 .credentials.yaml.bak（已加入 .gitignore）
//   - 全程不打印密钥，只打印改动摘要
//   - 解析器严格：只允许 version / refs / records 三个顶层键，
//     未知字段会被拒绝，因此这里只做最小插入
//
// 用法：node set-ds-key.mjs   （密钥从 refs 源文件读取，见 KEY_FILE）

import { readFileSync, writeFileSync, copyFileSync, existsSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const REF = 'DEEPSEEK_API_KEY';
const credFile = join(homedir(), '.dsh', '.credentials.yaml');
const backupFile = join(process.cwd(), '.credentials.yaml.bak');

// 密钥来源：优先环境变量，其次一个临时 key 文件（避免写进命令行参数）
let key = process.env.DS_KEY_TO_STORE || '';
if (!key) {
  const keyFile = join(process.cwd(), '.ds-key.tmp');
  if (existsSync(keyFile)) key = readFileSync(keyFile, 'utf8').trim();
}
if (!key) {
  console.error('[x] 没拿到密钥：请设置 DS_KEY_TO_STORE 或提供 .ds-key.tmp');
  process.exit(1);
}
if (!/^sk-[A-Za-z0-9]{16,}$/.test(key)) {
  console.error(`[x] 密钥格式不像 DeepSeek key（长度 ${key.length}）`);
  process.exit(1);
}

const raw = readFileSync(credFile, 'utf8');

// 备份
copyFileSync(credFile, backupFile);
console.log(`[ok] 已备份到 ${backupFile}`);

if (new RegExp(`^\\s*${REF}:`, 'm').test(raw)) {
  console.log(`[=] 凭据文件里已存在 ${REF}，不做修改（如需轮换请先在 GUI 里删除）`);
  process.exit(0);
}

const entry = `  ${REF}: "${key}"\n`;
let next;

if (/^refs:\s*$/m.test(raw)) {
  // refs 段已存在：把新条目插到 refs: 之后的第一行位置
  next = raw.replace(/^(refs:\s*\n)/m, `$1${entry}`);
  console.log('[ok] refs 段已存在，插入新条目');
} else {
  // 不存在的 refs 段：插到 records: 之前（保持两个顶层段都在）
  if (/^records:/m.test(raw)) {
    next = raw.replace(/^records:/m, `refs:\n${entry}records:`);
  } else {
    next = raw.endsWith('\n') ? `${raw}refs:\n${entry}` : `${raw}\nrefs:\n${entry}`;
  }
  console.log('[ok] 新建 refs 段');
}

writeFileSync(credFile, next, 'utf8');

// 回读校验：确认能按预期解析出键，且顶层结构未变
const after = readFileSync(credFile, 'utf8');
const topKeys = after
  .split('\n')
  .filter((l) => /^[A-Za-z]/.test(l))
  .map((l) => l.split(':')[0]);
console.log(`[ok] 写入完成。顶层键: ${topKeys.join(', ')}`);
console.log(`[ok] refs 中的条目数: ${(after.match(/^ {2}[A-Za-z_][A-Za-z0-9_]*:/gm) || []).length}`);
