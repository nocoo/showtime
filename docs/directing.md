# 用 AI Director 拍摄真实产品

Showtime 的主要操作方式是让 Agent 导演真实网页。用户在 AI Director 页面准备简报，进入 Theater 看 Agent 执行，再获取 MP4 和可复用的 JSON 剧本。

## 一次完整拍摄

在 Studio 打开目标网站，先在 Canvas 设置画面，在 Frame 选择可选设备，在 Cursor 和 Text 预览鼠标与字幕，再在 Export 确认视频尺寸和帧率。进入 AI Director，填写网站地址、要突出展示的流程，以及 30／45／60 秒的目标片长。右侧示意图展示 Agent → Showtime → 视频的关系；下方「Copy instructions for your agent」会复制包括以下内容的一整份任务：

- 用户目录中的固定 CLI / MCP 入口，自动读取 App 的本机连接信息，不依赖源码或 App 的安装路径。
- 网站、创意简报、目标片长、输出目录，以及当前 Canvas、设备 Frame、网页视口、顶栏主题、视频分辨率和帧率。
- 先检查网页、编写有场景和动作名称的剧本、排练、检查截图、正式拍摄、验证导出的步骤。

把整份任务贴给有终端或 MCP 能力的 Agent 即可。保持 Showtime 打开，在 Theater 观察。任务不会要求用户复制 Bearer token；「Connection details」还提供单独的 MCP 配置和 CLI 连接命令。

CLI / MCP 是可选工具，在 **AI Director → Agent integration** 点击 **Install tools** 后才复制到 `~/Library/Application Support/Showtime/bin`；普通启动与复制简报不会安装。页面随后检查 Python 3.10+，缺少时提供 **Download Python** 官方下载入口，安装后选择 **Check Python**。只打开网页、录制或观看 Theater 不需要 Python。已有 MCP 连接时可直接复制简报；未安装 CLI 的简报会明确提示先完成接入。

工具安装完成后，在每个新的 shell 中先运行一次：

```sh
export PATH="$HOME/Library/Application Support/Showtime/bin:$PATH"
showtime status
showtime studio --mode theater
showtime mcp-config
```

不修改 shell 配置文件，也不要求管理员权限。MCP 配置通过 `/bin/sh` 展开 `$HOME`，兼容不会自行展开环境变量的客户端。工具入口查找 PATH、Homebrew、python.org 和已安装开发工具中的 Python，并跳过可能弹出开发工具安装窗口的系统 Python 占位程序。

移动或重命名 App 无须改 Agent 的连接配置。App 升级后，页面比较随包文件与已安装工具，有变化时提示 **Update available**；用户点击 **Update tools** 后更新。工具不会在签名 App 包内写入文件或字节码。

「Watch an example」会明确加载并排练 Orbit 示例。正常打开网站、录制当前页面和创建自己的简报均不依赖 Orbit。

## Theater 中的可见状态

Agent 调用 `showtime_run` 或逐个调用 `showtime_act` 时，Theater 下方显示当前场景、动作图标、动作描述、下一步和完成进度。并行的鼠标、镜头与文字会显示为同一个编排动作。状态、图标和进度在动作边界一起更新。检查网页、等待页面响应、保存影片和出错也都有对应呈现。

为剧本步骤添加简洁的 `label`，用 `marker` 为场景命名，能让用户清楚理解每个动作的目的：

```json
{
  "version": 1,
  "name": "A useful first impression",
  "canvas": { "width": 1920, "height": 1080, "inset": 32, "backdrop": "mist", "browserTheme": "dark" },
  "recording": { "output": "/tmp/product-demo-new.mp4", "width": 1920, "height": 1080, "fps": 30 },
  "steps": [
    { "action": "open", "url": "http://localhost:3000", "label": "Open the product" },
    { "action": "marker", "text": "The first impression" },
    { "action": "cursor", "style": "hand", "size": 32 },
    { "action": "caption", "text": "A clearer way to work.", "style": "minimal", "position": "bottom", "duration": 3 },
    { "action": "wait", "duration": 3, "label": "Give the opening a moment" }
  ]
}
```

将地址替换为实际服务，输出文件必须尚不存在。Agent 应先 inspect 找到真实控件的选择器，再增加 click、type、scroll 等步骤，不应猜测元素。原生输入会真实操作网站，效果层负责镜头、光标与文字。Caption 不阻塞剧本，需要通过 wait 安排停留时间。

Studio 顶部 Record 只录当前网页。要完整执行已导入的剧本，使用 Rehearse 排练，再点 Storyboard 里的 Record storyboard，或者由 Agent 调用 `showtime_run`。

完成后界面提供影片路径和 Finder 入口。取消脚本也会尽量完成可播放的部分 MP4。影片仅包含 Canvas：原生 App 工具栏、设置面板、通知和导演状态都不会进入成片。Showtime 当前导出无音轨视频。

完整参数与窗口接口见 [Studio 与窗口控制](studio.md)。
