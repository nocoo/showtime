# 用 AI Director 拍摄真实产品

Showtime 把 Agent 操作分成两个阶段：设计时逐个预览动作并截图；排练和录制时执行预先写好的 JSON 剧本。App 连续执行所有动作、过渡和等待，Agent 的思考、响应和网络延迟不会打断正在播放的片段。

## 一键交给 Agent

先在 Studio 设置 Canvas、Frame、Cursor、Text 和 Export。进入 AI Director，填写网站、创意简报和目标片长，然后点击 **Copy instructions for your agent**。复制内容包括网站、简报、输出目录、当前画面和视频设置、稳定的连接入口、精确语法的查询方式，以及完整的 [内置 Showtime skill](../skills/showtime/SKILL.md)。Agent 无需查找源码，用户也不用复制 bearer token。

CLI / MCP 是可选工具，只在 **AI Director → Agent integration → Install tools** 点击后安装到 `~/Library/Application Support/Showtime/bin`。启动 App、进入页面和复制指令都不会安装工具或运行 Python。安装后检查现有 Python 3.10+，缺少时提供 **Download Python** 官方链接和 **Check Python** 入口。普通网页、手动录制和观看 Theater 不需要 Python。

```sh
export PATH="$HOME/Library/Application Support/Showtime/bin:$PATH"
showtime status
showtime guide
showtime schema caption
showtime schema camera
showtime mcp-config
```

PATH 只影响当前终端，不修改 shell 配置。MCP 配置通过 `/bin/sh` 展开 HOME，工具入口可在 GUI 的最小 PATH 中寻找现有 Python，并跳过系统安装占位程序。工具不依赖 App 位置，移动或重命名 App 后仍可连接。更新 App 后若出现 **Update available**，点击 **Update tools** 更新；不会静默升级，也不会在签名包内生成字节码。

有 MCP 的 Agent 先调用 `showtime_help`；`topic: "workflow"` 返回 skill，`topic: "script"` 返回剧本 schema，动作名如 `"camera"` 返回该动作的 schema。CLI 和 MCP 使用同一份语法定义。「Watch an example」明确加载并排练内置 Orbit。

## 设计：单个动作与截图

使用 CLI `showtime design` 或 MCP `showtime_design`。设计动作不会开启录制。字幕会保留供截图，直到清除或开始播放；相同字幕在剧本中按 `duration` 计时且不阻塞后续动作。

```sh
showtime design '{"action":"open","url":"showtime://demo"}'
showtime inspect
showtime design '{"action":"caption","text":"Hello","style":"title","position":"center","duration":3}' --screenshot /tmp/design-new.png
showtime design '{"action":"camera","scale":0.8,"offsetX":60,"flipX":true,"duration":0.6}'
showtime design '{"action":"caption","text":""}'
```

`design @action.json` 读取动作文件。传给 design 的动作对象可以原样放进剧本的 `setup` 或 `steps`。先 inspect 获取真实选择器；更改 Canvas、Frame、Content width 或 inset 后重新 inspect。

| 动作 | 用途 |
| --- | --- |
| `open`、`metadata` | 打开网页、设置成片中的标题和地址 |
| `move`、`click`、`doubleClick`、`drag` | 原生鼠标移动、点击、双击、拖动 |
| `scroll`、`type`、`key` | 原生滚轮、文字输入、键盘操作 |
| `camera` | 放大／缩小、平移、旋转、水平／垂直镜像 |
| `zoom` | 旧剧本的缩放简写；新剧本可统一使用 camera |
| `caption`、`cursor` | 字幕（含副标题、眉题）和鼠标外观 |
| `wait`、`waitFor` | 按秒停留，或等待可见元素／JavaScript 条件 |
| `assert`、`evaluate` | 检查实际网页结果、返回 JavaScript 的 JSON 值 |
| `screenshot`、`marker` | 保存合成 PNG、为场景命名 |
| `parallel` | 同时执行独立的镜头、鼠标、文字和等待 |

`camera.scale` 为 0.25–4；`offsetX/offsetY` 是 CSS 像素（各限 ±8192），`rotation` 为顺时针角度（−360–360），`flipX/flipY` 为布尔值。`selector` 或 `x/y` 设置支点。未指定的字段保持原值，数值在 duration 内过渡，镜像立即切换。恢复原样时显式设置 scale 为 1、偏移与旋转为 0、镜像为 false。

