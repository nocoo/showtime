# macOS 签名

Showtime 的本地开发构建默认使用 `Apple Development`，开发 Team 为 `93WWLTN9XU`。Bundle ID 保持 `studio.showtime.mac`。构建脚本按证书名称查找身份，不固定证书 SHA；证书轮换时继续使用同一开发身份，避免每次 ad-hoc 重建导致 TCC 权限身份变化。

这是 nmem「macOS：App签名」的项目约定，记忆 ID 为 `cda91722-a509-4193-bede-cba529e3f302`，可用以下命令查询：

```sh
nmem memories show cda91722-a509-4193-bede-cba529e3f302
```

## 本地开发

钥匙串需要包含有效的 Apple Development 证书及对应私钥。可以通过 Xcode 配置开发 Team，或导入已有的开发签名身份。只导入公开证书不能完成签名。

```sh
security find-identity -v -p codesigning
scripts/build.sh debug
scripts/build.sh release
```

其他开发者可使用自己的 Team；存在多套证书时用完整的证书名称选择身份：

```sh
CODE_SIGN_IDENTITY='Apple Development: Your Name (…)' \
DEVELOPMENT_TEAM=YOUR_TEAM_ID scripts/build.sh release
```

脚本在开始构建前检查身份是否存在，签名后执行 `codesign --verify --deep --strict` 并核对实际 Team ID。身份缺失或 Team 不匹配会明确失败，不会静默改成 ad-hoc。

## 临时验收与 CI

无开发证书的机器可以显式选择临时签名，运行源码构建和功能检查：

```sh
CODE_SIGN_IDENTITY=- scripts/build.sh debug
```

这种构建不提供稳定的 Apple 开发签名身份，也不代表已完成公开分发签名或公证。GitHub Actions 仅做编译验证，因此显式使用该选项，不接触个人证书或私钥。

## 公开分发

`Apple Development` 用于开发及本地验收。让 GitHub 下载的 App 无需额外安全确认地打开，需要 `Developer ID Application`、Hardened Runtime、secure timestamp 与 Apple notarization，再验证 stapling、Gatekeeper 和下载后的首次启动。开发签名和 ad-hoc 的本地启动成功不能替代这项验证。

本机需要对应 Team 的 Developer ID Application 证书和私钥，以及已经保存到钥匙串的 notarytool profile。配置 Apple 公证凭据时使用交互提示，不把 app-specific password 写进命令历史或仓库：

```sh
xcrun notarytool store-credentials showtime-notary
xcrun notarytool history --keychain-profile showtime-notary
```

`showtime-notary` 是示例名称。先由账户持有人配置真实证书及 profile，然后运行：

```sh
CODE_SIGN_IDENTITY='Developer ID Application: Your Name (93WWLTN9XU)' \
DEVELOPMENT_TEAM=93WWLTN9XU SHOWTIME_ARCH=universal scripts/build.sh release
python3 scripts/package_release.py --notary-profile showtime-notary
```

构建脚本对 Developer ID 启用 Hardened Runtime 和 timestamp。打包脚本先验证版本、完整资源、通用架构与签名，再提交 Apple 公证。只有 `Accepted` 后才会 staple、运行 Gatekeeper 检查、生成 ZIP，并对 ZIP 解压后的 App 再次验签、校验票据与内置 CLI。ZIP、SHA-256 和本地验证记录保存在 `dist/release-vX.Y.Z/`。打包脚本不会提交、推送、打 tag 或创建 GitHub Release，发布步骤见根 [CLAUDE.md](../CLAUDE.md)。

缺少分发证书时，可以验证本地通用包，但名称会明确包含 `local-preview`，不能作为正式 Release 资产：

```sh
CODE_SIGN_IDENTITY=- SHOWTIME_ARCH=universal scripts/build.sh release
python3 scripts/package_release.py --local-preview
```

若用户已知签名条件并授权先发布，使用显式分支生成未公证 Release 包：

```sh
CODE_SIGN_IDENTITY=- SHOWTIME_ARCH=universal scripts/build.sh release
python3 scripts/package_release.py --unnotarized
```

此分支仍验证代码签名完整性、架构、资源、App/CLI 版本、压缩包往返与 SHA-256，并记录实际 Gatekeeper 评估；不会声称公证通过。README 和每次 Release 下载说明必须写清「未经过 Apple 公证；首次打开如被 macOS 拦截，在系统设置 → 隐私与安全 → 仍要打开确认」，并提供命令行打开方式：

```sh
xattr -dr com.apple.quarantine "/Applications/Showtime.app"
open "/Applications/Showtime.app"
```

安装路径不同时替换路径；权限不足时在 `xattr` 前加 `sudo`。这只移除当前 App 的下载隔离标记，不增加 Apple 签名或公证。不能静默把公证失败改成未公证发行。v1.2.0、v1.2.1 使用用户已确认的这一发行方式，待证书就绪后在后续版本切换 Developer ID 公证。

不要通过关闭 Gatekeeper 或删除 quarantine 属性来宣称公开下载验证通过。发布后应重新下载 GitHub 上的实际 ZIP，核对 SHA-256，解压运行，验证真实网页与 MP4 导出。macOS 最低版本为 14；通用包包含 arm64 和 x86_64，应区分编译覆盖和实际执行过的架构。

构建后可以检查实际签名，不读取或导出私钥：

```sh
codesign --display --verbose=4 dist/Showtime.app
codesign --verify --deep --strict --verbose=2 dist/Showtime.app
xcrun stapler validate dist/Showtime.app
spctl --assess --type execute --verbose=2 dist/Showtime.app
```
