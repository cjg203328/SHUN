# 项目上下文

## 1. 项目目标
- 项目名称：瞬聊 / Sunliao
- 当前阶段：从“可联调测试版”持续优化到“可上线、可内网穿透测试”的版本
- 当前主线：不改变现有 UI 主题，按模块打磨体验、稳定性、测试和环境能力

## 2. 仓库结构
- `flutter-app`
  - Flutter 前端主工程
  - 主要结构：`lib/config`、`lib/providers`、`lib/screens`、`lib/widgets`、`lib/services`
  - 测试结构：`test/providers`、`test/services`、`test/smoke`
- `backend/server`
  - 后端服务
  - 主要结构：Nest 风格模块化组织，包含模块、应用服务、网关、测试
- `versions`
  - 版本记录、变更说明
- 根目录文档
  - `AGENTS.md`
  - `PROJECT_CONTEXT.md`
  - `CURRENT_SPRINT.md`
  - `RELEASE_CHECKLIST.md`
  - `ENVIRONMENT_SETUP.md`
  - `OPTIMIZATION_ROADMAP.md`

## 3. 已确认的产品方向
- 保持当前夜间主题和整体视觉基调
- 目标不是换风格，而是做出“更像原生精品 app”的细节质感
- 当前最重视的体验维度：
  - 首屏转化和行动指引
  - 聊天链路稳定性
  - 设置与我的信息架构
  - 失败态和权限态的可理解性
  - 小屏适配与弹层一致性

## 4. 已完成的关键优化
- 匹配页
  - 首屏 CTA、自适配、小屏可见性、失败提示和 smoke 已补强
- 聊天页
  - 输入区能力胶囊、失败态提示、发送区小屏适配、相关 smoke 已补强
- 消息页
  - 会话优先级标签、小屏列表适配、草稿/未读层级更清晰
- 我的 / 设置
  - 资料完成清单
  - 资料编辑改为统一抽屉式交互
  - 设置总览焦点卡、设备状态总览
  - 头像、背景、黑名单、手机号、密码等统一为更成品化的 bottom sheet
  - 设置页诊断卡改为动作型标签和处理状态摘要
  - 通知 / 隐身 / 振动开关增加动态状态徽标
  - 设备模式预设：在线回复 / 低干扰 / 安静观察
  - 系统通知权限缺失、通知通道未就绪等真实运行态反馈

## 5. 当前工程策略
- Flutter 主线继续走，不引入 SwiftUI 作为主 UI 栈
- 所有优化优先做成可复用的模块或状态能力，不堆一次性 UI
- 测试优先保证 smoke + provider 稳定
- 后端改动要服务于联调、穿透测试和正式上线收口

## 6. 环境与运行
- Flutter SDK 路径：`D:\flutter_windows_3.27.1-stable`
- 当前常用命令：
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test --reporter expanded`
- 重要运行备注：
  - 当前仓库里 `flutter` 命令存在已知“沙箱内假死”风险，根因是 SDK 在工作区外且会写 `bin\cache\lockfile`
  - 任何 `flutter test / analyze / build` 若长时间无输出，默认先查残留 `dart/flutter` 进程，再切到沙箱外执行
  - 详细快排见 `ENVIRONMENT_SETUP.md` 的“Flutter 命令假死快排”
- 环境分层和构建方式详见：
  - `ENVIRONMENT_SETUP.md`
  - `RELEASE_CHECKLIST.md`

## 7. 当前风险重点
- 后端正式上线能力还在持续收口，不能只看前端体验
- 演示逻辑、测试逻辑、正式逻辑必须持续隔离
- 内网穿透测试前，需要继续检查：
  - 鉴权
  - WebSocket 恢复
  - 错误日志与健康检查
  - 环境配置隔离
  - 媒体地址和推送链路

## 8. 新窗口接手建议
- 先读 `CURRENT_SPRINT.md` 了解做到哪里
- 再读当前要改模块的代码和测试
- 不要从“全局重构”开始
- 每轮结束后务必回写 `CURRENT_SPRINT.md`
