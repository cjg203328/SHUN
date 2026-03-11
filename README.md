# 瞬 - 项目说明

## 小白快速入口

- 区域测试部署说明：`区域测试部署说明.md`
- 当前交付缺失清单：`交付缺失清单.md`
- 一键启动测试后端：`start-test-backend.bat`
- 一键打区域测试包：`build-test-apk.bat`

## 📱 项目简介
瞬是一款基于Flutter开发的即时社交应用，支持随机匹配、实时聊天、亲密度系统等功能。

## 🏗️ 项目结构

```
sunliao/
├── backend/                 # 后端设计与实现目录（上线服务）
│   ├── docs/                # 开发计划、API契约、错误码
│   └── db/                  # 数据库Schema与迁移脚本
│
├── flutter-app/              # Flutter项目源码
│   ├── lib/                  # 源代码
│   │   ├── config/          # 配置文件（路由、主题）
│   │   ├── models/          # 数据模型
│   │   ├── providers/       # 状态管理
│   │   ├── screens/         # 页面
│   │   ├── services/        # 服务层
│   │   ├── utils/           # 工具类
│   │   └── widgets/         # 组件
│   ├── android/             # Android配置
│   └── pubspec.yaml         # 依赖配置
│
├── versions/                # 版本文档
│   ├── v1.0.0/             # V1.0.0版本文档
│   ├── v1.0.1/             # V1.0.1版本文档
│   ├── v1.0.2/             # V1.0.2版本文档
│   ├── CHANGELOG.md        # 版本变更日志
│   └── 版本索引.md         # 版本索引
│
├── apk-output/             # APK输出目录
│   └── 瞬-v1.0.X-release.apk
│
└── build.bat               # 智能打包脚本
```

## 🚀 快速开始

### 环境要求
- Flutter SDK 3.27.1+
- Android Studio
- Dart 3.0+

### 打包APK

1. **修改版本号**
   ```batch
   # 打开 build.bat，修改第8行
   set CURRENT_VERSION=1.0.3
   ```

2. **运行打包脚本**
   ```batch
   build.bat
   ```

   如需构建 Android App Bundle（上架推荐）：
   ```batch
   build.bat aab
   ```

3. **自动完成**
   - ✅ 清理构建缓存
   - ✅ 获取依赖包
   - ✅ 构建APK
   - ✅ 复制APK到输出目录
   - ✅ 自动创建版本文档目录
   - ✅ 自动生成文档模板

4. **手动补充**
   - 📝 填写版本文档内容
   - 📝 更新CHANGELOG.md
   - 📱 测试APK功能

## 📋 版本管理

### 版本迭代流程
1. 修改源码 → `flutter-app/lib/`
2. 更新版本号 → `build.bat` 中的 `CURRENT_VERSION`
3. 运行打包 → 双击 `build.bat`
4. 自动生成 → APK + 版本文档目录
5. 手动补充 → 填写版本说明、Bug修复记录、测试报告

### 版本文档结构
每个版本目录包含：
- `README.md` - 版本概览
- `瞬-vX.X.X-版本说明.md` - 详细版本说明
- `瞬-vX.X.X-PRD.md` - 产品需求文档
- `瞬-vX.X.X-Bug修复记录.md` - Bug修复记录
- `瞬-vX.X.X-测试报告.md` - 测试报告

## 🔧 开发指南

### 运行开发环境
```bash
cd flutter-app
flutter pub get
flutter run --dart-define=SUNLIAO_API_BASE_URL=http://10.0.2.2:3000/api/v1
```

### Android 发布签名
- 复制 `flutter-app/android/key.properties.example` 为 `flutter-app/android/key.properties`
- 填入正式 keystore 的 `storeFile`、`storePassword`、`keyAlias`、`keyPassword`
- 正式上架前请关闭 debug 签名兜底：将 `build.bat` 中 `ALLOW_DEBUG_RELEASE_SIGNING` 改为 `false`
- 推荐产物为 `AAB`：`build.bat aab`

### 发布环境变量
- 本地联调可通过环境变量覆盖接口地址：
  ```batch
  set SUNLIAO_API_BASE_URL=http://10.0.2.2:3000/api/v1
  build.bat apk
  ```
- 如对象存储/CDN 已就绪，可额外注入媒体访问前缀：
  ```batch
  set SUNLIAO_MEDIA_BASE_URL=https://cdn.example.com/sunliao
  build.bat apk
  ```
- 正式环境建议在 CI 或打包机中注入 HTTPS 地址

### 启动后端服务
```bash
cd backend/server
npm install
npm run start:dev
```

### 真机/模拟器联调说明
- Android 模拟器默认可使用 `http://10.0.2.2:3000/api/v1`
- iOS 模拟器/桌面调试可使用 `http://127.0.0.1:3000/api/v1`
- 真机调试请替换为你电脑的局域网 IP，例如 `http://192.168.1.20:3000/api/v1`

### 当前前端后端接入状态
- 已接入：登录 OTP、用户资料、设置同步、好友关系、匹配配额、消息会话 REST
- 已接入：聊天 WebSocket 实时收发、会话已读同步、账号切换本地缓存隔离
- 已补齐：聊天图片真实上传、本地媒体静态访问、媒体地址映射、图片消息预览保留
- 已补齐：头像/背景图片二进制上传、本地媒体静态访问、个人页网络图兼容
- 已补齐：应用内通知中心、消息/好友申请通知沉淀、底部导航未读角标
- 已补齐：埋点事件存储、全局错误采集入口、系统推送占位同步
- 待完善：正式推送 SDK 接入、正式环境发布配置、监控平台上报

### 后端规划文档
- 开发计划：`backend/docs/development-plan.md`
- 接口契约：`backend/docs/api-contract-v1.md`
- 错误码：`backend/docs/error-codes.md`
- 数据库：`backend/db/schema_v1.sql`

### 代码结构
- `config/` - 路由配置、主题配置
- `models/` - 数据模型（User、Message、ChatThread等）
- `providers/` - 状态管理（Auth、Chat、Match、Friend）
- `screens/` - 页面组件
- `widgets/` - 可复用组件
- `services/` - 本地存储等服务
- `utils/` - 工具类（权限管理、亲密度系统等）

## 📦 当前版本

### V1.0.2（最新）
- ✅ 亲密度系统
- ✅ 取关功能
- ✅ 消息状态管理
- ✅ 位置权限优化
- ✅ 导航逻辑修复

详见：[versions/v1.0.2/README.md](./versions/v1.0.2/README.md)

## 📞 联系方式
- 项目路径：`C:\Users\chenjiageng\Desktop\sunliao`
- Flutter路径：`D:\flutter_windows_3.27.1-stable\flutter`

## 📄 许可证
内部项目

