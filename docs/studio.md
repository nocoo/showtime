# Studio 与窗口控制

Studio 使用原生 macOS 统一工具栏与红绿灯。默认窗口为 1872 × 1248 pt，启动时在当前屏幕可用区域居中；屏幕较小时自动缩小。拖动、双击标题栏、Option + 绿灯缩放、最小化、全屏和窗口还原由 AppKit 处理；双击遵循系统的标题栏偏好设置。左侧按拍摄顺序排列 Canvas、Frame、Cursor、Text、Export，可用 logo 右侧按钮收起。Theater 模式将侧栏和分镜换为大画面及实时导演状态。第三个 Tab「AI Director」提供使用说明、创意简报和可一键复制的 Agent 指令，详见 [AI 导演流程](directing.md)。

## 录制真实网页

1. 每次启动打开内置 Orbit 示例；在 Live preview 上方输入自己的地址，点击 Open。支持本地 `http://localhost:3000`、远程 HTTPS 网站和 `file://` 页面。查询参数原样保留，网站通过 WebKit 真实加载和交互。网址不在下次启动时恢复。
2. Canvas 默认 1920 × 1080。在左侧 Canvas size 选择预设（最高 4K · 3840 × 2160），或输入宽高并按回车／应用按钮。Frame 的 Content width 控制屏幕在画布中的宽度；默认 Auto 按 Canvas/inset 自动适配。网页视口使用屏幕中扣除顶栏和安全区后的区域。已有会话保留用户保存的尺寸。
3. 在 Canvas 的 Backdrop 设置背景，进入 Frame 选择设备、Content width 及 Light／Dark 外观。输入固定宽度后，设备同比例缩放并居中，四周留白自动计算；Auto 模式下可用 Canvas 的 Inset 调整留白。Light 使用银色机身；Dark 在 MacBook Neo 上使用靛蓝色，其余设备使用深空黑，标题栏／状态栏同步切换。Browser identity 可覆盖浏览器顶栏的标题和地址；留空使用真实信息。接着在 Cursor 和 Text 设置鼠标及字幕效果。
4. 最后进入 Export，在 Video export 选择输出分辨率与 24、30、60 fps。视频使用偶数像素，保持与 Canvas 相同的比例。修改 Canvas 自动适配输出；自定义视频比例不匹配会提示错误，保留原设置。设置会在下次启动恢复。
5. 点击顶部 Record，直接录制当前页面；再次点击 Stop recording 完成 MP4。右上角绿色 LIVE 灯牌表示实时预览，录制时切换为红色 ON AIR。打开其他网站不会自动运行 Orbit。导入剧本后，Rehearse 负责排练，「Record storyboard」明确执行并录制整个剧本。

浏览器顶栏左侧提供紧凑的 Back、Forward 和 Stop loading，右侧保留刷新。前进／后退跟随 WebKit 历史；没有对应历史时变灰，Stop 仅在加载期间可用。播放、准备和保存期间导航控件禁用，手动录制仍允许真实浏览。Studio 地址输入框左侧也提供相同按钮，便于没有浏览器顶栏的设备使用。菜单与 ⌘[、⌘]、⌘R 使用相同状态。主动停止加载不会在稍后弹出超时错误，页内地址片段导航也能正常完成。

站点图标优先读取页面声明的 favicon，然后尝试该站点的 `/favicon.ico`；未提供或加载失败时使用 globe。图标来自真实网页，不随展示标题和地址的覆盖而改变，并同步进入截图和 MP4。

Canvas 范围为 800–3840 × 500–2160，自定义尺寸与预设共用这一上限。Auto 模式下，None 的网页至少保留 600 × 300，设备框架按可用画布等比适配；固定 Content width 的上限由 Canvas 和设备外壳共同决定。视频宽 640–3840、高 360–2160，均为偶数；竖屏和方形会提供符合编码范围的输出预设。输出为无音轨 H.264 MP4。帧率指编码时间轴；机器负载高于实时采集能力时会补重复帧。录制结果中的 `effectiveCaptureFPS` 是实际采集帧数除以影片时长，配合 `capturedFrames`、`duplicatedFrames` 和 `averageRenderMilliseconds` 判断录制流畅度，不能只看设置的 fps。

