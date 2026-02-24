# 瞬 - 项目说明

## 📱 项目简介
瞬是一款基于Flutter开发的即时社交应用，支持随机匹配、实时聊天、亲密度系统等功能。

## 🏗️ 项目结构

```
sunliao/
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
flutter run
```

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

