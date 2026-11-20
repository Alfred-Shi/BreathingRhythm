# 节律呼吸（BreathingRhythm）

一款基于 Flutter 的呼吸引导与助眠应用，通过可视化呼吸圆环动画、节拍语音提示与柔和背景音，帮助你放松身心、缓解焦虑并改善入睡体验。

---

## 功能特性

* **预设呼吸模式**：
  * **4-7-8（经典助眠）**：吸气 4 拍 → 屏息 7 拍 → 呼气 8 拍
  * **4-4-4（平衡呼吸）**：吸气 4 拍 → 屏息 4 拍 → 呼气 4 拍
  * **5-2-5（快速减压）**：吸气 5 拍 → 屏息 2 拍 → 呼气 5 拍
* **高度自定义节律**：
  * 吸气 `1 ~ 12` 拍、屏息 `0 ~ 12` 拍（设为 0 拍自动跳过屏息）、呼气 `1 ~ 12` 拍
  * 每拍时长支持 `0.5 ~ 2.0` 秒调节（步进 0.1 秒）
  * 支持**无限循环**或自定义 `1 ~ 999` 轮（支持滑块调节与点击数字弹窗精确输入）
  * 实时换算每轮用时与预计总用时，并自动保存配置到本地
* **沉浸式动画与主题**：
  * 呼吸圆环平滑缩放（`0.65x ~ 1.30x`），实时显示当前阶段、拍号、轮次与已用时长
  * 启停触感震动反馈，支持浅色 / 深色模式自动跟随系统
* **双层音频与后台保活**：
  * 背景音层与人声提示音层独立叠加，使用 `audio_session` 统一管理焦点与外部打断恢复
  * **Android**：通过 `mediaPlayback` 前台服务 + CPU 部分唤醒锁（`WAKE_LOCK`）保证切后台、息屏后计时与语音持续运行
  * **iOS**：配置 `UIBackgroundModes (audio)` 支持后台音频持续播放

---

## 音频资源配置说明（重要）

> **版权保护声明**：本项目所使用的背景音乐与人声引导提示音均受版权保护，**未包含在 Git 仓库中**（已在 `.gitignore` 中配置忽略）。克隆或下载本项目源码后，需自行准备音频文件并按以下命名规则放入指定目录，否则运行时会提示“音频资源加载失败”。

### 1. 存放目录

请将音频文件放置在项目根目录下的：

```text
assets/audio/
```

### 2. 文件命名与用途清单

程序在 [lib/services/audio_service.dart](lib/services/audio_service.dart) 中按固定路径预加载以下 **5 个 `.wav` 格式文件**，文件名与扩展名必须完全一致（区分大小写）：

| 文件名 | 用途 | 播放逻辑说明 |
| :--- | :--- | :--- |
| `opening_music.wav` | 开场背景音乐 | 点击开始呼吸后播放一次，在播放结束前约 1 秒无缝过渡到环境音 |
| `ambient_sound.wav` | 持续背景环境音 | 接续开场音乐淡入并无限循环播放；全部轮数自然结束时淡出 1.5 秒后停止 |
| `inhale.wav` | 吸气提示音 | 每次进入吸气阶段时播放（首轮吸气延迟约 1 秒后播放，自然融入开场音乐） |
| `hold.wav` | 屏息提示音 | 每次进入屏息阶段时播放（当屏息拍数设为 0 时自动跳过） |
| `exhale.wav` | 呼气提示音 | 每次进入呼气阶段时播放 |

### 3. 放置后目录结构示例

```text
assets/
└── audio/
    ├── .gitkeep
    ├── opening_music.wav
    ├── ambient_sound.wav
    ├── inhale.wav
    ├── hold.wav
    └── exhale.wav
```

---

## 环境要求与技术栈

* **Flutter / Dart**：Dart SDK `^3.12.0`
* **核心依赖**：
  * `just_audio`（`^0.9.36`）：多路音频播放与淡入淡出控制
  * `audio_session`（`^0.1.25`）：应用级音频焦点与系统打断处理
  * `shared_preferences`（`^2.3.4`）：呼吸配置本地持久化

---

## 项目结构

```text
lib/
├── main.dart                          # 应用入口、竖屏锁定与明暗主题入口
├── controllers/
│   └── breathing_controller.dart      # 呼吸状态机与毫秒级计时控制器
├── models/
│   └── breathing_config.dart          # 呼吸阶段枚举、配置模型与预设模式
├── pages/
│   └── home_page.dart                 # 主页面，协调控制器、音频与配置存取
├── services/
│   ├── audio_service.dart             # 双层音频播放、混音及生命周期管理
│   ├── background_service.dart        # Android 后台保活原生通道封装
│   └── storage_service.dart           # SharedPreferences 本地存储封装
├── theme/
│   └── app_theme.dart                 # 浅色/深色主题与样式扩展
└── widgets/
    ├── breathing_circle.dart          # 呼吸动画圆环与状态文本组件
    ├── mode_selector.dart             # 预设模式横向选择栏
    └── rhythm_settings_card.dart      # 自定义节律参数设置卡片与轮数弹窗
android/                               # Android 原生工程及前台保活服务
ios/                                   # iOS 原生工程及后台音频模式配置
web/                                   # Flutter Web 入口配置
test/                                  # 单元测试与 Widget 测试
```

---

## 快速开始

### 1. 安装依赖

确保已完成上方「音频资源配置」，然后在项目根目录执行：

```powershell
flutter pub get
```

### 2. 运行调试

```powershell
# 运行在已连接的真机或模拟器上
flutter run

# 或使用 Chrome 浏览器预览调试（Web 端无 Android 后台保活服务，属正常现象）
flutter run -d chrome
```

### 3. 代码检查与测试

```powershell
flutter analyze
flutter test
```

### 4. 打包 Android APK

```powershell
# 按 CPU 架构拆包（主流安卓真机推荐安装生成的 app-arm64-v8a-release.apk）
flutter build apk --release --split-per-abi

# 或生成通用全架构单包（app-release.apk）
flutter build apk --release
```

> **签名提示**：当前 `android/app/build.gradle.kts` 中 `release` 构建默认使用调试密钥签名（`signingConfigs.getByName("debug")`），可直接用于真机安装测试；如需发布至应用商店，请自行配置正式签名证书（`.jks` 与 `key.properties`）。

---

## 隐私与权限说明

本应用为纯离线本地应用，不申请定位、相机、麦克风、通讯录及联网（`INTERNET`）权限。Android 端仅声明以下运行必需权限：

* `WAKE_LOCK` / `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MEDIA_PLAYBACK`：用于在息屏或切换至后台时维持呼吸倒计时与语音提示不中断。
* `POST_NOTIFICATIONS`：Android 13 及以上系统用于展示后台运行常驻通知（即使拒绝授权也不影响呼吸功能及后台保活）。