右上角太阳／月亮切换整个 Studio 的主题并保存偏好。它独立于影片的 Frame 外观，不改变网页的系统配色偏好；网页自身的主题仍由网站控制。右上角通知显示复制、错误和导出结果，鼠标悬停暂停消失计时，通知不会进入 MP4。

## 背景、柔光与 Camera

Backdrop 保留原来的 Mist 绿色、Pearl 与 Midnight，新增发布会风格的 Silver 灰色，以及参考 iPhone 5c 的淡糖果色 Cloud（白）、Sky（蓝）、Mint（绿）、Rose（粉）、Butter（黄）。

下方 Soft glow 可以开关中心柔光。Radius 控制亮心向外淡出的距离，Core size 控制亮心直径，两者以 Canvas 短边的百分比显示。默认半径 75%、亮心 30%；旧设置默认关闭，保留原有背景。柔光处于 Backdrop 与设备／网页之间，不遮盖内容。强度随 Frame 的 Light／Dark 外观和深色背景自动适配；切换 Studio 主题不改变成片。预览、PNG 与 MP4 使用同一套绘制，并按导出分辨率采样。

Camera 的 Close-up 与二维偏移叠加。点击或拖动触控板改变位置，向右／下为正偏移；左右、上下各可移动半个网页视口。聚焦后方向键每次移动 10 px，空格回到中心；Center 只清除偏移，Reset camera 重置整个镜头。数值与 `showtime status` 中的 `camera.offsetX/offsetY` 相同。

在脚本中把缩放和偏移写进同一个 `camera` 动作，排练和录制会从当前镜头一起动画过渡，`duration` 默认 1 秒；设计和播放沿用同一语法：

```sh
showtime settings --backdrop silver --glow --glow-radius 0.75 --glow-size 0.3
showtime design '{"action":"camera","scale":1.5,"offsetX":90,"offsetY":-40,"duration":1.2}'
```

对应剧本配置为 `canvas: {"backdrop":"silver","glow":true,"glowRadius":0.75,"glowSize":0.3}`。`glowRadius` 范围 0.1–1.5，`glowSize` 范围 0–1；CLI 用 `--no-glow` 关闭。Agent 可从 `showtime schema script` 或 MCP `showtime_help(topic: "script")` 获取完整限制。

## 设备 Frame

Frame 默认选中 None。设备只定义外观和屏幕比例，不限制内容分辨率。Canvas 控制构图尺寸，Content width 控制屏幕宽度，Frame 决定外观与比例，Export 决定输出像素。手机和平板为状态栏与底部安全区留空，MacBook 为屏幕正对镜头的视角。

Content width 指屏幕内部的宽度，单位为 Canvas 像素，不含外壳，同时也是网页的 CSS 视口宽度。设备屏幕高度按设备比例推导，外壳、标题栏和状态栏同比例缩放，整体在 Canvas 中居中。None 继承 Canvas 的比例：例如 3840 × 2160 Canvas 配合 2000 px Content width，浏览器显示区域为 2000 × 1125，左右各留 920 px；网页高度还要扣除缩放后的浏览器顶栏。

留空、输入 Auto 或点击 Auto 按钮恢复自动适配；旧设置和旧剧本默认使用 Auto，保留原有 Canvas/inset 布局。固定宽度时 Inset 不参与尺寸计算。输入框下方显示当前最大宽度，计算时包含设备外壳和 Canvas 高度；超出上限会提示错误并保留原设置，切换设备或缩小 Canvas 也不会悄悄改变指定的宽度。可先降低 Content width 或恢复 Auto，再切换到较小的画布或较高的设备。

