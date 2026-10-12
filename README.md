# dsh-workspace

这是一个由 [DSH](https://github.com/deepseek-ai) 工作区首次推送上来的快照仓库，用来验证
「本地工作区 → GitHub」这条链路已经打通。

## 当前状态

| 环节 | 状态 |
|---|---|
| git | 2.56.0.windows.2 |
| 代理 | `127.0.0.1:7897`（Clash Verge Rev 默认混合端口） |
| TLS 后端 | `http.sslBackend=openssl`（沙箱内 schannel 取不到凭证） |
| 凭据 | 工作区 `.git-credentials`，由 `.github-token` 生成 |

## 文件

- `git-gh.cmd` —— git 包装脚本：自动带代理 + OpenSSL 后端 + 工作区内凭据
- `shadowrocket-recommended.conf` —— iOS Shadowrocket 分流配置模板
- `README.md`、`.gitignore`

## 注意

`.github-token` 和 `.git-credentials` 已被 `.gitignore` 排除，**永远不会被提交**。
