# TodoDemo — iOS 未签名 IPA 构建工程

一个最小可用的 SwiftUI 待办清单 App（添加 / 勾选完成 / 删除 / 本地持久化），
用于打通「源码 → 云端编译 → 未签名 IPA」整条流水线。

## 目录结构

```
TodoDemo/
├── project.yml                    # XcodeGen 工程描述（自动生成 .xcodeproj）
├── TodoDemo/
│   ├── TodoDemoApp.swift          # App 入口
│   ├── ContentView.swift          # 主界面
│   └── TaskStore.swift            # 数据模型 + 本地存储
└── .github/workflows/
    └── build-unsigned-ipa.yml     # GitHub Actions：自动编译未签名 IPA
```

## 构建方式（任选其一）

### 方式 A：GitHub Actions 云端构建（推荐，无需 Mac）
1. 在 GitHub 新建一个仓库（Public/Private 均可），把本目录所有文件推送上去（需保留 `.github` 文件夹）。
2. 进入仓库页面 → **Actions** → 左侧 **Build Unsigned IPA** → **Run workflow**。
3. 构建完成后，在本次运行页面底部 **Artifacts** 下载 `TodoDemo-unsigned-ipa`，解压得到 `TodoDemo-unsigned.ipa`。

### 方式 B：本机 Mac 构建
1. 安装 [XcodeGen](https://github.com/yonaskolb/XcodeGen)：`brew install xcodegen`
2. 在项目根目录执行：
   ```bash
   xcodegen generate
   xcodebuild -project TodoDemo.xcodeproj -scheme TodoDemo -configuration Release \
     -sdk iphoneos -derivedDataPath build \
     CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" build
   mkdir -p Payload
   cp -R build/Build/Products/Release-iphoneos/TodoDemo.app Payload/
   ditto -c -k --sequesterRsrc --keepParent Payload TodoDemo-unsigned.ipa
   ```
   产物为 `TodoDemo-unsigned.ipa`。

## 安装到 iPhone（未签名，需要自行签名）
未签名的 IPA 不能直接安装，需用你自己的 Apple ID 签名，常用工具：

| 工具 | 特点 |
| --- | --- |
| [Sideloadly](https://sideloadly.io/)（Windows/Mac） | 免费，Apple ID 自签，7 天过期需重签 |
| [AltStore](https://altstore.io/)（Mac 配合） | 免费，可自动续签，需要电脑常开 |
| [爱思助手](https://www.i4.cn/)（Windows） | 界面化签名安装，方便中文用户 |

签名时 Bundle ID 使用 `com.example.tododemo` 即可；越狱设备可绕过签名直接安装。

## 更换成你自己的 App
- 改功能：直接编辑 `TodoDemo/` 下的 Swift 文件。
- 改名称 / 图标：修改 `project.yml` 中的 `INFOPLIST_KEY_CFBundleDisplayName`，并补充 Assets.xcassets 图标。
- 改 Bundle ID：修改 `project.yml` 中的 `PRODUCT_BUNDLE_IDENTIFIER`（签名安装时需与签名工具一致）。