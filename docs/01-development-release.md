# 开发约束、验收与发布细则

Detailed project constraints and procedures. The root [CLAUDE.md](../CLAUDE.md) defines the quality contract and records current enforcement gaps.

## 项目结构与约束

- `Sources/Showtime/App`：原生窗口、工具栏、主题、Inspector、Toast、AI Director 引导。
- `Sources/Showtime/Browser`：真实 WebKit 页面、原生输入、紧凑浏览器顶栏及 favicon。
- `Sources/Showtime/Director`：剧本调度、并行动作、Theater 进度；`Recording` 负责 Canvas 合成与视频编码。
- `Sources/ShowtimeCore`：可校验的剧本与录制配置；`Tests/ShowtimeCoreTests` 是可在 Command Line Tools 环境运行的检查程序。
- `scripts/showtime`、`showtime_cli.py`、`showtime_mcp.py`：CLI / MCP 入口，打包时一起放进 App；不依赖源码目录。
- CLI / MCP 只在 **AI Director → Agent integration → Install / Update tools** 的显式点击后，通过 `AgentGuide.installTools()` 安装随包的 9 个文件（含 schema、SKILL.md 和 PROJECT_DEMO_SKILL.md）到 `~/Library/Application Support/Showtime/bin`。启动、进入页面和复制指令不能安装工具、执行 Python 或弹出依赖安装窗口。页面按文件内容识别未安装/已安装/待更新；Python 检查只在安装/检查按钮后执行，缺少时在页面提供官方 Python 下载链接与重新检查。普通网页/录制流程不依赖 Python。
- 用户在当前 shell 加入上述 PATH 后使用 `showtime`。MCP 配置调用同一入口的 `showtime mcp`，由 shell 展开 HOME；POSIX shell 入口查找现有 Python 3.10+，支持常见 Homebrew/python.org 路径并跳过 Apple 系统安装占位程序。不要把 `Bundle.main.resourceURL`、`#filePath`、临时下载或验收目录写入面向用户的指令；不要自动修改 shell profile 或系统 PATH。工具升级必须由用户点击；已安装工具与 App 文件一致才显示已就绪，工具不能在签名包内生成字节码。
- `package.json` 只管理版本与快捷命令，没有 Node 依赖，不运行 npm/bun install，也不生成 lockfile。
- 默认 Canvas 为 1920 × 1080；视频默认 1920 × 1080、30 fps。已保存的用户设置和显式剧本配置优先。视频宽高必须为偶数，与 Canvas 同比例。
- `canvas.frame` 默认 `none`，未指定 Frame 的旧 JSON 也解码为 `none`。Frame 只定义设备外观与屏幕比例，参考绘图尺寸不能限制网页或导出分辨率。`canvas.contentWidth` 为可选整数，表示不含外壳的屏幕宽度；缺省/null 为 Auto，保留 Canvas/inset 自动适配。固定宽度时忽略 inset，按设备屏幕比例推导高度并居中；None 继承 Canvas 比例。包含外壳的尺寸必须放得下，超限明确报错，不能静默缩放。WebKit 的 CSS 视口使用 `FrameLayout.canvasPage.size`，抓图按 Export 像素密度及镜头缩放采样；外壳与文字在目标分辨率绘制。`FrameLayout` 是预览、合成、鼠标坐标的共同几何来源，屏幕裁剪统一使用 `screenPath(in:)`；`DeviceFrameRenderer` 负责原生矢量外壳。MacBook Neo 为 2026 款 13 英寸、无刘海并保留浏览器顶栏；MacBook Pro 参考 2026 款 16 英寸机身，按用户要求采用完整 16:10 无刘海屏幕，不预留摄像头安全区或绘制浏览器顶栏。两款均为平直底座、上圆下直屏幕，下边框无字标，造型来源见 `docs/studio.md`。所有设备外壳、侧键和底座随 `canvas.browserTheme` 切换：light 为银色，dark 在 Neo 上为靛蓝色，其余为深空黑，独立于 Studio 和网页主题；None 仅切换浏览器顶栏。已移除 SE 和 mini 的绘制与选择入口；解码旧名称时 `iphone-se` → `iphone-16-pro`、`ipad-mini` → `ipad-pro-11`、`macbook` → `macbook-neo`，保留其余设置。iPhone/iPad 的状态栏和底部安全区不覆盖网页；手机框架不等同于 iOS/触摸模拟器。
- 保留原生红绿灯、标题栏拖动/双击、缩放、最小化、全屏和还原。不要用自绘控件替代窗口行为。
- 页面输入使用真实 WebKit/AppKit 鼠标、键盘和滚轮事件；JavaScript 用于检查、等待与断言，不代替真实点击。
- `overlay` 使用独立、透明、非持久化的 WKWebView 覆盖整个 Canvas，位于网页/外壳之上、原生鼠标/字幕之下。原生 hitTest 穿透且文档 inert，不能抢夺网页鼠标或键盘焦点。预览、PNG、MP4 使用同一帧回调与 alpha 抓图，按 Export 像素密度合成。setup 固定第 0 帧，播放开始或 props 更新重置时钟；每个新选段重置 renderer。一个 parallel 可有一个 overlay；任意数量组件在同一页面中绘制。React 示例依赖仅在 `examples/overlay-react` 中安装，根目录无 Node 依赖。协议见 `docs/overlays.md`，安装后的 skill 必须包含自足的回调说明。
- Agent 使用 design 预览单个动作，再用 rehearse / record 执行完整 JSON 或包含两端的步骤范围。两阶段共享动作语法；setup 在每个范围前执行且不进入录制，不隐式补跑跳过的步骤。设计字幕持续显示，播放字幕按 duration 计时。camera 的缩放、平移、旋转和镜像必须在原生预览、导出与输入反向映射中一致。
- CLI / MCP 的语法定义共用 scripts/showtime_schema.py；用户指引来自 skills/showtime/SKILL.md，并随 App 安装。App 一键复制应包含完整 skill 与 guide/schema/help 的入口。更改动作语法时同步文档、示例和测试。
- Studio Record 录当前网页，不隐式加载或重播 Orbit 剧本。App 的控制 UI、Toast 和导演状态不进入成片。
- 每次启动固定打开内置 Orbit（`showtime://demo`），清除旧 `lastWebsite` 偏好，不保存或恢复上次访问的网址。公开代码、文档和剧本不写个人测试站点；示例使用 Orbit 或 `http://localhost:3000`，真实测试地址通过 `--url` 传入。
- 录制取消仍应生成可播放的部分 MP4。不要隐瞒 `duplicatedFrames`；编码帧率与实际采集速度不同。
- 视频大图合成使用冻结的 Canvas、镜头和网页快照，在后台直接写入编码器的 CVPixelBuffer；AppKit 字幕和鼠标绘制留在主线程，使用同一帧冻结的效果状态。最多预取一帧，与后台合成重叠，不积压网页快照；旧 Canvas 或录制开始前的快照不能写入新 take。预览镜头使用 Core Animation 图层变换，滚动保留原生连续像素手势。优化不能降低 4K 采样密度；通过 `effectiveCaptureFPS`、`capturedFrames`、`duplicatedFrames` 和渲染耗时评估实际效果。
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
| 启动与旧偏好迁移 | `python3 scripts/test_startup.py --app dist/Showtime.app --output-dir artifacts/startup-check`：旧网址偏好清理、Orbit 首屏、原生点击、访问其他网页后重启 | 启动逻辑变化、发布验收 |
| 设计与脚本流程 | `python3 scripts/test_workflow.py --output-dir artifacts/workflow-check`：共享语法、字幕预览、setup、范围、状态、Orbit 收入与项目章节排练、完整发布演示、镜像输入及部分 MP4 | CLI、MCP、导演与效果变化 |
| 透明动画层 | 先在 `examples/overlay-react` 构建示例，再运行 `python3 scripts/test_overlay.py --output-dir artifacts/overlay-check`：原生点击穿透、焦点、React、帧时钟、错误与取消、1080p/4K/部分 MP4 | overlay、WebView 输入隔离与合成变化 |
| 真实输入与取消 | `python3 scripts/test_integration.py --output-dir artifacts/input-check` | 输入、导演、录制变化 |
| 原生窗口与布局 | `python3 scripts/test_studio.py --output-dir artifacts/studio-check` | 工具栏、布局、窗口变化 |
| 视频与 MCP | `python3 scripts/test_capture.py --url 'http://localhost:3000' --output-dir artifacts/capture-check`，省略 `--url` 使用 Orbit | Canvas、导出、Agent 流程变化 |
| 导航与画面效果 | `python3 scripts/test_presentation.py --output-dir artifacts/presentation-check`：原生前进／后退／停止、片段导航、九种背景、柔光、缩放与偏移的中间视频帧 | 浏览器导航、Backdrop、Camera 变化 |
| 设备框架 | `python3 scripts/test_frames.py --output-dir artifacts/frame-check`：全部尺寸、窄屏真实输入、缩放、Canvas 适配、原生预览和三类 MP4 | Frame、视口和合成变化 |
| Agent 工具 | 在 AI Director 点击 Install tools，再运行 `python3 scripts/test_agent_tools.py --app dist/Showtime.app --output-dir artifacts/agent-tools-check`；可用 `--brief` 检查保存的剪贴板指令 | CLI、MCP、按需安装和发布验收 |
| 压缩包往返 | `python3 scripts/package_release.py --local-preview` | 无证书本地/CI 验证包内容；此包不能作为正式 Release 资产 |

