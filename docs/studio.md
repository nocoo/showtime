# Studio 与窗口控制

Studio 使用原生 macOS 统一工具栏与红绿灯。拖动、双击标题栏、Option + 绿灯缩放、最小化、全屏和窗口还原由 AppKit 处理；双击遵循系统的标题栏偏好设置。左侧的 Canvas、Cursor、Text 面板可隐藏，Theater 模式隐藏侧栏和分镜，为预览留出更多空间。

以下 HTTP 接口沿用现有的 loopback 地址与 Bearer 认证。使用 `scripts/showtime_client.py` 中的 `Client` 会自动读取本机连接信息，无需复制 token。

```python
from showtime_client import Client

client = Client()
client.request("POST", "/v1/studio", {"inspector": "Cursor"})
client.request("POST", "/v1/studio", {"theater": True})
client.request("POST", "/v1/studio", {"theater": False, "showInspector": True})
client.request("POST", "/v1/studio/screenshot", {"output": "/tmp/showtime-studio.png"})
```

Studio 截图包含原生标题栏、工具栏和红绿灯；`/v1/screenshot` 与 MP4 仍只输出影片画面。输出路径必须尚不存在。

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
