# HarmonyOS 风格开机动画模块

[![Build module](https://github.com/mingzun09/HarmonyOS-BootAnimation/actions/workflows/build.yml/badge.svg)](https://github.com/mingzun09/HarmonyOS-BootAnimation/actions/workflows/build.yml)
[![GitHub release](https://img.shields.io/github/v/release/mingzun09/HarmonyOS-BootAnimation)](https://github.com/mingzun09/HarmonyOS-BootAnimation/releases)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)

一个面向 **HyperOS / MIUI / AOSP** 的系统无损（systemless）开机动画模块，兼容 **Magisk、KernelSU、KernelSU Next、APatch** 以及它们的**挂载元模块**。动画为原创绘制的 HarmonyOS 风格字标，不是华为官方资源。

![预览](docs/images/preview.gif)

![静态预览](docs/images/poster.png)

## 特性

- 黑底白色 **HarmonyOS** 字标，淡入扫光，蓝色呼吸光条，30 FPS。
- 两段式动画：2 秒入场 + 2 秒循环；系统发出结束请求时可立即退出，不会拖慢开机。
- 标准 Magisk 模块结构，同时兼容 KernelSU / APatch 的模块安装器。
- 自动适配 HyperOS 1 常见动画路径，并检测小米主题目录中的单文件动画。
- 支持 Magisk / KernelSU / APatch 的 system 覆盖与挂载元模块；安装时检查元模块就绪状态。
- 默认只写模块目录，不刷写 boot / logo / super 分区，不删除原主题文件。
- **可直接替换图片**：把图片放进 artwork/custom，构建脚本自动缩放、居中、生成规范的内层动画 ZIP。
- GitHub Actions 自动构建、校验并发布模块 ZIP。

## 兼容性

| 环境 | 支持情况 | 说明 |
| --- | --- | --- |
| Magisk 20.4+ | 支持 | 标准 systemless 覆盖，管理器安装。 |
| KernelSU 旧版 | 支持 | 使用框架原有挂载能力；找不到元模块只提示。 |
| KernelSU 3.3.1 / Next 3.4.2 | 支持 | 需要已启用的挂载元模块；安装时检查就绪状态。 |
| APatch 旧版 | 支持 | 使用原有挂载能力。 |
| APatch 11282+ | 支持 | 新版改为元模块挂载架构，需要匹配的挂载提供者。 |
| Magic Mount-rs / meta-overlayfs | 支持 | 已实机验证 Magic Mount-rs；其他实现按相同接口兼容。 |
| HyperOS 1 / Android 13 | 已实机验证 | Xiaomi M2105K81AC，APatch 11427 + Magic Mount-rs。 |
| 其他 HyperOS / MIUI / AOSP | 尽力兼容 | 路径和主题实现因机型而异，需按日志验证。 |

完整机制、版本边界和已知限制见 [兼容性说明](docs/COMPATIBILITY.md)。

> 元模块存在不等于挂载成功。模块会在早期钩子和 post-mount 钩子记录实际可见性，但最终是否播放仍取决于厂商加载器、命名空间和 SELinux。

## 安装

1. 确保手机已有可用的 Magisk、KernelSU 或 APatch。
2. 禁用其他开机动画模块，避免争抢同一路径。
3. 如果当前 Root 版本采用元模块挂载架构，先安装并启用匹配的**挂载元模块**，重启确认正常。
4. 在 Root 管理器的“模块 → 从本地安装”中选择 **模块 ZIP**。不要解压，不要用 Recovery 刷入。
5. 重启，观察 Android 动画阶段。
6. 可通过模块的“操作 / Action”按钮查看安装日志和开机日志。

> 只替换 Android 用户态动画，不会改最先出现的 MI / Redmi / POCO 静态 Logo。

## 用图片替换开机动画

这是本仓库最主要的可定制点。默认动画是代码绘制的；你也可以完全用自己的图片序列。

### 1. 准备图片

把图片放到以下目录：

~~~text
artwork/custom/intro/   # 入场段，播放一次；至少 1 张
artwork/custom/loop/    # 循环段，持续播放；可为空
~~~

- 支持 PNG、JPG/JPEG、WebP。
- 文件按名称自然排序（001、002、010……），建议三位数字前缀。
- 任意尺寸、任意宽高比；构建时会按比例缩放到画布内并居中，空白用背景色填充。
- 透明 PNG 支持，透明区域会合成到背景色。
- 循环目录为空时，自动使用入场段最后一张作为静态循环。

仓库内的 artwork/custom 已放了一套 **YOUR LOGO** 示例图，可直接替换。

### 2. 选择自定义模式

编辑 config.json：

~~~json
{
  "mode": "custom",
  "width": 720,
  "height": 256,
  "fps": 30,
  "background": "#000000"
}
~~~

或者不改配置，构建时临时指定：

~~~bash
python build.py --mode custom
~~~

### 3. 构建并安装

~~~bash
python build.py
~~~

生成的模块位于 artifacts/HarmonyOS-BootAnimation-v1.0.0.zip，同时生成 GIF/PNG 预览。

更完整的图片规范、尺寸建议和常见问题见 [自定义动画指南](docs/CUSTOMIZATION.md)。

## 从源码构建

需要 Python 3.10+：

~~~bash
python -m pip install pillow numpy
python build.py
python tests/validate.py
~~~

生成物：

~~~text
artifacts/HarmonyOS-BootAnimation-v1.0.0.zip
artifacts/HarmonyOS-BootAnimation-v1.0.0-preview.gif
artifacts/HarmonyOS-BootAnimation-v1.0.0-poster.png
~~~

build.py 会：

1. 读取 config.json 和 module/module.prop。
2. 生成或读取图片帧，统一为 RGB PNG。
3. 写入 desc.txt，并按 AOSP 规范生成 **ZIP_STORED** 的内层 bootanimation.zip。
4. 打包模块脚本、动画、README 和许可证为外层模块 ZIP。
5. 生成预览 GIF/PNG 和 SHA-256。

## 项目结构

~~~text
.
├── .github/workflows/build.yml   # CI：构建、校验、标签发布
├── artwork/custom/               # 可替换的图片序列
│   ├── intro/                    # 入场帧
│   └── loop/                     # 循环帧
├── config.json                   # 画布、FPS、生成/自定义模式
├── build.py                      # 动画生成与模块打包
├── module/                       # 模块模板（脚本、module.prop、META-INF）
├── tests/validate.py             # 离线结构与动画校验
├── docs/                         # 兼容性、定制、借鉴声明
├── README.md
└── LICENSE                       # GPL-3.0
~~~

## 工作原理

- 动画层：按 AOSP desc.txt 规范生成 part0（一次）和 part1（循环），所有帧为同尺寸 RGB PNG，内层 ZIP 使用 STORE。
- 安装层：安装时探测设备实际存在的动画路径，把动画复制到模块的 system/... 对应位置，由 Root 框架或元模块统一覆盖。
- 主题层：对 /data/system/theme/bootanimation* 等已存在的普通文件，使用独立副本和原文件 SELinux 标签做单文件 bind；不创建、不删除、不覆写原文件。
- 早期钩子：post-fs-data.sh 不 sleep、不等待启动完成属性；现代框架的 post-mount.sh 再尝试一次。service.sh 只做一次诊断性补查。
- 卸载：只卸载确认属于本模块的挂载；系统覆盖随重启消失。

## 日志与排查

~~~bash
su -c 'cat /data/adb/modules/harmonyos_bootanimation/install.log'
su -c 'cat /data/adb/modules/harmonyos_bootanimation/boot.log'
~~~

- 仍看到静态 MI/Redmi/POCO Logo：不在本模块范围。
- 日志出现 system paths visible: 0/...：检查挂载元模块、模块冲突或 late-load。
- bind failed / chcon failed：保留日志，不要关闭 SELinux。
- 命令命名空间可见不等于 bootanimation 进程可见，也不等于实际画面已验证。

## 借鉴与声明

本项目在模块格式、动画规范和 HyperOS 路径适配上参考了以下公开项目与文档。**模块脚本和动画绘制为独立实现，不包含上述项目的源代码或官方华为素材。**

- [Magisk](https://github.com/topjohnwu/Magisk)（GPL-3.0）：标准模块结构、安装器与 systemless 覆盖。
- [KernelSU](https://github.com/tiann/KernelSU)（GPL-3.0）：模块格式、元模块指针与 post-mount 生命周期。
- [APatch](https://github.com/bmax121/APatch)（GPL-3.0）：模块安装与元模块机制。
- [meta-magic_mount-rs](https://github.com/Tools-cx-app/meta-magic_mount-rs)（GPL-3.0）：挂载元模块兼容性验证。
- [HyperOS-Boot-Animation-Module](https://github.com/disbishxb/HyperOS-Boot-Animation-Module)（GPL-3.0）：HyperOS 候选动画路径与 ro.product.bootanim.file 的参考；未复制其代码或清理策略。
- [AOSP BootAnimation](https://android.googlesource.com/platform/frameworks/base/+/android-13.0.0_r1/cmds/bootanimation/)（Apache-2.0）：ZIP、desc.txt、帧尺寸和退出行为。
- Android 文档与 Linux mount namespace 手册：命名空间与挂载语义。

完整的借鉴范围、商标和素材声明见 [ATTRIBUTION.md](docs/ATTRIBUTION.md)。

HarmonyOS 是华为的商标。本项目不是华为官方项目，不包含华为官方开机动画、字体或 Logo 资源。示例图使用本机字体渲染，仓库不附带字体文件。

## 已知限制

- 不同 HyperOS/MIUI 机型的动画查找顺序可能不同；本项目覆盖常见候选，但不声称闭源 ROM 有统一优先级。
- 特殊 APEX 内动画、加密阶段动画、OEM 私有格式、未知主题路径可能无法覆盖。
- 主题服务重建文件可能使临时 bind 失效；启用期间不要另行切换开机动画主题。
- 不是所有 Root 版本/机型都经过实机验证；请在安装前确认自己的救援方式。

## 许可证

[GNU General Public License v3.0](LICENSE)。与 Magisk、KernelSU、APatch 及相关参考项目保持一致。

## English overview

A systemless HarmonyOS-style boot animation module for HyperOS/MIUI/AOSP, compatible with Magisk, KernelSU, KernelSU Next and APatch, including mounting metamodules. The animation is original artwork, not an official Huawei asset. Replace images in artwork/custom/intro and artwork/custom/loop, set mode to custom in config.json, then run python build.py. Licensed under GPL-3.0.
