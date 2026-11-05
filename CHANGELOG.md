# Changelog

## v1.0.1 - 2026-11-05

- 修复自定义图片模式下透明 PNG 的合成方式：透明区域现在显示配置的背景色，而不是黑色。
- 自定义图片支持读取 EXIF 方向。
- 版本号与自动更新清单更新到 1.0.1。

## v1.0.0 - 2026-11-05

- 首个公开版本。
- 原创 HarmonyOS 风格开机动画（720x256、30 FPS、入场 + 循环）。
- 支持 Magisk、KernelSU、KernelSU Next、APatch 和挂载元模块。
- 自动探测 HyperOS 1 常见动画路径与主题动画文件。
- 支持通过 artwork/custom/intro、artwork/custom/loop 替换图片。
- 增加 GitHub Actions 构建、校验和标签发布流程。
- 在 Xiaomi M2105K81AC / HyperOS 1 / APatch 11427 + Magic Mount-rs 上实机验证。