Canvas 中的 Camera 触控板写入同一组偏移，右／下为正。把 `scale`、`offsetX`、`offsetY` 放在同一个动作中即可同步动画，例如 `{"action":"camera","scale":1.5,"offsetX":90,"offsetY":-40,"duration":1.2}`。Backdrop 的 Silver 灰色、五种淡糖果色及可调中心柔光也可写入剧本 `canvas`，完整参数见 [背景与 Camera](studio.md#背景柔光与-camera)。

镜头只变换网页内容，设备外壳与字幕固定。动作目标始终是变换前的网页 CSS 坐标，左上角为原点；人的鼠标点击会反向映射。Frame 改变比例和外观，不模拟 iOS。原生输入会真实操作网站。

## 剧本：准备与播放

导航和准备放在 `setup`，每次选段都会执行，且不进入录像。`steps` 放需要拍摄的完整动作和等待。用非数字、唯一的 `id` 标记入口，`label` 说明动作目的，`marker` 为场景命名。

```json
{
  "version": 1,
  "name": "Orbit first impression",
  "setup": [
    {"action":"open","url":"showtime://demo"},
    {"action":"waitFor","selector":"#new-project"},
    {"action":"cursor","style":"hand","size":32}
  ],
  "steps": [
    {"id":"intro","action":"caption","text":"A clearer way to work.","duration":3},
    {"action":"wait","duration":3},
    {"id":"feature","action":"parallel","steps":[
      {"action":"camera","selector":"#new-project","scale":1.4,"duration":0.8},
      {"action":"move","selector":"#new-project","duration":0.8}
    ]},
    {"action":"wait","duration":1},
    {"id":"closing","action":"camera","scale":1,"duration":0.8}
  ]
}
```

保存为 `film.json`。省略 canvas 时继承当前画布；record 省略 recording 时继承当前导出设置并匹配画布比例。显式 recording 对象使用自身配置（缺省 1920 × 1080、30 fps），需与 Canvas 同比例且尺寸为偶数。rehearse 忽略 recording，不生成 MP4。字幕不阻塞步骤，需用 wait 安排停留时间。

```sh
showtime validate film.json
showtime rehearse film.json --screenshot /tmp/rehearsal-new.png
showtime rehearse film.json --from feature --to closing
showtime validate film.json --mode record --output /tmp/product-new.mp4
showtime record film.json --output /tmp/product-new.mp4 --no-wait
showtime job JOB_ID
showtime wait JOB_ID
```

CLI 默认等待完成，`--no-wait` 返回任务 ID。MCP `showtime_rehearse` / `showtime_record` 默认立即返回任务 ID，`wait: true` 等待；参数中必须且只能提供 `path` 或内联 `script` 之一。`showtime_validate` 接受同样的剧本来源，默认 `mode: "rehearse"`。例如把以下参数传给 showtime_rehearse，录制时改用 showtime_record 并增加 output：

```json
{"path":"/tmp/film.json","from":"feature","to":"closing","wait":false}
```

`from/to` 为从 1 开始的顶层步骤序号或 ID，两端包含；仅提供 from 时跑到结尾。它们不是视频时间码，也不能定位 setup 或 parallel 子步骤。播放前重置视觉效果，执行 setup，再运行选中步骤。跳过的步骤不会补跑，网页不自动回滚。重复排练中段所需的状态应写在 setup，准备动作也会真实影响网页。

setup 和顶层 steps 总计最多 1000 个。每组 parallel 最多 8 个子动作：一个 camera/zoom、一个 move、一个 caption 和多个 wait；其他输入顺序执行。完整字段和限制以 schema 为准。

JSON 文件内的图片、截图和录像路径相对文件解析；CLI 的 `--output/--screenshot` 相对当前终端目录。MCP 内联对象相对 bridge 工作目录，建议使用绝对路径。HTTP 输出路径必须绝对或以 `~/` 开头。PNG 和 MP4 都使用新文件名，不覆盖已有文件。

validate 校验整个剧本的动作参数和选段，即使非法步骤不在选段内也拒绝执行。它不操作网页或创建输出目录。元素是否存在、条件能否成立，需要通过排练验证。

## Theater 与任务反馈

设计显示 Design preview，排练整段显示 Rehearsing，录制区分准备、Recording 和 Saving film。Theater 显示场景、当前动作、下一步与进度，长 wait 也属于同一个任务。录制按钮不再因单个设计动作反复变红。

任务返回 mode、phase、elapsed、range、setup、原脚本 step、current 动作 ID／标签／耗时、completed 和逐步 results。准备阶段为 preparing/setup，播放为 running，保存为 saving，最终为 completed/failed/cancelled。total 是选段长度，step 是原序号，选段进度应使用 completed/total。失败信息指出 setup 或原步骤及 ID，保留已完成步骤的结果。

播放期间可以查询状态、任务、inspect、截图或取消，设计动作和录制设置变更返回忙碌错误。状态查询不创建活动。`showtime_job` 接受 id、可选 wait 和 includeImage；请求了最终截图后可用 includeImage 取回图像。

`showtime stop` / `showtime_stop` 取消任务；Ctrl+C 只停止 CLI 等待，App 任务继续。取消录像仍保存可播放的部分 MP4，结果标记 partial。录像结果报告 capturedFrames、duplicatedFrames、effectiveCaptureFPS 等统计，不将编码 fps 等同于实际采集速度。

Studio 顶部 Record 仍供人手动录制当前网页。载入的剧本可用 Rehearse 排练、Storyboard 的 Record storyboard 录制。影片只包含 Canvas，不包含工具栏、设置、通知或导演状态，目前没有音轨。

新版 CLI / MCP 用 design、rehearse、record 替代旧 open/act/run 和逐次 start/stop 流程。旧 JSON version: 1 与 zoom 仍支持；旧剧本首个 open 在正式录制前准备页面。兼容 HTTP 入口保留，Agent 指引统一采用新版流程，更新工具需要点击 Update tools。

运行 `python3 scripts/test_workflow.py --output-dir artifacts/workflow-check` 验证完整流程，需空闲的测试 App、FFmpeg 和新建输出目录。测试复用内置 Orbit 发布剧本：分段排练收入图表和项目创建，再录制完整演示，输出设计截图、章节代表帧、MP4 与测试结果。镜头变换后的原生点击也使用 Orbit 的真实表单。原生窗口及 HTTP 接口见 [Studio 与窗口控制](studio.md)。
