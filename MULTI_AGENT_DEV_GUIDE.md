# 瞬 (Sunliao) 多 Agent 协作开发指南

> 版本：v1.0 · 2026-03-18
> 适用范围：所有接手本项目的 AI Agent（Claude、Cursor 等）
> 配合阅读：`AGENTS.md` → `PROJECT_CONTEXT.md` → `CURRENT_SPRINT.md`

---

## 一、项目快照

| 项目 | 状态 |
|------|------|
| Flutter 客户端 | v1.0.4，主体功能完整，可联调 |
| NestJS 后端 | v0.1.0，Phase B，内存存储，未接 Postgres |
| PostgreSQL Schema | 已设计完成，未接入服务层 |
| 推送通知 | 仅本地权限管理，无 FCM/APNs |
| 媒体存储 | 本地文件系统，未接对象存储 |
| 认证 | OTP 硬编码 123456，Token 为 UUID，未上 JWT |

---

## 二、Agent 分工模型

本项目推荐按以下 **5 个职责域** 拆分 Agent，每个 Agent 同一时刻只负责一个域，避免跨域改动引发冲突。

```
┌─────────────────────────────────────────────────────┐
│                   Orchestrator Agent                 │
│   负责任务分解、优先级排序、各 Agent 产出物整合        │
└────────┬──────────┬──────────┬──────────┬───────────┘
         │          │          │          │
    ┌────▼───┐ ┌────▼───┐ ┌───▼────┐ ┌───▼────┐
    │Flutter │ │Backend │ │  Test  │ │  Docs  │
    │  Agent │ │ Agent  │ │ Agent  │ │ Agent  │
    └────────┘ └────────┘ └────────┘ └────────┘
```

### Orchestrator Agent
- 读取 `CURRENT_SPRINT.md` 确认当前状态
- 将大任务拆解为可并行的子任务分发给各 Agent
- 汇总各 Agent 产出，检查冲突，更新 `CURRENT_SPRINT.md`
- **不直接写业务代码**

### Flutter Agent
- 职责域：`flutter-app/lib/` 下所有 Dart 代码
- 主要文件：`screens/`、`widgets/`、`providers/`、`services/`、`models/`
- 禁止：修改 `config/theme.dart` 中的颜色常量（需 Docs Agent 审批）
- 每次改动后必须说明影响的 Widget 树路径

### Backend Agent
- 职责域：`backend/server/src/` 下所有 TypeScript 代码
- 主要文件：`modules/auth/`、`modules/match/`、`modules/chat/`、`modules/friends/`
- 禁止：修改 `schema_v1.sql`（需 Orchestrator 确认）
- 每次接口改动必须同步更新 `backend/docs/`

### Test Agent
- 职责域：`flutter-app/test/` 和 `backend/server/test/`
- 主要任务：补 smoke test、provider test、接口 integration test
- 每轮开发后自动运行现有测试套件并报告结果
- 禁止：修改被测代码，只写测试

### Docs Agent
- 职责域：根目录所有 `.md` 文件，`versions/` 目录
- 主要任务：同步 `CURRENT_SPRINT.md`，整理版本说明
- 每轮开发结束后由 Orchestrator 触发更新

---

## 三、Agent 启动 Checklist

每个 Agent 在接手任务前，必须按顺序完成以下检查：

```
[ ] 1. 阅读 AGENTS.md（理解不可跨越的红线）
[ ] 2. 阅读 CURRENT_SPRINT.md（了解当前进度和阻塞项）
[ ] 3. 阅读本文件对应的职责域说明
[ ] 4. 用 Grep/Glob 定位任务涉及的具体文件
[ ] 5. 先读代码，再提改动方案，不盲改
[ ] 6. 确认改动不会破坏现有测试
```

---

## 四、开发优先级队列

### P0 — 安全与数据完整性（阻塞上线）

| # | 任务 | 职责 Agent | 关键文件 |
|---|------|-----------|---------|
| 1 | 替换硬编码 OTP，接入 SMS 服务 | Backend Agent | `auth.service.ts` |
| 2 | Token 改为 JWT（HS256），含过期时间 | Backend Agent | `auth.service.ts` |
| 3 | Auth + Match 模块接入 PostgreSQL | Backend Agent | `*/application/*.service.ts` |
| 4 | 添加 API 限流（`@nestjs/throttler`） | Backend Agent | `app.module.ts` |

### P1 — 稳定性与持久化

| # | 任务 | 职责 Agent | 关键文件 |
|---|------|-----------|---------|
| 5 | Redis 替代内存 Session/OTP 存储 | Backend Agent | `auth.service.ts`、`match.service.ts` |
| 6 | 媒体文件迁移至对象存储（OSS/MinIO） | Backend Agent | `chat.service.ts` |
| 7 | Chat 模块接入 PostgreSQL | Backend Agent | `chat.service.ts` |
| 8 | Friends 模块接入 PostgreSQL | Backend Agent | `friends.service.ts` |

