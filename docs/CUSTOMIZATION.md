# 自定义开机动画图片

本仓库不要求你会写代码：替换 artwork/custom 下的图片，重新构建即可得到新的模块 ZIP。

## 目录与播放顺序

~~~text
artwork/custom/intro/   入场段：按文件名顺序播放一次
artwork/custom/loop/    循环段：按文件名顺序循环播放
~~~

- intro 至少要有 1 张图片。
- loop 可以为空；为空时使用 intro 的最后一张作为静态循环。
- 文件名建议使用 001.png、002.png、003.png。排序是自然排序，010 会排在 002 之后。
- 支持 .png、.jpg、.jpeg、.webp。
- 图片数量决定动画时长：帧数除以 FPS。
- 示例目录中已包含一套 **YOUR LOGO** 演示图，可全部删除后换成自己的图片。

## 图片尺寸与适配

构建时会把每张图按比例缩放到画布内并居中，空白区域填充背景色。不会拉伸变形，也不会裁剪。

默认画布：

~~~json
{
  "width": 720,
  "height": 256,
  "fps": 30,
  "background": "#000000"
}
~~~

建议：

- 直接提供 720x256 的图片可避免缩放。
- 宽高比与画布不同会产生上下或左右留白，这是正常现象。
- 重要内容不要贴边，给缩放和显示差异留出余量。
- 透明 PNG 会合成到 background，不会产生透明黑块。
- 想改画布尺寸，修改 config.json 的 width/height；构建脚本会同步 desc.txt 和所有 PNG。画布越大，GPU 纹理内存越高；手机开机动画建议不超过 1080x1080。
- 修改 fps 会改变播放速度；常用 24、30、60。

## 切换模式

方式一：修改 config.json：

~~~json
{
  "mode": "custom",
  "width": 720,
  "height": 256,
  "fps": 30,
  "background": "#000000",
  "custom": {
    "intro_dir": "artwork/custom/intro",
    "loop_dir": "artwork/custom/loop",
    "fit": "contain"
  }
}
~~~

方式二：不改配置，构建时覆盖：

~~~bash
python build.py --mode custom
~~~

恢复默认的代码绘制动画：

~~~bash
python build.py --mode generated
~~~

## 构建与预览

~~~bash
python -m pip install pillow numpy
python build.py --mode custom
~~~

输出：

~~~text
artifacts/HarmonyOS-BootAnimation-v1.0.0.zip
artifacts/HarmonyOS-BootAnimation-v1.0.0-preview.gif
artifacts/HarmonyOS-BootAnimation-v1.0.0-poster.png
~~~

先看预览 GIF，再把 ZIP 安装到手机。修改图片后不需要改模块脚本。

## 从视频制作帧（可选）

仓库不捆绑 ffmpeg。你可以用任意工具把视频拆成 PNG 序列，再放进 intro 或 loop。建议：

1. 先裁剪到目标宽高比。
2. 控制总帧数，避免模块过大和纹理内存过高。
3. 用 001.png 到 NNN.png 命名。
4. 构建后检查 preview.gif 与手机上实际显示是否一致。

## 版权

你替换的图片必须是你自己创作、已获授权或使用许可允许再分发的素材。不要把他人的官方开机动画、影视截图或未授权字体直接提交到本仓库。HarmonyOS 名称和相关商标属于华为。
