# Sunliao Agent Guide

## 1. Mission
- 本项目目标是把当前工程从“可联调测试版”持续收敛到“可上线、可内网穿透测试、可交付”的版本。
- 所有工作都要同时考虑产品体验、工程稳定性、测试可验证性。
- 优先做高性价比的小步优化，不做大而空的全局重构。

## 2. Non-Negotiables
- 保持当前 UI 主题和整体视觉方向，不随意换风格。
- 先理解模块边界，再开发，不盲改、不跳改。
- 每次改动必须带验证，至少说明跑了哪些命令、结果如何。
- 优先模块化推进：一次只处理一个明确问题或一个明确模块。
- 不要为了“看起来高级”引入新的 UI 技术栈；前端主线保持 Flutter。
- 不要擅自回退或覆盖用户已有修改。

## 3. Required Startup Routine
- 每个新会话开始时，先阅读：
  - `AGENTS.md`
  - `PROJECT_CONTEXT.md`
  - `CURRENT_SPRINT.md`
  - `RELEASE_CHECKLIST.md`
- 如果任务涉及环境、版本或发布，再补读：
  - `ENVIRONMENT_SETUP.md`
  - `OPTIMIZATION_ROADMAP.md`
  - `VERSIONING.md`
- 如果任务只涉及某个模块，再继续读该模块相关代码和测试，不做无关大范围探索。

## 4. Required Progress Update Routine
- 每次完成一轮有实际代码变更的开发后，必须更新 `CURRENT_SPRINT.md`。
- 更新内容至少包括：
  - 本轮完成了什么
  - 改动涉及哪些模块
  - 跑了哪些验证
  - 当前下一步建议做什么
- 如果本轮发现了风险、阻塞或  环境问题，也要记录到 `CURRENT_SPRINT.md`。
- 如果没有代码变更，只做了排查，也要在 `CURRENT_SPRINT.md` 的“最近动态”里补一句结论。

## 5. Product Direction
- 目标产品气质：克制、成熟、偏原生精品感。
- 优先提升：
  - 信息层级
  - 状态可理解性
  - 异常和失败反馈
  - 小屏适配
  - 一致性 
- 避免：
  - 主题漂移
  - 过度动画
  - 大量新增复杂入口
  - 没有验证支撑的“体验优化”

## 6. Engineering Direction
- 前端：Flutter 为主，保持现有 Provider / Screen / Widget / Service 结构，优先在模块内收口。
- 后端：继续按模块完善接口、状态同步、环境隔离、错误处理、联调能力。
- 数据与环境：逐步收敛到 demo / development / staging / production 分层，不让演示逻辑泄漏到正式链路。
- 测试策略：优先补 smoke test、provider test、关键服务测试，保证每轮都能稳定回归。

## 7. Current Working Style
- 当前默认开发顺序：
  1. 高频用户链路和稳定性
  2. “我的 / 设置”与聊天体验打磨
  3. 环境隔离与内网穿透准备
  4. 后端持久化与上线能力
- 当前优化原则：
  - 小步提交 
  - 快速验证
  - 文档同步
  -  不做重复返工

## 8. Handoff Rule
- 新窗口接手时，不要只依赖聊天记录。
- 先以 `CURRENT_SPRINT.md` 作为“现在做到哪一步”的单一事实来源。
- 如果聊天记录与文档冲突，以最新代码和最新文档为准，并在本轮结束时修正文档。
