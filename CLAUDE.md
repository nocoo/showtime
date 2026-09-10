# Showtime development guide

Showtime 是 macOS 14+ 的原生 SwiftUI / AppKit / WebKit 浏览器，由 Agent 编排真实网页操作，输出 H.264 MP4。主要用户流程是：打开网站 → Canvas → Cursor → Text → Export → AI Director → 在 Theater 观察拍摄。

## 项目结构与约束

- `Sources/Showtime/App`：原生窗口、工具栏、主题、Inspector、Toast、AI Director 引导。
- `Sources/Showtime/Browser`：真实 WebKit 页面、原生输入、紧凑浏览器顶栏及 favicon。
- `Sources/Showtime/Director`：剧本调度、并行动作、Theater 进度；`Recording` 负责 Canvas 合成与视频编码。
- `Sources/ShowtimeCore`：可校验的剧本与录制配置；`Tests/ShowtimeCoreTests` 是可在 Command Line Tools 环境运行的检查程序。
- `scripts/showtime`、`showtime_cli.py`、`showtime_mcp.py`：CLI / MCP 入口，打包时一起放进 App；不依赖源码目录。
- `package.json` 只管理版本与快捷命令，没有 Node 依赖，不运行 npm/bun install，也不生成 lockfile。
- 默认 Canvas 为 1920 × 1080；视频默认 1920 × 1080、30 fps。已保存的用户设置和显式剧本配置优先。视频宽高必须为偶数，与 Canvas 同比例。
- 保留原生红绿灯、标题栏拖动/双击、缩放、最小化、全屏和还原。不要用自绘控件替代窗口行为。
- 页面输入使用真实 WebKit/AppKit 鼠标、键盘和滚轮事件；JavaScript 用于检查、等待与断言，不代替真实点击。
- Studio Record 录当前网页；只有明确选择示例或剧本时才加载 Orbit。App 的控制 UI、Toast 和导演状态不进入成片。
- 录制取消仍应生成可播放的部分 MP4。不要隐瞒 `duplicatedFrames`；编码帧率与实际采集速度不同。
- 真实网站录像、连接信息与验收截图放进忽略的 `artifacts/`，不要提交私人网页内容或 bearer token。客户端通过 `showtime_client.Client` 读取连接文件。
- 不要求全局 Accessibility 或 Screen Recording 权限；窗口和页面测试使用本 App 的接口。
- 图标入口与来源见 `docs/branding.md`：工具栏用透明 `ShowtimeMark.png`，App / Dock 用带背景 ICNS。不要改回导致空白的按名称加载方式。
- 先检查工作树和协作文件归属，按路径暂存自己的改动。README 为中文，`docs/README.en.md` 为英文；存在独立文档协作时不要替其他人提交。

## 开发与构建

需要 macOS 14+、Swift 6 工具链（Xcode 或 Command Line Tools）、Python 3、Node（仅检查示例网页脚本）。视频验收需要 FFmpeg；发布需要 `gh`、`notarytool`、签名身份与公证配置。GUI App 不需要用户安装这些开发工具；CLI / MCP 使用 Python 3。

```sh
scripts/test.sh
scripts/build.sh debug
open dist/Showtime.app
scripts/showtime --version
scripts/showtime status
```

构建默认使用本机架构和稳定的开发签名。发布构建支持 Apple Silicon / Intel 通用二进制：

```sh
SHOWTIME_ARCH=universal scripts/build.sh release
```

`SHOWTIME_ARCH` 可设为 `arm64`、`x86_64`、`universal`。脚本分别编译两个 target，再用 lipo 合并，不要求完整 Xcode。先在临时目录组装并校验完整 App，再替换 `dist/Showtime.app`；资源、MIT 协议、版本 manifest 和 Agent 工具均在 App 内。不要直接 `swift run Showtime` 作为发布验收。

