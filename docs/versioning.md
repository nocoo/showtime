# 版本管理

根目录 `package.json` 的 `version` 是唯一版本来源，使用 `X.Y.Z`，界面显示为 `vX.Y.Z`。这是 Swift 项目；这个文件只管理版本与快捷命令，无 Node 依赖，也不需要安装依赖或生成 lockfile。

首个公开版本为 `v1.0.0`。版本显示在 Studio 左下角和系统 About 窗口；`GET /api/live` 返回 `version`，现有 `/health`、`/v1/status` 和 connection.json 返回 `appVersion`。这些接口与剧本中的整数 `version: 1` 是协议版本，独立维护。MCP 的 `serverInfo.version` 同样读取应用版本。

版本规则：

- 默认 patch：`X.Y.Z+1`，适用于修复、重构、依赖、文档和配置变更。
- 距离上次版本提交超过 3 天，或相对上次版本改动超过 500 行，默认 minor：`X.Y+1.0`。
- 新功能可以显式选择 minor；公共 API 等破坏性变更使用 major：`X+1.0.0`。
- 显式指定版本优先于自动选择。

更新版本：

```sh
python3 scripts/version.py bump --dry-run   # 预览自动选择
python3 scripts/version.py bump             # 自动选择并同步
python3 scripts/version.py bump minor       # 也支持 patch / major / 2.0.0
```

脚本会同步生成 `AppVersion.swift` 和 `Info.plist`。直接编辑 package.json 后运行 `python3 scripts/version.py sync`。构建时自动同步，测试和 CI 检查一致性。打包时，MCP 工具随 App 携带 manifest 副本。

发布时，维护根目录 CHANGELOG.md，运行 `scripts/test.sh` 及相关原生集成检查，按 [macOS 签名](signing.md) 构建 Developer ID 通用 App，并通过 `scripts/package_release.py --notary-profile <profile>` 完成公证、stapling、ZIP 往返验证及 SHA-256。提交并推送代码后，创建相同版本的 Git tag 和 GitHub Release。Release 的 What's New 使用本版本 changelog；`gh release create vX.Y.Z --verify-tag --title vX.Y.Z --notes-file <notes-file> <app.zip> <app.sha256>` 必须附上经过验证的 App，GitHub 自动生成的源码附件不算安装包。完整操作顺序与下载后验收见根 [CLAUDE.md](../CLAUDE.md)。

版本和打包脚本本身不提交、推送或发布。发布以用户当次授权为准；若已明确授权该版本，不重复请求确认；若要求先验收，本地构建不触发发布。未公开的中间版本归入最终版本的 changelog，不补造发布历史。

证书未就绪时，经用户知情授权可以通过 `scripts/package_release.py --unnotarized` 发行，并在 Release 中明确未公证状态、实际签名方式和首次打开步骤。公证失败不得静默降级；详细条件见签名文档。

发布后约 5 分钟检查 `gh run list --limit 5` 和对应 CI 日志；失败应修复并重新验证。README 保持简短。
