# 在真实网页上叠加 React 动画

`overlay` 让 Agent 通过 CLI 或 MCP 把自定义 HTML／React 动画放到 Canvas 上，例如点赞、粒子、贴纸、标注和数据卡片。它使用独立的透明 WebView，覆盖整个 Canvas，位于网页和设备框架之上、Showtime 光标和字幕之下。预览、PNG 和 MP4 使用同一层内容。

图层不接收鼠标事件，文档设为 `inert`，不会因按钮、输入框、`autofocus` 或 `focus()` 抢走后面网页的输入。图层使用独立的临时浏览器会话；主网页的 Cookie、DOM 和原生输入不与它共享。图层中的 HTML、CSS、SVG 和 canvas 仍可正常绘制。

## 先运行 React 示例

仓库中的 [React 点赞示例](../examples/overlay-react/) 是一个独立的小项目，依赖只安装在该目录。App 本身不依赖 Node，也不负责编译 JSX。准备已有 HTML 和构建好的 JS 后，普通使用无需 Showtime 源码。

```sh
cd examples/overlay-react
bun install --frozen-lockfile
bun run build
showtime rehearse demo.json
showtime record demo.json --output ~/Movies/Showtime/react-overlay-new.mp4
```

开发时可将 `showtime` 换为仓库内的 `../../scripts/showtime`。保持测试 App 在前台，每次导出使用新文件名。示例会在真实 Orbit 网页上创建项目，同时播放点赞动画。

## 加载、触发、清除

```sh
showtime schema overlay
showtime design '{"action":"overlay","source":"./index.html","props":{"label":"Love this!","count":128}}'
showtime design '{"action":"overlay","props":{"label":"Project created!","count":129},"duration":3}'
showtime design '{"action":"overlay","clear":true}'
```

MCP 使用相同动作对象：`showtime_design(step: {...})`。`showtime status` 的 `overlay` 字段返回 source、ready、active、frame、props，以及发生的错误。

| 字段 | 行为 |
| --- | --- |
| `source` | 本地 HTML 路径、本地 `file://` URL 或 HTTP(S) 地址。显式指定时重新加载页面并清空旧 props。 |
| `props` | JSON 对象，完整替换旧对象；省略时保留已有值。仅更新 props 会复用已加载的页面。 |
| `duration` | 可选显示秒数；到期自动隐藏。省略表示持续运行。此动作不阻塞后续步骤。 |
| `clear: true` | 隐藏图层，不能同时指定 source、props 或 duration。随后仍可用 props 触发已加载的页面。 |
| `timeout` | 加载与等待回调注册的超时，默认 15 秒。每次帧回调和抓图各有独立的 2 秒限制。 |

每次更新从动画第 0 帧开始。`source` 在 JSON 文件中相对该文件解析，内联 CLI 动作相对当前目录；内联 MCP 动作相对 bridge 工作目录，不确定时使用绝对路径。本地 HTML 及其子目录是资源读取范围，构建后的 JS、图片和字体应放在其中。

正式拍摄时，在 `setup` 加载页面；在 `steps` 更新 props 触发动画：

```json
{
  "setup": [
    {"action":"open","url":"showtime://demo"},
    {"action":"waitFor","selector":"#new-project"},
    {"action":"overlay","source":"index.html","props":{"visible":false}}
  ],
  "steps": [
    {"action":"overlay","props":{"label":"Keep clicking","count":128},"duration":3},
    {"action":"click","selector":"#new-project"},
    {"action":"wait","duration":3},
    {"action":"overlay","clear":true}
  ]
}
```

`visible` 等 props 由自己的组件解释。setup 阶段固定在第 0 帧，排练／录制开始时启动时钟；每个新选段都会先重置图层再执行 setup。想保留显示时间应显式写 `wait`。`parallel` 可同时包含一个 overlay、一个 camera/zoom、一个 move、一个 caption 和多个 wait。一个 WebView 内可以有任意数量的 React 组件。

## 渲染回调

HTML 必须定义 `window.showtimeOverlay(context)`，并保持 `html`、`body` 和根容器的背景透明。Showtime 每次传入下列对象，并等待回调完成后抓图：

| Context | 含义 |
| --- | --- |
| `frame`、`fps`、`time` | 从本次更新开始的帧号、当前导出帧率和秒数，`time = frame / fps`。 |
| `width`、`height` | Canvas 尺寸；坐标原点为左上角，单位为 Canvas 像素。 |
| `duration` | 本次显示秒数，未设置时为 `null`。 |
| `props` | 动作传入的 JSON 对象。 |

图层固定在 Canvas 上，不跟随网页 camera 变换。它的坐标与网页选择器使用的 CSS 坐标不同。导出 4K 时按导出像素密度抓取图层，无需把组件坐标翻倍。

React 的 DOM 提交要在回调返回前完成，可使用 `flushSync`：

```jsx
import {createRoot} from 'react-dom/client';
import {flushSync} from 'react-dom';

const root = createRoot(document.getElementById('root'));
window.showtimeOverlay = context => {
  flushSync(() => root.render(<MyAnimation {...context} />));
};
```

从 `frame / fps` 计算位置、缩放、弹簧和粒子状态，可采用与 Remotion 类似的组件写法。异步准备工作可以返回 Promise；Showtime 还会等待字体和图片解码。使用打包好的资源并预加载，避免依赖定时器、系统时钟、未固定种子的随机数或无法控制进度的 CSS 动画。WebGL／视频等异步绘图需要组件自行保证该帧已就绪。

这里仍然是实时网页录制：页面抓图和渲染耗时较长时会跳过动画帧、复制整帧补足视频时间轴。检查结果中的 `capturedFrames`、`duplicatedFrames` 和 `effectiveCaptureFPS`，并观看实际 MP4；编码 30 fps 不代表逐帧离线渲染。如果交付要求每一帧独立计算，可继续用离线渲染器制作片段。

## 开发验收

先构建 React 示例，再对空闲、前台的 Showtime 执行：

```sh
python3 scripts/test_overlay.py --output-dir artifacts/overlay-check-new
```

检查会验证 CLI／MCP、透明合成、真实窗口点击穿透、键盘焦点、时间轴、错误与取消，以及 1080p／4K 和部分 MP4 的实际像素。输出目录必须是新目录。运行时暂停手动键鼠输入，测试结束会恢复网页及画面设置。