重建前先结束当前 take，再退出 App（可使用空闲状态下的 `POST /v1/app/quit`）。新构建启动后轮询 `Client().status()` 等待 ready，并核对 `appVersion`；不要误测仍在运行的旧二进制。

## 测试与验收

| 检查 | 命令 / 内容 | 时机 |
| --- | --- | --- |
| 核心与静态检查 | `scripts/test.sh`：版本一致性、Swift 检查、构建脚本语法、Python 编译、示例 JS 语法 | 每次相关修改、CI |
| 真实输入与取消 | `python3 scripts/test_integration.py --output-dir artifacts/input-check` | 输入、导演、录制变化 |
| 原生窗口与布局 | `python3 scripts/test_studio.py --output-dir artifacts/studio-check` | 工具栏、布局、窗口变化 |
| 视频与 MCP | `python3 scripts/test_capture.py --url 'http://127.0.0.1:3200/ai-interpreter/service-overview?w=1d' --output-dir artifacts/capture-check` | Canvas、导出、Agent 流程变化 |
| 压缩包往返 | `python3 scripts/package_release.py --local-preview` | 无证书本地/CI 验证包内容；此包不能作为正式 Release 资产 |

测试输出目录必须新建，不能覆盖已有录像。窗口与录制集成检查共用一个 App，串行运行。它们会操作页面和部分会话状态；结束后恢复目标网站、用户的 Canvas/视频设置、主题与窗口布局。

发布前运行最终 Release 二进制：验证默认窗口居中与 1920 × 1080 Canvas、工具栏/Dock 图标、Light/Dark、Toast、下拉框对齐、四个 Inspector、AI Director 一键复制、Theater 当前/下一动作；检查红绿灯、标题栏双击及窗口还原。使用真实站点先排练再拍摄，检查 MP4 的尺寸、帧率、时长及代表帧。与改动相关的检查通过后，不无故重复全部测试。

## 版本号

根 `package.json` 的 `version` 是唯一来源，格式 `X.Y.Z`；界面/tag 显示 `vX.Y.Z`。不要手动修改生成的 `AppVersion.swift` 和 `scripts/Info.plist`。

```sh
python3 scripts/version.py show
python3 scripts/version.py bump --dry-run
python3 scripts/version.py bump minor  # 用户指定版本时，改传该 X.Y.Z 版本
python3 scripts/version.py check
```

显式版本优先，只在一轮发布中递增一次。未指定时默认 patch；距上次版本超过 3 天或改动超过 500 行自动 minor；破坏性 API 变更用 major。脚本同步 Swift / plist，构建复制 manifest，App、CLI、MCP、状态接口必须一致。JSON 剧本中的 `version: 1` 是协议版本，不随 App 发版递增。

同步维护 `CHANGELOG.md`。未公开的中间版本合并到实际发布版本中，不虚构 tag 或 Release 历史。细节见 `docs/versioning.md`。nmem 参考：`f1ee6f38-dc59-4f41-83c8-2a2663f32c31`（版本管理）。

## 签名

遵循 nmem「macOS：App签名」`cda91722-a509-4193-bede-cba529e3f302`：

- 本地默认 `CODE_SIGN_IDENTITY=Apple Development`，`DEVELOPMENT_TEAM=93WWLTN9XU`。
- Bundle ID 固定为 `studio.showtime.mac`；按证书名称选择身份，不固定证书 SHA。
- `security find-identity -v -p codesigning` 检查是否存在证书及匹配私钥。身份缺失时构建应明确失败，不能偷偷改为 ad-hoc。
- 显式 `CODE_SIGN_IDENTITY=-` 仅供临时本地/CI 验收；这不代表已公证或可通过下载后的 Gatekeeper。
- 无需额外安全确认的公开下载使用 `Developer ID Application` + Hardened Runtime + secure timestamp + Apple notarization + staple。证书名称与公证 profile 可配置，凭据只保存在钥匙串，不提交、不打印私钥或密码。
- 不关闭 Gatekeeper，不移除用户下载的 quarantine 属性来伪造通过。若证书或公证条件缺失，继续准备本地结果，并明确报告尚未完成的分发环节。

