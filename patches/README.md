# patches

对上游源码的修改以 `.patch` 文件形式存放在此处，按库名分子目录。

```
patches/
├── mpv/       # libmpv 的补丁（含 moltenvk context 的 resize 事件支持等）
├── ffmpeg/    # FFmpeg 的补丁
└── ...
```

所有 `.patch` 文件是对应 LGPL 上游代码的衍生作品，License 为 LGPL-2.1-or-later。