测试输出目录必须新建，不能覆盖已有录像。窗口与录制集成检查共用一个 App，串行运行。它们会激活原生窗口，运行期间暂停手动键鼠输入，避免焦点和表单内容被打断；结束后恢复目标网站、用户的 Canvas/视频设置、主题与窗口布局。

视觉验收延续内置 Orbit 的完整产品场景，用真实图表、项目表单和发布演示验证镜头、字幕与输入。保留页面设计与业务反馈，不用孤立色块或测试球替换界面；同时检查代表截图和成片。

完整成片的时序验收不要混入 `/v1/studio/screenshot` 整窗诊断：同步整窗抓图会占用主线程，拖慢采集并影响字幕淡入。整窗截图和故意触发错误的检查单独执行；Agent 的成片截图使用 `/v1/screenshot`。字幕验收需检查视频中的实际画面，不能只检查动作完成状态。

GUI 成片验收需要解锁的 macOS 会话。锁屏后 WebKit 会将页面标记为 `document.hidden` 并暂停 CSS 动画，即使 `ready` 为 true、截图和编码仍能返回。测试需等待页面可见且 Orbit 入场动画完成；主内容空白的录像不能算通过，也不能通过移除页面动画掩盖问题。

若另一个 Agent 正在操作常用 App，使用独立测试副本、独立 bundle ID 与空闲 `SHOWTIME_PORT`，并让 App 和测试客户端使用同一个绝对 `SHOWTIME_CONNECTION` 路径。该文件放在忽略的 `artifacts/` 私有子目录。不要让集成检查覆盖其他 Agent 的连接、会话或录像。

