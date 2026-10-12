// ds-balance.mjs —— 查询本机 DeepSeek 账号余额（无需 API Key）
//
// 原理：DSH 桌面版登录后，凭据存在 ~/.dsh/.credentials.yaml 的
//       `deepseek-account-platform/default` 记录里（token + issuer）。
//       用该 token 请求平台的 get_user_summary 接口即可拿到余额。
//
// 为什么需要它：余额接口 api.deepseek.com/user/balance 只认 API Key，
// 而 DSH 用的是账号设备授权 —— 这个脚本用账号令牌走平台接口，两者查的是同一个余额池。
//
// 用法（工作区根目录）：
//   $env:HTTP_PROXY="http://127.0.0.1:7897"
//   $env:HTTPS_PROXY="http://127.0.0.1:7897"
//   $env:NODE_USE_ENV_PROXY="1"
//   node ds-balance.mjs
//
// 只读取凭据，绝不打印令牌；不写入任何文件。

import { readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

const credFile = join(homedir(), '.dsh', '.credentials.yaml');

let yaml;
try {
  yaml = readFileSync(credFile, 'utf8');
} catch {
  console.error(`[x] 读不到凭据文件: ${credFile}`);
  process.exit(1);
}

const m = yaml.match(/deepseek-account-platform\/default:\s*\n([\s\S]*?)(?=\n {2}[^\s]|$)/);
if (!m) {
  console.error('[x] 凭据里没有 deepseek-account-platform/default 记录（尚未登录 DeepSeek 账号？）');
  process.exit(1);
}

const field = (name) => {
  const hit = m[1].match(new RegExp(`^\\s*${name}:\\s*(.+)$`, 'm'));
  return hit ? hit[1].trim().replace(/^["']|["']$/g, '') : '';
};

const token = field('token');
const issuer = field('issuer').replace(/\/+$/, '');
if (!token || !issuer) {
  console.error('[x] token / issuer 解析失败');
  process.exit(1);
}

let res;
try {
  res = await fetch(`${issuer}/api/v0/users/get_user_summary`, {
    headers: { 'x-dsh-auth-token': token, accept: 'application/json' },
  });
} catch (err) {
  console.error(`[x] 请求失败: ${err.message}`);
  console.error('    代理没开？试试  Test-NetConnection 127.0.0.1 -Port 7897');
  process.exit(1);
}

if (!res.ok) {
  console.error(`[x] HTTP ${res.status} —— 令牌可能已过期，重新登录 DSH 即可`);
  process.exit(1);
}

const biz = (await res.json())?.data?.biz_data;
if (!biz) {
  console.error('[x] 响应结构异常');
  process.exit(1);
}

const money = (v) => Number(v).toFixed(2);
const wallets = (list) =>
  (list ?? []).map((w) => `  ${w.currency}  ${money(w.balance)}`).join('\n') || '  (无)';

const sum = [...(biz.normal_wallets ?? []), ...(biz.bonus_wallets ?? [])].reduce(
  (acc, w) => acc + Number(w.balance),
  0,
);

console.log('DeepSeek 账户余额');
console.log(`  查询账号   : ${issuer}`);
console.log('');
console.log('  充值余额（自己充的）:');
console.log(wallets(biz.normal_wallets));
console.log('  赠送余额（活动送的，通常有有效期，优先扣除）:');
console.log(wallets(biz.bonus_wallets));
console.log('');
console.log(`  可用合计   : ${money(sum)}`);
console.log(`  累计已消费 :${(biz.total_costs ?? []).map((c) => ` ${c.currency} ${money(c.amount)}`).join('') || ' (无记录)'}`);
console.log('');
console.log('  充值入口   : https://platform.deepseek.com/top_up');
console.log('  用量明细   : https://platform.deepseek.com/usage');
