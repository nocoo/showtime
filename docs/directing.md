# 用 AI Director 拍摄真实产品

Showtime 的主要操作方式是让 Agent 导演真实网页。用户在 AI Director 页面准备简报，进入 Theater 看 Agent 执行，再获取 MP4 和可复用的 JSON 剧本。

## 一次完整拍摄

在 Studio 打开目标网站，先在 Canvas 设置画面，在 Cursor 和 Text 预览鼠标与字幕，再在 Export 确认视频尺寸和帧率。进入 AI Director，填写网站地址、要突出展示的流程，以及 30／45／60 秒的目标片长。右侧示意图展示 Agent → Showtime → 视频的关系；下方「Copy instructions for your agent」会复制包括以下内容的一整份任务：

- 当前机器的 CLI / MCP 入口，自动读取 App 的本机连接信息。
- 网站、创意简报、目标片长、输出目录，以及当前 Canvas、顶栏主题、视频分辨率和帧率。
- 先检查网页、编写有场景和动作名称的剧本、排练、检查截图、正式拍摄、验证导出的步骤。

把整份任务贴给有终端或 MCP 能力的 Agent 即可。保持 Showtime 打开，在 Theater 观察。任务不会要求用户复制 Bearer token；「Connection details」还提供单独的 MCP 配置和 CLI 连接命令。

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