发布前运行最终 Release 二进制：验证默认窗口居中与 1920 × 1080 Canvas、工具栏/Dock 图标、Light/Dark、Toast、下拉框对齐、五个 Inspector、Frame 默认为 None、AI Director 一键复制、Theater 当前/下一动作；检查红绿灯、标题栏双击及窗口还原。使用真实站点先排练再拍摄，检查 MP4 的尺寸、帧率、时长及代表帧。与改动相关的检查通过后，不无故重复全部测试。

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

若证书尚未就绪，且用户已知此状态仍授权发布，可以显式使用 `scripts/package_release.py --unnotarized`。必须在 README 和每次 Release 的下载区说明实际签名、未公证状态及「系统设置 → 隐私与安全 → 仍要打开」的首次确认方式，并附上以下可复制命令：

```sh
xattr -dr com.apple.quarantine "/Applications/Showtime.app"
open "/Applications/Showtime.app"
```

同时说明安装路径可替换、权限不足时在 `xattr` 前加 `sudo`；该操作只移除 App 的下载隔离标记，不增加签名或 Apple 公证。用户已明确要求保留这项安装说明。下载验收仍记录原始 Gatekeeper 结果，不能把移除隔离后的启动声称为默认 Gatekeeper 通过。`--unnotarized` 不会自动降级签名，也不消除 quarantine。未来补齐 Developer ID 后发布新版本，不替换已发布资产。v1.2.0、v1.2.1、v1.3.0 使用这类经用户确认的未公证发行。

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

   验证 AI Director 按需安装与复制：未安装时普通启动、进入页面、复制简报不能写入工具；缺少 Python 时展示页内安装入口。点击 Install tools 后从非仓库目录运行 CLI，用仅含系统 PATH 的 GUI 环境通过复制的 MCP 配置完成握手和状态查询。指令不得含开发者用户名、源码路径、`artifacts` 或 App 临时安装位置。移动或重命名解压的 App、重新启动后入口仍应有效；工具变化提示 Update tools，不能静默升级。README 用户命令必须使用此稳定入口；源码开发命令可以继续使用 `scripts/showtime`。
4. `git diff --check`，按路径 stage，commit，push main。tag 必须指向生成并验证该资产的提交。
5. 写实际多行 Release notes 文件，内容包括本版本 changelog、下载文件、macOS 14+ / 支持架构、解压并拖到 Applications 的安装方式。未公证发行必须复制上方 `xattr` / `open` 命令到 README 和 Release 下载区，并核对公开页面实际显示；不要只链接到签名文档。不要把历史版本列为新功能。
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
9. 恢复验收前的用户设置，清理仅由验收安装的工具。用户要求关闭 App 时，下载验收后通过空闲状态下的 `/v1/app/quit` 退出，并确认没有遗留的 Showtime 进程。

不要改动 Hexly 或其他项目的版本、网站或发布计划来完成 Showtime 的发布。