| Frame / `canvas.frame` | 屏幕比例（宽:高） |
| --- | --- |
| None / `none` | 随 Canvas 变化 |
| iPhone 16 Pro / `iphone-16-pro` | 201:437 |
| iPhone 16 Pro Max / `iphone-16-pro-max` | 110:239 |
| iPad Pro 11″ / `ipad-pro-11` | 139:199 |
| iPad Pro 13″ / `ipad-pro-13` | 3:4 |
| MacBook Neo 13″（2026）/ `macbook-neo` | 2408:1506（约 16:10）|
| MacBook Pro 16″（2026）/ `macbook-pro` | 16:10（无刘海） |

MacBook Neo 使用圆润的显示屏外壳、无刘海的 13 英寸屏幕和较薄的平直底座，保留浏览器顶栏。MacBook Pro 参考现款 16 英寸机身，使用更窄的边框与更厚的底座；按展示需要采用完整的 16:10 无刘海屏幕，不预留顶部空白，也不绘制浏览器顶栏。两款均有上圆下直的屏幕开口、正面开盖凹槽、铰链与脚垫，下边框为无字标玻璃。

所有设备 Frame 共用 Light／Dark 设置（`canvas.browserTheme`）：Light 对应银色金属外壳；Dark 在 Neo 上对应官方靛蓝色，其余设备对应深空黑。侧键、金属边缘和 MacBook 底座一同切换，屏幕玻璃保持黑色。None 仍仅切换浏览器顶栏外观。预览和 PNG／MP4 使用同一套原生矢量路径与屏幕裁剪。

网页 CSS 视口随 Canvas 中的屏幕区域变化，可在 Frame 的 Web viewport 查看。Export 决定抓图像素密度：4K Canvas 配合 MacBook 与 4K Export 时，网页不受参考绘图尺寸限制；较小 Canvas 也会按 4K 输出所需密度重新采样。网页直接由 WebKit 抓取，外框按目标分辨率绘制，不使用缩小后的工作台预览作为素材。最终视频保持 Canvas 的宽高比，设备内容等比放入屏幕。

外观参考（核对日期：2026-09-10）：

