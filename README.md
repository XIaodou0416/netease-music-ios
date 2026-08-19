# Beans — 网易云音乐播放器（iOS / 未签名 IPA）

Beans 是一款面向网易云账号的音乐播放器：扫码登录 → 拉取你的收藏与歌单 → 以 iOS 26 原生液态玻璃风格播放。
深色暖调咖啡色系（#131110 / #F6F0E6 / #9C948A / #E8A33D）。

## 功能
- 网易云 App 扫码登录（weapi 加密协议，Swift 原生实现）
- 我的收藏（我喜欢的音乐）+ 全部歌单
- 在线播放（AVPlayer + 锁屏控制 + 后台播放）
- 液态玻璃 UI（GlassEffectContainer / .glassEffect）

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