若证书尚未就绪，且用户已知此状态仍授权发布，可以显式使用 `scripts/package_release.py --unnotarized`。必须在 Release 下载区说明临时/开发签名、未公证状态及「系统设置 → 隐私与安全 → 仍要打开」的首次确认方式，不能声称默认 Gatekeeper 已通过。`--unnotarized` 不会自动降级签名，也不消除 quarantine。未来补齐 Developer ID 后发布新版本，不替换已发布资产。v1.2.0 是此类经用户确认的未公证发行。

完整操作见 `docs/signing.md`。CI 只验证通用构建和本地压缩包，不持有个人签名身份，也不自动发布。

## GitHub Release 流程

发布以用户当前授权为准；已授权的同一版本无需重复确认。若用户要求先验收，完成可审阅结果再等确认。构建和版本脚本本身不推送、不打 tag、不发 Release。

1. 确认版本、changelog、相关测试与源码审阅完成，退出旧 App。
2. 使用 Developer ID 编译 Release，并对 App 公证、staple、验证下载包：

   ```sh
   CODE_SIGN_IDENTITY='Developer ID Application: Your Name (93WWLTN9XU)' \
   DEVELOPMENT_TEAM=93WWLTN9XU SHOWTIME_ARCH=universal scripts/build.sh release
   python3 scripts/package_release.py --notary-profile showtime-notary
   ```

   名称/profile 是示例，使用本机已配置的真实名称。正式包为 `dist/release-vX.Y.Z/Showtime-X.Y.Z-macos-universal.zip`，附 `.sha256`；脚本检查完整资源、App/CLI 版本、架构、签名、公证结果、staple 和 Gatekeeper，并校验解压后的 App。公证分发仅接受 `Accepted`；经用户授权的未公证发行走上文的显式 `--unnotarized` 分支，并保留真实 Gatekeeper 检查结果。

3. 从这个 ZIP 解压到全新目录，启动其中的 App。确认无需源码即可加载页面，CLI/MCP 可连接，原生点击和 MP4 导出正常；检查 App 在运行工具后仍通过签名验证。Apple Silicon 和 Intel 架构都必须存在；实际执行过哪些架构要如实记录。
4. `git diff --check`，按路径 stage，commit，push main。tag 必须指向生成并验证该资产的提交。
5. 写实际多行 Release notes 文件，内容包括本版本 changelog、下载文件、macOS 14+ / 支持架构、解压并拖到 Applications 的安装方式。不要把历史版本列为新功能。
6. 创建并推送相同版本 tag，再发布含 ZIP 与校验文件的 Release：

   ```sh
   git tag -a vX.Y.Z -m 'Showtime vX.Y.Z'
   git push origin vX.Y.Z
   gh release create vX.Y.Z --repo nocoo/showtime --verify-tag --title vX.Y.Z \
     --notes-file dist/release-notes.md \
     dist/release-vX.Y.Z/Showtime-X.Y.Z-macos-universal.zip \
     dist/release-vX.Y.Z/Showtime-X.Y.Z-macos-universal.sha256
   ```

   GitHub 自动附带的源码 ZIP 不算可安装 App。不要覆盖已有版本 tag 或悄悄替换已发布资产。

7. 用 `gh release view` 核对 tag/资产，再用 `gh release download` 到新目录，核对 SHA-256、解压签名和启动。记录 Release URL、commit/tag、ZIP hash、签名/公证事实和验收产物。
8. 发布约 5 分钟后用 `gh run list --limit 5` 查看该提交的 CI；失败先调查修复，不把未完成或失败的 CI 报为通过。等待期间仍应及时同步进度。

不要改动 Hexly 或其他项目的版本、网站或发布计划来完成 Showtime 的发布。