- MacBook Neo：[Apple 规格](https://www.apple.com/macbook-neo/specs/)、[官方正面图](https://www.apple.com/v/macbook-neo/c/images/specs/display__gjwmz6l3m262_large_2x.jpg)和[靛蓝机身图](https://www.apple.com/v/macbook-neo/c/images/overview/product-viewer/pv_colors_indigo__ee1m3vsakryq_large.jpg)。Neo 首代为 2026 款；未找到可靠的完整机身 SVG，轮廓按官方图片重绘。
- MacBook Pro：[Apple 规格](https://www.apple.com/macbook-pro/specs/)、[官方 16 英寸正面图](https://www.apple.com/v/macbook-pro/specs/d/images/specs/16-inch/display_16_inch__bn4z91heotxy_large_2x.jpg)。参考 M5 Pro／Max 的 2026 款；官方图中的全屏视频在刘海周围留有黑边。
- SVG 结构参考：[MacBook Pro M5](https://github.com/marvinhuelsmann/apple-guide/blob/b0e04111d39faeb980fea58b0e88db1024bbe5fe/public/devices/macbook-pro-14-m5.svg)和[16 英寸 Pro](https://github.com/marvinhuelsmann/apple-guide/blob/b0e04111d39faeb980fea58b0e88db1024bbe5fe/public/devices/macbook-pro-16-m4-pro.svg)，用于交叉核对金属边缘与正面凹槽。项目重绘 Core Graphics 路径，Pro 按展示要求采用无刘海的 16:10 屏幕；这些参考 SVG 未打包进 App。

网页仍由 macOS WebKit 加载，保留真实鼠标和键盘事件，不模拟 iOS、触摸 API 或设备 User-Agent。网站是否提供移动布局由其自身实现决定。

```sh
scripts/showtime settings --frame iphone-16-pro
scripts/showtime inspect
scripts/showtime settings --frame macbook-neo --browser-theme dark
scripts/showtime settings --canvas 3840x2160 --frame macbook-pro --content-width 2000 --video 3840x2160
scripts/showtime settings --frame none --content-width 2000
scripts/showtime settings --content-width auto
```

MCP 使用 `showtime_settings(canvas: {"frame": "macbook-pro", "contentWidth": 2000})`，JSON 剧本写入 `canvas.frame` 和 `canvas.contentWidth`。`contentWidth: null` 恢复 Auto；HTTP/MCP 更新时省略该字段保留现值，剧本未写该字段则使用 Auto。更改 Frame、Content width、Canvas 尺寸或 inset 后重新 inspect 获取目标位置；x/y 始终为未放大的网页 CSS 坐标。只调整 Export 分辨率不会改变页面布局。设置会保存并写入 AI Director 的当前配置；旧剧本未写 `frame` 时仍使用 None。拍摄期间不能更改这些设置。

iPhone SE 和 iPad mini 已从设备选择、CLI 和 MCP 列表移除。载入旧设置或 JSON 时，`iphone-se` 迁移到 `iphone-16-pro`，`ipad-mini` 迁移到 `ipad-pro-11`，原 `macbook` 迁移到 `macbook-neo`；Canvas、留白、外观与导出配置保留，保存时写入新名称。未知设备名称仍会报错。

## Agent 接口

以下 HTTP 接口沿用现有的 loopback 地址与 Bearer 认证。使用 `scripts/showtime_client.py` 中的 `Client` 会自动读取本机连接信息，无需复制 token。

```python
from showtime_client import Client

client = Client()
client.request("POST", "/v1/studio", {"inspector": "Cursor"})
client.request("POST", "/v1/studio", {"mode": "theater", "theme": "dark"})
client.request("POST", "/v1/studio", {"mode": "studio", "showInspector": True})
client.request("POST", "/v1/studio/screenshot", {"output": "/tmp/showtime-studio.png"})
```

`GET /v1/studio` 读取布局及主题，`mode` 接受 `studio`、`theater`、`director`，`inspector` 接受 `Canvas`、`Frame`、`Cursor`、`Text`、`Export`。旧的 `theater` 布尔参数保持兼容，`mode` 优先。录制或执行剧本时不能进入 AI Director 设置页。

`GET /v1/settings` 返回当前 `canvas` 和 `video`。POST 接受部分字段，整体校验成功后一次应用；忙碌时返回 409。它与界面使用同一套参数。`/v1/record` 没有 `script.recording` 时继承当前导出设置并匹配画布比例。脚本中的显式 `canvas` / `recording` 优先。

```python
client.request("POST", "/v1/settings", {
    "canvas": {"width": 1440, "height": 900, "inset": 32, "browserTheme": "dark"},
    "video": {"width": 1920, "height": 1200, "fps": 60}
})
```

```sh
export PATH="$HOME/Library/Application Support/Showtime/bin:$PATH"
showtime settings --canvas 1440x900 --video 1920x1200 --fps 60 --browser-theme dark
showtime studio --mode theater --theme dark
showtime design '{"action":"open","url":"http://localhost:3000"}'
showtime validate film.json
showtime rehearse film.json
showtime record film.json --output /tmp/my-new-take.mp4
```

MCP 提供对应的 `showtime_settings`、`showtime_studio`、`showtime_design`、`showtime_validate`、`showtime_rehearse`、`showtime_record` 工具。用 `showtime_help` 获取内置 skill 和动作 schema。`GET /v1/status` 的 `workflow` 区分 design/rehearse/record，`busy` 表示任务或录像尚未结束；`director` 包含当前场景、动作、下一动作和已完成数量。查询状态不会制造新的活动记录。

| HTTP 接口 | 请求和行为 |
| --- | --- |
| `POST /v1/design` | `{ "step": ACTION, "screenshot": "/tmp/preview-new.png" }`；执行单个设计动作，截图可选 |
| `POST /v1/validate` | `{ "script": SCRIPT, "mode": "rehearse", "from": "feature", "to": "closing" }`；只校验，record 模式可提供 output |
| `POST /v1/rehearse` | `{ "script": SCRIPT, "from": 2, "to": 5 }`；先 setup，再执行范围，不录制 |
| `POST /v1/record` | `{ "script": SCRIPT, "output": "/tmp/take-new.mp4" }`；setup 后开始录制，范围可选 |
| `GET /v1/jobs/ID` | 查询模式、阶段、原步骤／ID、选段进度、结果、错误和导出统计 |
| `POST /v1/cancel` | 取消当前任务；正在录像时完成部分 MP4 |

三个执行接口返回 HTTP 202 和 `job`、`mode`、`poll`；最终结果通过任务查询读取。剧本接口均支持可选的最终 PNG 路径 `screenshot`；路径必须绝对或以 `~/` 开头。`from/to` 为包含两端的顶层序号或 ID，默认完整剧本。完整语义见 [拍摄指引](directing.md)。HTTP 保留 `/v1/actions`、`/v1/open`、`/v1/run` 和 `/v1/recording/start`、`/v1/recording/stop` 兼容入口；CLI / MCP 不再公开逐次控制录像的流程。

Studio 截图包含原生标题栏、工具栏和红绿灯；`/v1/screenshot` 与 MP4 仍只输出影片画面。输出路径必须尚不存在。

## 原生窗口

`GET /v1/studio/window` 返回窗口位置、尺寸、屏幕可用区域、内容区域、最小尺寸、缩放/最小化/全屏状态、全屏动画标记 `transitioning`，以及系统红绿灯的可见性和位置。坐标使用 AppKit 的左下角原点，窗口 frame 在屏幕坐标系中，内容区域和按钮在窗口坐标系中。

`POST /v1/studio/window` 接受以下 `action`。录制或剧本执行期间拒绝这些 API 操作。

| action | 行为 |
| --- | --- |
| `zoom` | 原生缩放，再次调用还原；要求窗口处于普通窗口模式 |
| `minimize` | 触发系统黄色按钮；要求已退出全屏 |
| `restore` | 从最小化、全屏或缩放状态还原，并显示窗口 |
| `fullscreen` | 切换原生全屏；要求窗口未最小化 |
| `resize` | 用 `width` 和 `height` 设置窗口尺寸（point），限制在窗口最小尺寸和当前屏幕可用范围内 |
| `doubleClickTitlebar` | 向原生标题栏发送双击事件，由系统执行用户设置的操作 |
| `click` | 在窗口内的 `x` / `y` point 位置发送原生点击，用于验证 Studio 按钮；与网页动作的 CSS 坐标系不同 |

```python
client.request("POST", "/v1/studio/window", {"action": "resize", "width": 1280, "height": 900})
client.request("POST", "/v1/studio/window", {"action": "zoom"})
client.request("POST", "/v1/studio/window", {"action": "restore"})
```

原生窗口动画和鼠标事件异步完成，POST 返回的是当前状态；调用方应轮询 GET，等待 `transitioning` 为 `false` 且达到目标状态。全屏动画期间的窗口操作返回 HTTP 409，完成状态来自 AppKit 的通知。还原与全屏操作会激活 App。窗口控制与 Studio 截图不需要全局辅助功能或屏幕录制权限。

运行中的 App 可以用以下检查验证原生窗口行为、窗口还原和最小尺寸下的网页点击，并保存正常、最小窗口及 Theater 截图。脚本遵循本机的标题栏双击偏好，不修改系统设置。

```sh
python3 scripts/test_studio.py --output-dir artifacts/studio-check
```

安装 FFmpeg 后，还可在当前 App 验证真实网站录制、三档帧率、横屏／竖屏输出、浏览器顶栏样式与 MCP 进度：

```sh
python3 scripts/test_capture.py --url 'http://localhost:3000' --output-dir artifacts/capture-check
python3 scripts/test_frames.py --output-dir artifacts/frame-check
python3 scripts/test_presentation.py --output-dir artifacts/presentation-check
```

`test_presentation.py` 用 Orbit 检查原生导航、慢加载停止、九种背景、柔光与组合镜头的中间视频帧。GUI 验收期间保持 Mac 解锁；锁屏会让 WebKit 暂停页面动画。
