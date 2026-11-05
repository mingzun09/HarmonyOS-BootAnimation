# Contributing

欢迎提交 Issue 和 Pull Request。

## 报告问题

请附上：

- 手机型号、HyperOS/MIUI 版本、Android 版本。
- Root 框架及版本。
- 挂载元模块名称及版本。
- /data/adb/modules/harmonyos_bootanimation/install.log。
- /data/adb/modules/harmonyos_bootanimation/boot.log。
- 实际开机画面描述，以及是否只看到静态 Logo。

不要公开设备序列号、账号或其他私人信息。

## 修改代码

1. Fork 并创建分支。
2. 修改 build.py、module/ 或 artwork/。
3. 安装依赖并构建：

~~~bash
python -m pip install pillow numpy
python build.py
python tests/validate.py
~~~

4. 如修改动画尺寸，请同步 config.json 和文档。
5. 如修改模块脚本，保持 POSIX sh 兼容、LF 换行、无 BOM。
6. 提交 PR，说明测试设备和验证范围。

## 素材要求

- 不要提交华为官方动画、官方字体、固件提取物或未授权素材。
- 自定义图片必须是你创作或有权再分发的。
- 新增示例图请在 PR 中说明来源和许可证。

## 版本与发布

- 版本号在 module/module.prop 中维护。
- 同步更新 CHANGELOG.md。
- 推送 v* 标签会触发 GitHub Actions 构建并创建 Release。