### P2 — 产品体验

| # | 任务 | 职责 Agent | 关键文件 |
|---|------|-----------|---------|
| 9 | UI 重布局（参见 `UI_REDESIGN_SPEC.md`） | Flutter Agent | `main_screen.dart`、各 Tab Widget |
| 10 | 消息Tab 搜索栏 + 置顶功能 | Flutter Agent | `messages_tab.dart` |
| 11 | 匹配Tab 历史记录入口 | Flutter Agent | `match_tab.dart` |
| 12 | 个人页 统计数据模块（匹配次数、好友数） | Flutter Agent | `profile_tab.dart` |

### P3 — 基础设施

| # | 任务 | 职责 Agent | 关键文件 |
|---|------|-----------|---------|
| 13 | FCM/APNs 推送集成 | Flutter Agent + Backend Agent | `push_notification_service.dart` |
| 14 | 真实匹配算法（基于标签/地理） | Backend Agent | `match.service.ts` |
| 15 | 补全 smoke test 覆盖所有主要流程 | Test Agent | `test/smoke/` |
| 16 | 清理备份文件和日志文件 | Docs Agent | `*.backup`、`*.log` |

---

## 五、模块边界与文件地图

### Flutter 端

```
flutter-app/lib/
├── config/
│   ├── theme.dart          ← 颜色/主题常量（谨慎修改）
│   └── app_env.dart        ← 环境开关（demo/dev/prod）
├── screens/
│   ├── main_screen.dart    ← 导航壳，TabBar 逻辑
│   ├── chat_screen.dart    ← 聊天详情页
│   └── auth/               ← 登录/OTP 流程
├── widgets/
│   ├── match_tab.dart      ← 匹配页（光球 + 快速问候）
│   ├── messages_tab.dart   ← 消息列表页
│   ├── friends_tab.dart    ← 好友页
│   └── profile_tab.dart    ← 个人资料页
├── providers/              ← 状态管理（Provider）
├── services/               ← 本地服务（上传、权限等）
├── models/                 ← 数据模型
└── core/
    ├── feedback/           ← 错误码、Toast 系统
    └── ui/                 ← UI Token（间距、圆角）
```

### Backend 端

```
backend/server/src/
├── modules/
│   ├── auth/               ← OTP、Token、用户创建
│   ├── match/              ← 每日配额、候选池、匹配逻辑
│   ├── chat/               ← WebSocket、消息存储、媒体上传
│   └── friends/            ← 好友关系、屏蔽
├── common/
│   ├── guards/             ← Auth Guard
│   └── filters/            ← 异常过滤器
└── app.module.ts           ← 全局模块注册
```

---

## 六、跨 Agent 协作协议

### 接口契约变更
1. Backend Agent 修改接口签名前，必须在 PR 描述中列出受影响的 Flutter 调用点
2. Flutter Agent 修改 Provider 签名前，必须列出受影响的 Widget
3. 双方改动必须在同一个 sprint 周期内完成，不允许半程悬空

### 冲突解决
- 同一文件不允许两个 Agent 同时修改
- 如发现冲突，由 Orchestrator 仲裁，以最新 `main` 分支代码为准
- 任何 Agent 均不得 force push

### 测试门控
- 每个 P0/P1 任务完成后，Test Agent 必须在 24h 内补充对应测试
- 未通过现有测试套件的 PR 不得合并

---

## 七、环境变量规范

| 变量名 | 作用 | 默认值 |
|--------|------|--------|
| `APP_ENV` | 运行环境 | `development` |
| `JWT_SECRET` | JWT 签名密钥 | 无（必须设置） |
| `DATABASE_URL` | PostgreSQL 连接串 | 无（P0 任务后必须） |
| `REDIS_URL` | Redis 连接串 | 无（P1 任务后必须） |
| `SMS_API_KEY` | 短信服务密钥 | 无（P0 任务后必须） |
| `OSS_BUCKET` | 对象存储 Bucket | 无（P1 任务后必须） |

Flutter 端通过 `app_env.dart` 的 `AppEnv` 枚举控制功能开关，不使用 `.env` 文件。

---

## 八、验证命令速查

```bash
# Flutter — 运行所有测试
cd flutter-app && flutter test

# Flutter — 只跑 smoke test
cd flutter-app && flutter test test/smoke/

# Flutter — 静态分析
cd flutter-app && flutter analyze

# Backend — 单元测试
cd backend/server && npm test

# Backend — 集成测试（顺序执行）
cd backend/server && npm run test:integration

# Backend — 编译检查
cd backend/server && npx tsc --noEmit
```

---

## 九、禁止事项（Red Lines）

以下操作任何 Agent 均不得执行，除非得到用户明确确认：

1. 修改 `flutter-app/lib/config/theme.dart` 中的颜色值
2. 删除或重命名 `models/models.dart` 中的任何公开字段
3. 修改