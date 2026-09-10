# Studio 与窗口控制

Studio 使用原生 macOS 统一工具栏与红绿灯。默认窗口为 1872 × 1248 pt，启动时在当前屏幕可用区域居中；屏幕较小时自动缩小。拖动、双击标题栏、Option + 绿灯缩放、最小化、全屏和窗口还原由 AppKit 处理；双击遵循系统的标题栏偏好设置。左侧按拍摄顺序排列 Canvas、Frame、Cursor、Text、Export，可用 logo 右侧按钮收起。Theater 模式将侧栏和分镜换为大画面及实时导演状态。第三个 Tab「AI Director」提供使用说明、创意简报和可一键复制的 Agent 指令，详见 [AI 导演流程](directing.md)。

## 录制真实网页

1. 每次启动打开内置 Orbit 示例；在 Live preview 上方输入自己的地址，点击 Open。支持本地 `http://localhost:3000`、远程 HTTPS 网站和 `file://` 页面。查询参数原样保留，网站通过 WebKit 真实加载和交互。网址不在下次启动时恢复。
2. Canvas 默认 1920 × 1080。在左侧 Canvas size 选择预设（最高 4K · 3840 × 2160），或输入宽高并按回车／应用按钮。None 框架的网页布局尺寸会减去 inset 和 56 px 浏览器顶栏；设备框架按比例适配 Canvas，网页视口使用实际屏幕区域。已有会话保留用户保存的尺寸。
3. 在 Canvas 的 Backdrop 设置留白和背景，进入 Frame 选择设备及 Light／Dark 外观：Light 使用银色机身；Dark 在 MacBook Neo 上使用靛蓝色，其余设备使用深空黑，标题栏／状态栏同步切换。Browser identity 可覆盖浏览器顶栏的标题和地址；留空使用真实信息。接着在 Cursor 和 Text 设置鼠标及字幕效果。
4. 最后进入 Export，在 Video export 选择输出分辨率与 24、30、60 fps。视频使用偶数像素，保持与 Canvas 相同的比例。修改 Canvas 自动适配输出；自定义视频比例不匹配会提示错误，保留原设置。设置会在下次启动恢复。
5. 点击顶部 Record，直接录制当前页面；再次点击 Stop Take 完成 MP4。右上角绿色 LIVE 灯牌表示实时预览，录制时切换为红色 ON AIR。打开其他网站不会自动运行 Orbit。导入剧本后，Rehearse 负责排练，「Record storyboard」明确执行并录制整个剧本。

影片内的浏览器顶栏只保留站点图标、标题、地址及刷新按钮，去掉前进／后退按钮与分割线。站点图标优先读取页面声明的 favicon，然后尝试该站点的 `/favicon.ico`；未提供或加载失败时使用 globe。图标来自真实网页，不随展示标题和地址的覆盖而改变，并同步进入截图和 MP4。

Canvas 范围为 800–3840 × 500–2160，自定义尺寸与预设共用这一上限。None 框架的网页至少保留 600 × 300；设备框架按可用画布等比适配。视频宽 640–3840、高 360–2160，均为偶数；竖屏和方形会提供符合编码范围的输出预设。输出为无音轨 H.264 MP4。帧率指编码时间轴；机器负载高于实时采集能力时会补重复帧。录制结果中的 `effectiveCaptureFPS` 是实际采集帧数除以影片时长，配合 `capturedFrames`、`duplicatedFrames` 和 `averageRenderMilliseconds` 判断录制流畅度，不能只看设置的 fps。

右上角太阳／月亮切换整个 Studio 的主题并保存偏好。它独立于影片的 Frame 外观，不改变网页的系统配色偏好；网页自身的主题仍由网站控制。右上角通知显示复制、错误和导出结果，鼠标悬停暂停消失计时，通知不会进入 MP4。

## 设备 Frame

Frame 默认选中 None。设备只定义外观和屏幕比例，不限制内容分辨率。外壳按 Canvas/inset 等比居中，网页按屏幕内的可用区域布局；Canvas、Frame 和 Export 分别控制构图尺寸、设备外观和输出像素。手机和平板为状态栏与底部安全区留空，MacBook 为屏幕正对镜头的视角。

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
scripts/showtime settings --canvas 3840x2160 --frame macbook-pro --video 3840x2160
scripts/showtime settings --frame none
```

MCP 使用 `showtime_settings(canvas: {"frame": "iphone-16-pro"})`，JSON 剧本写入 `canvas.frame`。更改 Frame、Canvas 尺寸或 inset 后重新 inspect 获取目标位置；x/y 始终为未放大的网页 CSS 坐标。只调整 Export 分辨率不会改变页面布局。设置会保存；旧剧本未写 `frame` 时仍使用 None。拍摄期间不能切换设备。

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
