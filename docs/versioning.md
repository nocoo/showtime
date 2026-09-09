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

发布时，维护根目录 CHANGELOG.md，运行 `scripts/test.sh` 和 `scripts/build.sh release`，提交并推送代码，然后创建相同版本的 Git tag 和 GitHub Release。Release 的 What's New 使用本版本 changelog，使用 `gh release create vX.Y.Z --verify-tag --title vX.Y.Z --notes-file <notes-file>` 发布。版本脚本本身不提交或推送代码。

发布后约 5 分钟检查 `gh run list --limit 5` 和对应 CI 日志；失败应修复并重新验证。README 保持简短。
