# Beans — 网易云音乐播放器（iOS / 未签名 IPA）

Beans 是一款面向网易云账号的音乐播放器：扫码登录 → 拉取你的收藏与歌单 → 以 iOS 26 原生液态玻璃风格播放。
深色暖调咖啡色系（#131110 / #F6F0E6 / #9C948A / #E8A33D）。共 71 项功能，清单见 FEATURES.md。

## 功能
- 网易云 App 扫码登录（weapi / eapi 加密协议，Swift 原生实现）
- 我的收藏（我喜欢的音乐）+ 全部歌单 + 新建 / 添加歌单
- 在线播放（AVPlayer + 锁屏控制 + 控制中心 + 后台播放）
- 队列管理 / 插队播放 / 播放历史 / 听歌排行 / 睡眠定时 / 倍速
- 发现页：排行榜、每日推荐、私人 FM、推荐歌单、新歌速递、热门歌单
- 搜索 + 热搜榜 + 相似歌曲 + 在线歌词逐行跟随
- 液态玻璃 UI（GlassEffectContainer / .glassEffect）+ 深浅色跟随系统
- 播放页：下滑退出 / 静态封面 / 点封面看歌词 / 歌词点击跳转播放
- 搜索即时联想（防抖）、网易云收藏数云端同步、App Store 风格底栏、顶部渐隐、触感与按压动效

## 工程结构
```
Beans/
├── BeansApp.swift            应用入口
├── RootView.swift            4 Tab 液态玻璃底栏 + 登录门禁
├── DiscoverView.swift       发现页（排行榜 / 每日推荐 / FM / 推荐歌单 / 新歌 / 热门歌单）
├── SearchView.swift          搜索 + 热搜
├── LibraryView.swift        音乐库（收藏 / 歌单 / 最近播放 / 听歌排行）
├── PlaylistView.swift       歌单详情
├── PlayerView.swift         播放页（旋转封面 / 歌词 / 进度 / 倍速 / 睡眠定时）
├── MiniPlayerView.swift     迷你播放条
├── QueueView.swift          播放队列
├── HistoryView.swift        最近播放
├── LoginView.swift          扫码登录（QR 轮询）
├── SimiSongsSheet.swift     相似歌曲
├── SleepTimerSheet.swift    睡眠定时
├── AddToPlaylistSheet.swift 添加到歌单
├── SongCell.swift / Components.swift  列表行与玻璃组件库
├── Models.swift / NetEaseAPI.swift / NetEaseCrypto.swift / PlayerManager.swift / AuthStore.swift / Theme.swift  核心逻辑层
└── Assets.xcassets          图标资源
```

## 构建
仓库的 GitHub Actions（Build Unsigned IPA）自动在 macOS 26 云机上编译未签名 IPA：
- 触发：推送到 main 或手动 Run workflow
- 产物：Actions 页面 Artifacts 下载 `Beans-unsigned-ipa`

本地构建（需要 Mac + Xcode 26）：
```bash
brew install xcodegen
xcodegen generate
xcodebuild -project Beans.xcodeproj -scheme Beans -configuration Release \
  -sdk iphoneos -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
mkdir -p Payload
cp -R build/Build/Products/Release-iphoneos/Beans.app Payload/
ditto -c -k --sequesterRsrc --keepParent Payload Beans-unsigned.ipa
```

## 安装到 iPhone
未签名 IPA 需自行签名：Sideloadly / AltStore / 爱思助手，用你的 Apple ID 签名（免费自签 7 天有效）。
要求 iOS 26+（液态玻璃）。Bundle ID：com.beans.app

## 说明
- 接入的是网易云非官方接口，仅供个人自用，请勿上架或商用
- 部分歌曲（VIP/版权受限）可能无法播放
- 手机 QQ 传输：把压缩包从电脑 QQ「文件传输助手」发到手机 QQ，在 iPhone 上解压后用爱思助手 / AltStore 安装