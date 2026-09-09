# Showtime

原生 SwiftUI macOS 演示浏览器。用 Agent 编排真实网页的鼠标、点击、输入、镜头缩放和动态文字，导出 MP4。内置 Orbit 测试网站，支持自定义浏览器标题与地址、系统及演示光标、JSON 剧本、CLI 和 MCP。

需要 macOS 14+、Swift 6 / Xcode Command Line Tools；CLI 和 MCP 需要 Python 3.10+。

```sh
scripts/run.sh
scripts/showtime demo --output artifacts/orbit-launch.mp4
scripts/showtime mcp-config
scripts/test.sh
```

App 构建到 `dist/Showtime.app`。剧本示例在 `examples/`，完整演示在 `Sources/Showtime/Resources/Scripts/orbit-launch.json`。当前导出不包含音轨。

版本由根目录 `package.json` 统一管理，更新方法见 [版本管理](docs/versioning.md)。

MIT License.
