# 瞬

## 项目定位

瞬是一个基于 Flutter 的即时社交应用，当前仓库主线为：

- `flutter-app/`：客户端源码
- `backend/server/`：NestJS 后端
- `versions/`：版本文档唯一归档目录

根目录不再存放零散版本报告。后续所有版本迭代统一收敛到 `versions/vX.Y.Z/`。

## 当前状态

- 当前代码版本：`1.0.4+5`
- 当前主要开发方向：聊天链路稳定性、环境隔离、数据持久化、UI 收口
- 当前版本文档入口：`versions/v1.0.4/README.md`

## 常用入口

- 环境配置：`ENVIRONMENT_SETUP.md`
- 优化路线：`OPTIMIZATION_ROADMAP.md`
- 发布检查：`RELEASE_CHECKLIST.md`
- 版本索引：`versions/版本索引.md`
- 版本规范：`VERSIONING.md`
- 区域测试部署：`区域测试部署说明.md`
- 交付缺口：`交付缺失清单.md`

## 开发运行

客户端：

```bash
cd flutter-app
flutter pub get
flutter run --dart-define=SUNLIAO_API_BASE_URL=http://10.0.2.2:3000/api/v1
```

后端：

```bash
cd backend/server
npm install
npm run start:dev
```

## 构建说明

- Android 模拟器默认接口：`http://10.0.2.2:3000/api/v1`
- 桌面或 iOS 模拟器默认接口：`http://127.0.0.1:3000/api/v1`
- 真机联调请改成本机局域网 IP
- 打包脚本：`build.bat`
- 区域测试打包：`build-test-apk.bat`

正式发布前仍需补齐：

- 正式推送 SDK
- 正式环境发布配置
- 监控与日志上报
- 正式签名与 AAB 流程

## 版本迭代规则

每次版本迭代都按版本号推进，不再新增散落的根目录 Markdown：

1. 修改代码。
2. 更新版本号。
3. 在 `versions/vX.Y.Z/` 中维护版本文档。
4. 更新 `versions/CHANGELOG.md` 和 `versions/版本索引.md`。
5. 本地验证后由你手动 `git push`。

详细规范见 `VERSIONING.md`。
## 接手开发先读

新窗口或新对话接手本项目时，请先阅读：

- `AGENTS.md`
- `PROJECT_CONTEXT.md`
- `CURRENT_SPRINT.md`
- `RELEASE_CHECKLIST.md`

如果涉及环境、发布或版本，再补读：

- `ENVIRONMENT_SETUP.md`
- `OPTIMIZATION_ROADMAP.md`
- `VERSIONING.md`
