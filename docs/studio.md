# Studio 与窗口控制

Studio 使用原生 macOS 统一工具栏与红绿灯。默认窗口为 1872 × 1248 pt，启动时在当前屏幕可用区域居中；屏幕较小时自动缩小。拖动、双击标题栏、Option + 绿灯缩放、最小化、全屏和窗口还原由 AppKit 处理；双击遵循系统的标题栏偏好设置。左侧按拍摄顺序排列 Canvas、Frame、Cursor、Text、Export，可用 logo 右侧按钮收起。Theater 模式将侧栏和分镜换为大画面及实时导演状态。第三个 Tab「AI Director」提供使用说明、创意简报和可一键复制的 Agent 指令，详见 [AI 导演流程](directing.md)。

## 录制真实网页

1. 每次启动打开内置 Orbit 示例；在 Live preview 上方输入自己的地址，点击 Open。支持本地 `http://localhost:3000`、远程 HTTPS 网站和 `file://` 页面。查询参数原样保留，网站通过 WebKit 真实加载和交互。网址不在下次启动时恢复。
2. Canvas 默认 1920 × 1080。在左侧 Canvas size 选择预设，或输入宽高并按回车／应用按钮。None 框架的网页布局尺寸会减去 inset 和 56 px 浏览器顶栏；设备框架使用自己的固定视口。已有会话保留用户保存的尺寸。
3. 在 Canvas 的 Backdrop 设置留白和背景，进入 Frame 选择设备及标题栏／状态栏的 Light／Dark 样式。Browser identity 可覆盖浏览器顶栏的标题和地址；留空使用真实信息。接着在 Cursor 和 Text 设置鼠标及字幕效果。
4. 最后进入 Export，在 Video export 选择输出分辨率与 24、30、60 fps。视频使用偶数像素，保持与 Canvas 相同的比例。修改 Canvas 自动适配输出；自定义视频比例不匹配会提示错误，保留原设置。设置会在下次启动恢复。
5. 点击顶部 Record，直接录制当前页面；再次点击 Stop take 完成 MP4。打开其他网站不会自动运行 Orbit。导入剧本后，Rehearse 负责排练，「Record storyboard」明确执行并录制整个剧本。

影片内的浏览器顶栏只保留站点图标、标题、地址及刷新按钮，去掉前进／后退按钮与分割线。站点图标优先读取页面声明的 favicon，然后尝试该站点的 `/favicon.ico`；未提供或加载失败时使用 globe。图标来自真实网页，不随展示标题和地址的覆盖而改变，并同步进入截图和 MP4。

Canvas 范围为 800–2560 × 500–1600，None 框架的网页至少保留 600 × 300；设备框架按可用画布等比适配。视频宽 640–3840、高 360–2160，均为偶数；竖屏和方形会提供符合编码范围的输出预设。输出为无音轨 H.264 MP4。帧率指编码时间轴；机器负载高于实时采集能力时会补重复帧，录制结果包含 `capturedFrames` 和 `duplicatedFrames`，便于检查。

右上角太阳／月亮切换整个 Studio 的主题并保存偏好。它独立于影片的浏览器顶栏样式，不改变网页的系统配色偏好；网页自身的主题仍由网站控制。右上角通知显示复制、错误和导出结果，鼠标悬停暂停消失计时，通知不会进入 MP4。

## 设备 Frame

Frame 默认选中 None。选择设备后，真实网页自动使用对应的 CSS 视口，触发网站自己的响应式布局；设备外壳同步出现在 Live Preview、Theater、PNG 和 MP4 中。Canvas 与输出尺寸保持原值，留白由 Canvas 的 inset 决定。手机和平板使用状态栏与底部安全区代替桌面浏览器顶栏，MacBook 为屏幕正对镜头的视角。

| Frame / `canvas.frame` | 逻辑显示尺寸 | 网页视口 |
| --- | --- | --- |
| None / `none` | 随 Canvas 变化 | 默认 1856 × 960 |
| iPhone SE / `iphone-se` | 375 × 667 | 375 × 647 |
| iPhone 16 Pro / `iphone-16-pro` | 402 × 874 | 402 × 790 |
| iPhone 16 Pro Max / `iphone-16-pro-max` | 440 × 956 | 440 × 872 |
| iPad mini / `ipad-mini` | 744 × 1133 | 744 × 1087 |
| iPad Pro 11″ / `ipad-pro-11` | 834 × 1194 | 834 × 1148 |
| iPad Pro 13″ / `ipad-pro-13` | 1032 × 1376 | 1032 × 1330 |
| MacBook 13″ / `macbook` | 1440 × 900 | 1440 × 844 |

尺寸指逻辑像素，已为设备状态区域留空；不是面板物理分辨率。网页仍由 macOS WebKit 加载，保留真实鼠标和键盘事件，不模拟 iOS、触摸 API 或设备 User-Agent。网站是否提供移动布局由其自身实现决定，内置 Orbit 已支持手机和平板。

```sh
scripts/showtime settings --frame iphone-16-pro
scripts/showtime inspect
scripts/showtime settings --frame none
```

MCP 使用 `showtime_settings(canvas: {"frame": "iphone-16-pro"})`，JSON 剧本写入 `canvas.frame`。切换后重新 inspect 获取目标位置；x/y 始终为未放大的网页 CSS 坐标，设备在 Canvas 上的缩放不会改变它。设置会保存；旧剧本未写 `frame` 时仍使用 None。拍摄期间不能切换设备。

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

`GET /v1/settings` 返回当前 `canvas` 和 `video`。POST 接受部分字段，整体校验成功后一次应用；忙碌时返回 409。它与界面使用同一套参数。`/v1/recording/start` 未指定的尺寸和帧率继承当前设置。脚本中的显式 `canvas` / `recording` 仍优先，Agent 的输出文件路径原样使用。

```python
client.request("POST", "/v1/settings", {
    "canvas": {"width": 1440, "height": 900, "inset": 32, "browserTheme": "dark"},
    "video": {"width": 1920, "height": 1200, "fps": 60}
})
```

```sh
scripts/showtime settings --canvas 1440x900 --video 1920x1200 --fps 60 --browser-theme dark
scripts/showtime studio --mode theater --theme dark
scripts/showtime open 'http://localhost:3000'
scripts/showtime record start --output /tmp/my-new-take.mp4
scripts/showtime record stop
```

MCP 提供对应的 `showtime_settings`、`showtime_studio`、`showtime_open`、`showtime_record` 工具。`GET /v1/status` 的 `director` 字段包含当前场景、动作、下一动作及已完成数量；查询状态不会制造新的活动记录。

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
```
