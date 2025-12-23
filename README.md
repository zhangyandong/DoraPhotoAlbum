# DoraPhotoAlbum

一个 iOS 照片/视频幻灯片播放应用（Swift + UIKit），支持本地相册与 WebDAV 资源浏览播放，并提供时钟/音乐/缓存/播放/计划任务等设置能力。

## 功能概览

- **幻灯片播放**：图片轮播、转场与播放控制（暂停/继续/切换等）
- **本地相册**：从系统照片库选择/读取媒体资源
- **WebDAV**：浏览 WebDAV 目录与媒体文件（适合 NAS/自建盘）
- **缓存**：图片缓存与缓存策略设置，提升播放流畅度
- **Ken Burns 动效**：图片平移缩放效果（Ken Burns）
- **音乐与视频**：背景音乐播放、视频播放管理
- **时钟叠加层**：模拟时钟/时钟覆盖显示与相关设置
- **定时/计划任务**：通过调度服务按计划触发相关行为（如播放/刷新等）

## 环境要求

- **macOS**：推荐最新稳定版 Xcode 所需系统版本
- **Xcode**：建议 Xcode 15+（项目为 Swift + UIKit）
- **iOS 部署版本**：以 `DoraPhotoAlbum/Info.plist` 与 Xcode Target 设置为准

## 运行方式

1. 打开项目：
   - 直接打开 `DoraPhotoAlbum.xcodeproj`
2. 选择一个模拟器或真机
3. `Product` → `Run`（或快捷键 `⌘R`）

> 如首次运行需要权限：应用可能会请求 **照片库访问权限**（本地相册）以及 **网络访问**（WebDAV）。

## 配置说明（常见）

- **WebDAV**：在应用内的 WebDAV 设置页配置服务器地址、账号等
- **缓存**：在缓存设置页可调整缓存策略/清理缓存
- **音乐/播放/时钟/计划任务**：均在设置页中进行配置

## 目录结构

```text
DoraPhotoAlbum/
├─ DoraPhotoAlbum/                 # App 源码与资源
│  ├─ AppDelegate.swift
│  ├─ Assets.xcassets/             # 图标与资源
│  ├─ Sources/
│  │  ├─ Constants.swift
│  │  ├─ Controllers/              # 主要页面与设置页控制器
│  │  ├─ Extensions/               # 常用扩展
│  │  ├─ Models/                   # 数据模型
│  │  ├─ Services/                 # 缓存/播放/WebDAV/调度等服务
│  │  └─ Views/                    # 自定义视图（时钟/仪表盘/控件等）
│  └─ Base.lproj/                  # 启动屏等本地化资源
├─ DoraPhotoAlbum.xcodeproj/       # Xcode 工程文件
├─ DoraPhotoAlbumTests/            # 单元测试
├─ DoraPhotoAlbumUITests/          # UI 测试
└─ Tools/                          # 工具脚本与图标素材
```

## 常见问题（Troubleshooting）

- **照片无法读取/为空**
  - 检查系统设置中是否已授予照片访问权限
  - 真机与模拟器的照片库内容不同，模拟器可能为空
- **WebDAV 无法连接**
  - 确认服务器地址/端口/路径正确
  - 检查同一网络/内网访问、证书（HTTPS）与账号权限
- **播放卡顿**
  - 尝试开启/调整缓存策略或降低资源分辨率
  - WebDAV 场景下建议在更稳定的网络环境中使用

## 许可协议

如需添加开源协议（MIT/Apache-2.0 等），请告诉我你希望使用的协议类型，我可以补充 `LICENSE` 文件与 README 对应说明。


