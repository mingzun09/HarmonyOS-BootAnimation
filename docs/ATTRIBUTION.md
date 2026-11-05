# 借鉴、参考与声明

本项目是独立实现的 HarmonyOS 风格开机动画模块。下面列出参考的项目、规范和边界，以便使用者了解来源与兼容性依据。

## 参考项目

### Magisk

- 作者：topjohnwu 及贡献者
- 许可证：GPL-3.0
- 用途：标准模块目录结构、module.prop、customize.sh、post-fs-data.sh、service.sh、卸载与 systemless 覆盖约定。
- 链接：https://github.com/topjohnwu/Magisk

### KernelSU

- 作者：tiann 及贡献者
- 许可证：GPL-3.0
- 用途：模块安装器行为、元模块指针 /data/adb/metamodule、metamodule=1 标记、post-mount 生命周期与模块命名空间。
- 链接：https://github.com/tiann/KernelSU

### KernelSU Next

- 许可证：GPL-3.0
- 用途：模块安装与元模块架构的兼容性目标。
- 链接：https://github.com/KernelSU-Next/KernelSU-Next

### APatch

- 作者：bmax121 及贡献者
- 许可证：GPL-3.0
- 用途：模块安装器、元模块指针、post-fs-data / post-mount / service 触发顺序。
- 链接：https://github.com/bmax121/APatch

### meta-magic_mount-rs

- 许可证：GPL-3.0
- 用途：实机挂载元模块兼容性验证；本项目不捆绑其二进制或源码。
- 链接：https://github.com/Tools-cx-app/meta-magic_mount-rs

### HyperOS-Boot-Animation-Module

- 许可证：GPL-3.0
- 用途：HyperOS 候选动画路径、ro.product.bootanim.file 和主题目录候选的交叉参考。
- 边界：未复制其代码、清理策略或刷写逻辑；本项目不删除主题、不使用 chattr、不关闭 SELinux。
- 链接：https://github.com/disbishxb/HyperOS-Boot-Animation-Module

### AOSP BootAnimation

- 许可证：Apache-2.0
- 用途：bootanimation.zip 的 desc.txt 格式、ZIP_STORED 要求、帧尺寸、退出行为、查找顺序等事实依据。
- 链接：https://android.googlesource.com/platform/frameworks/base/+/android-13.0.0_r1/cmds/bootanimation/

### Android / Linux 文档

- Android 模块与启动文档、Linux mount namespace 手册：用于理解早期挂载、命名空间和 SELinux 标签行为。

## 代码与素材边界

- 本项目的 Shell 安装脚本、动画绘制代码和构建脚本为独立实现。
- 未包含 Magisk、KernelSU、APatch、Magic Mount-rs 或 HyperOS 参考模块的源代码。
- 未包含华为官方开机动画、官方字体、官方 Logo 或任何提取的固件资源。
- 默认动画由代码使用本机无衬线字体渲染；仓库不附带或再分发字体文件。
- artwork/custom 中的示例图是占位图，使用本机字体渲染，可自由替换。
- HarmonyOS 是华为的商标。本项目不是华为官方项目，也未获得华为背书。

## 许可证选择

Magisk、KernelSU、APatch、Magic Mount-rs 和本项目的参考模块均使用 GPL-3.0。为保持一致并满足衍生生态的互惠要求，本项目采用 **GNU General Public License v3.0**。

如果你把本项目代码或动画整合到其他项目中，请遵守 GPL-3.0 的源代码提供和许可证保留要求。
