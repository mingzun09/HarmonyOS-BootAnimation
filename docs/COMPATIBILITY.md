# 兼容性与挂载说明

本模块采用标准 systemless 模块结构：把动画放到模块的 system/... 目录，由 Root 框架或挂载元模块在开机早期覆盖真实系统路径。它不直接 remount 或写入系统分区。

## 支持矩阵

| Root / 环境 | 状态 | 前提 |
| --- | --- | --- |
| Magisk 20.4 及以上 | 支持 | 管理器安装；使用 Magisk 内置挂载。 |
| KernelSU 旧版（内置挂载） | 支持 | 使用框架原有挂载能力。 |
| KernelSU 3.3.1 | 支持 | 需要已启用的挂载元模块。 |
| KernelSU Next 3.4.2 | 支持 | 需要已启用的挂载元模块。 |
| APatch 旧版 | 支持 | 使用框架原有挂载能力。 |
| APatch 11282 | 支持 | 需要已启用的挂载元模块。 |
| APatch 11427 | 已实机验证 | 配合 Magic Mount-rs v4.1.12-962。 |
| Magic Mount-rs | 已实机验证 | 提供 system 覆盖与 post-mount 钩子。 |
| meta-overlayfs | 兼容目标 | 通过标准的模块目录和元模块指针工作。 |
| KSU late-load | 不支持本次开机 | 模块在开机动画之后才加载，安装器会拒绝。 |

## 元模块（Metamodule）是什么

新版 KernelSU 和 APatch 把“模块文件如何覆盖系统”交给独立的挂载提供者实现。提供者本身也是一个模块，但其 module.prop 包含：

~~~text
metamodule=1
~~~

并且通常由 /data/adb/metamodule 符号链接指向它。模块安装器读取该指针和 module.prop，判断是否存在“已选中的挂载提供者”。

注意：

- 指针存在只代表“已选择”，不代表本次开机挂载成功。
- metamount.sh 是可选钩子；缺少它并不等于提供者不可用，但安装器会提示确认。
- 被禁用、待删除或待更新的提供者不视为就绪。
- 本动画模块不是元模块，不会替换或升级挂载提供者。

## 安装时的检测逻辑

1. 识别 APatch、KernelSU 或 Magisk 环境。
2. 对已核查的新版 KernelSU / APatch，如果没有已就绪的元模块，停止安装并提示先安装/启用提供者并重启。
3. 对未知旧版本，只提示“可能使用内置挂载或能力未知”，不凭内核版本码猜测。
4. 校验动画 SHA-256、desc.txt 第一行和 ZIP 完整性。
5. 把动画复制到模块内实际存在的 system 路径。
6. 对主题/OEM 单文件候选做安全绑定；失败只记录，不修改原文件。

## HyperOS 1 动画路径

模块会探测并覆盖设备上实际存在的以下候选（不是厂商固定优先级）：

~~~text
/apex/com.android.bootanimation/etc/bootanimation.zip   # 仅检测，不直接改 APEX
/system/media/bootanimation.zip
/system/media/bootanimation-dark.zip
/product/media/bootanimation.zip
/product/media/bootanimation-dark.zip
/vendor/media/bootanimation.zip
/vendor/media/bootanimation-dark.zip
/system_ext/media/bootanimation.zip
/system_ext/media/bootanimation-dark.zip
/system/media/theme/bootanimation.zip
/system/media/theme/cust_config/*/bootanimation.zip
ro.product.bootanim.file                                # 白名单内的现存路径/文件名
~~~

主题/OEM 单文件候选：

~~~text
/data/system/theme/bootanimation
/data/system/theme/bootanimation.zip
/data/system/theme/bootanimation-dark.zip
/oem/media/bootanimation.zip
~~~

这些路径来自 AOSP 加载顺序和公开 HyperOS 模块的候选清单，不代表闭源 HyperOS 在所有机型上具有相同优先级。实际读取哪个文件由厂商 bootanimation 加载器决定。

## SELinux 与命名空间

- 系统覆盖文件默认使用 system_file 标签；对已存在的系统资源，模块会读取原文件标签并仅应用到自己的独立副本。
- 主题绑定使用每个目标独立的副本，先 chcon 成功再 bind；失败则跳过，不关闭 SELinux，不添加宽泛策略。
- 模块在 post-fs-data 记录自身和 init 的 mount namespace；service 阶段只做可见性诊断。
- 脚本命名空间可见不等于 bootanimation 进程可见，更不等于实际画面已验证。

## 已实机验证的环境

- 设备：Xiaomi M2105K81AC / elish，1600x2560。
- 系统：HyperOS 1（OS1.0），Android 13 / API 33，V816.0.2.0.TKYCNXM。
- Root：APatch 11427。
- 挂载元模块：Magic Mount-rs v4.1.12-962。
- 结果：模块启用，系统动画路径覆盖 2/2，权限 0644，SELinux Enforcing，init 可见模块文件挂载；用户确认实际开机动画正常。

这只能证明该组合可用，不能外推到所有 Magisk/KSU/APatch 版本和所有 HyperOS 机型。

## 不支持的场景

- Recovery 刷入、刷 boot/logo/super 镜像。
- 修改最先出现的 bootloader/静态 Logo。
- 加密阶段的特殊动画、APEX 内部动画、OEM 私有格式。
- KSU late-load 模式下对“本次开机”生效。
- 与多个开机动画模块或竞争性挂载提供者同时使用。
