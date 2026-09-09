# Showtime 图标

当前图标来自 Hexly logo family 的 `showtime/2026-09-10-02` study、`finishing 03`。三个 2048 × 2048 master 按原字节保存，文件名和 SHA-256 记录在 [assets/branding.json](../assets/branding.json)。

| 文件 | 用途 |
| --- | --- |
| [logo.png](../logo.png) | 无背景、无投影的 canonical transparent master |
| [logo-readme.png](../logo-readme.png) | 浅绿色胶片底纹、圆角的 README presentation |
| [assets/app-icon-master.png](../assets/app-icon-master.png) | 无平台留白的方形图标 master |
| [ShowtimeMark.png](../Sources/Showtime/Resources/Brand/ShowtimeMark.png) | 透明 master 的 256 px 缩小版本，由 SwiftUI 工具栏实际使用 |

[scripts/make_icon.swift](../scripts/make_icon.swift) 从方形 master 生成 macOS 图标：1024 px 画布中居中放置 824 px 圆角图块，四边留白 100 px，并添加轻阴影。原画整体缩放到图块内。再生成 iconset 所需的 10 个 1× / 2× PNG，覆盖 16–1024 px，同时更新透明工具栏资源。生成过程不修改三个 master。

```sh
swift scripts/make_icon.swift .build/Showtime.iconset
scripts/build.sh release
```

构建脚本在 SwiftPM 打包前更新图片，再用系统 `iconutil` 生成 `dist/Showtime.app/Contents/Resources/Showtime.icns`。`Info.plist` 的 `CFBundleIconFile` 指向 `Showtime`，供 Dock、应用切换器、Finder 和系统 About 窗口使用。[ShowtimeApp.swift](../Sources/Showtime/App/ShowtimeApp.swift) 的 App delegate 在启动时直接读取该 ICNS 并设置 `NSApp.applicationIconImage`，使运行中的 Dock 图标同步更新。每次构建都会刷新 ICNS 和 App 目录时间，避免只替换 master 后留下旧图标。

工具栏在 [StudioView.swift](../Sources/Showtime/App/StudioView.swift) 的 `brand` 中以 `Image(nsImage: AppResources.brandMark)` 消费图片，保持原色并显示为 34 × 34 point。[AppResources.swift](../Sources/Showtime/App/AppResources.swift) 从实际 App 内的资源包直接加载 PNG，避免依赖开发机的 SwiftPM 构建路径或命名图片缓存。资源由 [Package.swift](../Package.swift) 的 `Resources/Brand` 打包到 `Showtime_Showtime.bundle/ShowtimeMark.png`。工具栏不使用带绿色背景或 macOS 留白的版本。

原生窗口截图可通过 `/v1/studio/screenshot` 获取，窗口和资源检查方法见 [studio.md](studio.md)。
