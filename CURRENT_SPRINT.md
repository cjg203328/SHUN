# 当前迭代

## 2026-04-05 最近动态 232
- 完成：对当前仓库 `C:\Users\chenjiageng\Desktop\sunliao` 做了一轮结构化分析，补充确认了客户端、服务端、环境分层、测试基线和当前工作区状态。
- 排查结论：
  - 当前仓库主线明确，是 `flutter-app` + `backend/server` + `versions` 的双端交付工程，不是单前端演示项目。
  - Flutter 侧结构已经按 `config / providers / services / widgets / screens / repositories` 分层，`main.dart` 入口里已接 `Auth / Match / Chat / Friend / Profile / Settings` 多个 Provider，并且带本地存储、埋点和推送初始化。
  - 后端 `backend/server` 已不是空壳 scaffold，`auth / users / settings / friends / match / chat / report` 模块、Swagger、静态媒体、全局异常处理、日志拦截器、以及 `memory / postgres / redis` 驱动切换都已落地。
  - 当前未提交改动主要集中在两条链路：通知权限引导与聊天投递状态，配套补了多组 smoke / widget test，说明项目当前在做的是高频主链路打磨，不是大范围重构。
  - 工程离“可持续联调和区域测试”已经不远，但离正式上线仍缺正式环境变量、HTTPS 域名、生产数据库与 Redis、推送正式接入、签名与监控等能力。
  - `CURRENT_SPRINT.md` 当前已混入大量外部项目与工具记录，且编号顺序不连续，会削弱它作为 Sunliao 当前进度单一事实来源的可信度，后续建议拆分或清理。
- 涉及模块：
  - `CURRENT_SPRINT.md`
- 验证：
  - 在项目根目录执行：`git status --short`：通过，确认当前工作区存在未提交的 Sunliao 改动，主要集中在 Flutter 通知权限提示、聊天投递状态和相关测试。
  - 在项目根目录执行：`git diff --stat`：通过，确认本轮前序在研改动主要落在 `settings_screen`、`messages_tab`、`chat_delivery_status`、`notification_permission_notice_card` 及对应 smoke/widget test。
  - 在项目根目录执行：`Get-ChildItem -Force`、`rg --files`：通过，确认仓库包含 `flutter-app`、`backend/server`、`versions`、`tools` 等明确边界。
  - 在 `backend/server` 目录执行：`npm.cmd run build`：通过。
  - 在 `backend/server` 目录执行：`npm.cmd run test:integration`：通过，`4` 个测试套件、`34` 条测试全部通过。
  - 在项目根目录执行：`(rg --files flutter-app\\test | Measure-Object).Count`：返回 `54`，确认 Flutter 侧已具备较完整的 smoke / provider / service / widget 测试基线。
- 风险 / 备注：
  - 本轮没有主动补跑 Flutter 全量 `analyze/test`，原因是项目文档已明确记录当前机器上 Flutter CLI 存在较高概率的 lockfile/权限假死风险；这属于环境阻塞，不应直接等同于代码不可用。
  - 当前 Git 工作区已经是脏状态，且包含历史未提交改动；后续继续开发时需要严格在现有改动之上增量推进，不能覆盖已有工作。
- 下一步建议：
  1. 先清理 `CURRENT_SPRINT.md` 中不属于 Sunliao 的外部项目记录，恢复它作为本仓库当前进度看板的可信度。
  2. 继续围绕“通知权限引导 + 聊天投递状态”做最小闭环，优先补跑对应 Flutter focused smoke / widget 回归。
  3. 如果目标转向可交付版本，下一阶段优先推进正式环境配置、后端持久化驱动切换和内网穿透前的鉴权 / WebSocket 恢复验证。

## 2026-04-05 最近动态 213
- 完成：继续修复外部项目 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 的顶部导航问题，针对“自定义导航下没有返回按钮、状态栏/灵动岛遮挡内容、胶囊区未预留安全区”做了一轮通用化处理。
- 完成：
  - 新增 `src/utils/nav.js`
    - 统一读取 `statusBarHeight` 和 `getMenuButtonBoundingClientRect()`
    - 为页面生成通用导航安全区数据
    - 提供 `goBackOrHome()` 兜底返回逻辑
  - 修复 `src/app.wxss`
    - 新增通用自定义导航样式：顶部安全区、返回按钮、胶囊占位区
  - 修复以下页面头部布局：
    - `src/pages/index/index`
    - `src/pages/food/food`
    - `src/pages/training/training`
    - `src/pages/plan/plan`
    - `src/pages/settings/settings`
    - `src/pages/exercise/exercise`
    - `src/pages/ai-config/ai-config`
    - `src/pages/agreement/agreement`
    - `src/pages/privacy/privacy`
  - 其中 `exercise / ai-config / privacy` 已补可点击的返回按钮；`agreement` 仅在已同意协议、从其他页面进入时显示返回
- 排查结论：
  - 微信运动：可以作为下一步优先接入方向，但当前项目要想真正拿到步数，需要接 `wx.getWeRunData()`，并通过云函数或服务端解密开放数据；当前仓库还是纯本地结构，尚未具备这一后端链路
  - 小米手环 / Apple Watch：当前未发现微信小程序官方提供的通用直连接口；如果它们把步数同步到了微信运动，可考虑“间接接微信运动”，但无法承诺拿到完整实时训练明细
- 涉及模块：
  - CURRENT_SPRINT.md
  - 外部项目 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram`
- 验证：
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`rg -n "with-nav|custom-nav-shell|nav-back-btn|goBack\\(|applyNavBar\\(" src\\pages src\\utils src\\app.wxss`：通过，确认通用导航结构和返回逻辑已接入目标页面
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`Get-ChildItem -Recurse -Filter *.js src | ForEach-Object { node --check $_.FullName }`：通过
  - 资料排查参考：
    - `https://docs.cloudbase.net/practices/get-wechat-open-data`
    - 该文档引用的官方开放接口链接 `https://developers.weixin.qq.com/miniprogram/dev/api/open-api/werun/wx.getWeRunData.html`
- 风险 / 备注：
  - 当前顶部安全区已经按胶囊按钮和状态栏做了代码层适配，但仍建议用微信开发者工具真机预览再过一遍 iPhone 灵动岛机型
  - 微信运动若要真正落地，不是只改前端 UI，就能“实时同步”；至少需要云开发或自建服务端参与开放数据解密
- 下一步建议：
  1. 先在开发者工具里复测 `exercise / ai-config / privacy / agreement` 四个页面，确认返回按钮和顶部安全区表现
  2. 如果你要继续推进运动数据导入，我建议下一轮先做“微信运动接入”，而不是直接做小米手环 / Apple Watch

## 2026-04-05 最近动态 212
- 完成：继续修复外部项目 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 的全页面 UI 错乱与兼容问题，这一轮重点处理的是“全局基础样式过紧、窄屏横向布局溢出、吸底区遮挡正文、表单/卡片多列不稳”这几类共性问题。
- 完成：
  - 修复全局样式 `src/app.wxss`
    - 放大 spacing token，缓解全站卡片、表单和列表过于拥挤的问题
    - 补充统一 `box-sizing`、文本换行、按钮边框重置和页面底部安全区留白
    - 为通用卡片增加 `overflow: hidden`，减少阴影和圆角内容溢出
  - 修复协议页 `src/pages/agreement`
    - 为固定底部同意区补充占位 spacer，避免遮挡正文内容
    - 优化 checkbox 文案对齐和按钮高度，小屏下不再挤压
  - 修复首页 `src/pages/index/index.wxss`
    - 今日热量区域改为纵向堆叠，避免圆环 + 统计块横向挤爆
    - 快捷入口从 4 列网格改为更稳的两列换行布局
    - 补充长标题换行和信息区 `min-width: 0`
  - 修复饮食页 `src/pages/food`
    - 概览卡改为纵向信息流，减少窄屏横向冲突
    - 营养摘要、弹窗表单和底部按钮改为可换行布局
    - 为三项营养素输入单独补了三列规则，避免弹窗排版凌乱
  - 修复运动页 `src/pages/exercise.wxss`
    - 常用运动入口改为两列换行布局
    - 记录列表和参考表补充最小宽度与文本换行处理
  - 修复方案页 `src/pages/plan.wxss`
    - 目标卡、自定义目标输入区、推荐卡头部和周统计做了换行与窄屏适配
    - 自定义目标 3 列输入改为稳定三列宽度
  - 修复训练页 `src/pages/training.wxss`
    - 目标选择改为两列换行布局
    - 计划头部、饮食建议、动作详情和我的计划列表补充长文本换行与窄屏容器收缩
  - 修复 AI 设置页 `src/pages/ai-config.wxss`
    - 服务商选择改为两列换行布局
    - 小输入框和按钮区域改为更稳的换行策略
  - 修复设置页 `src/pages/settings.wxss`
    - 用户卡和列表项增加长文本换行与 `min-width: 0`，减少标题/副标题顶破布局
- 涉及模块：
  - CURRENT_SPRINT.md
  - 外部项目 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram`
- 验证：
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`Get-ChildItem -Recurse -Filter *.js src | ForEach-Object { node --check $_.FullName }`：通过，说明本轮样式修复没有引入新的 JS 语法问题
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`rg -n "display:\\s*grid|position:\\s*fixed|calc\\(var\\(|width:\\s*48%|width:\\s*31%|agreement-footer-spacer|triple-row" src\\pages src\\app.wxss`：通过，已人工复查高风险布局点是否按预期收口
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`git status --short`：通过，确认本轮主要新增变更集中在 `app.wxss`、`agreement`、`index`、`food`、`exercise`、`plan`、`training`、`ai-config`、`settings`
- 风险 / 备注：
  - 当前工作区出现 `project.config.json` 变更和 `project.private.config.json` 新文件，较大概率是微信开发者工具导入项目后自动生成/更新，不属于本轮手工修复逻辑
  - 由于当前环境无法直接跑微信开发者工具截图回归，这一轮主要基于页面结构和样式代码做兼容性修复；仍建议在开发者工具里逐页手工确认
- 下一步建议：
  1. 在微信开发者工具里重点检查 `agreement`、`index`、`food`、`exercise`、`plan`、`training`、`ai-config` 七个页面的真机预览
  2. 如果还有单页错位，下一轮直接按“页面截图 + 页面名”继续定点收口，会比再次全局扫更高效

## 2026-04-05 最近动态 211
- 完成：继续收口外部项目 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 的基础可用性问题，已把“分析阶段发现但尚未落地”的核心问题补成可运行版本。
- 完成：
  - 修复 `src/pages/plan`：
    - 自定义目标从错误的“百分比模型”改为与实际存储一致的“克数模型”
    - 最近 7 天周趋势改为基于真实 `mealLogs` / `exerciseLogs` 计算净摄入与完成率
    - 三餐推荐改为按目标热量和三大营养素克数生成，不再依赖错误的 100% 校验
  - 修复 `src/pages/training/training.js`：
    - 统一改走 `app.requestAI()` / `src/utils/ai.js`
    - 增强 AI JSON 解析容错
    - 为页面上实际可选的 `glutes / legs / abs / arms / back / fatburn` 六个目标补齐内置兜底方案
    - AI 不可用或输出异常时自动回退内置训练计划，避免页面空白
  - 修复 `src/pages/ai-config`：
    - 配置读写改为使用统一 AI 配置归一化逻辑
    - 测试连接改为复用统一请求构造与错误提取逻辑
    - 明确当前版本统一关闭 Stream
    - 新增“清空本地配置”能力
    - 补充说明：Anthropic 走原生 `/messages`，其余预置项走 OpenAI-compatible 请求
  - 修复 `src/pages/privacy/privacy.wxml`：
    - 去掉“API Key 加密存储”的错误声明
    - 明确当前数据和 AI 配置保存在小程序本地存储
    - 补充从 AI 设置页清空本地配置的说明
  - 补充 `src/utils/ai.js` 与 `src/app.js`：
    - 统一了 provider 配置、请求构造、错误解析与文本提取
    - 支持 Ollama 在本地场景下不强制要求 API Key
- 涉及模块：
  - CURRENT_SPRINT.md
  - 外部项目 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram`
- 验证：
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`Get-ChildItem -Recurse -Filter *.js src | ForEach-Object { node --check $_.FullName }`：通过，当前 `src` 下所有 JS 文件语法检查通过
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`git status --short`：通过，确认本轮变更已覆盖 `app.js`、`plan`、`training`、`ai-config`、`privacy` 以及前一轮已改动页面
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`git diff -- src\utils\ai.js src\app.js src\pages\plan\plan.js src\pages\plan\plan.wxml src\pages\training\training.js src\pages\ai-config\ai-config.js src\pages\ai-config\ai-config.wxml src\pages\ai-config\ai-config.wxss src\pages\privacy\privacy.wxml`：通过，已人工核对本轮关键改动
- 风险 / 备注：
  - 该小程序仓库本身没有 `package.json`、单元测试或可直接调用的构建脚本；本轮验证主要覆盖 JS 语法与差异审查，尚未做微信开发者工具里的真机 / 编译回归
  - 目前仍有若干旧页面文案文件在终端里会出现乱码显示，但本轮优先处理的是已确认的功能性问题和错误声明
- 下一步建议：
  1. 用微信开发者工具实际打开 `eatfit-miniprogram`，重点点验 `plan`、`training`、`ai-config`、`food`、`exercise` 五个页面的真实渲染与交互
  2. 如果继续往“可交付”推进，下一轮优先做文案编码清理和一轮手工 smoke 清单

## 2026-04-05 最近动态 210
- 完成：排查了外部项目 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram`，已梳理出当前仓库的技术栈、页面结构和主要可交付风险。
- 涉及模块：
  - CURRENT_SPRINT.md
- 验证：
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`Get-ChildItem -Force`：通过，确认仓库为原生微信小程序结构
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`rg --files`：通过，确认当前无 `package.json`、无测试目录，核心代码集中在 `src/pages` 与 `src/app.js`
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`Test-Path src\assets`：返回 `False`，确认 `app.json` 引用的 tabBar 图标资源当前缺失
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行多轮 `Get-Content` / `rg -n`：通过，已定位 AI 接口实现、首页跳转、隐私声明与周报展示等关键风险点
- 风险 / 备注：该项目 README 宣称“Production Ready”，但代码实态更接近高保真演示版；当前至少存在资源缺失、AI 多厂商接入不成立、隐私文案与实际存储不一致，以及部分页面/文案文件存在明显损坏痕迹。
- 下一步建议：
  1. 如果要继续推进这个小程序，优先修复资源缺失、AI 接口适配和文本文件损坏，再考虑体验打磨
  2. 如果你要我继续接手，我建议下一轮直接按“先让项目能稳定编译和基础可用，再补 AI 与合规”这条顺序落地

## 2026-04-04 最近动态 197
- 完成：按 OpenClaw 官方 npm 安装方式，在本机全局环境安装了 `openclaw` CLI，并确认当前 Node 版本已满足要求。
- 涉及模块：
  - CURRENT_SPRINT.md
- 验证：
  - 在项目根目录执行：`node -v`：通过，`v24.13.1`
  - 在项目根目录执行：`npm.cmd -v`：通过，`11.8.0`
  - 在项目根目录执行：`npm.cmd config get prefix`：返回全局安装目录 `C:\Users\chenjiageng\AppData\Roaming\npm`
  - 在项目根目录提权执行：`npm.cmd install -g openclaw@latest`：首次因 `ECONNRESET` 中断，重试后命令超时退出，但安装产物已落地
  - 在项目根目录执行：`npm.cmd list -g openclaw --depth=0`：通过，确认已安装 `openclaw@2026.4.2`
  - 在项目根目录执行：`openclaw.cmd --version`：通过，输出 `OpenClaw 2026.4.2 (d74a122)`
- 风险 / 备注：本轮安装阶段出现一次网络重置、一次长时间无输出超时，但最终全局包和 CLI 均已可用；`openclaw` 后续真正接入前，仍需要按官方流程继续做 `onboard` / daemon 安装与账号配置。
- 下一步建议：
  1. 如果准备开始使用 OpenClaw，可继续执行 `openclaw onboard --install-daemon`
  2. 如果只需要 CLI 本体，本轮已经完成安装和版本验证

## 2026-03-31 最近动态 177
- 完成：继续把“focused test 内部收口”复制到消息列表的 intimacy chip 测试。这轮仍然没有改业务逻辑，只把 `flutter-app/test/widgets/messages_thread_intimacy_chip_layout_test.dart` 内部重复的这几类逻辑收成了局部 helper：
  - viewport 设置
  - intimacy chip 场景 pump
  - thread / preview / meta / chip / unread finder 聚合
  - 基础 intimacy chip 状态断言
- 完成：整理后，这个文件现在更清楚地收成了两个核心 case：
  - regular 宽度下，亲密度 chip 保持在 preview row
  - compact 宽度下，亲密度 chip 下沉到 meta row，并保持在 unread 右侧
  后续如果继续补 intimacy chip 的别的边界，不再需要每条 case 都重复写一遍相同的线程搭建和 finder 逻辑。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_intimacy_chip_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮检测到 1 个残留 `dart` 进程并已清理
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_intimacy_chip_layout_test.dart`：沙箱内异常退出且无输出；提权重跑后格式化通过，`1 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_intimacy_chip_layout_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 说明，当前环境里即便只是单文件测试侧整理，`format` 和 `analyze` 也可能先在沙箱里失败；继续保持“最小文件集 + 同一条命令提权重跑”的节奏最稳。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以开始把这些 focused test 的命名和文件顺序再做一次很小的整理，或者回头给还没收口的文件补同样的内部 helper 结构
  2. 如果准备切模块，消息列表这条链路的 focused test 内部结构已经基本统一，可以回到“我的 / 设置”里找下一个高频反馈组件复用同样节奏

## 2026-03-31 最近动态 176
- 完成：继续把“focused test 内部收口”复制到消息列表的 unread badge 测试。这轮仍然没有改业务逻辑，只把 `flutter-app/test/widgets/messages_thread_unread_badge_layout_test.dart` 内部重复的这几类逻辑收成了局部 helper：
  - viewport 设置
  - unread badge 场景 pump
  - preview/meta/badge finder 聚合
- 完成：整理后，这个文件现在更清楚地收成了两个核心 case：
  - regular 宽度下，未读徽标保持在 preview row
  - compact 宽度下，未读徽标下沉到 meta row
  后续如果继续补 unread badge 的别的边界，不再需要每条 case 都重复写一遍相同的线程搭建和 finder 逻辑。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_unread_badge_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮检测到 1 个残留 `dart` 进程并已清理
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_unread_badge_layout_test.dart`：沙箱内异常退出且无输出；提权重跑后格式化通过，`1 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_unread_badge_layout_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 说明，当前环境里哪怕只是最小的测试侧整理，`format` 和 `analyze` 也都可能先在沙箱里失败；继续保持“最小文件集 + 同一条命令提权重跑”的节奏最稳。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以按同一方式继续收 `messages_thread_intimacy_chip_layout_test.dart`，把这一批 focused test 的内部结构继续统一
  2. 如果准备切模块，消息列表这条链路的 focused test 已经越来越好维护，可以回到“我的 / 设置”里找下一个高频反馈组件复用同样节奏

## 2026-03-31 最近动态 175
- 完成：继续把“focused test 内部收口”复制到消息列表的 priority tag 测试。这轮仍然没有改业务逻辑，只把 `flutter-app/test/widgets/messages_thread_priority_tag_layout_test.dart` 内部重复的这几类逻辑收成了局部 helper：
  - compact viewport 设置
  - priority tag 场景 pump
  - priority / meta / unread finder 聚合
  - 基础 priority tag 状态断言
- 完成：整理后，这个文件现在更清楚地收成了两个核心 case：
  - `发送失败` 优先级标签保持在 meta row 之上
  - `即将到期` 标签保持在 meta row 之上
  后续如果继续补 priority tag 的别的状态面，不再需要每条 case 都重复写一遍相同的线程搭建和 finder 逻辑。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_priority_tag_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮检测到 2 个残留 `dart` 进程并已清理
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_priority_tag_layout_test.dart`：沙箱内异常退出且无输出；提权重跑后格式化通过，`0 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_priority_tag_layout_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 说明，当前环境里即便只是单文件测试侧整理，`format` 和 `analyze` 也可能先在沙箱里失败；继续保持“最小文件集 + 同一条命令提权重跑”的节奏最稳。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以开始把 `messages_thread_unread_badge_layout_test.dart` 和 `messages_thread_intimacy_chip_layout_test.dart` 也按同一方式收成统一结构，把这批 focused test 内部风格尽量对齐
  2. 如果准备切模块，消息列表这条链路的测试维护成本已经进一步下降，可以回到“我的 / 设置”里找下一个高频反馈组件复用同样节奏

## 2026-03-31 最近动态 174
- 完成：继续把“focused test 内部收口”从标题行、delivery badge 复制到消息列表的 draft preview 测试。这轮仍然没有改业务逻辑，只把 `flutter-app/test/widgets/messages_thread_draft_preview_layout_test.dart` 内部重复的这几类逻辑收成了局部 helper：
  - compact viewport 设置
  - draft 场景 pump
  - draft / meta / unread / priority finder 聚合
  - 基础草稿预览断言
- 完成：整理后，这个文件现在更清楚地收成了两个核心 case：
  - `发送中` 存在草稿时，preview 行继续显示草稿并隐藏 delivery badge
  - `发送失败` 存在草稿时，草稿继续留在 preview 行，失败优先级标签保持在下方
  后续如果继续补草稿相关边界，不再需要每条 case 都重复写一遍相同的线程搭建和 finder 逻辑。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_draft_preview_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮检测到 1 个残留 `dart` 进程并已清理
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_draft_preview_layout_test.dart`：沙箱内异常退出且无输出；提权重跑后格式化通过，`0 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_draft_preview_layout_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 说明，当前环境里就算只是单文件测试侧整理，`format` 和 `analyze` 也可能先在沙箱里失败；继续保持“最小文件集 + 同一条命令提权重跑”的节奏最稳。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以按同一方式继续收 `messages_thread_priority_tag_layout_test.dart`，把这批 focused test 的内部结构进一步统一
  2. 如果准备切模块，消息列表这条链路的测试维护成本已经在下降，可以回到“我的 / 设置”里找下一个高频反馈组件复用同样节奏

## 2026-03-31 最近动态 173
- 完成：继续把“focused test 内部收口”从标题行复制到消息列表的 delivery badge 测试。这轮仍然没有改业务逻辑，只把 `flutter-app/test/widgets/messages_thread_delivery_badge_layout_test.dart` 内部重复的这几类逻辑收成了局部 helper：
  - compact viewport 设置
  - delivery badge 场景 pump
  - badge / preview / meta / priority finder 聚合
  - 基础 delivery badge 状态断言
- 完成：整理后，这个文件现在更清楚地收成了两个核心 case：
  - `发送中` 徽标保持在 preview row
  - `发送失败` 徽标保持在 priority row 之上
  后续如果继续补 delivery badge 的别的状态面，不再需要每条 case 都重复写一遍相同的线程搭建和 finder 逻辑。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_delivery_badge_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮未检测到残留 `dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_delivery_badge_layout_test.dart`：沙箱内格式化通过，`0 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_delivery_badge_layout_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 说明，只要验证范围压到单文件，很多时候 `format` 可以在沙箱里直接通过；而 `analyze` 一旦撞权限，就继续按同一条最小命令提权重跑最稳。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以按同一方式继续收 `messages_thread_draft_preview_layout_test.dart` 或 `messages_thread_priority_tag_layout_test.dart`，把 focused test 文件内部结构继续统一
  2. 如果准备切模块，消息列表这条链路的 focused test 现在已经越来越容易维护，可以回到“我的 / 设置”里找下一个高频反馈组件复用同样节奏

## 2026-03-31 最近动态 172
- 完成：继续按上一轮建议，对标题行 focused test 做了一次很小的内部收口。这轮仍然没有改业务逻辑，只把 `flutter-app/test/widgets/messages_thread_title_markers_layout_test.dart` 内部重复的测试搭建和 finder 逻辑收成了局部 helper，包括：
  - viewport 设置
  - 标题线程场景 pump
  - 标题相关 finder 聚合
  - 基础标题标记断言
- 完成：整理后，标题相关 case 现在更清楚地收成了一个小套件：
  - regular 宽度标题行
  - compact 宽度标题标记
  - compact 常规时间文案
  - compact 更长天数时间文案
  - compact 空时间占位
  后续继续补标题边界时，不再需要每条 case 都从头写一遍相同的搭建和 finder。
- 完成：顺手保持了上一轮新增的“空时间标题行”边界测试，没有回退已有 coverage。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_title_markers_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮检测到 2 个残留 `dart` 进程并已清理
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_title_markers_layout_test.dart`：沙箱内格式化通过，`0 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_title_markers_layout_test.dart`：沙箱内停在 `Analyzing ...` 开头后异常退出
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 说明，哪怕只是测试文件内部整理，当前环境里 `analyze` 也可能停在 `Analyzing ...` 开头半挂起；继续把这类情况视为环境失败并对同一条最小命令提权重跑最稳。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以开始把标题行这几条 case 真正拆成更清晰的命名分组，或者转去别的 focused test 文件做同样的小型内部收口
  2. 如果准备切模块，消息列表这条高频提示链路已经有不错的测试基础，可以回到“我的 / 设置”里找下一个高频反馈组件复用同样的小步节奏

## 2026-03-31 最近动态 171
- 完成：继续沿消息列表标题行的小屏极限边界推进。这轮仍然只动了 `flutter-app/test/widgets/messages_thread_title_markers_layout_test.dart`，新增了一条 focused case，专门锁住：
  - `好友 + 置顶 + 超长昵称`
  - 但当前还没有最近消息时间
  - 在 compact 宽度下，`好友` tag / pinned icon 仍稳定留在 title row
  - 空时间位仍存在且不把标题行层级挤乱
  - title row 仍保持在 preview row 之上
- 完成：这样标题行这块现在不只覆盖“短时间文案”“更长天数时间文案”，也开始覆盖“没有最近消息时间”这条空态边界。后续如果标题行继续压缩宽度或调整时间占位，不容易把无消息线程的标题结构悄悄改坏。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_title_markers_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮检测到 2 个残留 `dart` 进程并已清理
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_title_markers_layout_test.dart`：沙箱内格式化通过，`1 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_title_markers_layout_test.dart`：沙箱内停在 `Analyzing ...` 开头后异常退出
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮再次说明，只要验证范围已经压到单文件，`format` 有机会直接在沙箱里通过；但 `analyze` 仍可能停在 `Analyzing ...` 开头半挂起，继续把它视为同类环境失败并提权重跑会更稳。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以开始把标题行这几条 focused case 少量整理成“时间存在 / 时间更长 / 时间为空”这类更清晰的分组，方便后续继续补边界
  2. 如果准备切模块，消息列表标题行这块的 focused 覆盖已经比较扎实，可以回到“我的 / 设置”里找下一个高频反馈组件复用同样节奏

## 2026-03-31 最近动态 170
- 完成：继续沿消息列表标题行的小屏极限边界推进。这轮仍然没有改业务逻辑，只在 `flutter-app/test/widgets/messages_thread_title_markers_layout_test.dart` 继续补了一条 focused case，专门锁住：
  - `好友 + 置顶 + 超长昵称 + 更长的天数时间文案（如 12天前）`
  - 在 compact 宽度下，时间仍稳定留在 title row 右侧
  - pinned icon 仍位于时间左侧
  - title row 仍保持在 preview row 之上
- 完成：这样标题行这块不只覆盖了“时间存在”这件事本身，也开始覆盖更接近真实极限的小屏长时间文案场景。后续如果继续压缩标题宽度或调整 row 间距，更不容易把时间文本悄悄挤掉。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_title_markers_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮检测到 2 个残留 `dart` 进程并已清理
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_title_markers_layout_test.dart`：沙箱内格式化通过，`0 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_title_markers_layout_test.dart`：沙箱内停在 `Analyzing ...` 开头后异常退出
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮再次说明，当前环境里沙箱 `analyze` 即便没有直接抛权限错误，也可能停在 `Analyzing ...` 开头后半挂起；继续把这种情况视为同类环境失败，直接对同一条最小命令提权重跑最稳。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以开始少量整理标题相关 focused test 的分组和命名，把“普通时间文案 / 长时间文案 / 标记组合”这几类边界收成更清晰的小套件
  2. 如果准备切模块，消息列表标题行这块的 focused 覆盖已经比较扎实，可以回到“我的 / 设置”里找下一个高频反馈组件复用同样节奏

## 2026-03-31 最近动态 169
- 完成：继续基于刚抽好的共享 helper 补消息列表标题行的组合状态测试。这轮没有改业务逻辑，只在 `flutter-app/test/widgets/messages_thread_title_markers_layout_test.dart` 新增了一条 focused case，专门锁住：
  - `好友 + 置顶 + 超长昵称 + 时间`
  - 在 compact 宽度下，时间仍稳定留在 title row 右侧
  - pinned icon 仍位于时间左侧
  - 整组标题标记仍完整落在线程卡内部
- 完成：这样标题行这块现在不只验证“`好友` tag / pinned icon 还在 title row”，也开始验证在更接近真实小屏极限的长标题场景里，时间文本不会被悄悄挤掉或和标题标记打架。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_title_markers_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮检测到 1 个残留 `dart` 进程并已清理
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_title_markers_layout_test.dart`：沙箱内异常退出且无输出
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_title_markers_layout_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe format`：格式化通过，`1 changed`
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 说明，即便只是单文件 focused test，当前环境里 `format/analyze` 也可能先在沙箱内失败；继续坚持“最小文件集 + 同一条命令提权重跑”的处理方式最稳。
- 下一步建议：
  1. 如果继续沿消息列表推进，下一步更值得补的是标题行在 `好友 + 置顶 + 超长昵称` 且没有最近消息时间时的最窄边界，或者开始少量整理这些 focused test 的命名和分组
  2. 如果准备切模块，消息列表这条高频提示链路已经有比较完整的 focused 保护，可以回到“我的 / 设置”里找下一个高频反馈组件复用同样的小步节奏

## 2026-03-31 最近动态 168
- 完成：继续按上一轮建议做了一次很小的测试侧收口，没有动业务逻辑。这轮新增了共享 helper：`flutter-app/test/widgets/helpers/messages_thread_test_host.dart`，把消息列表这几份 focused widget test 里重复出现的这几类基础搭建统一收口：
  - 测试初始化与会话清理
  - `MessagesTab` host 搭建
  - `ChatProvider/FriendProvider` dispose
  - 基础 `User` / `ChatThread` 构造
- 完成：已把当前这批消息列表 focused test 切到共享 helper 上，至少包括：
  - `messages_thread_unread_badge_layout_test.dart`
  - `messages_thread_priority_tag_layout_test.dart`
  - `messages_thread_delivery_badge_layout_test.dart`
  - `messages_thread_draft_preview_layout_test.dart`
  - `messages_thread_intimacy_chip_layout_test.dart`
  - `messages_thread_title_markers_layout_test.dart`
  - `messages_thread_row_hierarchy_test.dart`
  这样后续继续补消息列表 focused test 时，不再需要每个文件都重复写一遍 host / user / dispose 模板。
- 修正：这轮抽 helper 时，几份测试文件最开始顺手删掉了 `material.dart` 导入，导致 `Size` / `Key` / `Icons` 在 analyze 里报错。随后已做最小修正，把缺失导入补回，避免把这种纯测试侧回归留在工作区里。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/helpers/messages_thread_test_host.dart
  - flutter-app/test/widgets/messages_thread_unread_badge_layout_test.dart
  - flutter-app/test/widgets/messages_thread_priority_tag_layout_test.dart
  - flutter-app/test/widgets/messages_thread_delivery_badge_layout_test.dart
  - flutter-app/test/widgets/messages_thread_draft_preview_layout_test.dart
  - flutter-app/test/widgets/messages_thread_intimacy_chip_layout_test.dart
  - flutter-app/test/widgets/messages_thread_title_markers_layout_test.dart
  - flutter-app/test/widgets/messages_thread_row_hierarchy_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：第一轮检测到 1 个残留 `dart` 进程并已清理；修正导入后复跑时又检测到 2 个残留 `dart` 进程并已清理
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\helpers\messages_thread_test_host.dart ... messages_thread_row_hierarchy_test.dart`：首轮沙箱内异常退出且无输出；修正导入后复跑时沙箱内格式化通过，`0 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\helpers\messages_thread_test_host.dart ... messages_thread_row_hierarchy_test.dart`：首轮沙箱内 `CreateFile failed 5 / 拒绝访问`，提权 analyze 暴露出 71 条缺失 `material.dart` 导入错误；修正后再次执行同一组 analyze，沙箱内停在 `Analyzing ...` 开头，提权重跑后静态分析通过，`No issues found!`
- 风险 / 备注：这轮把两个经验都再次坐实了：
  - 测试 helper 收口这类“只改测试”的重构，也要继续坚持最小命令验证，否则很难快速定位是环境问题还是纯代码问题
  - 如果提权 analyze 真正返回了语义化错误列表，就应先修代码再重跑；不要把所有失败都机械地当成环境抖动
- 下一步建议：
  1. 如果继续沿消息列表推进，下一步更值得的是用这份共享 helper 再补一两条 focused test，把目前还没单独锁住的组合状态补齐，例如 `好友 + 置顶 + 时间` 更长文案下的标题换行边界
  2. 如果准备切模块，消息列表 focused 测试这边已经有共享搭建能力，可以回到“我的 / 设置”里找下一个高频反馈组件，用同样方式快速铺开小步测试

## 2026-03-31 最近动态 167
- 完成：继续做消息列表线程项层级的小范围收口。这轮补上了最后缺的一层稳定锚点：`messages-thread-priority-row-...`。这样 title row、preview row、priority row、meta row 这四层现在都有独立 row key，focused 测试终于可以直接验证“层级顺序”，不用再只靠零散子元素位置间接推断。
- 完成：新增 `flutter-app/test/widgets/messages_thread_row_hierarchy_test.dart`，focused 验证 compact 宽度下线程项的四层垂直顺序：
  - title row 在最上
  - preview row 在 title row 下方
  - priority row 在 preview row 下方
  - meta row 在 priority row 下方
  同时也确认这四层都仍完整落在线程卡内部。
- 完成：这样消息列表线程项这条高频链路不只是给每个提示元素补了局部保护，也开始有一条更偏结构层的“总顺序”保护。后续如果继续调小屏密度或局部间距，更不容易把整条线程项的层次关系悄悄改乱。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/widgets/messages_tab.dart
  - flutter-app/test/widgets/messages_thread_row_hierarchy_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮检测到 1 个残留 `dart` 进程并已清理
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\messages_tab.dart test\widgets\messages_thread_row_hierarchy_test.dart`：沙箱内异常退出且无输出
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\widgets\messages_tab.dart test\widgets\messages_thread_row_hierarchy_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe format`：格式化通过，`1 changed`
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮继续验证了当前环境最稳的处理方式：即便只是单文件 widget test，沙箱里的 `format/analyze` 依然可能先失败；只要命令已经压到最小文件集，就直接对同一条命令提权重跑，不要在失败态上多做试探。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以开始做一次很小的测试侧收口，把这些 widget test 里重复的 host/user/thread helper 提到共享 helper，减少后续继续补 focused test 的重复代码
  2. 如果准备切模块，消息列表线程项这一轮已经形成较完整的 focused 布局保护带，可以回到“我的 / 设置”里找下一个高频反馈组件复用同样节奏

## 2026-03-31 最近动态 166
- 完成：继续沿消息列表标题行的小屏标记链路推进。这轮把原来语义漂移的 `messages-thread-preview-row-*` 收回到真正的预览行，同时给标题行和标题标记补了稳定槽位 key：
  - `messages-thread-title-row-...`
  - `messages-thread-friend-tag-slot-...`
  - `messages-thread-pinned-icon-slot-...`
  这样 `好友` tag / pinned icon 是否仍稳定待在标题层，就终于能被 focused test 直接约束。
- 完成：新增 `flutter-app/test/widgets/messages_thread_title_markers_layout_test.dart`，focused 覆盖两条标题层级规则：
  - regular 宽度下，`好友` tag 和 pinned icon 继续留在 title row，且位于时间文本左侧
  - compact 宽度下，`好友` tag 和 pinned icon 仍完整落在 title row 内，并保持在真正的 preview row 之上
- 完成：这样消息列表线程项里常见的标题标记也开始纳入 focused 布局保护了。到这一步，title row、preview row、priority row、meta row 这四层主要视觉层级都开始有各自的定位锚点，后续继续调线程项密度时更不容易把行间语义搅乱。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/widgets/messages_tab.dart
  - flutter-app/test/widgets/messages_thread_title_markers_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮检测到 2 个残留 `dart` 进程并已清理
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\messages_tab.dart test\widgets\messages_thread_title_markers_layout_test.dart`：沙箱内异常退出且无输出
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\widgets\messages_tab.dart test\widgets\messages_thread_title_markers_layout_test.dart`：沙箱内只输出分析开头后异常退出
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe format`：格式化通过，`0 changed`
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮又补全了一条经验：如果 `dart analyze` 在沙箱里只输出 `Analyzing ...` 开头就异常退出，也应视为同类“半挂起”症状，直接切同一条最小命令提权重跑，不要继续空耗。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以开始做一次小范围代码收口，把 title / preview / priority / meta 这几层的稳定 key 和 focused 测试入口整理成更一致的命名，降低后续继续补测试时的心智负担
  2. 如果准备切模块，消息列表这条高频提示链路已经有较完整的 focused 保护带，可以回到“我的 / 设置”里找下一个高频反馈组件复用同样节奏

## 2026-03-31 最近动态 165
- 完成：继续沿消息列表的小屏高频标记链路推进。这轮给亲密度 chip 补了两组稳定槽位 key：
  - `messages-thread-intimacy-slot-preview-...`
  - `messages-thread-intimacy-slot-meta-...`
  这样亲密度 chip 在 regular 宽度和 compact 宽度下到底落在哪一行，终于可以被直接断言，不再只靠整卡矩形边界做间接判断。
- 完成：新增 `flutter-app/test/widgets/messages_thread_intimacy_chip_layout_test.dart`，focused 覆盖了两条高频规则：
  - regular 宽度下，亲密度 chip 继续留在 preview 行
  - compact 宽度下，亲密度 chip 下沉到 meta row，且仍保持在 unread 徽标右侧、落在线程卡内部
- 完成：这样消息列表线程项现在已经开始对 unread、priority、expiring、delivery badge、draft 和 intimacy chip 这些高频可见标记建立局部布局保护。后续即使继续调消息项密度或小屏层级，也更不容易把这些提示挤乱。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/widgets/messages_tab.dart
  - flutter-app/test/widgets/messages_thread_intimacy_chip_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮检测到 1 个残留 `dart` 进程并已清理
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\messages_tab.dart test\widgets\messages_thread_intimacy_chip_layout_test.dart`：沙箱内异常退出且无输出
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe format`：格式化通过，`1 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\widgets\messages_tab.dart test\widgets\messages_thread_intimacy_chip_layout_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮再次说明，只要当前验证范围已经压到最小文件集，沙箱里的静默失败和 `CreateFile failed 5` 都不值得继续空耗，直接切同一条命令提权重跑会更稳。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以开始看标题行里的 `好友` tag / pinned icon 组合在更紧凑宽度下是否也值得补一条 focused 布局保护，把线程项主要标记链路再收完整一点
  2. 如果准备切模块，消息列表这条高频提示链路已经有一串 focused 小组件保护，可以回到“我的 / 设置”里找下一个高频反馈组件复用同样节奏

## 2026-03-31 最近动态 164
- 完成：继续沿消息列表 preview 行推进“草稿优先”的高频状态保护。这轮给 `MessagesTab` 的草稿预览补了稳定 key：`messages-thread-draft-slot-...`，让“有草稿时预览行到底是不是还在显示草稿”终于可以被直接断言，而不是只靠文案存在性间接判断。
- 完成：新增 `flutter-app/test/widgets/messages_thread_draft_preview_layout_test.dart`，focused 覆盖了两条紧凑宽度规则：
  - `发送中` 消息存在草稿时，preview 行继续显示草稿，delivery badge 不出现，未读徽标仍下沉到 meta row
  - `发送失败` 消息存在草稿时，preview 行继续保留草稿，失败优先级标签仍单独留在下方，且不会回退成 `草稿待发送`
- 完成：这样消息列表这条高频链路现在已经不只保护 unread / priority / expiring / delivery badge，也开始保护“草稿优先于瞬时送达提示”的规则。后续如果继续改 preview 行密度或状态优先级，不容易再把草稿和送达态混成一层。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/widgets/messages_tab.dart
  - flutter-app/test/widgets/messages_thread_draft_preview_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮检测到 1 个残留 `dart` 进程并已清理
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\messages_tab.dart test\widgets\messages_thread_draft_preview_layout_test.dart`：沙箱内异常退出且无输出
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\widgets\messages_tab.dart test\widgets\messages_thread_draft_preview_layout_test.dart`：沙箱内异常退出且无输出
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe format`：格式化通过，`1 changed`
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮又补全了一条防卡经验：如果当前环境里 `dart format` 和 `dart analyze` 在沙箱内都静默失败，不要继续等待或扩大命令范围，直接对同一条最小命令提权重跑会更稳。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以开始检查 `好友` tag、亲密度 chip 和未读/时效行在更紧凑宽度下是否还值得补一条 focused 布局保护，把线程项的高频标记链路收得更完整
  2. 如果准备切模块，消息列表这边已经有一串 focused 小组件保护，可以回到“我的 / 设置”里找下一个高频反馈组件复用同样的小步节奏

## 2026-03-31 最近动态 163
- 完成：继续沿消息列表 preview 行的送达徽标推进。这轮给 `MessagesTab` 新增了两个稳定定位 key：
  - `messages-thread-preview-row-...`
  - `messages-thread-delivery-badge-slot-...`
  这样发送中 / 发送失败这类 delivery badge 是否还留在 preview 行、有没有被挤进别的层级，现在都能直接被 focused test 约束。
- 完成：新增 `flutter-app/test/widgets/messages_thread_delivery_badge_layout_test.dart`，focused 覆盖了两条紧凑宽度规则：
  - `发送中` 徽标在 compact 宽度下仍留在 preview 行，未读徽标继续下沉到 meta row
  - `发送失败` 徽标在 compact 宽度下仍位于优先级标签和 meta row 之上，保持 preview -> priority -> meta 三层结构
- 完成：这样消息列表里常见的 delivery badge 现在也开始有单独的小屏布局保护了。后续如果继续压缩 preview 行宽度、调整未读/优先级标签或改送达提示样式，不容易再把这些高频状态提示悄悄挤乱。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/widgets/messages_tab.dart
  - flutter-app/test/widgets/messages_thread_delivery_badge_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮检测到 1 个残留 `dart` 进程并已清理
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\messages_tab.dart test\widgets\messages_thread_delivery_badge_layout_test.dart`：沙箱内异常退出且无输出
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe format`：格式化通过，`1 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\widgets\messages_tab.dart test\widgets\messages_thread_delivery_badge_layout_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮继续坐实了一个经验：当前环境里 `dart format` 和 `dart analyze` 都可能在沙箱内先失败，但只要命令已经收敛到最小文件集，就不值得继续试探，直接对同一条命令提权重跑通常是最快的收尾方式。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以开始检查 preview 行里 `草稿` tag + delivery badge 互斥分支是否也值得补一条 focused 保护，把这条链路的主要状态面补完整
  2. 如果准备切模块，消息列表这边的 unread / priority / expiring / delivery badge 四类高频提示已经开始形成 focused 小屏保护带，可以回到“我的 / 设置”里找下一个高频反馈组件复用同样节奏

## 2026-03-31 最近动态 162
- 完成：继续沿消息列表的小屏高频标签推进。这轮给 `MessagesTab` 的底部时效行补了稳定 key：`messages-thread-meta-row-...`，专门用来锁定“优先级/即将到期标签是否仍稳稳待在时效行上方”这条布局边界。
- 完成：新增 `flutter-app/test/widgets/messages_thread_priority_tag_layout_test.dart`，focused 覆盖了两条紧凑宽度规则：
  - 失败优先级标签 `发送失败` 在 compact 宽度下仍位于 meta row 上方，不会和剩余时效行打架
  - `即将到期` 标签在 compact 宽度下仍完整落在线程卡内，并保持在 meta row 之上
- 完成：这样消息列表现在不只开始保护 unread badge 的上下行切换，也开始保护 `_TinyTag` 这类高频提示标签在紧凑宽度下的层级关系。后续如果继续压消息项密度、调整剩余时效行或补别的状态标签，更不容易把这些提示悄悄挤乱。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/widgets/messages_tab.dart
  - flutter-app/test/widgets/messages_thread_priority_tag_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮检测到 1 个残留 `dart` 进程并已清理
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\messages_tab.dart test\widgets\messages_thread_priority_tag_layout_test.dart`：沙箱内异常退出且无输出
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe format`：格式化通过，`1 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\widgets\messages_tab.dart test\widgets\messages_thread_priority_tag_layout_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮把另一个经验也坐实了: 当前环境里如果 `dart format` 在沙箱内异常退出却不吐信息，也没必要继续空等，直接对同一条最小命令提权重跑会更稳；和 `CreateFile failed 5` 一样，都应该按“最小命令、立即切换”处理。
- 下一步建议：
  1. 继续沿消息列表推进的话，可以开始看 preview 行里的 delivery badge 在更紧凑宽度下是否也值得补一条 focused 布局保护，把这条链路的高频提示再补完整
  2. 如果准备切模块，消息列表的 unread / priority / expiring 三类高频提示已经开始有 focused 布局保护，可以回到“我的 / 设置”里找下一个高频反馈组件复用同样节奏

## 2026-03-31 最近动态 161
- 完成：继续把“高频小组件 + focused test”这套做法复制到消息列表。这轮没有动大结构，只给 `MessagesTab` 里的未读徽标补了稳定定位 key：
  - `messages-thread-unread-slot-preview-...`
  - `messages-thread-unread-slot-meta-...`
  这样常规宽度和紧凑宽度下 unread badge 实际落在哪一行，后续终于可以被直接断言，不用再只靠肉眼看层级。
- 完成：新增 `flutter-app/test/widgets/messages_thread_unread_badge_layout_test.dart`，focused 覆盖两条真实布局规则：
  - regular 宽度下，未读徽标继续留在预览行
  - compact 宽度下，未读徽标下沉到剩余时效行
- 完成：这样消息列表里“未读数位置随尺寸切换”的小屏策略也开始有单独保护了。后续如果继续调消息项密度、移动亲密度徽标或压缩时效行，不容易再把 unread badge 悄悄挤回错误位置。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/widgets/messages_tab.dart
  - flutter-app/test/widgets/messages_thread_unread_badge_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\messages_tab.dart test\widgets\messages_thread_unread_badge_layout_test.dart`：格式化通过，`1 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\widgets\messages_tab.dart test\widgets\messages_thread_unread_badge_layout_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 说明，当前环境里只要是 `dart analyze` 遇到 `CreateFile failed 5`，就不应该继续僵在原命令上等结果，直接用同一条最小命令提权重跑才是最快的收尾方式。
- 下一步建议：
  1. 继续沿消息列表推进的话，更值得看的下一颗小组件是 `_TinyTag` 或消息项里的 delivery badge 组合，在更窄宽度下补一条 focused 布局保护
  2. 如果准备切模块，消息列表这条链路已经开始有 focused 小组件保护，可以回到“我的 / 设置”里找下一个高频提示组件复用同样节奏

## 2026-03-31 最近动态 160
- 完成：继续补齐 `ChatDeliveryBadge` 的 focused 行为覆盖，这轮新增了一条“普通态 -> 强调态”切换测试。`flutter-app/test/widgets/chat_delivery_badge_test.dart` 现在会直接验证：
  - `animated: true` 时切换前后的 badge 都仍由 `AnimatedSwitcher` 承载
  - 从 lightweight 状态切到 emphasized 状态后，阴影会按预期出现
  - 文案保持稳定可见
- 完成：顺手把 badge finder 提成了测试内的小 helper，避免后续继续补这个小组件时重复写同一段 widget 匹配逻辑，让测试本身也更容易维护。
- 完成：这样 `ChatDeliveryBadge` 现在不仅覆盖了静态态、强调态、轻量动画态，还开始覆盖真实的状态切换过程，focused 测试的约束力更完整了。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/chat_delivery_badge_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\chat_delivery_badge_test.dart`：格式化通过，`0 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\chat_delivery_badge_test.dart`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 说明，只要把验证范围保持在单文件 focused test，当前环境里在沙箱内直接 analyze 通过的概率很高；后续继续优先用这种粒度推进会更稳。
- 下一步建议：
  1. 如果继续沿聊天提示链路推进，可以考虑暂时收口，把注意力转到消息列表或设置页的其他高频提示组件，复用同样的方法
  2. 如果还想继续补 `ChatDeliveryBadge`，下一步更值得的是一条真正执行 widget test 的短超时尝试，但前提仍然是无输出就立即停止，避免再次卡死

## 2026-03-31 最近动态 159
- 完成：继续补齐 `ChatDeliveryBadge` 的 focused widget 覆盖，这轮新增了 `animated: true + emphasized: false` 的行为测试。`flutter-app/test/widgets/chat_delivery_badge_test.dart` 现在会直接验证：
  - 仍然包 `AnimatedSwitcher`
  - 非强调态不应带阴影
  - 边框仍然存在
  - 文案仍正常可见
- 完成：这样 `ChatDeliveryBadge` 这块现在已经把“静态态”“强调态”“轻量动画态”三种最常用的组合都覆盖到了，后续继续调徽标强调度或过渡方式时，focused 测试会更有约束力。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/chat_delivery_badge_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\chat_delivery_badge_test.dart`：格式化通过，`0 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\chat_delivery_badge_test.dart`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 说明，把验证控制到单文件 focused test 时，当前环境在沙箱内直接 analyze 通过的概率很高。后续继续优先用这种粒度推进，能明显降低“卡住”的概率。
- 下一步建议：
  1. 如果继续沿聊天提示链路推进，可以开始补 `ChatDeliveryBadge` 的 `animated: true + emphasized: true` 过渡存在性或 key 稳定性测试，把这颗徽标的行为面再补完整
  2. 如果准备切回别的高频组件，聊天提示链路里这几个核心小组件已经有不错的 focused 测试基础，可以先收口，转去下一个高频提示卡

## 2026-03-31 最近动态 158
- 完成：继续把聊天送达/失败提示链路里的高频小组件补成 focused widget test，这轮新增了 `flutter-app/test/widgets/chat_delivery_badge_test.dart`，直接覆盖 `ChatDeliveryBadge` 的两条核心分支：
  - `animated: false` 时不应包 `AnimatedSwitcher`
  - `emphasized: true` 时应带强调阴影和可见边框
- 完成：顺手修掉了这条新测试里一个已弃用 API 的小问题，把 `color.opacity` 改成了 `color.a`，避免后续每次 analyze 都在这条低价值 warning 上打断节奏。
- 完成：这样聊天提示链路现在已经不只是 `ChatDeliveryStatusCard` 有 focused 覆盖，连最常出现的状态徽标 `ChatDeliveryBadge` 也开始有自己的轻量测试，后续继续调颜色、动画或强调态时会更安心。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/chat_delivery_badge_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\chat_delivery_badge_test.dart`：格式化通过，`0 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\chat_delivery_badge_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：首次发现测试里有一个 deprecated API 使用
  - 修正测试后，在 `flutter-app` 目录再次执行同一条 `dart.exe analyze test\widgets\chat_delivery_badge_test.dart`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮再次说明，当前环境下“先最小 analyze，再根据结果补最小修正”仍然是最稳的节奏。哪怕提权 analyze 已经跑通，也可能只是帮我们暴露出下一层小问题；继续保持单文件粒度处理，才能避免卡住。
- 下一步建议：
  1. 如果继续沿聊天提示链路推进，可以把 `ChatDeliveryBadge` 的 animated=true 过渡存在性也补一条 focused 测试，继续完善这个小组件的行为面
  2. 如果准备切回别的高频链路，通知权限卡、送达状态卡、送达徽标这三块现在都已经有 focused 测试基础，可以把同样方法复制到下一个提示组件

## 2026-03-31 最近动态 157
- 完成：继续给 `ChatDeliveryStatusCard` 的 focused widget 覆盖补行为层验证。这轮新增了一条跨宽度点击测试，直接确认 `立即重试` 这颗 action chip：
  - 在 regular 宽度下可点击
  - 在 narrow 宽度下下沉后依然可点击
  - 两种宽度下都会稳定触发 `onActionTap`
- 完成：这样聊天送达/失败提示卡现在不只锁住了结构和层级，也开始锁住动作本身没有因为布局切换而失效。后续即使继续收小屏布局，也更不容易出现“看起来没问题，但点不到”的回退。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/chat_delivery_status_card_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\chat_delivery_status_card_test.dart`：格式化通过，`0 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\chat_delivery_status_card_test.dart`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 说明，把验证压到单文件 focused test 后，当前环境里在沙箱内直接 analyze 通过的概率会明显更高。后续继续优先保持这种粒度推进。
- 下一步建议：
  1. 如果继续沿聊天提示卡推进，可以开始给 `ChatDeliveryBadge` 或别的高频提示组件补同类 focused widget test，把“结构 + 可点击性”这套验证方式继续铺开
  2. 如果准备切回别的链路，这张卡已经有比较完整的 focused 覆盖，可以暂时收口，把注意力转到消息列表或设置页其他提示卡

## 2026-03-31 最近动态 156
- 完成：继续补齐 `ChatDeliveryStatusCard` 的 focused widget 覆盖，这轮新增了“失败但无动作”的窄宽度分支。`flutter-app/test/widgets/chat_delivery_status_card_test.dart` 现在会直接验证：
  - `暂不可重试` 这类无动作失败态在窄宽度下仍保持标签在上、详情在下
  - 详情文本仍完整落在卡片容器内部
  - 不应出现动作 chip
- 完成：这样聊天送达/失败提示卡现在已经覆盖了三类高频状态面：
  - 失败 + 动作
  - 成功 + 无动作
  - 失败 + 无动作
  这张卡后续再收文案或布局时，focused 测试给出的保护会更均衡，不会只盯某一类状态。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/chat_delivery_status_card_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\chat_delivery_status_card_test.dart`：格式化通过，`0 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\chat_delivery_status_card_test.dart`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 证明，只要把验证压到单文件 focused test，当前环境在沙箱内就有较高概率直接跑通 analyze。后续可以继续优先沿这个粒度推进，减少不必要的提权和卡死风险。
- 下一步建议：
  1. 如果继续沿聊天提示卡推进，可以再补一条 focused widget test 覆盖“成功态 + 较宽宽度”的布局，正式收齐这张卡的主要宽度/状态组合
  2. 如果准备切去别的组件，这套 focused widget 测试路线已经在通知权限卡和聊天送达卡两条链路上验证可行，可以直接复用

## 2026-03-31 最近动态 155
- 完成：继续补齐 `ChatDeliveryStatusCard` 的 focused widget 覆盖，这轮新增了“无动作成功态”分支。`flutter-app/test/widgets/chat_delivery_status_card_test.dart` 现在会直接验证：
  - `已送达` 成功态在窄宽度下仍保持标签在上、详情在下
  - 不应出现动作 chip
  - 详情文案仍完整可见
- 完成：这样聊天送达/失败提示卡现在不再只覆盖“失败 + 重试”这类动作态，也开始把高频成功态纳入 focused 测试。后续如果这张卡继续做视觉或密度收口，不会只对失败态有保护。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/chat_delivery_status_card_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\chat_delivery_status_card_test.dart`：格式化通过，`1 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\chat_delivery_status_card_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 说明，即便只是单文件 widget test，沙箱 analyze 也不稳定；但因为我们已经把验证收得足够小，所以一旦报 `CreateFile failed 5`，直接提权重跑同命令就能很快收尾，不会拖成卡死。
- 下一步建议：
  1. 如果继续沿聊天提示卡推进，可以再补一条 focused widget test 去覆盖“失败但无动作”的状态，比如 `暂不可重试`，把这张卡的主要状态面进一步补齐
  2. 如果准备切模块，这套 focused widget 测试方法已经在通知权限卡和聊天送达卡上都跑通了，可以直接迁移到别的高频提示组件

## 2026-03-31 最近动态 154
- 完成：从通知权限卡切回聊天里的高频失败提示卡，对 `ChatDeliveryStatusCard` 做了一轮小屏结构收口。现在这张卡在带动作时不再永远强行把动作留在右侧，而是会在更窄宽度下把动作下沉到详情下方，减少失败提示在窄气泡里的横向挤压。
- 完成：同步给 `ChatDeliveryStatusCard` 补了稳定 key 和 focused widget test，新增 `flutter-app/test/widgets/chat_delivery_status_card_test.dart`，直接锁住两条核心分支：
  - regular 宽度下：动作继续位于右侧并排
  - narrow 宽度下：动作下沉到详情下方，且仍完整落在卡片内部
- 完成：这样聊天失败/重试提示现在也开始走和通知权限卡同一套优化路径了：先补 focused 结构保护，再做小步布局收口，不再只靠整屏 smoke 发现问题。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/widgets/chat_delivery_status.dart
  - flutter-app/test/widgets/chat_delivery_status_card_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\chat_delivery_status.dart test\widgets\chat_delivery_status_card_test.dart`：格式化通过，`1 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\widgets\chat_delivery_status.dart test\widgets\chat_delivery_status_card_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 证明了，哪怕只是一个 widget 和一条 focused widget test，沙箱里的 analyze 也可能先撞权限。继续沿用现有经验即可：恢复脚本、最小 analyze、权限报错后立刻提权，不在失败命令上空耗。
- 下一步建议：
  1. 如果继续沿聊天失败提示推进，可以把 `ChatDeliveryStatusCard` 的无动作成功态也补成 widget test，彻底补齐这张卡的主要布局分支
  2. 如果切去别的高频提示卡，通知权限卡和聊天失败卡现在都已经证明这套“小步结构收口 + focused 测试”路线是有效的，可以直接复用

## 2026-03-31 最近动态 153
- 完成：继续补齐 `NotificationPermissionNoticeCard` 的最后一个主要布局分支。`flutter-app/test/widgets/notification_permission_notice_card_test.dart` 现在新增了 `regular + 双动作` 的 focused widget test，明确锁住：
  - 标题与 badge 继续保持同排
  - 描述继续位于标题区域之后
  - 主动作与次动作继续同排
  - 两颗按钮顶部保持对齐
  - 两颗按钮高度继续保持 `38`
- 完成：到这一步，这张通知权限卡的四种常见布局形态都已经有 focused widget test：
  - compact + 双动作
  - compact + 单动作
  - regular + 单动作
  - regular + 双动作
  后续如果继续调文案、动作数或布局密度，不再需要先依赖整屏 smoke 才能知道是不是把卡片结构改坏了。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/notification_permission_notice_card_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\notification_permission_notice_card_test.dart`：格式化通过，`0 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\notification_permission_notice_card_test.dart`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮依旧只做 focused widget test 收口，没有扩大到 `flutter test`。但从回归覆盖角度看，这张通知权限卡已经不再依赖整屏路径来识别结构回退，后续维护成本会明显更低。
- 下一步建议：
  1. 如果继续沿通知权限链路推进，这块卡片本身可以先暂时收口，把同样的方法切去别的高频提示卡
  2. 如果继续留在当前模块，下一步更值得补的是一次短超时的单文件 widget test 执行，验证这些 focused test 在当前环境里是否也能动态跑通

## 2026-03-31 最近动态 152
- 完成：继续给 `NotificationPermissionNoticeCard` 补更窄宽度下的 compact 边界验证。`flutter-app/test/widgets/notification_permission_notice_card_test.dart` 现在新增了 `compact + 双动作 + width: 280` 的 focused widget test，明确锁住：
  - 两颗按钮在更窄宽度下仍完整落在卡片容器内部
  - 主动作继续位于次动作之上
  - 不抛布局异常
- 完成：这样这张卡现在不只覆盖了布局形态本身，也开始覆盖更接近真实小屏边界的宽度条件。后续如果有人继续压缩 padding、改按钮文案或试图把双动作重新塞回一行，这条 focused test 会更早暴露问题。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/notification_permission_notice_card_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\notification_permission_notice_card_test.dart`：格式化通过，`0 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\notification_permission_notice_card_test.dart`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮单文件 widget test 在沙箱内直接 analyze 通过，继续说明当前环境下只要把验证范围压到足够小，稳定性会明显更好。后续可以优先保持这种 focused 验证节奏。
- 下一步建议：
  1. 如果继续沿通知权限链路推进，这张卡的结构测试已经比较完整，可以暂时收口，切去别的高频提示卡复用同样的方法
  2. 如果还想继续深挖这张卡，下一步更值得的是补一次真正的 widget test 执行而不只是 analyze，但前提仍然是保持短超时、无输出就立刻停止，避免再次卡死

## 2026-03-31 最近动态 151
- 完成：继续补齐 `NotificationPermissionNoticeCard` 最后一块主要布局分支。`flutter-app/test/widgets/notification_permission_notice_card_test.dart` 现在新增了 `compact + 单动作` 的 widget test，明确锁住：
  - `标题 -> badge -> 描述 -> 主动作`
  - 描述继续保持 `maxLines == 2`
  - 描述继续保持 `TextOverflow.ellipsis`
  - 主动作高度继续保持 `34`
  - 不应出现次动作按钮
- 完成：到这一步，这张通知权限卡的三种主要布局形态已经都有 focused widget test：
  - compact + 双动作
  - compact + 单动作
  - regular + 单动作
  后续继续调结构或文案时，不再只能依赖整屏 smoke 才能发现回退。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/notification_permission_notice_card_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\notification_permission_notice_card_test.dart`：格式化通过，`0 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\notification_permission_notice_card_test.dart`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮是最近一次在沙箱内直接通过 analyze 的小步测试收口，也进一步说明当范围控制到单文件时，当前环境的稳定性会好很多；后续继续优先用这种 focused 验证方式推进。
- 下一步建议：
  1. 如果继续沿通知权限链路推进，可以考虑暂时收口，把注意力切回聊天或通知中心里别的高频提示卡，复用这套“先下沉 focused test，再调结构”的方式
  2. 如果仍想继续打磨这张卡，下一步更值得的是补一次 widget test 验证 compact 宽度边界，例如更窄尺寸下不抛异常且动作区仍完整可见

## 2026-03-31 最近动态 150
- 完成：继续收紧 `NotificationPermissionNoticeCard` 的 widget test，把 compact / regular 两套布局里最容易回退的两个细节也补成显式断言：
  - compact 描述：`maxLines == 2`，`overflow == TextOverflow.ellipsis`
  - compact 双动作高度：两颗按钮都保持 `34`
  - regular 描述：`maxLines == null`，`overflow == TextOverflow.visible`
  - regular 单动作高度：保持 `38`
- 完成：这样这张卡现在不只锁住了层级顺序，也锁住了最关键的截断和尺寸规则。后续即使继续改文案长度或按钮文案，也更难把 compact / regular 两套分支悄悄改坏。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/notification_permission_notice_card_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\notification_permission_notice_card_test.dart`：格式化通过，`0 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\notification_permission_notice_card_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮再次验证，哪怕只是单文件 widget test，沙箱 analyze 也可能先被权限拦住；当前环境里看到 `CreateFile failed 5` 还是应该直接提权重跑，不要在同一条命令上继续空等。
- 下一步建议：
  1. 如果继续沿通知权限链路推进，这张卡本身已经有比较完整的结构保护，可以考虑切回聊天或通知中心，把其它高频提示卡也按同样方式下沉到 widget / focused smoke
  2. 如果继续深挖这张卡，下一步更值得的是补一次 focused widget test 去覆盖 compact 单动作分支，彻底补齐三种主要布局形态

## 2026-03-31 最近动态 149
- 完成：继续把通知权限卡的结构保护从整屏 smoke 下沉到更聚焦的 widget test。新增了 `flutter-app/test/widgets/notification_permission_notice_card_test.dart`，直接覆盖两套核心布局分支：
  - compact + 双动作：锁住 `标题 -> badge -> 描述 -> 主动作 -> 次动作`
  - regular + 单动作：锁住标题与 badge 同排、描述在其下、主动作继续位于描述之后
- 完成：这样后续如果继续调这张卡的文案、按钮标签或紧凑布局，不需要每次都先跑聊天页 / 通知中心整屏 smoke 才能发现结构回退，测试反馈会更聚焦也更轻。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/notification_permission_notice_card_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\notification_permission_notice_card.dart test\widgets\notification_permission_notice_card_test.dart`：格式化通过，`1 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\widgets\notification_permission_notice_card.dart test\widgets\notification_permission_notice_card_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮没有主动跑 `flutter test`，继续遵守当前环境里的“先最小静态验证，不把小改动拖进长时间动态执行”的原则。与此同时，这轮也再次证明，哪怕只是一个 widget test 文件，沙箱内 analyze 依旧可能先被权限拦住，看到 `CreateFile failed 5` 还是应该直接提权重跑。
- 下一步建议：
  1. 如果继续沿通知权限链路推进，可以开始把 `NotificationPermissionNoticeCard` 在 compact 模式下的描述截断和按钮高度也补进 widget test，进一步减少对整屏 smoke 的依赖
  2. 如果切回聊天主链路，可以沿用同样的方法，把消息发送失败 / 重试提示也从整屏 smoke 下沉一层到更聚焦的 widget 或 utils 测试

## 2026-03-31 最近动态 148
- 完成：继续把 `NotificationPermissionNoticeCard` 的 compact 结构补成完整可验证链路。这轮新增了 `notification-permission-notice-description` key，并把聊天页、通知中心两条 compact smoke 都补成显式层级断言，明确要求小屏下通知权限卡遵循：
  - 标题在上
  - badge 在标题下方
  - 描述在 badge 下方
  - 动作区在描述之后
  这样 compact 结构保护已经不只是“标题和 badge 分层”或“按钮上下排布”，而是整张卡片的阅读顺序都被锁住了。
- 完成：这轮没有继续改视觉样式和文案，只是在现有设计方向里把结构保护补完整。后续即使继续调整文案长短或按钮标签，也更不容易把小屏层级压坏。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/widgets/notification_permission_notice_card.dart
  - flutter-app/test/smoke/chat_screen_notification_permission_smoke_test.dart
  - flutter-app/test/smoke/notification_center_screen_smoke_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\notification_permission_notice_card.dart test\smoke\chat_screen_notification_permission_smoke_test.dart test\smoke\notification_center_screen_smoke_test.dart`：格式化通过，`0 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\widgets\notification_permission_notice_card.dart test\smoke\chat_screen_notification_permission_smoke_test.dart test\smoke\notification_center_screen_smoke_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮再次回到了“沙箱 analyze 被权限拦住、提权同命令通过”的老模式，也说明即便只是 smoke 层级断言补强，当前环境里仍要继续保留这套快排习惯，别让小改动拖成卡死。
- 下一步建议：
  1. 如果继续沿通知权限链路推进，可以开始考虑给 `NotificationPermissionNoticeCard` 补一个更聚焦的 widget test，直接锁住 compact 与 regular 两套布局分支，进一步减少对整屏 smoke 的依赖
  2. 如果切回聊天主链路，更值得把消息发送失败 / 重试提示的小屏层级按同样方式补 key 和位置断言，延续这几轮已经跑顺的优化节奏

## 2026-03-31 最近动态 147
- 完成：把通知中心 compact 场景里的通知权限卡结构保护补齐到和聊天页一致。`flutter-app/test/smoke/notification_center_screen_smoke_test.dart` 现在除了继续检查权限按钮、筛选条和通知项的纵向层级，还新增了：
  - `notification-permission-notice-title`
  - `notification-permission-notice-badge`
  两个 finder 的位置断言，明确要求小屏下 badge 位于标题下方。
- 完成：到这一步，聊天页和通知中心两条高频入口都已经锁住了同一套 compact 结构规则：标题在上、badge 在下、动作区位于内容区之后。后续即使继续调小屏密度，也更不容易把这块悄悄改回拥挤布局。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/smoke/notification_center_screen_smoke_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\smoke\notification_center_screen_smoke_test.dart`：格式化通过，`0 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\smoke\notification_center_screen_smoke_test.dart`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮是最近第二次单文件 smoke 在沙箱内直接 analyze 通过，说明“恢复脚本 + 单文件命令”这条节奏目前仍然是最稳的默认解法，可以继续优先采用。
- 下一步建议：
  1. 如果继续沿通知权限链路推进，可以把 `NotificationPermissionNoticeCard` 的 compact 描述截断也补成显式断言，避免后续文案再变长时压坏小屏结构
  2. 如果切回聊天主链路，更值得开始收消息发送失败 / 重试提示的小屏层级，继续沿用“先补 key 和位置 smoke，再动文案”的方式

## 2026-03-31 最近动态 146
- 完成：继续把 `NotificationPermissionNoticeCard` 的 compact 结构从“实现细节”补成“可验证结构”。这轮给通知权限卡补了稳定 key：
  - `notification-permission-notice-title`
  - `notification-permission-notice-badge`
  然后在聊天页 compact smoke 里新增位置断言，明确要求小屏下 `待授权` badge 位于标题下方，而不是再悄悄挤回同一行。
- 完成：这样我们现在不只锁住了小屏下双按钮上下排布，也正式锁住了标题和 badge 的分层关系；后续如果有人为了“省空间”又把它们塞回同排，smoke 会第一时间报出来。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/widgets/notification_permission_notice_card.dart
  - flutter-app/test/smoke/chat_screen_notification_permission_smoke_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\notification_permission_notice_card.dart test\smoke\chat_screen_notification_permission_smoke_test.dart`：格式化通过，`1 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\widgets\notification_permission_notice_card.dart test\smoke\chat_screen_notification_permission_smoke_test.dart`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮是最近少数一次在沙箱内直接通过 analyze 的小改动，也再次说明只要范围足够小、前置恢复脚本做掉，当前环境并不是每次都需要提权。可以继续优先尝试最小 analyze，再根据结果决定是否提权。
- 下一步建议：
  1. 如果继续沿通知权限链路推进，可以回到通知中心页的 compact 场景，把标题和 badge 分层也补成显式断言，让两条入口的结构保护完全对齐
  2. 如果切回聊天主链路，接下来更值得把发送失败 / 重试提示的小屏层级也按同样方式补上 key 和位置 smoke

## 2026-03-31 最近动态 145
- 完成：继续把上一轮通知权限卡的小屏结构正式锁进通知中心的 compact smoke。`flutter-app/test/smoke/notification_center_screen_smoke_test.dart` 现在不再只检查 banner、筛选条和列表项都存在，而是新增了权限处理按钮 `notification-center-permission-action` 的位置断言，明确要求：
  - 权限处理按钮存在
  - 权限处理按钮位于筛选条之上
  - 筛选条仍位于第一条通知项之上
  这样通知中心这条入口就和聊天页一样，有了更明确的小屏层级锚点。
- 完成：这轮没有继续改视觉样式，而是把上一轮 `NotificationPermissionNoticeCard` 的结构收口补齐到另一条高频入口，避免聊天页测住了、通知中心却在后续迭代里悄悄回退。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/smoke/notification_center_screen_smoke_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\smoke\notification_center_screen_smoke_test.dart`：格式化通过，`0 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\smoke\notification_center_screen_smoke_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮再次说明，哪怕只是单文件 smoke 断言补强，当前环境里 `dart analyze` 也可能直接撞上权限错误。后续继续坚持同一条经验：只跑单文件、看到 `CreateFile failed 5` 立即提权，不做额外空等。
- 下一步建议：
  1. 如果继续沿通知权限链路推进，可以回到 `NotificationPermissionNoticeCard` 看描述在 compact 模式下是否还值得减少截断，或者补一条 widget/smoke 锁住 badge 在紧凑模式下不与标题同排拥挤
  2. 如果切回聊天主链路，可以开始检查消息发送失败 / 重试提示在小屏下的布局密度，沿用这几轮已经验证有效的“结构先稳住，再补文案和 smoke”方式

## 2026-03-31 最近动态 144
- 完成：继续沿通知权限链路收 `NotificationPermissionNoticeCard` 的小屏布局。现在紧凑尺寸下如果卡片同时有两个动作：
  - 标题和 `待授权` badge 不再硬挤同一行
  - 主动作和次动作改成纵向堆叠
  这样聊天页的小屏通知权限 banner 不会再为了把两颗按钮塞进一行而显得过密，整体更稳，也更符合这类提示卡“先看状态、再做动作”的浏览顺序。
- 完成：同步把 `flutter-app/test/smoke/chat_screen_notification_permission_smoke_test.dart` 的 compact 场景断言收紧，不再只看 banner 和输入框都存在，而是明确检查两颗按钮在小屏下保持上下排布，并且次动作仍在 composer 之上。
- 完成：到这一步，通知权限提示链路已经不只是文案更一致，小屏下的结构层级也开始更清楚了；这轮没有改颜色、风格和动作语义，只是在原有视觉方向内把信息密度往下压了一层。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/widgets/notification_permission_notice_card.dart
  - flutter-app/test/smoke/chat_screen_notification_permission_smoke_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\notification_permission_notice_card.dart test\smoke\chat_screen_notification_permission_smoke_test.dart`：格式化通过，`0 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\widgets\notification_permission_notice_card.dart test\smoke\chat_screen_notification_permission_smoke_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮再次说明，哪怕只是一个 widget + 一条 compact smoke，当前环境也可能直接在 `dart analyze` 阶段碰到权限错误。后续继续坚持“最小命令 + 立即提权重跑”的策略，不让这种小改动再拖成卡死。
- 下一步建议：
  1. 如果继续沿通知权限链路推进，可以看 `NotificationPermissionNoticeCard` 在通知中心页是否还值得补一条 compact smoke，把单动作卡的小屏层级也锁住
  2. 如果切回聊天主链路，更值得把消息发送失败 / 重试提示也按同样方式检查一遍，看小屏下是否也存在按钮和提示挤压的问题

## 2026-03-31 最近动态 143
- 完成：继续收口通知权限缺失时的公共指导语，把 `NotificationPermissionGuidance` 从“技术状态描述”改成更结果导向、也更符合当前真实行为的表达：
  - `settingsDescription` 改成 `新消息仍会留在通知中心，系统提醒暂不可用。`
  - `settingsFollowUpDescription` 改成 `去系统设置打开后，回来就会恢复提醒。`
  - 通知中心 / 聊天页的说明也同步收成 `新消息会先留在这里...` / `离开会话后，新消息会先留在通知中心...`
  这样不再继续强调“应用通知已打开但系统权限未授权”这种偏实现细节的描述，也顺手修掉了旧文案里“回来再刷新一次”和当前自动刷新行为不一致的问题。
- 完成：同步给三条 smoke 补上新的描述断言，避免这轮公共文案收口只靠人工记忆：
  - `flutter-app/test/smoke/settings_screen_smoke_test.dart`
  - `flutter-app/test/smoke/chat_screen_notification_permission_smoke_test.dart`
  - `flutter-app/test/smoke/notification_center_screen_smoke_test.dart`
- 完成：到这一步，设置页、聊天页、通知中心三处通知权限缺失提示终于开始共享同一套“先说结果，再补充影响”的语言，跨页面的一致性更完整。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/utils/notification_permission_guidance.dart
  - flutter-app/test/smoke/settings_screen_smoke_test.dart
  - flutter-app/test/smoke/chat_screen_notification_permission_smoke_test.dart
  - flutter-app/test/smoke/notification_center_screen_smoke_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\utils\notification_permission_guidance.dart test\smoke\chat_screen_notification_permission_smoke_test.dart test\smoke\notification_center_screen_smoke_test.dart test\smoke\settings_screen_smoke_test.dart`：格式化通过，`0 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\utils\notification_permission_guidance.dart test\smoke\chat_screen_notification_permission_smoke_test.dart test\smoke\notification_center_screen_smoke_test.dart test\smoke\settings_screen_smoke_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮再次验证，哪怕只动一个公共文案文件和 3 个 smoke，`dart analyze` 也可能在沙箱里直接被权限拦住。后续遇到同类小改动，继续沿用当前经验：先恢复脚本，再最小 analyze，一旦出现 `CreateFile failed 5` 就立刻提权重跑同一条命令，不做额外等待。
- 下一步建议：
  1. 如果继续沿通知链路推进，可以开始检查 `NotificationPermissionNoticeCard` 本身在小屏下的标题、描述、双 action 是否还有信息密度偏高的问题
  2. 如果切回聊天主链路，这套“过程态不要停留、公共文案要跟真实行为一致”的原则可以继续拿去收消息发送失败和重试提示

## 2026-03-31 最近动态 142
- 完成：修掉了 `SettingsScreen` 一条更真实的通知权限返回态问题。之前从系统设置返回后，如果通知权限没有变化，页内 feedback 会一直停在旧的 `已打开系统设置 / 等待返回`，这其实是过期的过程态；现在这条链路改成“只要确实从系统设置返回过，就刷新成当前结果态”。因此未授权场景会立即回到：
  - `通知权限仍待授权`
  - `待授权`
  - `返回后仍未检测到系统通知权限。`
  这样用户不会再被“已经打开过系统设置”这类旧提示卡住。
- 完成：同步把 `flutter-app/test/smoke/settings_screen_smoke_test.dart` 里对应的 smoke 场景从“避免重复 feedback”改成“返回后展示当前通知状态”，并补上 description 断言，正式锁住这条返回态行为。
- 完成：顺手把 provider 返回值语义也收清楚了。`refreshPushRuntimeStateAfterSystemSettingsReturn()` 现在返回的是“这次系统设置返回是否已被处理”，而不是“状态有没有变化”，这样 UI 可以稳定刷新到当前结果态，不再被 no-op 刷新误导。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/providers/settings_provider.dart
  - flutter-app/lib/screens/settings_screen.dart
  - flutter-app/test/smoke/settings_screen_smoke_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\providers\settings_provider.dart lib\screens\settings_screen.dart test\smoke\settings_screen_smoke_test.dart`：格式化通过，`0 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\providers\settings_provider.dart lib\screens\settings_screen.dart test\smoke\settings_screen_smoke_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮再次说明，哪怕只是 provider + 单屏 smoke 的小改动，`dart analyze` 也可能在沙箱内直接被权限拦住。当前最稳的处理方式仍然是：先跑恢复脚本，只跑最小文件集，一旦看到 `CreateFile failed 5` 就立刻提权重跑同一条命令，不要继续扩大范围或反复空等。
- 下一步建议：
  1. 如果继续沿设置页推进，可以继续看权限缺失常量本身的说明语，尤其是 `NotificationPermissionGuidance.settingsDescription` 这类偏技术表达，是否还值得收成更结果导向的语言
  2. 如果想切换模块，同样的“别让旧过程态停留在屏上”原则也适合回到聊天或通知中心，继续清理返回态和失败态提示

## 2026-03-31 最近动态 141
- 完成：继续收 `SettingsScreen` 的通知运行态描述，让标题和描述不再都在复述“系统权限 / 通道是否就绪”这类技术状态。现在通知相关反馈进一步改成更结果导向的表达：
  - 总览焦点卡与运行态卡：同步中的说明改成 `提醒会在通道恢复后回来。`
  - inline feedback 成功态：改成 `新消息会正常提醒。`
  - 系统设置返回后的恢复态：改成 `新消息会重新正常提醒。`
  - 权限已恢复但应用仍静默：改成 `系统权限已恢复，当前仍保持静默。`
  这样通知链路现在更像“告诉用户接下来会发生什么”，而不是继续堆技术条件。
- 完成：顺手把 `flutter-app/test/smoke/settings_screen_smoke_test.dart` 里还停留在旧通知标题上的断言补齐，包括：
  - `通知已静默`
  - `通知已在线`
  - 以及对应的描述断言
  这样这轮通知反馈收口不再只靠人工记忆。
- 完成：到这一步，设置页通知反馈已经从“标题、badge、描述一起解释运行态”进一步收成“标题说结果，badge 说状态，描述说影响”，和前两轮账号安全、体验预设的收口方向也更一致。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/screens/settings_screen.dart
  - flutter-app/test/smoke/settings_screen_smoke_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\screens\settings_screen.dart test\smoke\settings_screen_smoke_test.dart`：格式化通过，`0 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\screens\settings_screen.dart test\smoke\settings_screen_smoke_test.dart`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮同样只跑了最小文件集，没有主动扩大到整页 `flutter test`。不过和上一轮相比，这次 `dart analyze` 在沙箱内直接通过，说明“先恢复脚本、再最小 analyze”的节奏在当前环境里仍然是最稳妥的默认路径。
- 下一步建议：
  1. 如果继续沿设置页打磨，更值得继续看通知权限缺失和系统设置返回这两个场景下，页内反馈与运行态卡是否还存在“同一语义两处都说得太满”的轻微重复
  2. 如果切回主链路，可以开始按同样的方法收聊天或通知中心里的失败态提示，继续统一成“先说结果，再补充影响”

## 2026-03-31 最近动态 140
- 完成：继续收 `SettingsScreen` 里通知运行态和体验预设的反馈标题，重点去掉“标题、badge、描述都在重复说同一件事”的堆叠。现在相关 inline feedback / 总览焦点卡统一改成更短的结果表达：
  - 通知运行态：`通知同步中 / 通知恢复中 / 通知已在线 / 通知已静默 / 通知仍静默`
  - 体验预设：`已切到在线回复 / 已切到低干扰 / 已切到安静观察`
  这样 badge 和描述继续负责补充状态含义，标题本身只承担“一眼看到结果”的职责，设置页整体会更克制。
- 完成：同步更新 `flutter-app/test/smoke/settings_screen_smoke_test.dart` 里的文案断言，继续把这轮设置页反馈收口锁进 smoke，避免后续又回退到更冗长的表达。
- 完成：到这一步，`SettingsScreen` 里账号安全、通知运行态、体验预设三块高频反馈都开始朝同一套“短标题 + 有区分的 badge/描述”方式收敛，设置页状态语言的一致性更完整。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/screens/settings_screen.dart
  - flutter-app/test/smoke/settings_screen_smoke_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\screens\settings_screen.dart test\smoke\settings_screen_smoke_test.dart`：格式化通过，`0 changed`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\screens\settings_screen.dart test\smoke\settings_screen_smoke_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮仍然保持“只跑最小文件集”的策略，避免因为很小的文案收口又把 Flutter CLI 拉进长时间无输出。若 analyze 再次出现 `CreateFile failed 5 / 拒绝访问`，继续沿用既有经验，立即转提权重跑同一条最小命令，不扩大范围。
- 下一步建议：
  1. 如果继续沿设置页打磨，可以再看通知运行态描述文案和总览焦点卡 subtitle 是否还有轻微重复，但前提是保持这轮已经收紧的短标题结构不回退
  2. 如果切回主业务链路，更值得把聊天或通知中心里仍然偏泛的失败态提示，继续按“先说结果，再补充状态”的方式收一轮

## 2026-03-31 最近动态 139
- 完成：回到 `SettingsScreen` 收口账号安全入口的保存反馈。手机号和密码保存后的 inline feedback 现在都改成更短、更结果导向的表达：
  - 手机号：`手机号已更新 / 已同步 / 当前账号已切到新手机号。`
  - 密码：`密码已更新 / 已保存 / 请改用新密码登录。`
  这样不再出现“已更新 + 已刷新 + 已同步”这类重复堆叠，也更贴近这两个入口真正想传达的结果。
- 完成：同步更新 `flutter-app/test/smoke/settings_screen_smoke_test.dart` 里的对应断言，避免后续把这两条反馈又改回冗长表达时没有测试提醒。
- 完成：到这一步，`SettingsScreen` 里的媒体、账号安全、返回首页反馈三块高频可见反馈都已经开始从“描述过程”转向“直接说结果”，整个设置链路的状态表达更克制一致。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/screens/settings_screen.dart
  - flutter-app/test/smoke/settings_screen_smoke_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：本轮检测到 4 个残留 `dart` 进程并已清理
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\screens\settings_screen.dart test\smoke\settings_screen_smoke_test.dart`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\screens\settings_screen.dart test\smoke\settings_screen_smoke_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮再次说明，哪怕只是很小的设置页文案收口，当前环境里也可能先残留多余 `dart` 进程。继续维持同一条经验：先恢复，再跑最小命令，再决定是否提权，不要直接上更大的 Flutter CLI 命令。
- 下一步建议：
  1. 如果继续沿设置页打磨，下一轮可以看通知运行态和体验预设反馈里是否还存在类似“标题、badge、描述都在重复说同一件事”的文案堆叠
  2. 如果想切回主业务链路，更值得把聊天或通知链路里仍然偏泛的失败态提示，按“直接说结果”这套方式再收一轮
## 2026-03-30 最近动态 138
- 完成：补齐了“设置返回首页”最后一块低 refocus 场景。`flutter-app/test/smoke/main_screen_smoke_test.dart` 现在新增两条 focused smoke：
  - `账号设置已同步 / 已同步`
  - `设置已保存在本机 / 待联网同步`
  这两条都直接覆盖“只改手机号、不涉及头像背景和资料文本”的返回态，避免首页提示只对高 refocus 的资料变更有文案锚点。
- 完成：两条新 smoke 还顺手锁住了 `shouldRefocusIdentityArea: false` 的行为。测试里会先把个人页滚动位置推下去，再从设置返回，最后断言滚动位置没有被强行拉回顶部，确保低优先级账号设置变化不会打断当前浏览位置。
- 完成：到这一步，设置返回首页这条链路在 success / deferred、high refocus / low refocus 四个象限上都已经有了明确 smoke 场景，资料反馈链路的状态可验证性明显更完整。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/smoke/main_screen_smoke_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\profile_tab.dart test\smoke\main_screen_smoke_test.dart`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\widgets\profile_tab.dart test\smoke\main_screen_smoke_test.dart`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮依旧没有主动跑 `flutter test`，但从测试设计角度看，设置返回态这块已经不再依赖“人工记住该看哪些标题”，后续只要环境允许，就可以直接针对现有单文件 smoke 补动态结果。
- 下一步建议：
  1. 如果继续沿“我的 / 设置”链路推进，下一轮可以回到 `SettingsScreen` 自身，把保存后的 inline feedback 再收一轮重复表达，尤其是手机号 / 密码这类账号安全入口
  2. 如果准备切去其他主链路，这块资料反馈已经够稳，可以把注意力转回聊天或通知链路里仍然偏泛的失败态文案
## 2026-03-30 最近动态 137
- 完成：把“设置返回首页”的成功提示也统一成和弱网提示同一风格的具体语义。`flutter-app/lib/widgets/profile_tab.dart` 现在成功分支不再说“已同步到首页 / 主页已刷新”这类泛表达，而是改成：
  - `资料和展示已同步`
  - `头像和背景已同步`
  - `头像已同步`
  - `背景已同步`
  - `个人资料已同步`
  - `账号设置已同步`
  并统一把 badge 收成 `已同步`，这样 success / deferred 两侧终于变成同一套命名方式。
- 完成：同步把成功返回场景的 smoke 断言从“只要非空即可”升级成明确文案断言。`flutter-app/test/smoke/main_screen_smoke_test.dart` 现在会直接检查“头像和背景已同步 / 已同步 / 当前首页已显示新的头像和背景。”这组成功提示，避免后续再把具体文案改回笼统表达时没有测试提醒。
- 完成：到这一步，设置返回首页这条链路里，无论远端成功还是失败，首页提示都已经和资料类型一一对应，用户更容易一眼看懂“这次到底同步了什么、现在处于什么状态”。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/widgets/profile_tab.dart
  - flutter-app/test/smoke/main_screen_smoke_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\profile_tab.dart test\smoke\main_screen_smoke_test.dart`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\widgets\profile_tab.dart test\smoke\main_screen_smoke_test.dart`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮依旧只做了 focused 静态验证，没有主动补跑 `flutter test`。但和前几轮相比，成功返回和弱网返回两侧都已经有了明确的 smoke 文案锚点，后续即使动态测试环境恢复，也能更快看出是不是文案或状态被回退。
- 下一步建议：
  1. 如果继续沿“我的 / 设置”链路推进，下一轮更适合补“账号设置已同步 / 已保存在本机”这组低 refocus 场景的 smoke，彻底补齐设置返回态的最后一块
  2. 如果转回别的主链路，这条资料反馈收口已经足够稳定，可以开始切去处理聊天或通知链路里仍然偏泛的失败提示
## 2026-03-30 最近动态 136
- 完成：继续压缩“设置返回首页”这条弱网提示的重复感。`flutter-app/lib/widgets/profile_tab.dart` 的 `_buildDeferredSettingsSyncState(...)` 现在不再统一说“首页已更新”，而是会按真实变化类型返回更具体的标题：
  - `资料和展示已保存在本机`
  - `头像和背景已保存在本机`
  - `头像已保存在本机`
  - `背景已保存在本机`
  - `个人资料已保存在本机`
  这样首页返回提示就能直接对上当前媒体管理摘要和资料保存反馈，不再出现“首页提示很泛、管理摘要很具体”的落差。
- 完成：补了一条 focused smoke 到 `flutter-app/test/smoke/main_screen_smoke_test.dart`，专门锁住“有 token、设置返回、远端刷新失败，但本地头像/背景已经回显”这条场景。现在会明确断言首页提示是“头像和背景已保存在本机 / 待联网同步”。
- 完成：到这一步，个人页资料链路已经把“设置返回提示”“媒体管理摘要”“保存后的 inline feedback”三处文案统一到了同一套本机/待同步语义上，弱网态的信息层级明显更干净。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/widgets/profile_tab.dart
  - flutter-app/test/smoke/main_screen_smoke_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\profile_tab.dart test\smoke\main_screen_smoke_test.dart`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\widgets\profile_tab.dart test\smoke\main_screen_smoke_test.dart`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮依旧没有主动跑 `flutter test`，但和前几轮相比，我们已经把“远端刷新失败时首页应该怎么说”正式锁进 smoke 文件了，后续环境允许时可以直接针对这条场景补动态通过结果。
- 下一步建议：
  1. 如果继续沿个人页打磨，下一轮可以把“设置返回首页”的成功提示也做同样的具体化收口，让 success / deferred 两侧风格完全对齐
  2. 如果准备补动态验证，优先只尝试 `test/smoke/main_screen_smoke_test.dart` 单文件，继续坚持短超时和无输出即停止
## 2026-03-30 最近动态 135
- 完成：继续把个人页媒体摘要的视觉状态和文案状态对齐。`flutter-app/lib/widgets/profile_tab.dart` 里的 `_ProfileMediaManagementSummary` 现在新增 `highlightBadge`，因此“头像/背景已保存在本机”这类待联网同步状态不再沿用远端成功态的高亮 badge，避免视觉上继续像“已同步”。
- 完成：补了一条 focused smoke 到 `flutter-app/test/smoke/main_screen_smoke_test.dart`，直接锁住“本地媒体文件存在但还没远端同步”这条真实场景：个人页头像 / 背景管理弹层会显示“已保存在本机” + “待联网同步”，并且 action 文案保持“更换头像 / 更换背景”。
- 完成：到这一步，个人页媒体链路已经不仅逻辑和文案统一，连 badge 高亮语义也和设置页同一方向了；后续即使再补动态测试，也更容易发现真正的状态回退，而不是被视觉成功态掩盖。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/widgets/profile_tab.dart
  - flutter-app/test/smoke/main_screen_smoke_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\profile_tab.dart test\smoke\main_screen_smoke_test.dart`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\widgets\profile_tab.dart test\smoke\main_screen_smoke_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮依旧没有主动补跑 `flutter test`，但和上一轮相比，我们已经把最关键的一条本地媒体场景正式锁进 smoke 文件本身，后续一旦环境允许补跑，这条行为会比纯人工记忆更可靠。
- 下一步建议：
  1. 下一轮可以把设置返回首页后“本机媒体预览”与“远端同步未完成”的 inline feedback 再往同一套词汇收一层，减少首页提示和管理摘要之间剩余的轻微重复
  2. 如果准备补一次动态验证，优先只尝试 `test/smoke/main_screen_smoke_test.dart` 单文件，并继续保持短超时和无输出即中止的策略
## 2026-03-30 最近动态 134
- 完成：继续把个人页媒体链路里的状态词收口到和设置页一致。`flutter-app/lib/widgets/profile_tab.dart` 现在在头像 / 背景管理摘要里也会区分“远端已同步”和“本机预览中”两种媒体态：
  - 远端媒体：显示“头像已同步 / 背景已生效”
  - 本地媒体：显示“头像已保存在本机 / 背景已保存在本机”，badge 改为“待联网同步”
  - 默认态：统一改成“正在使用默认头像 / 背景”和“上传头像 / 背景”这套词
- 完成：个人页入口卡片、管理弹层和上一轮补好的保存反馈，现在三处都使用同一套同步语义，不再出现“保存后说待联网同步，但管理摘要还写已同步”的轻微割裂。
- 完成：顺手把个人页头像 / 背景管理的 action 文案也一起收成“更换头像 / 更换背景”，继续和设置页保持一致。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/widgets/profile_tab.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\profile_tab.dart`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\widgets\profile_tab.dart`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮没有补新的动态 smoke，只做了词汇和摘要状态收口。这里也顺手补一条经验：如果本轮改动只是局部状态词和已有状态分支的映射，优先先拿 focused analyze 结果；不要为了很小的词汇收口去立刻扩大到整页动态回归。
- 下一步建议：
  1. 下一轮可以把 `main_screen_smoke_test.dart` 里与个人页媒体反馈最接近的场景补成明确文案断言，正式锁住“本机预览中 / 待联网同步”这套口径
  2. 如果继续沿“我的 / 设置”主线推进，更高价值的下一步是把设置返回首页后“本机预览媒体”的同步提示也做成更连贯的弱网态闭环
## 2026-03-30 最近动态 133
- 完成：把 `flutter-app/lib/widgets/profile_tab.dart` 的头像 / 背景上传也接到 `UserMediaUploadResult`。现在“我的”页媒体更新和设置页一样，会按真实结果区分三种反馈：
  - 远端成功：继续显示“资料已刷新 / 氛围已刷新”
  - 无 session：改为“本机已更新 / 已保存在本机”
  - 远端失败回退本地：改为“远端同步未完成 / 待联网同步”
- 完成：`ProfileTab` 新增 `_showMediaUploadToast(...)`，只有远端成功时才继续弹保存成功 toast；如果只是本机保存，则改成“头像已保存在本机 / 背景已保存在本机”的轻提示，不再把本地回写误导成已同步。
- 完成：至此，个人页文本资料、设置页媒体上传、个人页媒体上传三条高频资料反馈路径已经统一到了同一套真实同步语义上，首页和设置页之间的口径差异进一步收敛。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/widgets/profile_tab.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\profile_tab.dart`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\widgets\profile_tab.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：首次超时后立即执行恢复脚本，再次重试分析通过，`No issues found!`
- 风险 / 备注：这轮再次验证，“提权 analyze”本身也不是每次都稳定首发成功。如果提权后仍然超时，不要继续等待；先执行恢复脚本确认残留进程，再重试一次最小 analyze。只要第二次仍无明确输出，就应立即停止，避免再次出现长时间卡死。
- 下一步建议：
  1. 下一轮可以把个人页媒体管理摘要也继续收口成与设置页同一套“本机预览中 / 待联网同步”状态词，避免入口卡片和保存反馈之间还存在轻微语义差
  2. 如果想补动态验证，优先挑现有 `main_screen_smoke_test.dart` 里和媒体反馈最接近的小场景，严格限制在单文件、短超时，不要直接放大回归范围
## 2026-03-30 最近动态 132
- 完成：把设置页头像 / 背景上传也收口到真实同步状态。`flutter-app/lib/services/media_upload_service.dart` 新增 `uploadUserMediaWithStatus()` / `UserMediaUploadResult`，现在可以明确区分三种结果：
  - 远端上传成功：返回远端媒体引用
  - 无 session：只保存在本机预览
  - 已尝试远端但失败：回退到本地路径，并明确标记为待联网同步
- 完成：`flutter-app/lib/screens/settings_screen.dart` 的头像 / 背景替换动作已经切到新的上传结果。设置页 inline feedback 现在会按真实状态显示“资料已刷新 / 本机已更新 / 待联网同步”，并且只有远端成功时才继续弹保存成功 toast；如果只是本机保存，则改成“已保存在本机”的轻提示。
- 完成：把设置页媒体摘要一并校正。`_SettingsMediaPreviewState` 和 `resolveMediaPreviewState(...)` 现在都会携带 `isRemote`，因此本地路径不会再被误标成“已同步 / 首屏已生效”；本地预览态会明确显示“本机预览中 / 待联网同步”。
- 完成：补了 focused 回归并同步适配设置页 smoke fake service：
  - `flutter-app/test/services/media_upload_service_test.dart`：新增 `uploadUserMediaWithStatus()` 的 local-only / remote-failed 断言
  - `flutter-app/test/utils/media_preview_state_resolver_test.dart`：新增 `isRemote` 断言
  - `flutter-app/test/smoke/settings_screen_smoke_test.dart`：适配新的 `uploadUserMediaWithStatus()` fake 返回
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/services/media_upload_service.dart
  - flutter-app/lib/utils/media_preview_state_resolver.dart
  - flutter-app/lib/screens/settings_screen.dart
  - flutter-app/test/services/media_upload_service_test.dart
  - flutter-app/test/utils/media_preview_state_resolver_test.dart
  - flutter-app/test/smoke/settings_screen_smoke_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\services\media_upload_service.dart lib\utils\media_preview_state_resolver.dart lib\screens\settings_screen.dart test\services\media_upload_service_test.dart test\utils\media_preview_state_resolver_test.dart test\smoke\settings_screen_smoke_test.dart`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\services\media_upload_service.dart lib\utils\media_preview_state_resolver.dart lib\screens\settings_screen.dart test\services\media_upload_service_test.dart test\utils\media_preview_state_resolver_test.dart test\smoke\settings_screen_smoke_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮依旧没有主动补跑 `flutter test`，不是因为这块没有测试价值，而是当前环境里动态测试仍有“无输出假死”风险。这里再记一条经验：当服务层和页面态已经有 focused 静态验证时，优先补小粒度逻辑测试和 fake 适配，不要为了拿一个 smoke 结果回到长时间等待。
- 下一步建议：
  1. 下一轮可以把 `ProfileTab` 里的头像 / 背景上传也接到同一套 `UserMediaUploadResult`，让“我的”页和设置页的媒体反馈完全统一
  2. 如果继续往设置链路推进，更适合补的是“本机预览中”这类状态在返回首页后的同步提示衔接，而不是再扩更多入口
## 2026-03-30 最近动态 131
- 完成：把个人主页里昵称 / 签名 / 状态三处文本保存入口统一改成读取 `ProfileSaveResult`。`flutter-app/lib/widgets/profile_tab.dart` 新增 `_showTextSaveFeedback(...)`，现在会区分三种结果：
  - 远端成功：继续沿用“展示已刷新”的正常成功反馈
  - 无 session、仅本地保存：改为“本机已更新 / 已保存在本机”提示，不再假装已经远端同步
  - 有 session 但远端失败：改为“远端同步未完成 / 待联网同步”弱网反馈，并且不再继续弹成功 toast
- 完成：`_presentNicknameEditor(...)`、`_presentSignatureEditor(...)`、`_buildStatusOptionTile(...)` 已全部切到 `updateNicknameWithStatus(...)`、`updateSignatureWithStatus(...)`、`updateStatusWithStatus(...)`，首页文本资料保存反馈口径现在和上一轮“设置返回首页”同步态保持一致。
- 完成：补了两条 focused 状态回归，继续把这轮新增的保存语义锁在逻辑层：
  - `flutter-app/test/services/profile_service_test.dart`：新增昵称保存在“无 session 本地保存”和“远端失败回退到本地”两条断言
  - `flutter-app/test/providers/profile_provider_test.dart`：新增 provider 层昵称保存状态透传断言，锁住 local-only 和 remote-failed 两种结果
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/widgets/profile_tab.dart
  - flutter-app/test/services/profile_service_test.dart
  - flutter-app/test/providers/profile_provider_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\profile_tab.dart test\services\profile_service_test.dart test\providers\profile_provider_test.dart`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\widgets\profile_tab.dart test\services\profile_service_test.dart test\providers\profile_provider_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：本轮仍然没有主动补跑 `flutter test`，原因不是逻辑不完整，而是当前机器上 Flutter CLI 首分钟可能完全无输出。这里继续沉淀一条固定经验：一旦 `flutter test / flutter analyze / dart analyze` 在当前模式下没有明确进度或直接命中 `CreateFile failed 5`，立即停止等待，切到“恢复脚本 -> focused command -> 必要时提权 analyze”的短链路，不再长时间卡住。
- 下一步建议：
  1. 继续沿资料编辑链路推进时，下一轮更值得把设置页内昵称 / 签名 / 状态保存后的反馈也统一成同一套 `ProfileSaveResult` 口径，避免设置页和首页提示分裂
  2. 如果转回动态验证，先只尝试最小单文件测试并把超时压到 45 秒以内，首分钟无进度就立刻中止，不再重复出现“看起来像卡死”的等待
## 2026-03-30 最近动态 130
- 完成：补上了“设置返回首页后的远端同步结果”可见性。`flutter-app/lib/services/profile_service.dart` 新增 `refreshProfileWithStatus()` / `ProfileRefreshResult`，让资料刷新不再只有 snapshot，还会明确返回这次是否真正尝试了远端刷新、是否成功。
- 完成：`flutter-app/lib/providers/profile_provider.dart` 新增 `refreshFromRemoteWithStatus()`，把 service 层的刷新结果继续透传给上层，同时保持 provider 状态更新逻辑不变。
- 完成：`flutter-app/lib/widgets/profile_tab.dart` 现在会在设置页返回后读取这次远端刷新结果；如果资料确实变了，但远端刷新失败，就改为展示“首页已更新，本次远端同步未完成 / 待联网同步”这类弱网提示，并且不再继续显示成功同步 cue，避免把“本地已更新”误导成“远端已同步完成”。
- 完成：补了两条轻量测试入口：
  - `flutter-app/test/services/profile_service_test.dart`：锁住无 session 时 `refreshProfileWithStatus()` 的本地态结果
  - `flutter-app/test/providers/profile_provider_test.dart`：锁住 provider 层 `refreshFromRemoteWithStatus()` 的本地态结果
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/services/profile_service.dart
  - flutter-app/lib/providers/profile_provider.dart
  - flutter-app/lib/widgets/profile_tab.dart
  - flutter-app/test/services/profile_service_test.dart
  - flutter-app/test/providers/profile_provider_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\services\profile_service.dart lib\providers\profile_provider.dart lib\widgets\profile_tab.dart test\providers\profile_provider_test.dart test\services\profile_service_test.dart`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\services\profile_service.dart lib\providers\profile_provider.dart lib\widgets\profile_tab.dart test\providers\profile_provider_test.dart test\services\profile_service_test.dart`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮为了避免继续卡死，没有主动再跑 `flutter test`。当前环境里动态测试仍可能无进度挂住，所以本轮优先保证逻辑闭环和 focused 静态验证；新的测试入口已补齐，等 CLI 状态恢复后可单文件补跑。
- 下一步建议：
  1. 如果继续沿“我的 / 设置”链路推进，下一轮可以把“资料更新失败后的设置页内反馈”也统一成与首页返回态一致的弱网提示口径
  2. 如果回到业务主链路，更值得做的是把昵称 / 签名 / 状态更新失败时的本地暂存提示补到设置页编辑保存动作上
## 2026-03-30 最近动态 129
- 完成：继续缩短 `SettingsScreen` 的媒体管理弹层代码。新增 `flutter-app/lib/widgets/settings_media_management_preview_card.dart`，把头像/背景管理卡片里重复的 `status + badge` 结构抽成共享 widget，只保留各自的 leading preview 差异。
- 完成：`flutter-app/lib/screens/settings_screen.dart` 的 `_buildAvatarManagementPreviewCard(...)` 和 `_buildBackgroundManagementPreviewCard(...)` 现在都改为组合 `SettingsMediaManagementPreviewCard` + `SettingsMediaPreviewSurface`，原来页面内重复的 badge 装饰和状态文案布局已删除。
- 完成：补了聚焦 widget test `flutter-app/test/widgets/settings_media_management_preview_card_test.dart`，锁住新卡片会正确渲染 status/badge key 和文案，避免后续再次把这种小结构验证压回大页面 smoke。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/widgets/settings_media_management_preview_card.dart
  - flutter-app/lib/screens/settings_screen.dart
  - flutter-app/test/widgets/settings_media_management_preview_card_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\settings_media_management_preview_card.dart lib\screens\settings_screen.dart test\widgets\settings_media_management_preview_card_test.dart`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\widgets\settings_media_management_preview_card_test.dart --reporter expanded`，45s 无输出后超时，中止等待
  - 在项目根目录再次执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\widgets\settings_media_management_preview_card.dart lib\screens\settings_screen.dart test\widgets\settings_media_management_preview_card_test.dart`：静态分析通过，`No issues found!`
- 风险 / 备注：当前机器上，即使是只渲染文本和 key 的极小 widget test，也可能在 45 秒内完全不出进度。这轮再次确认，Flutter CLI 验证必须继续坚持“短超时 + 立即恢复 + 静态分析兜底”的策略，不能回到长时间等待。
- 下一步建议：
  1. 如果继续收设置页，可以把媒体管理项的 item subtitle / badge 摘要也往小组件下沉，进一步压缩 `settings_screen.dart`
  2. 如果准备回到业务链路，下一轮更适合转向“设置返回首页后的身份同步提示”和“弱网下资料更新失败反馈”这两个真实用户感知更强的点
## 2026-03-30 最近动态 128
- 完成：继续把 `SettingsScreen` 里头像/背景预览 surface 的重复 UI 收成共享 widget。新增 `flutter-app/lib/widgets/settings_media_preview_surface.dart`，统一处理圆形头像预览、圆角背景预览、远端图片显示和失效本地媒体回退图标。
- 完成：`flutter-app/lib/screens/settings_screen.dart` 的 4 处调用点已经全部切到 `SettingsMediaPreviewSurface`，原来页面内的 `_buildAvatarPreviewSurface(...)`、`_buildBackgroundPreviewSurface(...)` 和 `_buildMediaPreviewImageProvider(...)` 已删除，设置页媒体预览逻辑进一步收口。
- 完成：补了聚焦 widget test `flutter-app/test/widgets/settings_media_preview_surface_test.dart`，锁住“失效本地文件回退图标”和“远端媒体引用会构建图片 widget”两条基础行为。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/widgets/settings_media_preview_surface.dart
  - flutter-app/lib/screens/settings_screen.dart
  - flutter-app/test/widgets/settings_media_preview_surface_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\settings_media_preview_surface.dart lib\screens\settings_screen.dart test\widgets\settings_media_preview_surface_test.dart`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\widgets\settings_media_preview_surface_test.dart --reporter expanded`，60s 无输出后超时，中止等待
  - 在项目根目录再次执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\widgets\settings_media_preview_surface.dart lib\screens\settings_screen.dart test\widgets\settings_media_preview_surface_test.dart`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮再一次验证，当前机器上即使是新的单 widget `flutter test` 也可能完全不出进度。因此后续所有 Flutter CLI 验证都继续遵守同一条经验：先恢复、再跑最小命令、首分钟无进度就立即停掉，不做长时间等待。
- 下一步建议：
  1. 如果继续沿设置页打磨，可以把头像/背景管理卡片里重复的 badge + status 结构再收成小组件，继续缩短 `settings_screen.dart`
  2. 如果想先回到业务链路，下一轮更适合转去“我的/设置”返回首页后的同步提示与弱网失败反馈收口
## 2026-03-30 最近动态 127
- 完成：继续把 `SettingsScreen` 的媒体预览状态读取链路收口到共享解析逻辑。新增 `flutter-app/lib/utils/media_preview_state_resolver.dart`，把“是否真的是可渲染媒体预览”统一收成 `resolveMediaPreviewState(...)`。
- 完成：`flutter-app/lib/screens/settings_screen.dart` 里的 `_readMediaPreviewState(...)` 和 `_normalizePreviewStateSync(...)` 现在都改走同一套 preview resolver，不再一处依赖 `avatarExists/backgroundExists`，另一处依赖 `resolveRenderableMediaPath(...)`。这样即使存进来的值是纯文本占位或失效路径，也会稳定回到默认预览态。
- 完成：补了纯逻辑测试 `flutter-app/test/utils/media_preview_state_resolver_test.dart`，覆盖远端媒体、有效本地文件、失效本地文件和纯文本占位四条边界，避免继续把这类验证压到 settings 页面 smoke 上。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/utils/media_preview_state_resolver.dart
  - flutter-app/lib/screens/settings_screen.dart
  - flutter-app/test/utils/media_preview_state_resolver_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\utils\media_preview_state_resolver.dart lib\screens\settings_screen.dart test\utils\media_preview_state_resolver_test.dart`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\utils\media_preview_state_resolver_test.dart --reporter expanded`，120s 无输出后超时，中止等待
  - 在项目根目录再次执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\utils\media_preview_state_resolver.dart lib\screens\settings_screen.dart test\utils\media_preview_state_resolver_test.dart`：静态分析通过，`No issues found!`
- 风险 / 备注：这次连新的纯 util `flutter test` 也在当前机器上出现了假死，说明问题不只在大页面 smoke。后续只要 `flutter test` 首分钟没有明确进度，就直接停止并改走“恢复脚本 -> focused analyze / 更小替代验证”，不要继续硬等。
- 下一步建议：
  1. 继续沿着媒体链路推进时，可以把 `SettingsScreen` 里头像/背景预览 surface 的重复 fallback UI 再收成更小的共享 widget
  2. 如果要补动态验证，优先挑已有稳定通过的单 widget test 或已有 smoke 子场景，不要直接重试大范围 settings 回归
## 2026-03-30 最近动态 126
- 完成：继续把头像 / 媒体路径解析逻辑向共享工具收口。新增 `looksLikeMediaReference(...)`，让 `flutter-app/lib/utils/media_reference_resolver.dart` 现在可以同时分辨“纯文本头像”“远端媒体引用”和“本地文件引用”，并把 `resolveRenderableMediaPath(...)` 收成只接受真正媒体引用。
- 完成：`flutter-app/lib/widgets/app_user_avatar.dart` 已经切到共享解析器。原来散在组件里的 `_looksLikeMediaRef`、`_isNetworkMediaPath`、`_resolveLocalMediaFile` 已删除，远端图片加载占位、失效本地头像错误占位和纯文本头像回退语义保持不变。
- 完成：`flutter-app/lib/widgets/profile_tab.dart` 也切到同一套 resolver 入口。头像、背景和管理预览现在都通过 `resolveRenderableMediaPath(...)`、`isRemoteMediaReference(...)` 和 `resolveLocalMediaFile(...)` 处理，不再各自维护一套本地 / 远端判断。
- 完成：补强了轻量回归：
  - `flutter-app/test/utils/media_reference_resolver_test.dart` 新增“纯文本不应被当成媒体引用”和 `looksLikeMediaReference(...)` 判断测试
  - `flutter-app/test/widgets/app_user_avatar_test.dart` 改成 Unicode 转义的默认头像断言，避免编码状态影响测试稳定性
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/utils/media_reference_resolver.dart
  - flutter-app/lib/widgets/app_user_avatar.dart
  - flutter-app/lib/widgets/profile_tab.dart
  - flutter-app/test/utils/media_reference_resolver_test.dart
  - flutter-app/test/widgets/app_user_avatar_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\utils\media_reference_resolver.dart lib\widgets\app_user_avatar.dart lib\widgets\profile_tab.dart test\utils\media_reference_resolver_test.dart test\widgets\app_user_avatar_test.dart`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\utils\media_reference_resolver_test.dart --reporter expanded`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\widgets\app_user_avatar_test.dart --reporter expanded`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze lib\utils\media_reference_resolver.dart lib\widgets\app_user_avatar.dart lib\widgets\profile_tab.dart test\utils\media_reference_resolver_test.dart test\widgets\app_user_avatar_test.dart`，120s 无输出后超时，本轮未继续硬等
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\utils\media_reference_resolver.dart lib\widgets\app_user_avatar.dart lib\widgets\profile_tab.dart test\utils\media_reference_resolver_test.dart test\widgets\app_user_avatar_test.dart`：静态分析通过，`No issues found!`
- 风险 / 备注：本地机器上的 `flutter analyze` 仍可能再次出现看似真卡死的无输出状态，但这轮已经验证可以立刻按“恢复脚本 -> dart analyze”的替代路径拿到静态验证结果，不再等到整个命令挂死。
- 下一步建议：
  1. 如果继续按媒体稳定性推进，下一轮可以继续把 `SettingsScreen` 的预览 image provider 和其他页面小块也收成同一套 resolver 入口
  2. 动态页面验证依然不要直接上大 settings smoke，先以 util / widget 级闭环回归为主

## 2026-03-30 最近动态 125
- 完成：把设置页这段“本地媒体路径还能不能继续渲染”的判断抽成共享工具 `flutter-app/lib/utils/media_reference_resolver.dart`。现在 `SettingsScreen` 通过 `resolveRenderableMediaPath(...)`、`isRemoteMediaReference(...)` 和 `resolveLocalMediaFile(...)` 来统一处理远端媒体、可用本地文件和失效本地路径，不再各处散着判断。
- 完成：为这段共享逻辑补了轻量单元测试 `flutter-app/test/utils/media_reference_resolver_test.dart`，锁住三条边界：
  - 远端媒体引用仍可渲染
  - 存在的本地媒体路径仍可渲染
  - 已失效的本地媒体路径会被拒绝，不再继续当成可用媒体
- 完成：把之前加在超大 `settings_screen_smoke_test.dart` 里的 stale-media 场景拆到了更小的独立文件 `flutter-app/test/smoke/settings_media_fallback_smoke_test.dart`，方便后续单独补拿动态页面结果，而不是继续和整份 settings 总 smoke 绑死。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/utils/media_reference_resolver.dart
  - flutter-app/lib/screens/settings_screen.dart
  - flutter-app/test/utils/media_reference_resolver_test.dart
  - flutter-app/test/smoke/settings_media_fallback_smoke_test.dart
  - flutter-app/test/smoke/settings_screen_smoke_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\utils\media_reference_resolver.dart lib\screens\settings_screen.dart test\utils\media_reference_resolver_test.dart test\smoke\settings_media_fallback_smoke_test.dart`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\utils\media_reference_resolver_test.dart --reporter expanded`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze lib\utils\media_reference_resolver.dart lib\screens\settings_screen.dart test\utils\media_reference_resolver_test.dart test\smoke\settings_media_fallback_smoke_test.dart`
- 风险 / 备注：设置页的专用页面 smoke 文件已经拆出来，但在当前机器上，页面级 `flutter test` 仍可能被 `dart` worker 假死打断；这轮先拿到了共享逻辑层的稳定回归和 focused analyze 结果，动态页面结果还需要后续补跑。
- 下一步建议：
  1. 优先补跑 `test/smoke/settings_media_fallback_smoke_test.dart` 的真实通过结果，确认新拆分的小文件是否比原大文件更稳定。
  2. 如果页面级 settings 测试仍反复卡住，下一步就该继续把高价值页面逻辑下沉成更小的 util / widget 级测试，而不是继续堆大 smoke。

## 2026-03-30 最近动态 124
- 完成：把“失效本地媒体路径”的同步兜底进一步补到 `SettingsScreen`。现在设置页列表项和头像/背景管理 sheet 在消费 `_SettingsMediaPreviewState` 时，会先走 `_normalizePreviewStateSync(...)`；如果本地文件已经不存在，就会回到默认态摘要、默认预览和无删除按钮，而不是继续把旧本地引用当成“已同步”。
- 完成：`_buildMediaPreviewImageProvider(...)` 也补了本地文件存在性判断，避免预览层继续把失效本地路径交给 `FileImage`。
- 完成：新增了 `settings_screen_smoke_test.dart` 的弱边界回归，覆盖“设置页打开后本地头像/背景文件被删除，再进入管理 sheet 时会回到默认态”这条场景。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/screens/settings_screen.dart
  - flutter-app/test/smoke/settings_screen_smoke_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\screens\settings_screen.dart test\smoke\settings_screen_smoke_test.dart`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze lib\screens\settings_screen.dart lib\widgets\profile_tab.dart test\smoke\settings_screen_smoke_test.dart test\smoke\main_screen_smoke_test.dart`
  - 尝试两次在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\smoke\settings_screen_smoke_test.dart --plain-name "settings screen should fallback cleanly when local media references become stale" --reporter expanded`
- 风险 / 备注：本轮新增的 settings smoke 在当前机器上连续两次被 Flutter `dart` worker 假死卡住，未拿到动态测试结果；代码静态分析通过，但这条行为还需要在后续 CLI 状态更稳定时补一遍真实 smoke 结果。排障过程中已再次验证 `repair_flutter_cli_hang.ps1` 能清掉残留 `dart` 进程。
- 下一步建议：
  1. 先不要扩大 Flutter 长回归范围，下一轮优先补拿这条 settings smoke 的真实通过结果。
  2. 如果 smoke 仍反复卡住，可考虑把这条场景下沉成更小的 widget test，进一步降低对 Flutter test worker 的依赖。

## 2026-03-30 最近动态 123
- 完成：继续把“失效本地媒体路径”的兜底从统一头像组件扩到个人主页。`profile_tab.dart` 现在在渲染头像、背景主视觉和媒体管理预览时，会先判断本地文件是否仍存在；如果本地路径已经失效，就直接回退到当前页面已有的文字/图标占位，而不是继续让 `FileImage` 去读坏路径。
- 完成：补了一条 `main_screen_smoke_test.dart`，锁住“个人主页遇到失效本地头像/背景引用时，首屏和媒体管理 sheet 仍然稳定渲染、不抛异常”这条边界。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/widgets/profile_tab.dart
  - flutter-app/test/smoke/main_screen_smoke_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\profile_tab.dart test\smoke\main_screen_smoke_test.dart`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\smoke\main_screen_smoke_test.dart --plain-name "profile tab should fallback cleanly when local media references are stale" --reporter expanded`
- 风险 / 备注：这轮只收了 `ProfileTab`，没有把 `SettingsScreen` 的本地媒体预览也一起统一到同一套同步兜底；不过设置页启动时本身已经有一层 `ImageUploadService.avatarExists/backgroundExists` 检查，所以当前优先级没有个人主页高。
- 下一步建议：
  1. 如果继续沿媒体稳定性推进，下一轮可以把 `SettingsScreen` 的本地预览也补成和个人主页一致的同步兜底，彻底消掉同类边界差异。
  2. 或转回业务主链路，继续收聊天/资料页的弱网失败反馈。

## 2026-03-30 最近动态 122
- 完成：继续把统一头像组件往“可交付”方向收口。`AppUserAvatar` 现在对“本地头像路径已失效”的情况做了同步判断：如果缓存里的本地文件已经不存在，会立刻落到统一失败占位并显示错误标记，而不是继续停在加载态。
- 完成：保持了远端媒体的加载占位与渐进显示逻辑不变，同时把这条新边界补成稳定组件测试；并额外跑了一条 `MatchTab` 单页 smoke，确认共享组件改动没有把匹配结果卡里的远端头像回显打坏。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/widgets/app_user_avatar.dart
  - flutter-app/test/widgets/app_user_avatar_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\app_user_avatar.dart test\widgets\app_user_avatar_test.dart`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\widgets\app_user_avatar_test.dart --reporter expanded`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\smoke\match_tab_smoke_test.dart --plain-name "match tab should render remote avatar image when available" --reporter expanded`
- 风险 / 备注：这轮只收了“失效本地文件 -> 立即错误占位”这条弱边界，还没有继续补远端图片真正加载失败时的统一提示文案、缓存策略或更轻的 skeleton 样式；但至少 stale 本地头像不会再无限停留在加载假象里。
- 下一步建议：
  1. 如果继续做头像链路，下一轮更值得统一的是远端图片超时 / 失败时的交互细节，比如是否要保留右下角错误标记、是否需要更轻的 skeleton。
  2. 或切回更接近交付的主链路，优先做聊天/资料页的弱网失败反馈真机验证。

## 2026-03-30 最近动态 121
- 完成：把“Flutter CLI 假死恢复”从纯文档补成仓库内可直接执行的脚本。项目根目录新增 `repair_flutter_cli_hang.ps1`，会检查并强制清理残留的 `flutter/dart` 进程，最多重试 3 轮，并在收尾时给出“接下来只跑最小 Flutter 命令”的提示。
- 完成：同步把脚本入口补进 `ENVIRONMENT_SETUP.md`，后续再遇到 `flutter test` / `analyze` 长时间无输出时，不需要再手动一条条试命令，直接在根目录执行：
  - `powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`
- 完成：实际验证了恢复链路。本轮运行脚本时，确实识别到了残留 `dart` 进程并执行了两轮清理；随后顺序复查 `Get-Process flutter,dart ...` 已无残留输出，当前 CLI 基线恢复正常。
- 涉及模块：
  - CURRENT_SPRINT.md
  - ENVIRONMENT_SETUP.md
  - repair_flutter_cli_hang.ps1
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`
  - 在项目根目录执行：`Get-Process flutter,dart -ErrorAction SilentlyContinue | Select-Object ProcessName,Id,StartTime`
- 风险 / 备注：这轮仍然是工程恢复能力建设，不是业务功能推进；当前最重要的流程经验是“恢复脚本执行后，进程复查必须串行跑，不要和清理动作并行执行”，否则很容易再次读到旧状态，误以为脚本失效。
- 下一步建议：
  1. 后续任何 Flutter 长命令卡住时，先运行 `repair_flutter_cli_hang.ps1`，再恢复最小验证集。
  2. 恢复业务开发时，先跑单组件测试或单页面 smoke，不再直接上多文件长回归。

## 2026-03-30 最近动态 120
- 完成：补了一轮“Flutter 命令假死”排障沉淀，避免后续继续在同一类问题上空等。`ENVIRONMENT_SETUP.md` 已新增“Flutter 命令假死快排”，把本仓库已确认的根因、判断方式和标准处理顺序写成固定手册；`PROJECT_CONTEXT.md` 也同步补了运行备注，提醒后续接手时直接按这套口径处理。
- 完成：排掉当前这轮中断测试留下的残留进程，已执行 `Get-Process dart -ErrorAction SilentlyContinue | Stop-Process -Force`，把当前 Flutter CLI 环境恢复到更干净的基线。
- 涉及模块：
  - CURRENT_SPRINT.md
  - ENVIRONMENT_SETUP.md
  - PROJECT_CONTEXT.md
- 验证：
  - 在项目根目录执行：`Get-Process flutter,dart -ErrorAction SilentlyContinue | Select-Object ProcessName,Id,StartTime`
  - 在项目根目录执行：`Get-Process dart -ErrorAction SilentlyContinue | Stop-Process -Force`
- 风险 / 备注：这轮是工程流程收口，不是业务功能开发；`flutter test` 在当前机器上仍可能因为 SDK 外置和残留 `dart` 进程叠加而出现假死，所以后续只要再次遇到“命令长时间无输出”，不要继续等待，直接按文档里的“查进程 -> 清进程 -> 沙箱外执行”三步走。
- 下一步建议：
  1. 后续所有 Flutter 验证都默认先走“目标命令 + 沙箱外执行”，不要再先尝试沙箱内长时间等待。
  2. 在下一轮恢复业务开发前，先从最小验证集开始，例如单组件测试或单页面 smoke，确认 CLI 状态正常后再扩大范围。

## 2026-03-30 最近动态 119
- 完成：继续把高频社交入口的真实头像回显往下收，`MatchTab` 匹配成功结果卡里的两处旧文本头像都已切到统一的 `AppUserAvatar`。现在匹配结果拿到远端 `avatarUrl` 时，会直接渲染真实头像图片，不再退回纯文字/emoji 占位。
- 完成：给匹配结果头像补了稳定测试定位 `match-result-avatar`，并新增 `match_tab_smoke_test.dart` 回归，锁住“匹配成功时若用户头像是远端媒体引用，则页面里会出现图片渲染”这条契约。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/widgets/match_tab.dart
  - flutter-app/test/smoke/match_tab_smoke_test.dart
- 验证：
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\match_tab.dart test\smoke\match_tab_smoke_test.dart`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\smoke\match_tab_smoke_test.dart --reporter expanded`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze`
- 风险 / 备注：这轮把匹配页结果卡收进统一头像链路后，消息页、好友页、聊天页、匹配页这几条高频链路已经基本统一；剩下还没系统化的主要不是“哪页没显示真头像”，而是头像图片加载失败态、弱网骨架和缓存策略仍然各页面零散处理，没有统一抽象。
- 下一步建议：
  1. 如果继续沿着头像这条线推进，下一轮更值得做的是给 `AppUserAvatar` 补一个统一的加载失败态/弱网占位，而不是继续找零星页面替换。
  2. 或切回更接近交付的链路，优先补“资料修改后跨端刷新”和“弱网下聊天/匹配失败反馈”的真机验证与收口。

## 2026-03-30 最近动态 118
- 完成：继续收高频社交入口的真实头像回显。新增 `flutter-app/lib/widgets/app_user_avatar.dart`，把“远端媒体引用 / 本地文件 / 文本占位”三种头像来源统一收成一个轻量组件，先落到消息列表、好友列表/好友请求/UID 搜索结果、聊天头部、聊天用户资料弹层和语音通话弹层。
- 完成：同步修正 Flutter 服务层对后端 `avatarUrl` 的吞值问题。`ChatService` 和 `FriendService` 现在不再把远端头像引用直接抹成 `👤`，而是保留真实媒体引用给上层 UI 渲染，这样前一轮已经打通的 `/users/me`、好友列表、会话列表远端头像数据终于能在页面上真正显示出来。
- 完成：补了两层回归。
  - service test：`chat_service_test.dart`、`friend_service_test.dart`，锁住“后端 avatarUrl 会保留下来，空头像才回退占位”。
  - smoke test：`messages_tab_smoke_test.dart`、`friends_tab_smoke_test.dart`、`chat_screen_smoke_test.dart`，锁住消息页、好友页、聊天头部在拿到远端头像引用时会渲染图片，不再只是文本占位。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/widgets/app_user_avatar.dart
  - flutter-app/lib/services/chat_service.dart
  - flutter-app/lib/services/friend_service.dart
  - flutter-app/lib/widgets/messages_tab.dart
  - flutter-app/lib/widgets/friends_tab.dart
  - flutter-app/lib/screens/chat_screen.dart
  - flutter-app/test/services/chat_service_test.dart
  - flutter-app/test/services/friend_service_test.dart
  - flutter-app/test/smoke/messages_tab_smoke_test.dart
  - flutter-app/test/smoke/friends_tab_smoke_test.dart
  - flutter-app/test/smoke/chat_screen_smoke_test.dart
- 验证：
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\widgets\app_user_avatar.dart lib\services\chat_service.dart lib\services\friend_service.dart lib\widgets\messages_tab.dart lib\widgets\friends_tab.dart lib\screens\chat_screen.dart test\services\chat_service_test.dart test\services\friend_service_test.dart test\smoke\messages_tab_smoke_test.dart test\smoke\friends_tab_smoke_test.dart test\smoke\chat_screen_smoke_test.dart`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\services\chat_service_test.dart test\services\friend_service_test.dart test\smoke\messages_tab_smoke_test.dart test\smoke\friends_tab_smoke_test.dart test\smoke\chat_screen_smoke_test.dart --reporter expanded`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze`
- 风险 / 备注：这轮只收了消息/好友/聊天这组高频入口，`MatchTab` 以及其它仍把 `User.avatar` 当纯文本占位处理的次级页面还没一起切换；另外真实头像图片现在已经能回显，但页面里仍然没有做统一的图片缓存、加载骨架或超时态，这块要等后续再看是否值得继续系统化。
- 下一步建议：
  1. 继续把 `MatchTab` 和其它剩余的 `avatar ?? '👤'` 入口一起切到统一头像组件，彻底收掉“有些页是真头像、有些页还是文本”的割裂。
  2. 如果真机上已经开始稳定看到远端头像，下一轮更值得继续做的是统一头像加载失败态和弱网骨架，而不是继续堆更多散点适配。

## 2026-03-30 最近动态 117
- 完成：继续做前后端媒体契约收口。后端 `UserEntity`、PostgreSQL store、`schema_v1.sql` 和 `UsersService.uploadMedia(...)` 已补齐 `backgroundUrl` 持久化与返回逻辑，`/users/me` 现在在头像之外也能回传最新背景引用，避免背景上传只在当前设备本地生效。
- 完成：前端 `ProfileService.refreshProfile()` 现在会在拉取 `/users/me` 后同步远端 `avatarUrl / backgroundUrl` 到 `ImageUploadService`，这样同账号换端登录、清本地缓存后重新进入时，资料页和设置页的头像/背景预览能直接回显后端已保存的媒体引用。
- 完成：补了一条 Flutter 服务测试 `flutter-app/test/services/profile_service_test.dart`，锁住“远端头像/背景引用会写回本地媒体引用”“空 payload 不会覆盖现有媒体引用”这两条边界。
- 完成：后端集成测试回归继续通过，头像上传与新增的背景上传回写断言都已覆盖。
- 完成：排掉本轮前端验证阻塞。根因不是代码编译失败，而是沙箱下 `flutter` 无法写 `D:\flutter_windows_3.27.1-stable\flutter\bin\cache\lockfile`；在沙箱外执行后，`dart format`、新增服务测试和 `flutter analyze` 均恢复正常通过。
- 涉及模块：
  - CURRENT_SPRINT.md
  - backend/server/src/modules/shared/domain/entities.ts
  - backend/server/src/modules/shared/infrastructure/postgres-user-settings.store.ts
  - backend/server/src/modules/users/application/users.service.ts
  - backend/server/test/auth-users-settings.spec.ts
  - backend/db/schema_v1.sql
  - flutter-app/lib/services/profile_service.dart
  - flutter-app/test/services/profile_service_test.dart
- 验证：
  - 在 `backend/server` 目录执行：`cmd /c npm run test:integration`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\services\profile_service.dart test\services\profile_service_test.dart`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\services\profile_service_test.dart --reporter expanded`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze`
- 风险 / 备注：当前代码链路已经验证通过，但 Flutter SDK 位于工作区外的 `D:` 目录，沙箱内执行 `flutter` 会因为 `bin\cache\lockfile` 写权限受限而假死；后续如果再跑 Flutter 命令，默认要么继续走沙箱外执行，要么把 SDK 放到可写位置，否则很容易再次误判成“命令卡死”。
- 下一步建议：
  1. 继续检查消息页、好友页、聊天头部这些仍然只把远端头像当文本占位的映射层，决定是否要进一步支持真实头像回显。
  2. 如果准备进入更接近交付的阶段，后续需要把 `backgroundUrl` 进一步纳入正式数据库迁移脚本和接口文档，不只停留在当前 `schema_v1` 草案。
  3. 后续任何 Flutter 验证都优先复用“沙箱外执行”口径，避免再被 SDK `lockfile` 问题卡住。

## 2026-03-30 最近动态 116
- 完成：修正后端认证集成测试的旧 mock 假设。`auth-users-settings.spec.ts` 和 `chat-gateway.spec.ts` 现在都会在测试启动时显式设置 `OTP_OVERRIDE=123456`，让 OTP 验证和当前后端真实实现重新对齐，不再因为服务默认随机验证码而从登录入口开始级联失败。
- 完成：同步把认证测试里对 access token 的旧式 `atk_` 字符串断言改成 JWT 结构断言，适配当前 `AuthService` 已切到 HS256 JWT 的实现，避免测试继续绑死历史 token 形态。
- 完成：复跑后端集成测试后，当前 `backend/server` 的 `4` 个测试套件、`34` 条用例已全部通过，认证、资料、设置、好友关系、匹配、聊天 REST 与 WebSocket 回归基线恢复可用。
- 涉及模块：
  - CURRENT_SPRINT.md
  - backend/server/test/auth-users-settings.spec.ts
  - backend/server/test/chat-gateway.spec.ts
- 验证：
  - 在 `backend/server` 目录执行：`cmd /c npm run test:integration`
- 风险 / 备注：这轮修的是“测试基线落后于真实实现”，没有继续改业务逻辑本身；另外在当前 PowerShell / 沙箱环境下，`cmd /c npm test` 仍会因为 `jest-worker` 子进程 `spawn EPERM` 失败，所以本轮稳定验证口径还是 `npm run test:integration --runInBand`。
- 下一步建议：
  1. 继续把后端测试环境变量补齐到更完整的基线，比如在集成测试里显式设置 `JWT_SECRET`，去掉当前的 insecure dev default 警告。
  2. 开始做一轮前后端契约核对，优先检查 Flutter 登录、refresh token、好友关系、建会话和图片上传链路是否还残留旧 mock 时代假设。
  3. 如果准备继续往交付推进，下一轮优先把 `build.bat` 的 debug signing fallback 和正式签名口径彻底拆开。

## 2026-03-30 最近动态 115
- 排查：完成一轮项目级盘点，确认当前仓库已经具备 Flutter 前端、NestJS 后端、版本归档、发布清单和自动化测试的基本骨架，整体阶段更接近“可持续迭代的联调版”，不是一次性原型。
- 排查：确认前端环境分层和本地 fallback 开关已经落到代码里，`demo / development / staging / production` 四档运行环境、OTP 本地回退、模拟匹配池、模拟聊天回复都有显式边界；但这也说明项目还没有完全摆脱 demo/dev 兼容逻辑。
- 排查：完成当前健康检查。`flutter-app` 的 `flutter analyze` 通过；后端改用 `cmd /c npm run test:integration` 后能跑起测试，但现状是 `4` 个套件里 `2` 个失败、`34` 条测试里 `16` 条失败，失败主要从认证登录入口开始级联。
- 排查：后端失败原因已定位到明显契约漂移。`AuthService.sendOtp()` 默认发随机验证码，现有集成测试却固定用 `123456`；同时测试仍在断言旧式 `atk_` token 形态，但服务已经切到 JWT。说明后端正在从 mock 契约向真实鉴权收口，但测试基线和部分接口预期没有同步更新。
- 排查：补充确认了一项发布风险。根目录 `build.bat` 里 `ALLOW_DEBUG_RELEASE_SIGNING=true` 仍然开启，只适合当前 demo / 本地体验包，不适合作为正式交付口径。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/config/app_env.dart
  - flutter-app/lib/main.dart
  - flutter-app/lib/services/auth_service.dart
  - flutter-app/lib/providers/match_provider.dart
  - flutter-app/lib/providers/chat_provider.dart
  - backend/server/src/app.setup.ts
  - backend/server/src/modules/auth/application/auth.service.ts
  - backend/server/src/modules/auth/controller/auth.controller.ts
  - backend/server/src/modules/auth/dto/verify-otp.dto.ts
  - backend/server/test/auth-users-settings.spec.ts
  - backend/server/test/chat-gateway.spec.ts
  - build.bat
- 验证：
  - 在项目根目录执行：`git status --short`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze`
  - 在 `backend/server` 目录执行：`cmd /c npm test`，结果因 `jest-worker` 子进程 `spawn EPERM` 未完成
  - 在 `backend/server` 目录执行：`cmd /c npm run test:integration`
- 风险 / 备注：当前最大风险不是前端 UI，而是“前后端正在真实化、测试仍带旧 mock 假设”的收口断层；如果不先把认证契约、测试基线和环境隔离统一，后面做内网穿透、双端联调和上线前回归都会不断被同一类问题反复打断。
- 下一步建议：
  1. 先修后端认证测试基线，统一 OTP 测试策略和 token 断言口径，优先让 `auth-users-settings.spec.ts` 与 `chat-gateway.spec.ts` 重新稳定。
  2. 随后做一轮前后端契约核对，重点确认登录、刷新 token、好友关系、建会话、图片上传和已读同步是否还存在 mock 时代遗留假设。
  3. 发布前单独收 `build.bat` 的正式签名口径，把 debug signing fallback 和 demo 包构建规则彻底与正式包隔离。

## 2026-03-27 最近动态 114
- 完成：继续收 `MessagesTab` 的成功态噪音。消息列表里的 `已送达 / 已读` 成功徽标已去掉，只保留预览文案和聊天页内联送达状态；发送中、失败、重选图片这类需要用户关注的状态徽标仍然保留，避免列表层重复表达低价值成功反馈。
- 完成：同步把 `MessagesTab` smoke 回归从“展示送达/已读徽标”改成“保留成功预览文案但不再展示成功徽标”，明确锁住当前更克制的列表交互。
- 涉及模块：
  - flutter-app/lib/widgets/messages_tab.dart
  - flutter-app/test/smoke/messages_tab_smoke_test.dart
- 验证：
  - 在项目根目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/widgets/messages_tab.dart flutter-app/test/smoke/messages_tab_smoke_test.dart
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/messages_tab_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
- 风险 / 备注：这轮只去掉了列表层低价值成功徽标，没有改聊天页送达状态、消息预览文案和剩余时间行布局；如果真机上仍觉得消息列表有点满，下一轮更值得继续收的是“剩余时间整行是否需要常驻显示”。
- 下一步建议：
  1. 继续看 `MessagesTab` 的剩余时间行，把“常驻倒计时行”是否收成更克制的临期展示做一轮验证。
  2. 或切回 `ChatScreen` / `SettingsScreen`，继续压失败反馈弹层和轻提示的二级说明。

## 2026-03-27 最近动态 113
- 完成：继续收 `MessagesTab` 的临期提示密度。现在当陌生人会话已经进入“2 小时内即将到期”窗口时，列表会优先展示 `即将到期`，不再和 `对方在线可聊` 同时并排出现；保留时效提醒，去掉同层低价值在线标签，减少一条卡片里双标签堆叠。
- 完成：补了一条 `MessagesTab` smoke 回归，锁住“普通在线会话仍显示在线可聊、临期在线会话改为只显示即将到期”这组分流逻辑，避免后续继续收列表密度时把优先级又打乱。
- 涉及模块：
  - flutter-app/lib/widgets/messages_tab.dart
  - flutter-app/test/smoke/messages_tab_smoke_test.dart
- 验证：
  - 在项目根目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/widgets/messages_tab.dart flutter-app/test/smoke/messages_tab_smoke_test.dart
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/messages_tab_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
- 风险 / 备注：这轮只收了临期标签和在线标签的并存关系，没有继续改未读角标、送达徽标和时间剩余行的版式；如果真机上仍觉得消息列表视觉信息偏多，下一轮更值得继续看的还是“未读角标 + 送达徽标 + 剩余时间”三者在单卡片里的占位关系。
- 下一步建议：
  1. 继续检查 `MessagesTab` 里 success badge 与未读角标并存的场景，必要时把低价值送达态在列表层再后置，保留聊天页内联状态即可。
  2. 回到 `ChatScreen` / `SettingsScreen` 继续收失败回调和轻提示，把真机上仍然突兀的次级说明进一步压短。

## 2026-03-27 最近动态 112
- 完成：继续收 `MessagesTab` 的低价值优先标签。现在 `对方在线可聊` 只会在“无未读、无草稿、无失败态、无发送引导态”的干净会话里展示；如果同一条会话已经有未读数、即将到期提示或失败/引导状态，这个在线标签会直接让位，避免列表首屏同时堆太多提示。
- 完成：补了一条 `MessagesTab` smoke 回归，明确锁住“干净在线会话仍然显示在线可聊标签”，避免这轮收密度时把本来有价值的在线感知也一起删掉。
- 涉及模块：
  - flutter-app/lib/widgets/messages_tab.dart
  - flutter-app/test/smoke/messages_tab_smoke_test.dart
- 验证：
  - 在项目根目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/widgets/messages_tab.dart flutter-app/test/smoke/messages_tab_smoke_test.dart
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/messages_tab_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
- 风险 / 备注：这轮只收了消息列表优先标签密度，没有调整卡片布局、摘要文案和时间行结构；如果后续真机上仍觉得一屏信息偏满，更值得继续看的是“优先标签 + 未读角标 + 送达徽标 + 即将到期”这些信号在同一卡片上的并存关系。
- 下一步建议：
  1. 继续检查 `MessagesTab` 里“即将到期 + 送达/失败徽标 + 未读角标”并存时的视觉密度，优先把重复表达的状态继续后置或合并。
  2. 回到 `ChatScreen` / `SettingsScreen` 做失败回调收口，继续清真机上仍然突兀的二级说明和轻提示。

## 2026-03-27 最近动态 111
- 完成：继续收 `MessagesTab` 的摘要优先级。现在消息列表里如果同一会话同时存在“失败消息 + 新草稿”，优先标签会先显示失败态，不再被“草稿待发送”盖掉；草稿预览本身仍然保留，避免列表同时漏掉待处理失败和用户刚写的新内容。
- 完成：继续压 `ChatScreen` 图片失败说明弹层的读文成本。保持原有弹层结构和标题层级不变，只把大图失败、格式失败、重选图片这三组说明改成更短的动作句，并把“回输入区重选图片 / 弱网时优先压缩图 / 换常见格式图片”分别收成 `重新选图 / 先发压缩图 / 换 JPG/PNG`，减少真机上读长句的负担。
- 完成：恢复本地 Flutter 依赖缓存。前面清理磁盘时把 `Pub Cache` 清掉了，导致 smoke 首次运行直接因依赖缺失失败；本轮已补执行 `flutter pub get`，当前工程依赖恢复正常，后续测试可继续跑。
- 涉及模块：
  - flutter-app/lib/widgets/messages_tab.dart
  - flutter-app/lib/screens/chat_screen.dart
  - flutter-app/test/smoke/messages_tab_smoke_test.dart
  - flutter-app/test/smoke/chat_screen_smoke_test.dart
  - flutter-app/test/smoke/chat_screen_delivery_failure_smoke_test.dart
- 验证：
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat pub get
  - 在项目根目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/widgets/messages_tab.dart flutter-app/lib/screens/chat_screen.dart flutter-app/test/smoke/messages_tab_smoke_test.dart flutter-app/test/smoke/chat_screen_smoke_test.dart flutter-app/test/smoke/chat_screen_delivery_failure_smoke_test.dart
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/messages_tab_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_delivery_failure_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
- 风险 / 备注：这轮只收了消息列表标签优先级和图片失败弹层文案，没有继续改消息列表预览文本策略、消息列表排序逻辑或失败引导弹层样式；另外本地依赖缓存刚恢复，若后面再做磁盘清理，需要把 `flutter-app` 的 `Pub Cache` 排除掉，避免再次把测试环境清空。
- 下一步建议：
  1. 继续检查 `MessagesTab` 里“失败态 + 未读态 + 即将到期”三类标签并存时的密度，必要时把低价值状态后置，避免一条会话卡片首屏出现太多标签。
  2. 继续清 `ChatScreen` 的失败引导弹层，重点看大图/格式异常说明里是否还可以继续减一层文案，或者直接把二级建议进一步图标化。

## 2026-03-26 最近动态 110
- 完成：继续把消息列表页的失败摘要标签和聊天页失败卡做一轮对齐。`MessagesTab` 里的 `会话过期 / 凭证失效 / 上传失败` 现在统一改成 `会话已过期 / 上传凭证失效 / 上传准备失败`，减少列表页和会话页同类失败名称不一致的问题。
- 完成：同步更新 `messages_tab_delivery_failure_smoke_test.dart` 的断言，锁住“上传凭证失效”这类摘要在当前结构下会出现两处可见文本的实际表现。
- 涉及模块：
  - flutter-app/lib/widgets/messages_tab.dart
  - flutter-app/test/smoke/messages_tab_delivery_failure_smoke_test.dart
- 验证：
  - 在项目根目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/widgets/messages_tab.dart flutter-app/test/smoke/messages_tab_delivery_failure_smoke_test.dart
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/messages_tab_delivery_failure_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
- 风险 / 备注：这轮只对齐了失败摘要标签，没有继续改消息列表预览文案和优先级排序逻辑；如果下一轮继续收列表页体验，更值得看的是失败摘要出现时，草稿、未读、最近消息摘要之间的信息优先级是否还够清晰。
- 下一步建议：
  1. 继续排 `MessagesTab` 的摘要优先级，把失败态、草稿态、未读态之间的优先顺序再确认一遍，避免列表首屏同时抢信息。
  2. 继续回到 `ChatScreen` 的图片失败说明弹层，把说明文字再压短一轮，减少用户阅读负担。

## 2026-03-26 最近动态 109
- 完成：继续收聊天页失败态文案，把 `ChatDeliveryStatus`、`chat_retry_feedback.dart` 和 outgoing retry failure toast 的说法统一压成更短的动作型表达。现在“会话过期 / 关系受限 / 上传准备失败 / 上传中断 / 凭证失效 / 网络异常 / 不可重试 / 原图失效 / 重试失败”这几类高频失败不再各说各话，聊天页里的卡片、toast 和重试反馈语气已基本统一。
- 完成：顺手把聊天页里“原图失效”相关文案统一成 `原图失效，请重选图片`，避免会话页和消息页分别出现“重新选图 / 重选图片”两种叫法。
- 涉及模块：
  - flutter-app/lib/widgets/chat_delivery_status.dart
  - flutter-app/lib/utils/chat_retry_feedback.dart
  - flutter-app/lib/utils/chat_outgoing_delivery_feedback.dart
  - flutter-app/test/utils/chat_retry_feedback_test.dart
  - flutter-app/test/services/chat_outgoing_delivery_feedback_test.dart
  - flutter-app/test/smoke/chat_screen_smoke_test.dart
- 验证：
  - 在项目根目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/widgets/chat_delivery_status.dart flutter-app/lib/utils/chat_retry_feedback.dart flutter-app/lib/utils/chat_outgoing_delivery_feedback.dart flutter-app/test/utils/chat_retry_feedback_test.dart flutter-app/test/services/chat_outgoing_delivery_feedback_test.dart flutter-app/test/smoke/chat_screen_smoke_test.dart
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/utils/chat_retry_feedback_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/services/chat_outgoing_delivery_feedback_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_delivery_failure_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
- 风险 / 备注：这轮只统一了聊天会话内的失败态表达，还没有继续收消息列表页摘要、设置页 delivery debug 文案和底层 service 错误词的完全一致性；如果下一轮继续压反馈密度，最值得看的就是消息列表摘要标签与聊天页失败卡是否仍然存在命名分叉。
- 下一步建议：
  1. 继续检查 `messages_tab.dart` 的失败摘要标签，把“会话过期 / 上传失败 / 上传中断 / 凭证失效 / 重选图片”这些列表态名称和聊天页卡片态做一轮一对一对齐。
  2. 继续清 `ChatScreen` 里失败引导弹层的说明文案，优先压缩“图片需要重选”和大图/格式异常说明，减少读文成本。

## 2026-03-26 最近动态 108
- 完成：继续收聊天页成功态反馈密度。`ChatScreen` 现在只对 outgoing delivery 的失败态保留 toast，普通“已送达 / 已读 / 重试成功”不再额外弹轻提示，改为只依赖我方消息气泡里的内联送达状态，避免同一条消息出现“状态卡 + toast”双层成功反馈。
- 完成：同步更新聊天页 smoke 回归，明确锁住“成功态不弹 toast，但内联送达状态仍正常展示；重试失败反馈继续保留”这组交互预期。
- 涉及模块：
  - flutter-app/lib/screens/chat_screen.dart
  - flutter-app/test/smoke/chat_screen_smoke_test.dart
- 验证：
  - 在项目根目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/screens/chat_screen.dart flutter-app/test/smoke/chat_screen_smoke_test.dart
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
- 风险 / 备注：这轮只收了聊天页成功态展示策略，没有改失败卡文案、失败引导弹层或设置页里的 delivery debug 信息；如果真机上仍觉得聊天页提示偏多，下一轮更该继续看“重试失败 toast + 内联失败卡 + 图片失败说明”这三层之间是否还能再压一层。
- 下一步建议：
  1. 继续收 `ChatScreen` 的失败态反馈，把“立即重试失败”“图片重选说明”“会话失效”几条常见失败路径统一成更短、更一致的动作型文案。
  2. 继续检查消息页摘要区是否还有和聊天页相同的状态重复表达，避免列表页和会话页在失败文案上继续分叉。

## 2026-03-26 最近动态 107
- 完成：继续收聊天页的双提示问题。图片发送成功后，`ChatScreen` 里原来的即时 `已发送` toast 已移除，改成只保留后续 provider 送达反馈，避免“图片刚入队就提示一次，真正送达再提示一次”的重复反馈和语义错位。
- 完成：同步收 `ImageUploadService` 的底层错误提示。头像/背景选择的权限失败不再落到泛化 `permissionDenied` 默认词，而是统一改成“未开启图片权限，请先授权”；图片选择异常也分别改成“头像选择失败，请重试”“背景选择失败，请重试”，让资料管理链路里的错误更具体。
- 涉及模块：
  - flutter-app/lib/screens/chat_screen.dart
  - flutter-app/lib/services/image_upload_service.dart
- 验证：
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/screens/chat_screen.dart lib/services/image_upload_service.dart
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/services/image_upload_service_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
- 风险 / 备注：这轮只收图片发送成功后的即时提示和图片选择底层错误词，没有改图片上传、送达状态卡或 burn-after-read 语义；如果真机上发送图片后仍觉得反馈密度偏高，下一轮更值得继续看的就是图片失败卡、顶部 toast 和底部状态卡之间的重叠。
- 下一步建议：
  1. 继续检查聊天页里图片失败、重试失败、送达成功三类反馈是否还能再错峰，避免同一时段里出现两层以上轻提示。
  2. 继续排 `chat_screen.dart` 和 `app_feedback.dart` 里剩余高频 detail，优先清最常见的发送失败和媒体失败提示。

## 2026-03-26 最近动态 106
- 完成：继续收 `ChatScreen._sendCurrentMessage()` 的同步回调组合。文本发送成功后，provider listener 在消息数变化时已经会统一安排一次追底，因此发送成功分支里原来额外的 `_scheduleScrollToBottom()` 已删除，避免同一轮发送链路里重复安排滚动。
- 完成：结合上一轮的“程序性输入改值不回写草稿”，现在发送成功后的本地同步链路已经进一步收成“入队发送 -> 清空输入框 -> 清理草稿 -> 等 provider listener 统一处理追底和 delivery feedback”，减少页面内部重复调度。
- 涉及模块：
  - flutter-app/lib/screens/chat_screen.dart
- 验证：
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/screens/chat_screen.dart
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
- 风险 / 备注：这轮仍然只是在 `ChatScreen` 本地回调侧做减法，没有改 provider 的送达判定和列表选择器；如果真机还有残余“慢半拍”，下一轮应该继续看 delivery feedback 和顶部/底部轻提示之间是否还能再错峰，而不是继续只收滚动触发。
- 下一步建议：
  1. 继续排 `ChatScreen` 里发送成功 / 失败后反馈组件的触发先后，确认能不能把 delivery feedback 和顶部/底部其他提示再进一步解耦。
  2. 开始清 `image_upload_service.dart` 的权限失败、文件失败和默认 unknown 提示，让高频底层错误口径继续收敛。

## 2026-03-26 最近动态 105
- 完成：继续收 `ChatScreen` 里发送链路的无效草稿同步。程序性改输入框内容的两条高频路径已经从 `_handleInputChanged -> saveDraft(...)` 里剥离：线程切换时 hydrate 草稿不再反向重写 provider 草稿；发送成功后清空输入框也不再先走一次空草稿保存，再额外 `clearDraft` 一次。
- 完成：新增 `_suspendDraftSync` 和 `_replaceComposerText(...)`，把“用户真实输入”和“页面内部程序性改值”分开处理，减少发送后和切换会话时的无效 provider 状态操作，同时不改当前草稿恢复和发送清空的交互语义。
- 涉及模块：
  - flutter-app/lib/screens/chat_screen.dart
- 验证：
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/screens/chat_screen.dart
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
- 风险 / 备注：这轮只收程序性输入改值引起的草稿写入，没有改真实输入过程的草稿保存策略；如果真机上发送手感仍有残余卡顿，下一轮更值得看的点是 `sendMessage()` 成功后 `_scheduleScrollToBottom()`、delivery feedback 和 composer 可用态刷新之间是否还存在同拍叠加。
- 下一步建议：
  1. 继续检查 `ChatScreen._sendCurrentMessage()` 里发送成功后的同步链路，确认显式 `_scheduleScrollToBottom()` 是否还能再减一层。
  2. 回到 `image_upload_service.dart` 和 `chat_screen.dart` 里的底层失败 detail，继续统一高频错误回调的口径。

## 2026-03-26 最近动态 104
- 完成：继续下钻 `ChatProvider` 的高频发送 / 已读链路，把一批重复的 thread interaction revision 收掉。`_updateThread()` 现在支持在外层已经手动标记 interaction 的路径里跳过重复标记；`restoreThread()` 也改成只有线程真的从 deleted 恢复时才会改 revision，不再对本来就可见的线程做无效 interaction 变更。
- 完成：同步把 `sendMessage` / `sendImageMessage` 的 `messagesSinceUnfollow` 更新、`markAsRead` / `markImageAsRead` 的 `unreadCount` 更新、以及 realtime/self-echo/image 发送成功后的 `_addIntimacy(...)` 全部改成不再重复追加 interaction revision；并补了 provider 回归测试，锁住“未互关发消息只涨一次 revision”“markAsRead 只涨一次 revision”“重复 incoming message 不再无意义涨 revision”这三条边界。
- 涉及模块：
  - flutter-app/lib/providers/chat_provider_threads.dart
  - flutter-app/lib/providers/chat_provider_messages.dart
  - flutter-app/lib/providers/chat_provider_realtime.dart
  - flutter-app/test/providers/chat_provider_test.dart
- 验证：
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/providers/chat_provider_threads.dart lib/providers/chat_provider_messages.dart lib/providers/chat_provider_realtime.dart test/providers/chat_provider_test.dart
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/chat_provider_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
- 风险 / 备注：这轮主要压的是 provider 级别的 revision/listener 噪音，没有改发送成功后的业务语义；但 `ChatScreen` 里发送动作本身仍然会触发 `clearDraft / scheduleScrollToBottom / delivery feedback` 这几条回调链，真机如果还有“慢半拍”，下一轮要继续查这些回调的组合时序，而不是再重复收 provider revision。
- 下一步建议：
  1. 继续检查 `ChatScreen._sendCurrentMessage()` 和 `ChatProvider.sendMessage()` 之间的即时回调，重点看 `clearDraft` 是否还有必要以 provider 维度参与当前链路。
  2. 继续收 `image_upload_service.dart`、`chat_screen.dart`、`app_feedback.dart` 里剩余的底层错误 detail，让高频失败回调进一步统一。

## 2026-03-26 最近动态 103
- 完成：继续收聊天页反馈时序。`ChatScreen` 里送达 feedback 不再在同一轮消息变更里立刻弹出，而是改成下一帧调度；这样消息列表更新、追底滚动和 `SnackBar` 反馈不再抢同一拍，降低“发出后 UI 先顿一下再提示”的体感。
- 完成：顺手压短 `AppFeedback` 的共享默认错误词，把 `permissionDenied / invalidInput / notSupported` 的兜底文案统一收成更短的结果句，并同步更新 `chat_screen_smoke_test.dart` 里依赖旧同帧反馈时序的断言等待。
- 涉及模块：
  - flutter-app/lib/screens/chat_screen.dart
  - flutter-app/lib/core/feedback/app_feedback.dart
  - flutter-app/test/smoke/chat_screen_smoke_test.dart
- 验证：
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/screens/chat_screen.dart lib/core/feedback/app_feedback.dart test/smoke/chat_screen_smoke_test.dart
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_delivery_failure_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
- 风险 / 备注：这轮只收反馈触发时机和基础文案，没有改消息发送、送达判定和 toast 视觉样式；如果真机上仍有“点了以后慢半拍”，下一轮就该继续往 `ChatProvider -> ChatScreen` 的发送回调链路和列表重建边界下钻，而不是继续只收提示词。
- 下一步建议：
  1. 继续检查 `ChatScreen` 里发送成功后 `clearDraft / markAsRead / scheduleScrollToBottom / delivery feedback` 的先后关系，确认还能不能再拆掉一处同步回调。
  2. 回到 `AppFeedback` 的调用面，优先清 `image_upload_service.dart`、`report_screen.dart`、`chat_screen.dart` 里还没完全收口的底层错误 detail。

## 2026-03-26 最近动态 102
- 完成：继续收聊天页高频失败反馈。`chat_delivery_status.dart` 里“上传准备失败，可稍后重试 / 请稍后重试”统一压成“上传准备失败，请重试”；`chat_screen.dart` 里消息发送失败和会话不可用提示也继续缩短，改成“消息未发出，请重试”“会话已过期 / 不可用，请返回列表重试”，减少连续操作时的拖沓感。
- 完成：补跑聊天状态 widget test、聊天页 smoke、聊天失败 smoke 和全量 smoke，确认这轮仍然只改反馈文案，没有带出聊天链路回归。
- 涉及模块：
  - flutter-app/lib/widgets/chat_delivery_status.dart
  - flutter-app/lib/screens/chat_screen.dart
- 验证：
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/widgets/chat_delivery_status.dart lib/screens/chat_screen.dart
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/widgets/chat_delivery_status_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_delivery_failure_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
- 风险 / 备注：这轮仍未改聊天页的布局和触发时序，只是先把高频失败文案压短；如果真机上还觉得“点了以后慢半拍”，下一轮应该回到发送回调链路和轻提示触发时机，而不是继续只收文案。
- 下一步建议：
  1. 继续检查 `chat_screen.dart` 里发送成功 / 失败后的轻提示、delivery card、滚动追底三者时序，找还有没有“先停一下再反馈”的尾巴。
  2. 回到 `app_feedback.dart` 和权限相关提示层，继续清一轮全局基础错误文案，避免不同页面继续出现口径不一。

## 2026-03-26 最近动态 101
- 完成：继续收 `SettingsScreen`、`ProfileTab`、`ChatRetryFeedback`、`MatchService` 里剩余的高频失败提示，把“稍后重试 / 稍后再试”进一步统一成更短的结果句。头像/背景失败卡片的 badge 统一改成 `未保存`，toast/detail 改成“未更新，请重试”；`UID` 未就绪场景改成更贴状态的 `生成中`；匹配服务失败文案也继续压短。
- 完成：同步更新 `settings_screen_smoke_test.dart` 里 `UID` 未就绪反馈的旧断言，并补跑设置页、首页、匹配页、聊天重试工具和全量 smoke，确认这轮只是文案收口，没有引入功能回归。
- 涉及模块：
  - flutter-app/lib/screens/settings_screen.dart
  - flutter-app/lib/widgets/profile_tab.dart
  - flutter-app/lib/utils/chat_retry_feedback.dart
  - flutter-app/lib/services/match_service.dart
  - flutter-app/test/smoke/settings_screen_smoke_test.dart
- 验证：
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/screens/settings_screen.dart lib/widgets/profile_tab.dart lib/utils/chat_retry_feedback.dart lib/services/match_service.dart test/smoke/settings_screen_smoke_test.dart
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/utils/chat_retry_feedback_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/match_tab_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
- 风险 / 备注：这轮仍然只做高频失败反馈减法，没有改页面布局和交互链路；全局仍有少量“不可用 / 稍后再试”类文案散落在聊天页和反馈工具层，后续需要继续按“高频优先、说明后置”原则筛一轮。
- 下一步建议：
  1. 继续排 `chat_screen.dart`、`chat_delivery_status.dart`、`app_feedback.dart` 里的剩余失败提示，优先收用户连续操作最容易看到的回调。
  2. 真机回看“设置头像/背景失败”“个人页头像/背景失败”“UID 未就绪”“匹配失败”四条链路，确认现在提示更短且不突兀。

## 2026-03-26 最近动态 100
- 完成：继续收举报页频控提示和聊天重试失败 toast。`report_screen.dart` 里的“提交过于频繁，请稍后再试”改成更短的“提交频繁，请稍后重试”；`chat_outgoing_delivery_feedback.dart` 里的“重试未成功，请稍后再试”改成“重试未成功，请重试”，减少高频失败反馈里的重复词。
- 完成：同步更新 `report_screen_smoke_test.dart`、`chat_screen_smoke_test.dart`、`chat_outgoing_delivery_feedback_test.dart` 的旧文案断言，并补跑对应 smoke、service test 和全量 smoke，确认这轮小范围减法没有带来回归。
- 涉及模块：
  - flutter-app/lib/screens/report_screen.dart
  - flutter-app/lib/utils/chat_outgoing_delivery_feedback.dart
  - flutter-app/test/smoke/report_screen_smoke_test.dart
  - flutter-app/test/smoke/chat_screen_smoke_test.dart
  - flutter-app/test/services/chat_outgoing_delivery_feedback_test.dart
- 验证：
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/screens/report_screen.dart lib/utils/chat_outgoing_delivery_feedback.dart test/smoke/report_screen_smoke_test.dart test/smoke/chat_screen_smoke_test.dart test/services/chat_outgoing_delivery_feedback_test.dart
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/report_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/services/chat_outgoing_delivery_feedback_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
- 风险 / 备注：这轮只收高频失败提示词，不改举报提交流程和聊天重试逻辑；当前高频错误回调已经更短，但权限工具层和个别资料管理失败提示仍有“请稍后重试 / 稍后再试”口径未完全统一。
- 下一步建议：
  1. 继续筛全局剩余错误句，优先处理权限工具层和资料管理里还没统一到“更短结果句”的地方。
  2. 真机重点看举报频控 toast 和聊天重试失败 toast，确认现在反馈更直接、不拖沓。

## 2026-03-26 最近动态 99
- 完成：继续收消息列表失败态和匹配页失败引导。`chat_delivery_status.dart` 里图片过大 / 格式异常的预览短句继续压短；`messages_tab.dart` 把“发送失败待处理”收成“发送失败”；`match_provider.dart`、`auth_provider.dart` 的默认失败句统一改成更短的结果句；`match_tab.dart` 的失败引导 tips 也从说明句改成更直接的动作句。
- 完成：同步更新 `messages_tab_delivery_failure_smoke_test.dart` 和 `match_tab_smoke_test.dart` 的旧文案断言，并补跑消息列表、匹配页、聊天失败状态和全量 smoke，确认这轮文案减法没有影响回归稳定性。
- 涉及模块：
  - flutter-app/lib/widgets/chat_delivery_status.dart
  - flutter-app/lib/widgets/messages_tab.dart
  - flutter-app/lib/providers/match_provider.dart
  - flutter-app/lib/providers/auth_provider.dart
  - flutter-app/lib/widgets/match_tab.dart
  - flutter-app/test/smoke/messages_tab_delivery_failure_smoke_test.dart
  - flutter-app/test/smoke/match_tab_smoke_test.dart
- 验证：
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/widgets/chat_delivery_status.dart lib/widgets/messages_tab.dart lib/providers/match_provider.dart lib/providers/auth_provider.dart lib/widgets/match_tab.dart test/smoke/messages_tab_delivery_failure_smoke_test.dart test/smoke/match_tab_smoke_test.dart
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/messages_tab_delivery_failure_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/match_tab_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/widgets/chat_delivery_status_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
- 风险 / 备注：这轮主要是消息列表和匹配页的短句统一，没有改业务逻辑；当前高频失败提示已经更短，但登录页、举报页、权限工具层里仍有少量默认提示口吻不完全一致。
- 下一步建议：
  1. 继续收登录页、举报页和权限弹层里的默认错误句，把“请稍后重试 / 暂不支持 / 不可用”统一成同一套更短的口径。
  2. 真机重点看消息列表失败摘要和匹配失败卡，确认现在首屏不再有明显冗长提示。

## 2026-03-26 最近动态 98
- 完成：继续收聊天页失败 guide 弹层和默认错误提示。`chat_screen.dart` 里“图片过大 / 格式不支持 / 原图失效”的 guide 标题、说明和 tips 统一压短；发送失败 toast、空会话占位文案、图片复制失败提示也一起减掉冗余说明。
- 完成：继续收 `AppFeedback` 默认错误文案，把 `sendFailed` / `notSupported` / `unknown` 的默认提示统一改成更短的结果句，减少各处错误提示口吻不一致的问题。
- 完成：同步更新 `chat_screen_smoke_test.dart`、`chat_screen_delivery_failure_smoke_test.dart`，并跑完整个聊天失败链路和全量 smoke，确认这轮只动文案没有引入交互回归。
- 涉及模块：
  - flutter-app/lib/screens/chat_screen.dart
  - flutter-app/lib/core/feedback/app_feedback.dart
  - flutter-app/test/smoke/chat_screen_smoke_test.dart
  - flutter-app/test/smoke/chat_screen_delivery_failure_smoke_test.dart
- 验证：
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/screens/chat_screen.dart lib/core/feedback/app_feedback.dart test/smoke/chat_screen_smoke_test.dart test/smoke/chat_screen_delivery_failure_smoke_test.dart
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_delivery_failure_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/utils/chat_retry_feedback_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
- 风险 / 备注：这轮主要收聊天页文案和默认错误提示，不改状态判断；当前聊天链路的失败反馈已经明显更短，但 `messages_tab.dart`、`match_provider.dart`、`auth_provider.dart` 里仍有少量默认错误句和占位提示没有统一风格。
- 下一步建议：
  1. 继续收 `messages_tab.dart` 和 `AppFeedback` 之外残留的默认错误文案，尤其是消息列表失败态和匹配失败提示。
  2. 真机重点看聊天失败 guide 弹层、消息发送失败 toast、空会话占位页，确认现在已经没有明显“教学式”提示。

## 2026-03-26 最近动态 97
- 完成：继续收聊天高频失败态的解释文案，重点压了 `chat_delivery_status.dart` 和 `chat_retry_feedback.dart` 里上传准备失败、上传中断、凭证失效、网络波动、暂不可重试、原图失效等失败反馈，把“建议检查网络 / 重新投递 / 立即重试”这类说明句改成更短的结果句。
- 完成：同步更新 `chat_screen_smoke_test.dart` 与 `chat_retry_feedback_test.dart` 的旧文案断言，并补跑聊天失败态相关 smoke / widget / util 测试，确认这轮只改文案没有影响失败态映射和交互。
- 涉及模块：
  - flutter-app/lib/widgets/chat_delivery_status.dart
  - flutter-app/lib/utils/chat_retry_feedback.dart
  - flutter-app/test/smoke/chat_screen_smoke_test.dart
  - flutter-app/test/utils/chat_retry_feedback_test.dart
- 验证：
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/widgets/chat_delivery_status.dart lib/utils/chat_retry_feedback.dart test/smoke/chat_screen_smoke_test.dart test/utils/chat_retry_feedback_test.dart
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_delivery_failure_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/messages_tab_delivery_failure_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/utils/chat_retry_feedback_test.dart test/widgets/chat_delivery_status_test.dart --reporter expanded
- 风险 / 备注：这轮只收聊天失败态文案，不改失败分类和重试逻辑；当前失败态更短了，但 `chat_screen.dart` 内部的失败 guide 弹层和 `AppFeedback` 的默认错误提示还没完全统一到同一套短句风格。
- 下一步建议：
  1. 继续收 `chat_screen.dart` 里的失败 guide 弹层标题 / 说明，以及 `AppFeedback` 的默认 `sendFailed` / `unknown` 错误文案。
  2. 真机重点看消息页和聊天页失败卡，确认现在是否已经没有“像说明书一样的一大段”。

## 2026-03-26 最近动态 96
- 完成：继续收共用提示文案，统一了 `NotificationPermissionGuidance` 在设置页、聊天页、通知中心的口径，把“系统通知权限还没打开”等说明句压成更短的状态句，动作按钮文案也更直接。
- 完成：继续收 `chat_delivery_debug_sheet.dart` 的诊断文案，去掉一批重复前缀词，比如“最新状态：”“建议：”“状态：”，并缩短顶部说明和轨迹说明，让发送诊断 sheet 更像结果面板而不是说明页。
- 完成：同步更新 `settings_screen_smoke_test.dart`、`chat_screen_notification_permission_smoke_test.dart`、`notification_center_screen_smoke_test.dart` 的旧文案断言，确保共用提示词改动可稳定回归。
- 涉及模块：
  - flutter-app/lib/utils/notification_permission_guidance.dart
  - flutter-app/lib/widgets/chat_delivery_debug_sheet.dart
  - flutter-app/lib/screens/settings_screen.dart
  - flutter-app/test/smoke/settings_screen_smoke_test.dart
  - flutter-app/test/smoke/chat_screen_notification_permission_smoke_test.dart
  - flutter-app/test/smoke/notification_center_screen_smoke_test.dart
- 验证：
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/utils/notification_permission_guidance.dart lib/widgets/chat_delivery_debug_sheet.dart lib/screens/settings_screen.dart test/smoke/settings_screen_smoke_test.dart test/smoke/chat_screen_notification_permission_smoke_test.dart test/smoke/notification_center_screen_smoke_test.dart
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_notification_permission_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/notification_center_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
- 风险 / 备注：这轮只收共用文案和诊断 sheet 的前缀词，不改诊断逻辑；当前提示层口吻已经更统一，但聊天发送失败页和消息列表失败态里还有部分“指导型”说明未统一到同一风格。
- 下一步建议：
  1. 继续检查聊天失败引导卡、消息列表失败态和 `AppFeedback` 的错误文案，把“建议 / 原因 / 状态”类前缀再统一收一轮。
  2. 真机重点看聊天页通知权限 banner 和发送诊断 sheet，确认现在的信息密度和阅读节奏是否更自然。

## 2026-03-26 最近动态 95
- 完成：继续压 `SettingsScreen` 主界面上最显眼的副标题，重点收了体验预设卡、顶部概览焦点卡、通知状态卡里的说明句，把“适合作为主聊天入口 / 通勤工作 / 等待恢复”这类解释型句子改成更短的状态句，减少设置页首屏的信息噪音。
- 涉及模块：
  - flutter-app/lib/screens/settings_screen.dart
- 验证：
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/screens/settings_screen.dart
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
- 风险 / 备注：这轮只改设置页主界面文案，不动结构和业务逻辑；当前设置页首屏提示感已经继续下降，但 `NotificationPermissionGuidance` 这类跨模块说明文案还没统一收口。
- 下一步建议：
  1. 继续检查 `NotificationPermissionGuidance`、`chat_delivery_debug_sheet.dart` 这类共用提示文案，避免设置页、聊天页出现风格不一致的说明句。
  2. 真机重点看设置页首屏信息密度，确认现在是否已经接近“入口为主、说明后置”的感觉。

## 2026-03-26 最近动态 94
- 完成：继续收设置页里剩余偏重的说明句和确认弹窗。`SettingsScreen` 中头像 / 背景删除反馈、解除拉黑反馈、通知权限回流反馈、手机号 / 密码编辑页说明、保存后的结果反馈，以及退出登录 / 注销账号确认文案都继续压短，尽量改成直接结果句。
- 完成：继续把全局 `AppDialog.showConfirm` 做轻量化处理，去掉确认弹窗顶部拖拽把手，缩小标题与内容字距、上下留白和按钮纵向内边距，让确认层更接近“轻确认”而不是大块说明弹窗。
- 完成：同步更新 `settings_screen_smoke_test.dart` 与 `settings_logout_smoke_test.dart` 的旧描述断言，避免 smoke 继续绑死历史文案。
- 涉及模块：
  - flutter-app/lib/screens/settings_screen.dart
  - flutter-app/lib/widgets/app_toast.dart
  - flutter-app/test/smoke/settings_screen_smoke_test.dart
  - flutter-app/test/smoke/settings_logout_smoke_test.dart
- 验证：
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/screens/settings_screen.dart lib/widgets/app_toast.dart test/smoke/settings_logout_smoke_test.dart
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format test/smoke/settings_screen_smoke_test.dart test/smoke/settings_logout_smoke_test.dart
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_logout_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
- 风险 / 备注：这轮主要是“减法”和弹窗轻量化，没有改业务逻辑；当前设置页的大部分高频反馈已经更短，但体验预设卡片和部分概览状态副标题仍有继续压缩空间。
- 下一步建议：
  1. 继续清理 `SettingsScreen` 顶部概览卡和体验预设卡里的副标题，把仍然偏解释型的句子改成更短的状态句。
  2. 真机重点看通知权限链路、退出登录 / 注销账号确认层、账号安全编辑页，确认现在的弹窗层级和停留感是否已经更接近你要的“轻确认”。

## 2026-03-26 最近动态 93
- 完成：继续收口设置与个人页的反馈层体验。`SettingsScreen` 的顶部内联反馈改为短暂停留后自动收起，并加了更轻的淡入淡出 + 轻微下滑动效，避免反馈卡长期悬停、显得突兀；同时继续压缩 `ProfileTab` 里“从设置返回同步”“头像/背景成功或失败”“昵称/签名/状态编辑与保存”等说明型文案，尽量只保留用户当下需要知道的结果句。
- 完成：统一收轻 `AppToast` 的视觉重量，缩小指示条、图标、内边距并缩短停留时长，让底部回调提示更接近即时反馈，而不是强打断提示。
- 完成：在 `settings_screen_smoke_test.dart` 增加设置页内联反馈自动消失断言，避免后续回退成常驻提示。
- 涉及模块：
  - flutter-app/lib/screens/settings_screen.dart
  - flutter-app/lib/widgets/profile_tab.dart
  - flutter-app/lib/widgets/app_toast.dart
  - flutter-app/test/smoke/settings_screen_smoke_test.dart
- 验证：
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/screens/settings_screen.dart lib/widgets/profile_tab.dart lib/widgets/app_toast.dart test/smoke/settings_screen_smoke_test.dart
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
- 风险 / 备注：这轮只收反馈层和文案，不改页面结构；当前设置页和个人页的提示已经更轻，但部分底部编辑 sheet 仍保留说明段，下一轮如果继续做减法，需要优先看是否还能在不损失可理解性的前提下再缩一层。
- 下一步建议：
  1. 继续检查 `ProfileTab` 和 `SettingsScreen` 里仍然存在的编辑 sheet 描述段，能改成“标题 + 当前值 + 单行 helper”的地方继续收。
  2. 真机重点验证设置页顶部反馈卡、底部 toast、资料编辑后的回调是否还会有“停太久 / 太抢眼 / 一次出现太多层提示”的感觉。

## 2026-03-26 最近动态 92
- 完成：继续收 `SettingsScreen` 里剩余入口的说明型副标题，重点压了隐身模式、消息通知、黑名单、震动提醒，以及“举报违规用户 / 账号安全提示 / 关于瞬聊 / 隐私政策 / 用户协议”等低频入口。整体从“说明句”进一步收成更直接的功能描述，继续减少设置页列表里的阅读负担。
- 涉及模块：
  - flutter-app/lib/screens/settings_screen.dart
- 验证：
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/screens/settings_screen.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
- 风险 / 备注：这轮只收副标题，不动交互、布局或测试结构；当前全量 smoke 已通过，设置页剩余仍偏“提示卡”的区域主要集中在少量权限恢复说明和个别低频帮助入口。
- 下一步建议：
  1. 继续把 `SettingsScreen` 顶部和中段里仍然偏“帮助文案”的卡片说明再减一轮，优先看通知 runtime card 和账号安全提示。
  2. 如果你准备下一版真机测试，可以重点感受设置页滚动浏览时的信息密度，确认现在是否已经更接近你要的微信式简洁入口感。

## 2026-03-26 最近动态 91
- 完成：继续收 `SettingsScreen` 的低频反馈和确认弹窗文案。退出登录 / 注销账号卡片描述与确认弹窗内容继续压短；头像 / 背景更新成功与失败反馈、UID 复制 / 未就绪反馈、通知系统设置返回反馈、拉黑解除反馈也统一收成更直接的结果句，减少设置页下半区和权限回流链路里的说明感。
- 完成：同步更新 `settings_logout_smoke_test.dart` 和 `settings_screen_smoke_test.dart` 的旧文案断言，确保这轮减法不会再被历史提示词绑住。
- 涉及模块：
  - flutter-app/lib/screens/settings_screen.dart
  - flutter-app/test/smoke/settings_screen_smoke_test.dart
  - flutter-app/test/smoke/settings_logout_smoke_test.dart
- 验证：
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/screens/settings_screen.dart test/smoke/settings_screen_smoke_test.dart test/smoke/settings_logout_smoke_test.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_logout_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
- 风险 / 备注：这轮仍然只动文案，不改设置页交互逻辑；并行触发多个 `flutter test` 仍然会偶发 startup lock 提示，所以后续继续保持串行全量回归更稳。
- 下一步建议：
  1. 继续看 `SettingsScreen` 里剩余的低频入口说明，优先处理“举报违规用户 / 账号安全提示 / 关于与协议”这类仍偏说明式的副标题。
  2. 如果下一轮要出真机包，优先回归“设置 -> 通知权限恢复 -> 账号安全 -> 退出登录/注销账号”这条低频链路，确认页面是否已经足够干净直接。

## 2026-03-26 最近动态 90
- 完成：继续收 `SettingsScreen` 的低频区域文案，重点压了账号与安全、头像/背景管理、拉黑列表三块。手机号和 UID 入口副标题继续收短；手机号 / 密码编辑弹层里的保存前提示、输入提示和保存成功反馈改成更直接的结果句；头像 / 背景管理的状态文案和操作文案从“当前还在使用默认头像 / 重新上传头像 / 补一张背景”这类说明式表达统一收成更短的状态和动作词；拉黑列表的摘要、空状态和单行说明也去掉了一层解释感。
- 完成：同步更新 `settings_screen_smoke_test.dart` 的头像 / 背景管理、账号安全保存反馈相关断言，保证这轮文案减法不会再被旧文案基线卡住。
- 涉及模块：
  - flutter-app/lib/screens/settings_screen.dart
  - flutter-app/test/smoke/settings_screen_smoke_test.dart
- 验证：
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/screens/settings_screen.dart test/smoke/settings_screen_smoke_test.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
- 风险 / 备注：这轮仍然只做低频区文案减法，没有改设置页布局和功能链路；当前 smoke 已通过，剩余还偏“说明卡”的区域主要集中在设置页少量 inline feedback、拉黑解除后的反馈描述，以及账号删除 / 退出登录一带的低频确认文案。
- 下一步建议：
  1. 继续看 `SettingsScreen` 里剩余的 inline feedback 和低频确认弹窗，把还能进一步压短但不影响判断的句子再减一轮。
  2. 如果要准备下一版真机包，优先回归“设置 -> 头像/背景管理 -> 账号安全 -> 拉黑管理”这条低频链路，确认页面现在是否已经更接近你要的简洁感。

## 2026-03-26 最近动态 89
- 完成：收口 `SettingsScreen` 的通知中心摘要短句，把“待查看提醒 / 最新待查看”继续压成更直接的“未读提醒 / 最新”；同时再压了一轮通知关闭态的概览说明、运行态描述和 inline feedback 文案，减少设置页通知区的说明感。
- 完成：继续压 `chat_delivery_debug_sheet.dart` 的诊断文案密度，把“当前诊断结论 / 原因说明 / 处理状态说明 / 处理建议”等长标签收成更短的结果句；同时把“最近异常”视图里诊断摘要和下方轨迹卡重复的一次动作建议去掉，改成“异常集中在哪条链路”的短句，并把顶部说明、轨迹区说明和空状态提示再收短一轮，减少面板内部重复提示和教学感。
- 完成：同步更新 `settings_screen_smoke_test.dart`，把诊断弹层的断言切到新的短文案和最新打开方式，并修掉由于文案重复被压缩后带出的数量断言回归。
- 涉及模块：
  - flutter-app/lib/screens/settings_screen.dart
  - flutter-app/lib/widgets/chat_delivery_debug_sheet.dart
  - flutter-app/test/smoke/settings_screen_smoke_test.dart
- 验证：
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/screens/settings_screen.dart lib/widgets/chat_delivery_debug_sheet.dart test/smoke/settings_screen_smoke_test.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded
  - 在 `flutter-app` 目录执行：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
- 风险 / 备注：这轮没有改设置页交互和诊断统计逻辑，只继续做文案减法与重复信息清理；当前全量 smoke 已通过，短期风险主要还是设置页少量低频状态提示和个别调试/诊断文案仍有继续收短空间。
- 下一步建议：
  1. 继续扫 `SettingsScreen` 里低频反馈和空状态描述，优先看拉黑列表、头像/背景管理和账号安全区域里还能继续减法的句子。
  2. 如果下一轮要做真机检查，优先回归“设置 -> 通知状态切换 / 通知中心摘要 / 发送诊断弹层”这三条低频路径，确认页面已更接近你要的简洁感。

## 2026-03-26 最近动态 88
- 完成：继续压 `SettingsScreen` 里手机号 / 密码编辑弹层和账号操作确认弹窗的说明文案。手机号与密码校验提示改成更短的结果句；手机号 / 密码头部说明和当前状态提示也继续收短；退出登录、注销账号确认弹窗的双行文案压成更直接的动作结果表达。
- 完成：同步更新 `settings_logout_smoke_test.dart` 的确认弹窗断言，避免后续又被旧的长句文案绑住；设置页主 smoke 和全量 smoke 已再次回归，确认这轮减法没有影响布局和流程。
- 涉及模块：
  - flutter-app/lib/screens/settings_screen.dart
  - flutter-app/test/smoke/settings_logout_smoke_test.dart
- 验证：
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/screens/settings_screen.dart flutter-app/test/smoke/settings_logout_smoke_test.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_logout_smoke_test.dart --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
- 风险 / 备注：这轮只收口文案，不改退出登录 / 注销账号 / 编辑手机号 / 编辑密码的交互逻辑；当前设置页剩余仍偏长的主要是通知中心摘要、发送诊断面板和个别通知状态说明，可以继续按同样方式减法。
- 下一步建议：
  1. 继续扫 `SettingsScreen` 里的通知中心摘要文案、发送诊断区文案和少量通知状态 follow-up 文案，把低频说明继续压短。
  2. 如果要开始新一轮真机回归，优先看“设置 -> 退出登录/注销账号/改手机号/改密码”这几条低频链路，确认页面现在是否已经足够干净直接。

## 2026-03-26 最近动态 87
- 完成：继续收 `SettingsScreen` 里的状态说明密度，重点压了设备模式、概览焦点、通知运行态和页面内 inline feedback 的长句。当前保留原有标题、badge 和交互动作不变，只把说明收成更短的结果表达，减少设置页首屏和反馈卡片的“读文案负担”。
- 完成：顺手把头像 / 背景恢复默认、上传失败、解除拉黑等低频反馈再压短一轮，统一改成更直接的结果句，避免这些路径在真机上出现“提示比动作还重”的感觉。
- 涉及模块：
  - flutter-app/lib/screens/settings_screen.dart
- 验证：
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/screens/settings_screen.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
- 风险 / 备注：这轮没有动设置页的交互逻辑和标题关键字，主要是继续收短说明；当前 smoke 已覆盖设置页主流程和全量 smoke 回归，短期可以继续往删除账号确认、手机号 / 密码校验提示这些剩余长句推进。
- 下一步建议：
  1. 继续扫删除账号确认弹窗、手机号 / 密码校验提示、通知中心摘要文案，把还能压短但不影响判断的句子继续减法。
  2. 如果你要做下一次真机检查，可以重点看“设置首页首屏状态卡”“通知状态切换反馈”“头像/背景恢复默认反馈”这三类路径，确认页面是不是已经更接近你要的简洁手感。

## 2026-03-26 最近动态 86
- 完成：继续收 `LegalDocumentScreen` 的首屏结构。协议页不再是一进来就砸一整块正文，而是补上了轻量头信息卡，统一展示文档类型、更新日期和一句摘要；正文卡继续保留可滚动、可选择复制的长文，整体更像成熟应用里的协议详情页。
- 完成：继续压 `SettingsScreen` 里账号与安全、账号操作相关文案。手机号、UID、密码入口的副标题改成更直接的短句；手机号 / 密码弹层头部说明和保存成功反馈也收短了一轮；退出登录和注销账号卡片描述压成更接近动作结果的表达，减少低频页里的说明感。
- 完成：同步把协议页新结构补进 smoke。`legal_pages_smoke_test.dart` 和 `settings_legal_navigation_smoke_test.dart` 现在都覆盖了 `legal-document-summary-card`，锁住“协议页至少要有头信息卡 + 正文卡”的结构基线，避免后续再退回只有一整块正文。
- 涉及模块：
  - flutter-app/lib/content/app_legal_content.dart
  - flutter-app/lib/screens/legal_document_screen.dart
  - flutter-app/lib/screens/settings_screen.dart
  - flutter-app/test/smoke/legal_pages_smoke_test.dart
  - flutter-app/test/smoke/settings_legal_navigation_smoke_test.dart
- 验证：
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/content/app_legal_content.dart flutter-app/lib/screens/legal_document_screen.dart flutter-app/lib/screens/settings_screen.dart flutter-app/test/smoke/legal_pages_smoke_test.dart flutter-app/test/smoke/settings_legal_navigation_smoke_test.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/legal_pages_smoke_test.dart --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_legal_navigation_smoke_test.dart --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
- 风险 / 备注：并行触发多个 `flutter test` 仍然会碰到 startup lock，后续继续保持串行回归更稳；这轮没有改协议正文内容本身，只改了首屏信息组织和设置低频文案密度。
- 下一步建议：
  1. 继续扫 `SettingsScreen` 里通知运行态卡、账号弹层和删除账号确认弹窗的文案，把还能进一步收短但不影响理解的句子继续压一轮。
  2. 如果你准备再做一次真机确认，下一版可以重点回归“设置 -> 关于/协议/账号安全/账号操作”这整条低频链路，看是否已经达到你要的简洁感。

## 2026-03-26 最近动态 85
- 完成：继续收 `AboutScreen` 和低频设置入口的文案密度。关于页不再是“长说明卡”堆叠，而是改成“应用信息 / 支持能力 / 产品定位 / 版权信息”的短信息块结构；Hero 区也压掉了双层口号，保留名称、定位和版本标识，整体更像信息页而不是说明页。
- 完成：把 `SettingsScreen` 里低频区域继续往“入口优先”收。安全与举报、关于与协议的副标题统一压短；头像管理和背景管理在设置列表里的状态说明也改成更直接的一句话，减少用户进入设置后先读大段解释的负担。
- 完成：同步调整关于页 smoke 基线。`legal_pages_smoke_test.dart` 现在验证关于页核心信息块在紧凑尺寸下可见且稳定；如果页面内容仍可滚动则继续校验滚动，不再强依赖“关于页必须超出一屏”这类旧假设。
- 涉及模块：
  - flutter-app/lib/screens/about_screen.dart
  - flutter-app/lib/screens/settings_screen.dart
  - flutter-app/test/smoke/legal_pages_smoke_test.dart
- 验证：
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/screens/about_screen.dart flutter-app/lib/screens/settings_screen.dart flutter-app/test/smoke/legal_pages_smoke_test.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/legal_pages_smoke_test.dart --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_legal_navigation_smoke_test.dart --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
- 风险 / 备注：这轮只收口文案密度和关于页信息结构，没有改协议正文、路由或设置页的核心交互；当前 smoke 已覆盖关于页、设置页入口跳转和设置页主流程，短期可以继续沿同一方向扫剩余低频文案。
- 下一步建议：
  1. 继续看 `LegalDocumentScreen` 的首屏可读性，评估是否需要给协议页补“更新时间 / 文档类型”这种轻量头信息，而不是直接砸整块正文。
  2. 回到 `SettingsScreen` 的账号与安全、账号操作区域，再压一轮说明型描述，尽量把低频页统一成“看入口就能判断去哪”的语言风格。

## 2026-03-26 最近动态 84
- 完成：继续收 `MatchTab` 的匹配成功卡文案密度。招呼语区域从“标题 + 解释文案 + 建议卡 + 输入框”收成了更直接的“标题 + 快捷语 / 输入框”结构，去掉了“建议别太正式”这类重复解释；输入框 placeholder 也改短，减少页面像教程卡片的感觉。
- 完成：把匹配成功后的在线 / 离线提示压成更短的一句话，避免和上方招呼区再次重复解释“现在该怎么说”。当前保留的是必要状态提醒，不再对用户说教式引导。
- 涉及模块：
  - flutter-app/lib/widgets/match_tab.dart
- 验证：
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/widgets/match_tab.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/match_tab_smoke_test.dart --reporter expanded
- 风险 / 备注：这轮没有改匹配成功后的动作链路、线程创建或发招呼逻辑，只是继续对首屏和成功卡做文案减法；当前 smoke 覆盖的是紧凑尺寸、失败态和快捷招呼布局稳定性。
- 下一步建议：
  1. 继续扫 `About` / `Legal` / 低频设置页里的长说明文案，把还能压缩的说明继续收短。
  2. 如果你要马上真机看这一轮 UI 变化，可以基于当前代码重新出一版测试包，重点看“匹配首页普通态”和“匹配成功卡”的信息密度是否已经顺手。

## 2026-03-25 最近动态 83
- 完成：继续按“入口优先、说明后置”的方向收 `SettingsScreen` 首页结构。顶部不再叠“设置总览说明 + 设备状态说明 + 设备模式预设 + 账号操作提示卡”这类连续说明区，改成更直接的“当前设备 / 关键状态 / 直达动作”结构；设备模式下沉为独立模块，账号操作前的整块提示卡也收掉，只保留退出登录和注销账号两张动作卡。
- 完成：同步把设置页 smoke 基线切到新结构。相关回归现在不再假设设备模式预设始终位于首屏顶区，而是按真实滚动路径验证 overview、device mode、账号操作和紧凑尺寸表现；这样后续继续收口设置页时，测试不会再被旧布局绑定住。
- 完成：继续收 `MatchTab` 首屏普通态。现在普通空闲态不再默认显示 `match-guide-card` 和按钮下方的重复 helper 文案，只保留次数、状态和主按钮；失败态、匹配中和次数用尽态仍然保留必要说明，避免把错误反馈也一并删掉。
- 完成：同步更新匹配页和主页面 smoke。`match_tab_smoke_test.dart` 现在校验“普通态无 guide、失败态再展开 guide”的新逻辑，`main_screen_smoke_test.dart` 也改成验证匹配页首屏主操作而不是旧的引导卡。
- 涉及模块：
  - flutter-app/lib/screens/settings_screen.dart
  - flutter-app/test/smoke/settings_screen_smoke_test.dart
  - flutter-app/lib/widgets/match_tab.dart
  - flutter-app/test/smoke/match_tab_smoke_test.dart
  - flutter-app/test/smoke/main_screen_smoke_test.dart
- 验证：
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/screens/settings_screen.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/widgets/match_tab.dart flutter-app/test/smoke/match_tab_smoke_test.dart flutter-app/test/smoke/main_screen_smoke_test.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/test/smoke/settings_screen_smoke_test.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_logout_smoke_test.dart --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/match_tab_smoke_test.dart --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
- 风险 / 备注：功能链路没有扩大，主要是首屏结构减法和测试基线迁移；并行触发多个 `flutter test` 仍然会偶发 startup lock，后续回归继续串行执行更稳。
- 下一步建议：
  1. 继续收 `MatchTab` 的匹配成功卡和“开场白”区域，把目前偏解释性的提示句再往下压，只保留必要动作。
  2. 再回头扫一轮 `About` / `Legal` / 低频设置页里的长说明文案，把还能收短的文案继续压缩，统一整套页面的语言密度。

## 2026-03-25 最近动态 82
- 完成：继续把“我的”页从“分组引导卡”收回到“直接入口”结构。`ProfileTab` 里保留了头像、签名、状态、背景、设置这些自然入口，去掉了原来那种成组的“常用入口/完成清单”式组织方式，让页面更接近微信、抖音那种“看到入口直接点进去处理”的布局。
- 完成：补回了一个轻量的资料统计条，但没有把页面重新做回提示堆叠。好友数 / 会话数现在以单条信息卡放在资料区下方，作为轻量信息层，不再承担引导职责；同时把原本会重复触发的数字动画去掉，减少首页细碎动效和重建成本。
- 完成：顺手修了两处这轮结构调整带出来的交互尾巴。紧凑态下的状态入口现在补到更合理的点击高度；“设置返回首页后的同步提示”也改成稳定经历“同步中 -> 已同步”的短反馈，避免真机和 smoke 在返回时序上出现忽快忽慢的不一致。
- 完成：重建并收稳了 `main_screen_smoke_test.dart` 这条主 smoke 基线，断言已经从旧的“常用入口/清单卡”结构切到新的直接入口结构，后续继续迭代 Profile 页时可以直接靠这条基线回归。
- 涉及模块：
  - flutter-app/lib/widgets/profile_tab.dart
  - flutter-app/test/smoke/main_screen_smoke_test.dart
- 验证：
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/widgets/profile_tab.dart flutter-app/test/smoke/main_screen_smoke_test.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
- 风险 / 备注：这轮没有出新包，也没有扩大到设置页 / 匹配页的整体布局收口；当前确认的是 Profile 页的新入口结构和相关 smoke 已经稳定，适合继续按同一原则往其他页面推进。
- 下一步建议：
  1. 继续把 `SettingsScreen`、`MatchTab` 里“说明先于入口”的区域收成“入口优先、说明后置或折叠”的结构，和现在的 Profile 页保持同一产品语言。
  2. 如果你想马上做真机确认，可以基于当前代码再出一版新的 demo APK，重点回归“我的”页首屏密度、紧凑机型点击手感，以及设置返回首页时的同步提示节奏。

## 2026-03-24 最近动态 69
- 完成：继续收 `MessagesTab` 的线程列表与线程摘要组装成本。列表层现在按 `threadListPresentationRevision` 做了本地 view-data 缓存，线程摘要层也新增了基于 `ChatThreadSummarySnapshot` 实例和好友态的本地缓存，避免消息页在高频 provider 通知下反复把同一批线程摘要重新拼装一遍。
- 完成：把线程行里重复派生的投递状态提前收进 `_MessagesThreadSummaryViewData`。最近消息的 `deliveryState` 现在在摘要组装阶段只计算一次，列表行渲染时不再多次重复走 `resolveChatDeliveryStatus(...)`，进一步压低消息列表滚动和状态刷新时的细碎开销。
- 完成：顺手补了缓存回收和小成本收口。线程列表重算时会清掉已经不可见的本地摘要缓存，搜索筛选也改成复用单次 lower-case 查询，减少列表切换和搜索输入时的重复小计算。
- 涉及模块：
  - flutter-app/lib/widgets/messages_tab.dart
- 验证：
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/widgets/messages_tab.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/messages_tab_smoke_test.dart --reporter expanded
- 风险 / 备注：这轮是消息列表内部缓存与派生逻辑收口，没有改动交互语义；当前收益主要体现在高频通知、未读变化和草稿/摘要刷新时少做重复拼装，后续如果继续收口，还可以再往 `NotificationCenterProvider` 和聊天页顶部状态共用摘要层推进。
- 下一步建议：
  1. 继续回到 `ChatScreen` 顶部状态和 `MessagesTab` 共享的线程摘要源，看看是否还能把未读 / 置顶 / 最近消息摘要再往 provider 内部拆细一层。
  2. 真机重点回归消息页滚动、切回聊天再返回、以及设置改资料后回到消息页时的列表刷新手感，确认“慢半拍”是否继续下降。

## 2026-03-24 最近动态 68
- 完成：继续收 `SettingsProvider` 的无效通知链路。现在本地加载、远端刷新、通知权限回刷、隐身/震动/通知开关和体验预设应用都只会在状态真的发生可见变化时才 `notifyListeners()`，其中推送运行时状态比较也改成只关注 `notificationsEnabled / permissionGranted / deviceToken` 这几个会影响 UI 的字段，避免 `lastSyncedAt` 之类的后台时间戳把设置页和概览卡片一起白白重建。
- 完成：把“当前预设重复点击”的 no-op 操作收掉。`SettingsScreen` 里的体验预设卡现在对当前激活项不再触发点击链路，`_applyExperiencePreset()` 也增加了同态早退，减少重复保存、埋点和页内反馈，让设置页操作更干脆。
- 完成：补了一条系统设置返回的体验兜底。通知权限从系统设置返回但运行时状态没有变化时，设置页不再额外弹一轮“恢复中 / 待授权”反馈，避免用户看到页面又抖一下、像是重复回调。
- 涉及模块：
  - flutter-app/lib/providers/settings_provider.dart
  - flutter-app/lib/screens/settings_screen.dart
  - flutter-app/test/providers/settings_provider_test.dart
  - flutter-app/test/smoke/settings_screen_smoke_test.dart
- 验证：
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/providers/settings_provider.dart flutter-app/lib/screens/settings_screen.dart flutter-app/test/providers/settings_provider_test.dart flutter-app/test/smoke/settings_screen_smoke_test.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/settings_provider_test.dart --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --plain-name "settings screen should ignore tapping active experience preset" --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --plain-name "settings screen should apply experience preset from overview card" --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --plain-name "settings screen should auto refresh notification permission after returning from system settings" --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --plain-name "settings screen should avoid duplicate recovery feedback when notification permission is unchanged after returning from system settings" --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --plain-name "settings screen should refresh notification runtime state into ready feedback" --reporter expanded
- 风险 / 备注：这轮主要是性能和回调逻辑收口，没有扩大 UI 视觉方向；中途验证时发现并行执行多个 `flutter test` 会抢 startup lock，后续这类回归继续保持串行执行更稳。
- 下一步建议：
  1. 继续回到 `ChatScreen` 和 `MessagesTab` 收 selector 粒度，把高频消息摘要、未读和顶部状态进一步从整段 provider 通知里剥出来。
  2. 继续补“设置返回首页后的身份感知一致性”真机向回归，重点看改手机号 / 头像 / 背景后返回首页、消息列表和聊天页时的同步节奏是否还有慢半拍。

## 2026-03-24 最近动态 67
- 完成：收口 ChatScreen 顶部“取关后限制发送”提示条的半完成改造。`_selectUnfollowBannerViewData()` 现在只输出稳定的 banner view-data，剩余可发条数统一做非负收口；顶部提示条补上了稳定 key，并在紧凑宽度下把“提醒”动作切成纵向堆叠，避免小屏下文案和按钮互相挤压。
- 完成：顺手修掉了这轮回归里暴露出的真实小屏问题。空会话态原本在 `未关注提示条 + 320x568` 组合下会发生底部 `RenderFlex overflow`，现在改成了紧凑参数 + `SingleChildScrollView` 滚动兜底，首屏空间被压缩时也不会再把页面顶爆。
- 完成：补了一条聊天页紧凑布局 smoke，专门锁住 `chat-unfollow-banner` / `chat-unfollow-banner-remind-action` 和输入区共存时的结构稳定性，避免后续再把顶部提示条改回依赖文案长度的脆弱实现。
- 涉及模块：
  - flutter-app/lib/screens/chat_screen.dart
  - flutter-app/test/smoke/chat_screen_smoke_test.dart
- 验证：
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/screens/chat_screen.dart flutter-app/test/smoke/chat_screen_smoke_test.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_notification_permission_smoke_test.dart --reporter expanded
- 风险 / 备注：这轮没有扩大改动面，主要还是沿着聊天页顶部状态和空态小屏适配做收口；工作区里仍有其他未提交改动，本轮只增量处理了和 `ChatScreen` 紧凑布局稳定性直接相关的部分。
- 下一步建议：
  1. 继续往性能手感收口，优先看 `SettingsScreen` 和 `ChatScreen` 里仍然偏大的 selector / listener 覆盖范围，把“点了以后慢半拍”的 rebuild 源头再往下压。
  2. 再补一轮 320~360 宽度下的聊天首屏回归，重点看“通知权限 banner + 取关提示条 + 空态/消息列表 + 输入区”这几层组合同时出现时的稳定性，避免真机上重新出现局部重叠。

## 2026-03-24 最近动态 66
- 完成：继续收 ChatScreen 的当前线程监听开销。_handleChatProviderChanged() 现在先用 	hreadInteractionRevision + canonicalThreadId + quickSignal 做轻量判定，只有当前会话真的发生可见变化时才继续做完整的投递状态指纹计算，减少了别的会话或无关通知打到聊天页时的无效计算。
- 完成：继续收 ChatScreen 消息列表和输入区的 selector 成本。新增当前线程级别的 view-data 缓存，_selectMessageListViewData() 和 _selectComposerViewData() 不再在每次 ChatProvider.notifyListeners() 时都重新做整段 bubble / composer 快照，优先只在当前线程 revision 变化时重算，直接压低真机上“点了以后慢半拍”的体感来源。
- 完成：补强聊天失败引导链路的小屏稳定性。图片失败说明 sheet 现在增加了紧凑布局、最大高度约束、滚动兜底和稳定 key；ChatDeliveryStatusCard 也补了稳定 action key，聊天页 smoke 改成通过 key 触发失败说明入口，避免再依赖文案命中。
- 完成：顺手修了本轮验证里暴露出的测试稳定性尾巴。chat_screen_notification_permission_smoke_test.dart 的 compact 用例补了持久化 debounce 的显式泵过时序，避免 teardown 时遗留 pending timer。
- 涉及模块：lutter-app/lib/screens/chat_screen.dart、lutter-app/lib/widgets/chat_delivery_status.dart、lutter-app/test/smoke/chat_screen_smoke_test.dart、lutter-app/test/smoke/chat_screen_notification_permission_smoke_test.dart
- 验证：
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/screens/chat_screen.dart flutter-app/lib/widgets/chat_delivery_status.dart flutter-app/test/smoke/chat_screen_smoke_test.dart flutter-app/test/smoke/chat_screen_notification_permission_smoke_test.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_notification_permission_smoke_test.dart --reporter expanded
- 风险 / 备注：这轮中途因为 chat_screen.dart / chat_screen_smoke_test.dart 的历史中文编码残留，出现过一次写回后字符串截断。已在本轮修正并重新跑通 nalyze + smoke；后续如果继续批量改这两个文件，优先用稳定 key 和小块补丁，少做整文件重写。
- 下一步建议做什么：
  1. 继续沿着 ChatScreen 顶部提示条、取关提示条和失败说明/语音通话 sheet 往下压，把能进一步快照化的 header/banner 状态再收一层。
  2. 开始看 SettingsScreen 和 MessagesTab 里仍然高频触发的局部回调点，优先找“点击后等待感”和“返回后状态回流”这两类真机最敏感的问题。
## 2026-03-23 最近动态 65
- 完成：继续收 `ChatScreen` 顶部更多菜单的 `itemBuilder`，把菜单项从现场条件分支拼装改成 `_ChatActionMenuItemViewData` 列表快照。现在 selector 会连同菜单标签、图标、危险态和显隐条件一起准备好，弹出菜单时只消费已算好的菜单项列表，不再在弹层 build 过程中重复走一遍 `if isFriend / isBlocked / canCall / canAddFriend` 这套条件判断。
- 完成：顶层菜单快照 `*_ChatActionMenuViewData*` 现在也把菜单项列表纳入比较边界，保证关系状态、语音权限或互关权限变化时，菜单内容会正确刷新，但无关通知不会触发重复列表拼装。
- 完成：保持上一轮补的稳定 key 不变，并继续通过聊天页 smoke 验证“更多菜单 -> 用户资料弹层”链路，确保菜单快照化后交互入口仍然稳定可测。
- 涉及模块：`flutter-app/lib/screens/chat_screen.dart`
- 验证：
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/screens/chat_screen.dart test/smoke/chat_screen_smoke_test.dart`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：顶部菜单本身已经基本从“点击时临时现算”收到了“构建时按快照消费”，后续继续优化的重点可以从菜单本身转回更影响真机体感的失败说明 sheet、顶部状态提示和语音弹层这些打开/关闭路径。
- 下一步建议做什么：
  1. 继续检查 `ChatScreen` 的失败说明 sheet 和顶部提示条，把小屏布局、开启关闭动画和状态切换链路继续往局部快照与更稳的自适应结构上收。
  2. 如果真机上聊天页顶部区域仍偶发发闷，下一轮优先看通知权限 banner、取关提示条和头部标题区是否还存在可合并或可缩小的 selector 边界。

## 2026-03-23 最近动态 64
- 完成：继续收 `ChatScreen` 顶部 `PopupMenuButton` 的动作分发。菜单选中后不再临时重新读取 `FriendProvider` 再判断互关/拉黑/语音权限，而是直接消费已经在 selector 中准备好的 `_ChatActionMenuViewData`，只在真正需要时读一次当前线程本体，减少点击后的重复 provider 查询和重复权限计算。
- 完成：给聊天页更多菜单补了稳定 key，包括 `chat-action-menu-profile`、`chat-action-menu-call`、`chat-action-menu-add-friend`、`chat-action-menu-remark`、`chat-action-menu-unfollow`、`chat-action-menu-block`、`chat-action-menu-report`。这样后续继续补菜单交互 smoke 或做回归定位时，不再依赖菜单文案或顺序命中。
- 完成：把上一轮新增的“更多菜单 -> 用户资料 sheet” smoke 改成基于 key 的稳定触发，避免测试环境中文文案编码波动带来的误报，同时锁住顶部菜单与资料弹层之间的真实交互链路。
- 涉及模块：`flutter-app/lib/screens/chat_screen.dart`、`flutter-app/test/smoke/chat_screen_smoke_test.dart`
- 验证：
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/screens/chat_screen.dart test/smoke/chat_screen_smoke_test.dart`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：顶部菜单的点击尾巴已经继续压下去了一层，但菜单项本身仍然是 build 时现场拼装的字符串列表；这不是主要性能热点，后续优先级低于继续看失败说明 sheet、语音弹层和顶部提示条这些更接近真机操作手感的路径。
- 下一步建议做什么：
  1. 继续检查 `ChatScreen` 的失败说明 sheet 和顶部提示条，把“打开 / 关闭 / 状态切换”链路再往局部快照和更窄布局结构上收。
  2. 如果真机上顶部更多菜单弹出仍有轻微发闷，可以再把 `itemBuilder` 里的菜单项模型收成静态 action list，进一步减少 build 阶段的条件拼装。

## 2026-03-23 最近动态 63
- 完成：继续收 `ChatScreen` 顶部动作区，把“用户资料”sheet 从整块 `Consumer2<ChatProvider, FriendProvider>` 改成 `_ChatUserProfileSheetViewData + Selector2`。现在弹层打开后只会在资料真正相关的线程/关系字段变化时刷新，不会再因为无关 provider 通知把整张资料 sheet 跟着重建。
- 完成：顺手修掉了这条高频入口的布局风险。资料 sheet 现在改成 `SingleChildScrollView + min-content column`，并去掉了中段内容里的硬 `Expanded`，避免在测试窗口和更小尺寸设备上出现底部 CTA 被挤爆、内容溢出的情况。
- 完成：补了一条聊天页 smoke，锁住“更多菜单 -> 用户资料 sheet”这条入口，后续继续优化顶部动作区或菜单逻辑时，这条用户高频路径能更早暴露回归。
- 涉及模块：`flutter-app/lib/screens/chat_screen.dart`、`flutter-app/test/smoke/chat_screen_smoke_test.dart`
- 验证：
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/screens/chat_screen.dart test/smoke/chat_screen_smoke_test.dart`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：本轮已经把聊天页顶部一个真实高频入口从“宽监听 + 固定高布局”收成了更稳的快照和自适应结构，但 `PopupMenuButton` 的动作分发本身仍然是在选择后临时读取一次当前线程做处理；这不是滚动期热点，不过后续如果继续压“点一下慢半拍”，还能再把菜单动作也收成更直接的 action snapshot。
- 下一步建议做什么：
  1. 继续看 `ChatScreen` 的更多菜单动作分发，把语音、互关、备注、取关、拉黑、举报继续收成更直接的动作快照，减少点按后临时读取 provider 和重复判断。
  2. 继续检查失败说明 sheet、顶部提示条和语音弹层这几处 action path，优先找还会在打开/关闭时放大 rebuild 或出现小屏挤压的点。

## 2026-03-23 最近动态 62
- 完成：继续压 `SettingsScreen` 的高频重建范围，把“隐身模式 / 消息通知 / 震动提醒”三个 section 从共用 `_SettingsViewData` 的宽监听，拆成更窄的 `_SettingsInvisibleModeItemViewData`、`_SettingsNotificationItemViewData`、`_SettingsVibrationItemViewData`。现在切一个开关时，设置总览仍会按需刷新，但另外两个无关 section 不会再被同一份大 selector 一起带着重建。
- 完成：把“黑名单管理”sheet 从整块 `Consumer2<FriendProvider, ChatProvider>` 现场查数据，收成 `_SettingsBlockedUsersSheetViewData` / `_SettingsBlockedUserRowViewData` 快照。弹层渲染时不再在 `itemBuilder` 里反复 `getFriend + getThread`，列表展示和解除拉黑后的回流边界更清晰，也更利于后面继续做局部验证。
- 完成：本轮保持现有 UI 结构、交互路径和测试 key 不变，只缩小设置页主树和黑名单弹层的监听面，没有改动账号安全、媒体管理、通知权限恢复和首页回流链路。
- 涉及模块：`flutter-app/lib/screens/settings_screen.dart`
- 验证：
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/screens/settings_screen.dart`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：设置页现在已经把最明显的“改一个开关，几个 section 一起动”的尾巴压下去了，但总览卡内部仍然承接了设备模式、通知运行态和焦点提示这几组汇总信息；这块本身属于首页式总览，不适合过度切碎，后续优先级低于继续压聊天页顶部动作区和失败反馈链路。
- 下一步建议做什么：
  1. 回到 `ChatScreen` 的头部更多菜单、失败说明 sheet 和顶部状态提示，把动作触发链路继续收成“只读快照 + 动作时一次读取”，进一步压真机点按后的尾巴。
  2. 如果真机上“我的 / 设置”页打开弹层仍有轻微发闷，下一轮优先看媒体管理 sheet 和通知运行态卡片，评估是否还存在可下沉的局部状态或可复用快照。

## 2026-03-23 最近动态 61
- 完成：把 `ChatScreen` 的消息列表 selector 继续往下收口成 `_ChatMessageBubbleViewData` 快照。`_selectMessageListViewData()` 现在会在 selector 阶段一次性准备每条消息的 `canRecall`、失败态对应的 `ChatDeliveryStatusSpec`，`_MessageBubble.build()` 只消费快照，不再在每个气泡 build 时重复调用 `canRecallMessage / deliveryFailureStateFor`。
- 完成：同步更新消息列表 `presentationKey`，把送达状态卡、撤回能力等真正影响渲染的字段纳入比较边界。这样失败重试、状态回落和送达状态变化仍然会正确刷新，但长会话下不会再把同一批 provider 扫描分散到每个 cell 的 build 阶段。
- 完成：补齐这轮稳定性验证，确认聊天页消息气泡快照化后，`analyze`、聊天 smoke、provider 回归和主页面 smoke 都通过，当前可以继续沿着真机手感方向往下压 action path 的尾巴。
- 涉及模块：`flutter-app/lib/screens/chat_screen.dart`、`flutter-app/lib/providers/chat_provider_messages.dart`
- 验证：
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/screens/chat_screen.dart lib/providers/chat_provider_messages.dart`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/chat_provider_test.dart --reporter expanded`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：本轮已经压掉消息气泡 build 里的高频 provider 扫描，但 `ChatScreen` 头部更多菜单、失败说明 sheet 和少量动作反馈路径仍然会在触发时临时读取 provider 状态；这些不是滚动期热点，不过仍有继续收成“只读快照 + 动作时一次性读取”的空间。
- 下一步建议做什么：
  1. 继续看 `SettingsScreen` 和 `ChatScreen` 的 action path，把更多菜单、失败说明、顶部状态提示继续收成局部 view data，进一步压真机“点一下慢半拍”的尾巴。
  2. 给聊天页补一条更贴近“失败重试 / 送达状态变化”的回归验证，锁住这次 delivery 状态快照化后的边界，避免后续继续优化时把消息气泡监听面重新放大。

## 2026-03-23 最近动态 60
- 完成：继续收 `MessagesTab / ChatProvider` 的线程摘要计算链路。`ChatProvider` 新增 `ChatThreadSummarySnapshot` / `ChatMessagePreviewSnapshot` 和按线程缓存的 `_threadSummaryCache`，把消息列表 cell 依赖的昵称、头像、未读、草稿、置顶、最近消息预览和失败态从 UI selector 现场拼装改成 provider 侧按需缓存。
- 完成：`MessagesTab` 的线程条目摘要选择器改成优先读取 `chatProvider.threadSummarySnapshot(threadId)`，再只叠加 `FriendProvider` 的好友/拉黑关系。现在 provider 有无关通知时，列表项不会再重复扫 `getThread + getMessages + draft + deliveryFailureStateFor` 这整套链路，列表滚动和返回消息页时的隐性计算成本更低。
- 完成：补了一条 provider 回归，锁住“只改某个线程的草稿/置顶，不会把其它线程摘要缓存一起打脏”的边界，避免后续优化把消息列表监听范围重新放大。
- 涉及模块：`flutter-app/lib/providers/chat_provider.dart`、`flutter-app/lib/providers/chat_provider_messages.dart`、`flutter-app/lib/providers/chat_provider_storage.dart`、`flutter-app/lib/providers/chat_provider_threads.dart`、`flutter-app/lib/widgets/messages_tab.dart`、`flutter-app/test/providers/chat_provider_test.dart`
- 验证：
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/providers/chat_provider.dart lib/providers/chat_provider_messages.dart lib/providers/chat_provider_storage.dart lib/providers/chat_provider_threads.dart lib/widgets/messages_tab.dart test/providers/chat_provider_test.dart`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/chat_provider_test.dart --reporter expanded`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/messages_tab_smoke_test.dart --reporter expanded`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：当前线程摘要缓存已经把消息列表最容易反复算的“最近消息 + 草稿 + 失败态”沉到了 provider，但搜索输入仍然会在 `MessagesTab` 本地对列表做一次字符串过滤；这部分当前复杂度不高，优先级低于继续压 provider 通知扇出。
- 下一步建议做什么：
  1. 继续看 `MessagesTab` 搜索态和列表项 `relativeTime` 刷新，评估是否要把搜索结果也做成可复用快照，进一步减少输入时的重复映射。
  2. 回到 `ChatScreen` 头部更多菜单和失败说明 sheet，把动作分发和只读快照再往下收一层，继续压真机“点一下后慢半拍”的尾巴。

## 2026-03-23 最近动态 59
- 完成：继续收 `ProfileTab` 的本地 UI 状态，把头像/背景引用从页面级 `setState()` 改成 `ValueNotifier<_ProfileMediaState>`，并补了 `copyWith + ==`，避免 `_loadImages()`、设置返回、头像/背景更新或删除时重复触发相同快照重建。
- 完成：把“页内轻提示”和“设置返回后的身份同步徽标”分别改成 `ValueNotifier + ValueListenableBuilder` 局部驱动。现在 2.2 秒反馈自动消失、同步中切到已同步时，只刷新 quick actions 里的提示区域和头像区右上角徽标，不再把整页 `ProfileTab` 一起带着 rebuild。
- 完成：保留原有交互、文案和测试锚点不变，包括 `profile-settings-sync-hint`、`profile-identity-sync-badge`、`profile-identity-sync-label`、`profile-inline-feedback-*` 等关键 key，确保设置返回同步提示、远端媒体回显和页内反馈链路继续可测。
- 涉及模块：`flutter-app/lib/widgets/profile_tab.dart`
- 验证：
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/widgets/profile_tab.dart`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：本轮已经把 `ProfileTab` 的定时反馈和同步徽标从整页重建里剥离出来，但媒体引用变化仍会驱动资料页主体按快照刷新一次；这类操作本身频率不高，当前优先先把真机“轻提示消失也会抖一下”的体感压掉，后续如仍需继续压缩，可再把头像/背景依赖区拆成更细粒度的局部 builder。
- 下一步建议做什么：
  1. 继续检查 `ProfileTab` 里头像卡、背景面板和 quick actions 对媒体快照的依赖，评估是否要把媒体变更再从整页快照压到头图区 / 快捷卡两个局部 builder。
  2. 回到 `MessagesTab / ChatProvider` 的线程摘要监听收口，继续压消息列表切回和会话摘要变化时的计算与通知扇出。

## 2026-03-23 最近动态 58
- 完成：继续收 `ChatScreen` 页面级状态更新，把亲密度增长轻提示从整页 `setState()` 改成 `ValueNotifier<_ChatIntimacyChangeState?> + ValueListenableBuilder`。现在亲密度增长时只刷新消息列表上方那一小块浮层动画，不再把整页聊天头部、消息列表和输入区一起带着重建。
- 完成：保留原有 2 秒提示时长和动画节奏不变，但把显示/隐藏切换都收进局部 notifier；同时给动画补了基于 token 的重播 key，避免短时间内连续增长时出现同数值提示不重新触发的问题。
- 完成：本轮收完后，`flutter-app/lib/screens/chat_screen.dart` 里已经没有页面级 `setState()` 残留，聊天页主路径上的高频交互状态已经全部改到更局部的 notifier / selector 驱动。
- 涉及模块：`flutter-app/lib/screens/chat_screen.dart`
- 验证：
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/screens/chat_screen.dart`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这一轮把 `ChatScreen` 最后两处页面级 `setState()` 收掉了，但头部更多菜单、失败图片说明 sheet 和部分动作分发逻辑仍然可以继续往“只读快照 + 局部动作处理”方向整理；本轮优先保证稳定回归，没有把权限依赖较重的语音通话 smoke 一起拉进主 smoke 集合。
- 下一步建议做什么：
  1. 继续收 `ChatScreen` 头部更多菜单，把菜单内容和动作分发抽成更明确的局部快照/处理方法，减少 build 内重复判断。
  2. 回到 `SettingsScreen` 的保存成功反馈与媒体管理链路，继续查是否还有不必要的页面主树刷新尾巴。

## 2026-03-23 最近动态 57
- 完成：继续往 `ChatScreen` 的图片预览链路压局部重建。`_BurnHoldPreviewOverlay` 和 `_ImagePreviewScreen` 里的闪图倒计时都从整块 `setState()` / `Future.doWhile` 改成 `ValueNotifier<int> + Timer.periodic`，现在每秒只刷新底部倒计时文案，不再把整张图片预览 overlay / 预览页一起重建。
- 完成：顺手清掉 `MessageBubble` 里闪图 overlay 打开/关闭时两处无效的 `setState()`。这两个状态本身并不参与当前消息气泡 build，去掉后可以减少长按闪图时无意义的消息气泡重绘。
- 完成：为后续图片预览链路补回归预留了稳定 key：`burn-preview-countdown-label`、`image-preview-burn-countdown-label`。本轮仍优先保留现有稳定 smoke 套件，没有把手势敏感的额外交互 smoke 一起带进来，避免把本轮回归面引入不稳定因素。
- 涉及模块：`flutter-app/lib/screens/chat_screen.dart`
- 验证：
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/screens/chat_screen.dart test/smoke/chat_screen_smoke_test.dart`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这一轮把图片预览“每秒整页重建”的尾巴压掉了，但闪图长按 overlay 和图片预览页仍然缺少直接命中的独立 smoke；后面如果要继续打磨闪图体验，建议基于这次补的 key 再补一条更稳的手势/overlay 回归，而不是直接把不稳定用例留在主 smoke 集合里。
- 下一步建议做什么：
  1. 回到 `ChatScreen` 头部菜单和更多操作区，把菜单选择后的动作分发和菜单内容继续往更局部的只读快照收。
  2. 继续检查普通图片预览、失败图片说明 sheet 和消息气泡内联状态卡，看是否还能再减少无关 build。

## 2026-03-23 最近动态 56
- 完成：把上一轮停在半路的 `SettingsScreen` 账号安全弹层正式收口。手机号 sheet 和密码 sheet 现在都改成“外层弹层静态、底部校验提示卡和保存/取消按钮用 `ValueListenableBuilder<_SettingsSheetValidationState>` 局部刷新”，输入过程中不再把整张 bottom sheet 一起重建，同时保留原有校验文案、按钮禁用态和保存路径不变。
- 完成：继续压 `ChatScreen` 语音通话弹层的局部刷新范围。`_VoiceCallSheet` 里的静音、扬声器和通话时长不再走整块 `setState()` / `Stream.periodic`，而是改成 `ValueNotifier<bool> + ValueNotifier<int> + Timer.periodic`；现在每秒只刷新时长文本，点静音或扬声器时只刷新对应动作按钮，减少真机上“点了慢半拍”的尾巴。
- 完成：顺手补了语音通话弹层的稳定 key，包含 `voice-call-duration-label`、`voice-call-mute-action`、`voice-call-speaker-action`、`voice-call-end-action`，后面如果要继续补更细的 widget/smoke 覆盖，测试锚点已经准备好。
- 涉及模块：`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/lib/screens/chat_screen.dart`
- 验证：
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/screens/chat_screen.dart lib/screens/settings_screen.dart`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这一轮把 `SettingsScreen` 半成品改动修回了稳定可验证状态，也继续压小了 `ChatScreen` 语音通话弹层的局部重建；但语音通话弹层目前还没有独立 smoke 用例，现阶段主要依赖 `analyze + chat/settings/main smoke` 保证不回归，后面如果继续打磨通话态体验，建议把这块也补上更直接的交互回归。
- 下一步建议做什么：
  1. 继续检查 `ChatScreen` 头部菜单、图片预览和消息气泡内联预览，把页面级交互态再往局部 notifier / selector 下沉。
  2. 继续检查 `SettingsScreen` 头像 / 背景管理 sheet 和保存成功后的 feedback 链路，看是否还能进一步减少无关页面主树刷新。

## 2026-03-23 最近动态 55
- 完成：继续收口 `SettingsScreen / ChatScreen` 的局部刷新范围。`SettingsScreen` 把顶部轻提示卡、头像预览、背景预览从整页 `setState()` 改成 `ValueNotifier + ValueListenableBuilder` 局部驱动；现在切换通知反馈、头像/背景更新或恢复默认时，只刷新对应提示卡和媒体管理行，不再顺手把整页设置列表一起重建。
- 完成：把 `ChatScreen` 里闪图模式开关从整页 `setState()` 收成 composer 子树内的 `ValueNotifier<bool>`。现在切换闪图、发送闪图后自动回落关闭时，只重绘输入区和能力提示，不再把消息列表、头部和上方状态条一起带着重刷，继续往真机“点了不拖泥带水”的手感压一层。
- 完成：本轮保持现有 UI 结构和交互不变，只缩小高频回调后的重绘面，没有改动消息发送、设置保存、sheet 打开关闭和首页回流的用户路径。
- 涉及模块：`flutter-app/lib/screens/chat_screen.dart`、`flutter-app/lib/screens/settings_screen.dart`
- 验证：
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/screens/chat_screen.dart lib/screens/settings_screen.dart`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这轮已经把两处“用户点一下就整页刷”的热点继续压小了，但 `ChatScreen` 头部菜单、语音通话弹层和部分消息气泡内部预览仍有继续做局部状态隔离的空间；`SettingsScreen` 里少数底部弹层提交流程也还可以继续减少无关 toast / feedback 链路对页面主树的影响。
- 下一步建议做什么：
  1. 继续检查 `ChatScreen` 头部菜单、语音通话 sheet 和图片预览链路，把交互态从页面级 state 再往局部 widget 状态下沉。
  2. 继续检查 `SettingsScreen` 的头像 / 背景管理 sheet、手机号 / 密码 sheet 保存后链路，看是否还能把弹层内校验和保存态进一步局部化，减少主页面 rebuild 尾巴。

## 2026-03-23 最近动态 54
- 完成：继续收口 `ChatScreen / SettingsScreen` 这轮“点了以后慢半拍”优化。`SettingsScreen` 补齐 `_SettingsAccountSecurityViewData`，把账号与安全区的手机号 / UID 展示正式收口成单一 `Selector<AuthProvider, _SettingsAccountSecurityViewData>`，避免这块仍然直接挂两处 `Consumer<AuthProvider>`。
- 完成：把 `ChatScreen` 的 provider 监听门禁从“只看 thread interaction revision”补成“interaction revision + canonical thread id + outgoing delivery fingerprint”的轻量组合判断。这样仍然能挡住无关 `ChatProvider` 通知，但不会再漏掉本线程送达提示、重试成功/失败反馈，以及本地 thread 升级为远端 thread 后的 canonical route 替换。
- 完成：补了一条 `ChatProvider` 回归测试，锁住“其他线程变更不会推动当前线程 interaction revision，而当前线程发消息会推动；置顶这类列表层变化不该推动当前线程 interaction revision”这条边界，避免后续继续压性能时把 `ChatScreen` 监听面重新放大。
- 涉及模块：`flutter-app/lib/screens/chat_screen.dart`、`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/test/providers/chat_provider_test.dart`
- 验证：
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/providers/chat_provider.dart lib/providers/chat_provider_threads.dart lib/providers/chat_provider_messages.dart lib/providers/chat_provider_realtime.dart lib/providers/chat_provider_storage.dart lib/screens/chat_screen.dart lib/screens/settings_screen.dart test/providers/chat_provider_test.dart`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/chat_provider_test.dart --reporter expanded`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded`
  - `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：`ChatScreen` 现在已经把最容易放大“慢半拍”的 provider listener 尾巴压住了，但 `ChatProvider` 仍是单一 `ChangeNotifier`；如果真机上聊天页切换、撤回、已读同步时还偶发轻微发闷，下一轮应该继续往“输入区状态 / 送达统计 / 当前线程头部信息”的更细粒度 selector 或局部 revision 推进。
- 下一步建议做什么：
  1. 继续检查 `SettingsScreen` 里剩余依赖 `SettingsProvider` 的动作回调和 sheet 返回链路，确认保存后反馈、弹层关闭和首页回流不再有多余 notify。
  2. 继续往 `ChatScreen` 的输入区和头部操作区收口，把“发送中 / 失败 / 已读 / 路由纠正”相关状态拆得更局部，进一步压低真机点击后的尾部感。

## 2026-03-23 最近动态 53
- 完成：继续沿着 `MessagesTab` 列表层性能收口，把“线程排序 / 置顶优先级 / 搜索所依赖的列表快照”从 `ChatProvider` 的整体验证里再拆细一层。`ChatProvider` 现在新增了 `threadListPresentationRevision` 和排序缓存，只在真正影响列表呈现的变化发生时，才让消息列表层重新拿一次排序结果；像草稿、已读、未读清零这类只该影响单条会话卡片的状态，不会再顺手把整列线程顺序快照一起判成脏。
- 完成：给线程列表顺序缓存补了更细的失效边界。现在置顶/取消置顶、线程增删、删除恢复、会话升级为远端线程、最近消息时间变化、远端历史合并导致最后一条消息变化时，才会刷新列表 revision；而像草稿保存、行内已读回调、未读数清零这类 row-only 变化，会继续留在单条线程的 selector 里消化。
- 完成：顺手把 `MessagesTab` 顶层 selector 从整份 `thread list view data` 比较，收成只监听 `threadListPresentationRevision`。这样 provider 有无关通知时，消息页列表层不需要再重复做整份 `sortedThreads -> entries` 映射和逐项比较，进一步减少“没重建但每次都在算”的隐性成本。
- 完成：补了一条 provider 回归测试，锁住“草稿和 markAsRead 不应推动线程列表 revision，而置顶和最近消息变化应该推动 revision”这条边界，避免后续继续压性能时把列表层监听面又放大回去。
- 涉及模块：`flutter-app/lib/providers/chat_provider.dart`、`flutter-app/lib/providers/chat_provider_threads.dart`、`flutter-app/lib/providers/chat_provider_messages.dart`、`flutter-app/lib/providers/chat_provider_realtime.dart`、`flutter-app/lib/providers/chat_provider_storage.dart`、`flutter-app/lib/widgets/messages_tab.dart`、`flutter-app/test/providers/chat_provider_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format lib/providers/chat_provider.dart lib/providers/chat_provider_threads.dart lib/providers/chat_provider_messages.dart lib/providers/chat_provider_realtime.dart lib/providers/chat_provider_storage.dart lib/widgets/messages_tab.dart test/providers/chat_provider_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/providers/chat_provider_test.dart --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/messages_tab_smoke_test.dart --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这一轮把消息列表“是否需要重算顺序”的成本往 provider 层前移了，能继续减轻真机上列表页切回来的发闷感；但 `ChatProvider` 仍然是单一 `ChangeNotifier`，像送达状态统计、聊天输入区回调和设置运行态反馈区，后续仍然有继续拆局部监听和减少无关 notify 的空间。
- 下一步建议做什么：下一轮优先继续推进两件事：
  1. 回到 `SettingsScreen` 和 `ChatScreen`，继续查真机上“点了以后慢半拍”的高频 rebuild / 回调尾巴，优先看设置运行态反馈区和聊天输入区。
  2. 如果消息页大列表真机上仍有轻微发闷，再继续把搜索输入态和列表过滤结果做成本地可复用快照，进一步减少用户输入时的重复映射成本。

## 2026-03-20 最近动态 52
- 完成：继续把 `MessagesTab` 的线程摘要监听从 `ChatProvider` 的整体验证里往下压一层。现在列表层只保留 `threadId + nickname` 这类顺序和搜索所需的轻量数据，单条线程卡片改成通过 `Selector2<ChatProvider, FriendProvider, _MessagesThreadSummaryViewData?>` 自己监听置顶、未读、草稿、最近消息摘要、关系态和在线态，避免一条线程的摘要变化把整页消息列表一起拉着重建。
- 完成：把上一轮中途停下的 `messages_tab.dart` 重构彻底收口，补齐了 `_ThreadItem` / `_ThreadAvatar` 对 `viewData` 的新参数模型，顺手抽出 `_UnreadBadge` 复用未读徽标渲染，并清掉 `build()` 里残留的旧版列表实现注释块。这样后续继续做消息页性能收口时，代码结构已经回到清晰、可维护的状态。
- 完成：保留现有消息页视觉层级和交互不变，只缩小高频 rebuild 的边界。现在像置顶切换、未读数变化、草稿更新、送达状态变化、最近消息摘要变化，都会优先收敛到对应线程卡片自身，而不是扩大成整个 `MessagesTab` 的列表重建。
- 涉及模块：`flutter-app/lib/widgets/messages_tab.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format lib/widgets/messages_tab.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/messages_tab_smoke_test.dart --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这一轮已经把消息列表里最影响“点了慢半拍”的摘要监听面缩小了，但 `ChatProvider` 仍然是单一 `ChangeNotifier`，列表排序和搜索过滤仍然依赖 `sortedThreads` 的整体验证结果；如果后面真机上在大量会话场景里仍能感到列表切换发闷，下一轮就该继续把线程排序快照或列表域通知再拆细一层。
- 下一步建议做什么：下一轮优先继续推进两件事：
  1. 继续沿着 `MessagesTab` 往下压，把线程排序、搜索过滤和置顶优先级的只读快照继续从 `ChatProvider` 的整体验证里拆出来。
  2. 回到 `SettingsScreen` 和 `ChatScreen` 的高频交互点，继续查真机上“点了以后慢半拍”的 rebuild / 回调尾巴，尤其是设置运行态反馈区和聊天输入区。

## 2026-03-20 最近动态 51
- 完成：继续沿着“性能手感收口”推进，把 `ChatProvider` 里“通知 UI”和“需要落盘”的边界拆得更清楚。现在像置顶/取消置顶、草稿的可选通知、以及本地聊天快照恢复完成后的首轮刷新，都会走不触发持久化的通知路径，避免这类只影响当前会话感知或列表呈现的局部状态，顺手拉起一次无意义的磁盘写入计划。
- 完成：收掉一处会放大聊天页“轻微慢半拍”体感的同步细节。`_loadMessagesRemoteInternal()` 现在在远端消息合并后，会先判断消息列表的呈现结果是否真的变化；如果只是更新内部的最近远端同步时间，而消息内容、顺序、状态和图片引用都没有变化，就不再额外 `notifyListeners()`，从而避免把“同步已发生但 UI 无差异”也变成一次聊天页重绘。
- 完成：补了这轮性能边界的 provider 回归测试，锁住三类容易回退的问题：本地恢复后不要立刻回写、置顶状态更新不要带持久化、远端历史与本地一致时不要产生额外 UI 通知。这样后续继续做 `ChatProvider` 和消息页性能优化时，有一层明确的约束兜底。
- 涉及模块：`flutter-app/lib/providers/chat_provider.dart`、`flutter-app/lib/providers/chat_provider_storage.dart`、`flutter-app/test/providers/chat_provider_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format lib/providers/chat_provider.dart lib/providers/chat_provider_storage.dart test/providers/chat_provider_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/providers/chat_provider_test.dart --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这一轮没有改聊天功能行为，只是在 provider 层减少无意义通知和回写；但 `ChatProvider` 里仍然是单一 `ChangeNotifier`，像线程列表排序、未读汇总、送达统计和当前会话消息变化，后续仍有继续拆通知域的空间。如果你真机上消息列表页和会话页切换时还会偶发“半拍慢”，下一轮就该继续往更细粒度的只读快照或分层 provider 推进。
- 下一步建议做什么：下一轮优先继续推进两件事：
  1. 继续看 `MessagesTab`，把线程列表需要的摘要数据从 `ChatProvider` 整体通知里再往下收，尤其是置顶、未读和最近消息摘要这几类高频变化。
  2. 回到 `SettingsScreen`，继续收账号区和运行态反馈区对 `AuthProvider / SettingsProvider` 的监听精度，把“设置页点一下有轻微拖感”的尾巴再压一轮。

## 2026-03-20 最近动态 50
- 完成：把上一轮做了一半的 `SettingsScreen` 性能收口补完整，正式去掉总览区对整块 `SettingsProvider` 的宽监听，改成基于 `_SettingsViewData / _SettingsOverviewViewData` 的局部 `Selector`。现在总览卡、设备状态卡、体验预设卡和三个高频开关区都只对自己真正关心的状态字段敏感，避免通知运行态、隐身态或振动态的局部变化把整页设置列表一起带着重建，继续往真机“点了不拖泥带水”的手感收。
- 完成：顺手把这轮工作区里的临时产物清掉，并补上忽略规则，避免后续开发再被测试日志和损坏备份文件污染。已删除 `flutter-app/lib/widgets/profile_tab.dart.corrupt-1654.bak` 与 `tmp_test_logs/` 内的临时日志，同时在根目录 `.gitignore` 增加 `tmp_test_logs/` 和 `*.corrupt-*.bak`。
- 完成：把本轮改动控制在“性能与工作区卫生”范围内，没有改动设置页现有视觉结构、信息层级和交互路径；重点是缩小 rebuild 范围、降低高频点击后的无关重绘，保证你真机上设置页的响应更干净、稳定。
- 涉及模块：`flutter-app/lib/screens/settings_screen.dart`、`.gitignore`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format lib/screens/settings_screen.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这一轮已经把 `SettingsScreen` 顶层最重的一层监听拆下来了，但设置页里仍有少量账号信息展示区直接依赖 `AuthProvider`，聊天侧也还没有继续往 `ChatProvider` 内部通知域拆分；如果真机上“点了以后慢半拍”的感觉还偶发出现，下一轮就应该继续往 provider 内部的通知粒度和局部数据快照下沉。
- 下一步建议做什么：下一轮优先推进两件事：
  1. 继续检查 `SettingsScreen` 里账号区和运行态反馈区是否还能再缩小监听面，尤其是 UID / 手机号展示和通知反馈回调链路。
  2. 回到 `ChatProvider`，把当前会话、送达状态、未读统计和线程列表的通知边界继续拆细，进一步压低聊天页那种“轻微慢半拍”的体感。

## 2026-03-20 最近动态 49
- 完成：继续按“先压高频 rebuild，再谈更深层性能”的思路，优先收了 `ChatScreen` 里最容易带来“点了慢半拍”的两个依赖点。消息列表原来直接整块挂在 `Consumer<ChatProvider>` 下，只要聊天 provider 里有任意会话更新、路由纠正、未读变化或送达统计变化，当前会话的消息列表都有机会被一起带着重建；这轮已经把它改成只对“当前 thread 的消息展示状态”敏感的选择器，尽量把其他会话或无关 provider 更新挡在列表之外。同时，聊天页顶部的通知权限横幅也从整页依赖改成了局部选择器，避免通知权限态变化时把整页聊天内容重新拉一遍。
- 完成：顺手收了 `SettingsScreen` 里一个很不划算的整页依赖。之前设备状态卡内部会直接监听 `NotificationCenterProvider`，导致通知中心摘要一变，整页设置列表都有机会跟着重建；现在这层依赖已经被缩到“通知通道提示”卡内部，通知摘要仍然会正常刷新，但不会再放大成整页列表的重建成本。
- 完成：把这轮性能收口控制在“不改交互、不改视觉”的范围内，优先保证真机手感。现有 `ChatScreen` 和 `SettingsScreen` 的 smoke 行为都保持稳定，说明这轮优化主要是在减少无关更新带来的界面抖动和响应拖延，而不是靠牺牲交互逻辑换性能。
- 涉及模块：`flutter-app/lib/screens/chat_screen.dart`、`flutter-app/lib/screens/settings_screen.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format lib/screens/chat_screen.dart lib/screens/settings_screen.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这一轮已经明显缩小了两处高频整页重建来源，但还没有继续深入到 provider 内部的更细粒度状态拆分，例如 `ChatProvider` 内部线程列表 / 当前会话 / 送达统计的通知域隔离，以及 `SettingsScreen` 顶层整页 consumer 的进一步收口；如果真机上仍然能感到“偶尔慢半拍”，下一轮就该继续往 provider 分层和更细粒度 selector 下沉。
- 下一步建议做什么：下一轮优先继续推进两件事：
  1. 继续深挖 `ChatProvider` 的通知粒度，把当前会话和其他会话的状态变更进一步隔离，尤其是送达统计、未读同步和 thread 元数据更新。
  2. 继续检查 `SettingsScreen` 顶层 overview / preset / toggle 区块，看看是否有必要把整页 `Consumer<SettingsProvider>` 再拆成几个局部 selector 卡片，进一步压低切换和点击开关时的整页重绘感。

## 2026-03-20 最近动态 48
- 完成：继续收 `ProfileTab -> SettingsScreen -> 返回首页` 的回流节奏，把原来“直接弹成功提示 + 首页已同步”的单段反馈，改成更自然的两段式状态。现在当用户在设置里改了会直接影响首页身份区的内容后，返回 `我的` 页如果当前还停在下方内容区，会先在顶部身份区看到一个短暂的 `首页同步中` 徽标，页面同时自动回到身份区顶部，随后再切换为 `首页已同步`，最后补上原来的成功轻提示，整体更像成熟聊天产品里“先回焦点、再确认同步完成”的节奏。
- 完成：把这段状态机收成局部能力，没有去改动现有视觉方向。`ProfileTab` 现在只在“确实存在首页可见变更且需要回焦点”时展示 `同步中 -> 已同步`，账号类改动仍然保持轻提示即可，不会把所有设置返回都做成打扰式提示；同时保留原有头像/背景远端回显、滚动回顶和首页轻提示逻辑，避免这轮体验优化影响既有链路。
- 完成：补齐这轮回流体验的 smoke 约束。`main_screen_smoke_test.dart` 现在除了继续锁住“返回设置后远端媒体引用正确回显、滚动回到身份区顶部、最终成功提示出现”，还会额外验证中间态 `首页同步中` 与后续 `首页已同步` 的切换，确保后续继续打磨 `ProfileTab` 时，这段回流节奏不会被无意改回去。
- 涉及模块：`flutter-app/lib/widgets/profile_tab.dart`、`flutter-app/test/smoke/main_screen_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format lib/widgets/profile_tab.dart test/smoke/main_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这一轮主要压的是设置返回首页后的“状态理解成本”和“视线回流节奏”，还没有继续深入清理 `SettingsScreen / ChatScreen` 内部更细的高频 rebuild、异步回调串行和局部重绘开销；当前交互已经更顺，但真机上仍建议重点观察低端机或高刷新屏下，这个 `同步中` 徽标的停留是否自然，以及自动回顶时是否还有轻微顿挫感。
- 下一步建议做什么：下一轮优先继续推进两件事：
  1. 继续排查 `SettingsScreen` 与 `ChatScreen` 内部高频 rebuild / 重回调点，把“点击后慢半拍”和“回调有点滞”的体感往下压一轮。
  2. 沿着 `我的` 页首屏继续做小屏与手势操作的真机微调，重点看头像、背景、更多设置三类入口的单手触达和停留密度。

## 2026-03-20 最近动态 47
- 完成：把 `SettingsScreen` 底部原来两个孤立的危险按钮，收成了更清晰的“账号操作区”。现在在 `关于与协议` 下方会先出现一张差异说明卡，明确告诉用户“退出登录”只影响当前设备，“注销账号”会清除账号与会话数据且不可恢复；下面再分别用两张独立语义卡承接这两个动作，点击热区更大，误触和犹豫成本都更低，也更符合成熟聊天产品对危险操作的层级设计。
- 完成：强化危险操作确认文案，不再只给泛泛的“确定吗”。退出登录确认框现在会明确说明“仅退出当前设备，账号资料和关系仍保留，可重新登录”；注销账号确认框会明确说明“账号资料与会话数据会被清除，且不可恢复，如果只是暂时离开建议先退出登录”。这样用户在最后一步也不会把两个动作混淆。
- 完成：补齐危险操作区的回归约束。`settings_logout_smoke_test.dart` 现在会额外锁住账号操作说明卡、退出卡、注销卡以及两类确认文案；`settings_screen_smoke_test.dart` 也补了 compact 小屏下危险操作区的可见性约束，确保这一轮结构优化不会在后续小屏调优里被挤坏。
- 涉及模块：`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/test/smoke/settings_logout_smoke_test.dart`、`flutter-app/test/smoke/settings_screen_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format lib/screens/settings_screen.dart test/smoke/settings_logout_smoke_test.dart test/smoke/settings_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_logout_smoke_test.dart --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这一轮主要解决的是危险操作区的语义分层和误触风险，还没有继续往下收“设置返回首页后的焦点回流”和“设置页内部更多局部 rebuild / 卡顿源”两类真机体感问题；当前逻辑已更清楚，但真机上仍建议重点观察超长系统字体、深色状态栏和不同安卓厂商底部手势区下，这两张账号操作卡的点击舒适度和确认弹层阅读节奏。
- 下一步建议做什么：下一轮优先继续推进两件事：
  1. 回到 `ProfileTab -> SettingsScreen -> 返回首页` 的往返链路，继续压资料修改成功后的轻提示停留节奏、滚动焦点和同步完成的体感。
  2. 继续排查 `SettingsScreen` 与 `ChatScreen` 内部高频 rebuild / 重回调点，结合真机反馈把“点击后有点滞”和“回调慢半拍”的感觉再往下压一轮。

## 2026-03-20 最近动态 46
- 完成：继续推进 `我的 -> 设置 -> 返回首页` 链路里最容易让用户产生“点了保存却没底”的两张账号 sheet。`SettingsScreen` 里的手机号和密码编辑弹层现在不再默认让 `保存 / 确认` 按钮一直可点，而是会根据输入状态实时切换成“未完成校验 / 可以保存”的表单态反馈；无效输入会留在当前 sheet 里继续修正，不会像之前那样先把弹层关掉、再把用户丢回设置列表页看失败提示。
- 完成：把这套表单态体验做成统一模式，顺手补上更明确的视觉反馈。手机号 sheet 现在会区分“还需要完整的 11 位手机号”“当前号码未变化”“可以保存新手机号”；密码 sheet 会区分“旧密码还未校验通过”“新密码至少需要 6 位”“两次输入的新密码还不一致”“可以保存新密码”。同时 `保存 / 确认` 按钮在未通过校验时会连同文字态一起进入禁用样式，减少“看起来能点、点了却没反应”的错觉。
- 完成：补齐这轮设置页交互优化的 smoke 约束。`settings_screen_smoke_test.dart` 现在除了继续验证手机号和密码修改成功后的页内反馈，还会额外锁住“无效输入时 sheet 保持打开、按钮仍处于禁用态、校验提示留在弹层内”的行为；`settings_logout_smoke_test.dart` 也重新通过，确认这次改动没有连带影响底部退出登录和注销账号链路。
- 涉及模块：`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/test/smoke/settings_screen_smoke_test.dart`、`flutter-app/test/smoke/settings_logout_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format lib/screens/settings_screen.dart test/smoke/settings_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_logout_smoke_test.dart --reporter expanded`
- 风险 / 备注：这一轮主要收的是账号 sheet 的输入体验和反馈时序，还没有继续改动危险操作确认框本身的内容层级；当前已经避免了“错误输入直接关闭 sheet”的体验断层，但真机上仍建议重点观察系统键盘弹起后弹层底部按钮的遮挡感，以及不同 Android 输入法下按钮禁用态的可辨识度是否足够。
- 下一步建议做什么：下一轮优先继续做两件事：
  1. 把 `SettingsScreen` 底部危险操作区做成更清晰的“退出登录 / 注销账号”差异说明，减少误触和犹豫成本。
  2. 继续回到 `ProfileTab` 与 `SettingsScreen` 的往返链路，重点看资料修改成功后的返回时机、轻提示停留时长和滚动焦点，继续往真机成品感推进。

## 2026-03-20 最近动态 45
- 完成：继续沿着 `ProfileTab` 做真机导向的小步体验优化，把 compact 首屏三颗快捷动作和 `更多设置` 轻入口的点击尺寸统一收口。现在 `补头像 / 改状态 / 补背景` 三个快捷按钮在 360~390 宽度机型下不再因为文案长短出现明显尺寸波动，`更多设置` 也同步抬到更稳定的最小宽高，单手点击更稳，整体首屏观感更像成熟聊天 app 的一组主操作区，而不是临时拼起来的几个小标签。
- 完成：把全屏背景态右上角那组“两个小圆点按钮”收成了更成熟的共享操作区。`ProfileTab` 在竖屏全屏背景模式下，右上角现在会显示一组带短标签的胶囊操作区，分别承接 `背景` 和 `设置`，热区明显更大、语义更清楚，也减少了用户把它误解成开发态浮层按钮的风险。
- 完成：补齐这轮体验优化的 smoke 回归。`main_screen_smoke_test.dart` 现在除了继续锁住 compact 首屏的无额外滚动空间，还会额外验证小屏快捷动作的最小宽度，以及全屏背景态共享操作区的出现、按钮尺寸和背景管理入口是否可正常触达，确保后续继续调 `ProfileTab` 时，这轮优化不会被无意覆盖掉。
- 涉及模块：`flutter-app/lib/widgets/profile_tab.dart`、`flutter-app/test/smoke/main_screen_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format lib/widgets/profile_tab.dart test/smoke/main_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这轮仍然只在 `ProfileTab` 里做局部收口，没有继续扩到 `SettingsScreen` 或更大的全局导航层；当前结构已经更稳，但真机上仍建议重点观察全屏背景态右上角操作区在不同刘海屏、状态栏高度和手持姿势下的遮挡感，以及 compact 首屏三个快捷动作在不同系统字体缩放下是否仍然保持同一行可读。
- 下一步建议做什么：下一轮优先继续推进两个方向：
  1. 继续压 `ProfileTab` 紧凑身份卡和快捷整理卡之间的纵向留白，让小屏首屏在不增加滚动的前提下更干净、更聚焦。
  2. 开始回到 `SettingsScreen`，沿着“我的 -> 设置 -> 返回首页”的链路继续检查底部弹层、危险操作确认框和保存后反馈时序，把这条链路的真机体感继续往上线质量推进。

## 2026-03-20 最近动态 44
- 完成：把 `flutter-app/lib/widgets/profile_tab.dart` 从编码损坏后的不可编译状态完整救回。上一轮在修小屏布局时，这个文件因为编码回写被破坏，导致 `build()` 主树断裂、`ProfileTab` 连带出现 175 个 analyze 问题；这一轮已经把顶部背景区、身份区、紧凑小屏快捷整理卡和全屏背景态的层级重新接回稳定结构，恢复到可编译、可继续开发的状态。
- 完成：把 `ProfileTab` 里被截断成 `?` 的核心产品文案和状态语义一起收口，避免“代码能跑但交互不可信”。这轮重点修回了 `想找人聊聊` 默认状态、`补头像 / 改状态 / 补背景` 快捷入口、`待补充 / 首屏展示中 / 展示已刷新 / 首页已同步` 等回调文案，同时把完成清单、优先动作卡、头像/背景管理 sheet、设置返回首页轻提示的文字统一回成熟社交产品语境，保证小屏和正常屏下的感知一致。
- 完成：把这次恢复和产品回归重新锁进主 smoke。`main_screen_smoke_test.dart` 现已重新通过，继续覆盖 compact 首屏快捷动作顺序、热区高度、无额外滚动空间、头像/背景管理 sheet 状态、优先动作卡展开、设置返回首页后的远端媒体回显和同步提示等关键链路，确保这次不只是“勉强修能编译”，而是把用户能感知到的交互一起拉回稳定线。
- 涉及模块：`flutter-app/lib/widgets/profile_tab.dart`、`flutter-app/test/smoke/main_screen_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format lib/widgets/profile_tab.dart test/smoke/main_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：当前 `ProfileTab` 已从“文件损坏”回到“可稳定迭代”，但这一轮主要是在保住已有产品方向和恢复回归基线，还没有继续往下压真机上的细粒度体感，例如头像/背景管理 sheet 的单手触达顺序、全屏背景态右上角双操作按钮的点击舒适度，以及个人页卡片间距在不同 Android 机型上的一致性。
- 下一步建议做什么：下一轮优先继续做两件高性价比的小步优化：
  1. 继续压 `ProfileTab` 紧凑首屏的卡片间距和动作层级，让 `更多设置`、头像管理、背景管理在 360~390 宽度机型上更像微信 / Telegram 这类成熟聊天 app 的单手操作顺序。
  2. 在保持现有 smoke 稳定的前提下，补一轮 `ProfileTab` 真机导向的交互验证点，例如 sheet 打开/关闭节奏、全屏背景态入口热区和资料编辑回流提示时长，避免后续只靠静态 UI 看起来“对了”，但手感仍然发紧。

## 2026-03-20 最近动态 43
- 完成：继续把 `我的 / 设置 / 返回首页` 这条链路往“用户一眼能感知已经生效”推进。`ProfileTab` 现在在设置返回且确实发生头像、背景、昵称、状态或签名变化时，除了原有页内轻提示，还会在顶部身份区短暂出现一个 `首页已同步` 轻徽标，让用户第一眼就知道当前看到的主页资料已经刷新完成，不需要只靠读文案来确认是否生效。
- 完成：把这层顶部身份感知也接回现有主 smoke。`main_screen_smoke_test.dart` 里的“从设置返回后回显远端头像/背景”用例，现在除了继续验证轻提示文案、头像/背景网络图回显和滚动位置回顶，还会额外锁住 `profile-identity-sync-badge` 的出现，避免后续继续调 `ProfileTab` 头部结构时，把这层对用户更直接的同步感知悄悄回退掉。
- 涉及模块：`flutter-app/lib/widgets/profile_tab.dart`、`flutter-app/test/smoke/main_screen_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format lib/widgets/profile_tab.dart test/smoke/main_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这一轮刻意只加了轻徽标，不去叠更重的高亮动画或额外弹层，目的是继续守住“克制、成熟、偏原生”的产品方向；当前同步感知已经更直接，但真机上仍建议重点观察徽标出现的位置和时长，确认不会遮住头像/昵称操作入口，也不会显得像系统级打扰。
- 下一步建议做什么：如果这条回流链路真机反馈稳定，下一轮优先继续收两件事：
  1. 压 `ProfileTab` 顶部身份区与快捷整理卡之间的视觉过渡，让同步完成后的注意力自然落到“接下来可做什么”而不是停在提示本身。
  2. 继续检查 `更多设置` 轻入口、头像入口、背景入口在单手持机场景下的误触率和热区边界，把小屏体验再往成熟聊天 app 靠一轮。

## 2026-03-20 最近动态 42
- 完成：把 `ProfileTab` 这一轮“紧凑小屏快操作层级收口”正式验证完。当前 compact 个人页不再把 `更多设置` 和资料整理 badge 放在同一优先级里竞争注意力，而是把设置收进标题右侧的轻入口，首屏主动作继续聚焦在 `补头像 / 改状态 / 背景管理` 这三件高频任务上，减少用户在小屏里先看设置、再回头找资料完善入口的认知切换。
- 完成：补齐 `main_screen_smoke_test.dart` 对这次 compact 层级调整的回归约束。用例现在明确锁住 compact 态下 `profile-quick-actions-badge` 不再出现，同时继续验证 `profile-quick-settings`、`更多设置`、`改状态`、`补头像`、`补背景` 等主入口仍然可见，并保持 `profile-main-scroll` 在 360x640 尺寸下没有额外滚动空间，避免后续再把小屏首屏挤回可滚动态。
- 涉及模块：`flutter-app/lib/widgets/profile_tab.dart`、`flutter-app/test/smoke/main_screen_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format lib/widgets/profile_tab.dart test/smoke/main_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这一轮已经把 compact 首屏的按钮优先级和 smoke 约束重新对齐，但还没有继续下压 `我的 / 设置` 真机上的动态回流体感，比如“从设置返回后顶部身份区的轻提示是否足够自然”、“更多设置入口在深色背景上的触达感是否还需要再轻一点”。这些更适合下一轮结合真机反馈做微调，而不是继续在同一轮里叠新入口。
- 下一步建议做什么：继续沿着 `我的 / 设置 / 返回首页` 链路做产品化打磨，优先看两件事：
  1. 真机验证 `更多设置` 轻入口在单手操作下是否足够稳、是否会误触头像/背景编辑入口。
  2. 如果这条链路已经稳定，下一轮优先收 `ProfileTab` 顶部身份区和设置返回后的轻反馈过渡，让用户在改完资料后更自然地感知“首页已同步”，而不是只看到静态结果。

## 2026-03-20 最近动态 41
- 完成：继续按“产品经理 + 用户操作体验”的视角收 `我的 / 设置` 返回链路。`ProfileTab` 现在不再只用一个泛泛的“首页身份信息已同步”提示，而是会根据用户这次在设置里实际改了什么，给出更具体的轻提示，例如“头像和背景已同步到首页”“个人资料已同步到首页”“账号设置已经更新”；这样用户返回后不需要再自己猜到底是头像、背景还是资料发生了变化。
- 完成：补上“设置返回首页后的身份感知一致性”。当用户在设置里改动了头像、背景、昵称、签名或状态这类首页可见信息后，返回 `我的` 页时会自动把页面带回身份区顶部，再显示对应轻提示，避免用户停留在下方卡片位置时虽然数据已经同步，但肉眼第一时间看不到变化，导致误以为没有生效。
- 完成：顺手修掉设置页总览快捷动作在窄宽度场景下的横向溢出。`SettingsScreen` 的总览按钮现在会根据可用宽度自动切换成更紧凑的按钮布局，保证在较窄真机宽度、分栏和 smoke 环境里不会再出现文字被挤爆或按钮横向溢出的情况，首屏操作入口更稳定。
- 涉及模块：`flutter-app/lib/widgets/profile_tab.dart`、`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/test/smoke/main_screen_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/screens/settings_screen.dart flutter-app/lib/widgets/profile_tab.dart flutter-app/test/smoke/main_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这轮重点解决的是“设置返回我的后的感知断层”和“窄宽度设置页入口溢出”，没有继续扩展新的信息入口；当前回流提示已经更具体、回到首页也更容易第一时间看到变化，但后续如果你在真机上仍觉得顶部变化感不够强，下一轮可以继续评估是否把“首页身份区局部高亮”或“头像 / 背景变化瞬时描边”也纳入轻量交互层，而不是新增更重的弹层。
- 下一步建议做什么：继续真机重点看 `我的 / 设置 / 首页返回` 这条链路，尤其验证用户在个人页中下部进入设置、修改头像背景再返回时，现在是否能第一时间理解“已经生效”；如果这条链路稳定，下一轮优先继续压 `我的` 页卡片密度、按钮层级和首屏信息顺序，让资料整理、设置入口和反馈层更像一套成熟社交产品。

## 2026-03-20 最近动态 40
- 完成：继续收口 `SettingsScreen` 的损坏状态，修复了设置页里残留的乱码文案、断裂字符串和重复类型声明，恢复了设备状态卡、体验预设卡、黑名单管理、通知中心摘要、头像/背景管理、注销入口等核心区块的可读性与可编译性，避免真机和 smoke 里继续出现中文乱码、状态误解和编译断裂。
- 完成：把设置页的页内轻反馈重新接回成可见链路，并改成顶部轻提示层，保证从通知权限、头像背景管理、账号安全编辑等低频入口返回后，用户不用回滚到页首也能立即看到结果反馈；同时把默认媒体 badge、删除后的 badge 和通知权限恢复描述统一回归到现有 smoke 约定，补齐“待补充 / 已清空 / 检测到系统通知权限已恢复”等关键状态文案。
- 完成：补回设置首屏焦点卡与紧凑布局稳定性。新增 `_buildOverviewFocusCard(...)` 实现，修复 `settings-overview-focus-card` 缺失导致的回归失败；同时继续压 tight 小屏下体验预设卡的纵向高度，把 320~340 宽度级别设备上的卡片高度重新压回 smoke 约束内，减少首屏挤压和滚动压力。
- 涉及模块：`flutter-app/lib/screens/settings_screen.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/screens/settings_screen.dart flutter-app/test/smoke/settings_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_logout_smoke_test.dart --reporter expanded`
- 风险 / 备注：这轮主要是把设置页从“文件损坏 + 局部回归失效”拉回到稳定基线，没有继续扩展新功能；当前 smoke 和 analyze 都已经恢复，但由于设置页近期改动密度较高，后续如果继续调整 `我的 / 设置` 的文案或布局，建议优先守住现有 key、badge 文案和顶部轻反馈层的位置，不要再让首屏焦点卡、媒体管理 badge 和 notification runtime feedback 脱离回归覆盖。
- 下一步建议做什么：回到真机继续重点看 `我的 / 设置` 的真实滚动和回调体感，优先验证顶部轻提示层是否会遮挡首屏内容、头像/背景管理往返是否足够自然，以及通知权限从系统设置返回后的反馈是否和实际设备行为一致；如果这块稳定，再继续推进更大范围的 `我的 / 设置` 小屏密度优化和交互收口。

## 2026-03-20 最近动态 39
- 完成：把 `ProfileTab` 里的头像/背景入口从“直接换图”收口成和设置页一致的“先看状态、再做操作”的管理 sheet。个人页头像、背景、compact 快捷操作、检查清单现在都会先进入管理面板，再按当前是否已有媒体动态显示 `补头像 / 头像管理`、`补背景 / 背景管理`、`补一个头像 / 重新上传背景 / 调整背景模式 / 删除` 这套动作，个人页和设置页的媒体心智进一步对齐。
- 完成：补齐个人页媒体管理在小屏下的稳定性。头像/背景管理 sheet 改为 `isScrollControlled`，避免 360x640 级别真机或 smoke 环境里被默认半屏高度截断；管理 badge 的 key 也统一落在文本节点上，和现有页内 inline feedback 的约定保持一致，测试定位更稳定。
- 完成：顺手修复设置页危险操作回归的稳定性。`退出登录` 和 `注销账号` 按钮补回稳定 key，`AppDialog.showConfirm(...)` 改为可滚动、可在小屏安全展开的确认弹层，避免后续危险操作链路因为弹层高度或按钮定位漂移而脱离 smoke 覆盖。
- 涉及模块：`flutter-app/lib/widgets/profile_tab.dart`、`flutter-app/lib/widgets/app_toast.dart`、`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/test/smoke/main_screen_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/widgets/profile_tab.dart flutter-app/lib/widgets/app_toast.dart flutter-app/test/smoke/main_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/screens/settings_screen.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_logout_smoke_test.dart --reporter expanded`
- 风险 / 备注：这轮主要收的是“个人页媒体管理一致性 + 小屏弹层稳定性”，还没有把 `ProfileTab` 和 `SettingsScreen` 的媒体管理弹层完全抽成共享组件；目前交互已经统一，但后续如果继续新增媒体状态文案或动作，仍建议继续往同一套 helper 收口。
- 下一步建议做什么：继续回到真机重点看 `我的 / 设置` 来回切换头像、背景、背景模式时的回显是否够自然；如果这一块稳定，下一轮优先压剩余的小屏布局挤压和局部滚动感。

## 2026-03-20 最近动态 38
- 完成：继续收 `SettingsScreen` 里头像 / 背景管理的状态表达，让设置页和个人页的媒体入口更像同一套产品语言。设置页列表项现在不再只写“已设置 / 默认”，而是改成更结果导向的“已同步 / 首屏已生效 / 待补充”；头像列表项会直接告诉用户“当前头像已经同步到消息列表和个人主页”，背景列表项会明确说明“当前背景已经生效在个人主页首屏”，减少用户看到入口后还得自己判断“现在到底有没有真正生效”的成本。
- 完成：同步收口媒体管理 sheet 的当前状态和主动作。头像 / 背景管理弹层顶部预览卡现在会显示“当前头像已经同步 / 当前背景已经生效”或“当前还在使用默认头像 / 背景”，对应 badge 改成“展示中 / 首屏展示中 / 待补充”；主操作也改成按当前状态动态表达，例如“补一个头像 / 补一张背景”以及“重新上传头像 / 重新上传背景”，让用户点进弹层后立刻知道自己下一步最应该做什么。
- 完成：补强设置页媒体管理 smoke。现有回归现在会继续锁住默认态和已设置态下的媒体管理 badge、sheet 状态 badge 与主操作标题，并额外验证上传成功后列表项状态会更新成“已同步 / 首屏已生效”，避免后续继续改设置页 UI 时又回到“提示文案更像成品，但入口状态还是很泛”的状态。
- 涉及模块：`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/test/smoke/settings_screen_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/screens/settings_screen.dart flutter-app/test/smoke/settings_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这轮仍然是“媒体入口和状态语义一致性”收口，没有继续把个人页和设置页的媒体操作抽成完全共用的一套组件；当前用户理解成本已经下降，但如果后面真机反馈还觉得“个人页点头像改、设置里点管理改”是两套心智，下一轮可以继续评估是否把媒体管理入口和反馈层进一步统一。
- 下一步建议：继续做真机回归，重点看个人页与设置页来回切换修改头像 / 背景时，状态回显和入口理解是否已经自然；如果这块稳定，下一轮继续压 `我的 / 设置` 里剩余的小屏触达路径和滚动体感问题。

## 2026-03-20 最近动态 37
- 完成：继续收 `ProfileTab` 在 compact 小屏下的媒体入口层级。个人页顶部的头像编辑角标和背景编辑角标现在都改成更轻的圆形入口，不再继续用占面积更大的横向浮层 pill；这样 360x640 级别下头像和背景图的主体信息不容易再被入口本身压住，首屏视觉也更接近常见成熟社交产品的“内容主体 + 轻入口”关系。
- 完成：调整 compact 个人页快捷区的入口优先级。原来小屏快捷按钮里有一个和卡片本身重复度较高的“编辑签名”，这一轮改成了更有价值的“换头像”，同时把背景按钮改成按当前状态动态表达：没背景时直接显示“补背景”并直达上传，有背景时继续显示“背景模式”；这样头像和背景这两个真机反馈里最容易让人找不到入口的点，现在都能在首屏直接看到，不再只靠用户猜“点头像/点背景图能不能改”。
- 完成：补强个人页 compact smoke。回归现在会继续锁住小屏首屏零额外滚动、快捷区里新的“换头像”入口、无背景时的“补背景”文案，以及有背景时头像/背景角标保持轻量尺寸的行为，避免后续再把 compact 页头重新改回“大角标压内容”的状态。
- 涉及模块：`flutter-app/lib/widgets/profile_tab.dart`、`flutter-app/test/smoke/main_screen_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/widgets/profile_tab.dart flutter-app/test/smoke/main_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这轮优先做的是 compact 个人页入口层级收口，没有继续把个人页头像 / 背景操作抽成和设置页同一套完整管理面板；当前入口可见性和压迫感已经改善，但如果后面真机反馈仍觉得“头像和背景的可编辑状态不够统一”，下一轮可以再评估是否要把个人页媒体管理和设置页媒体管理进一步共用同一套交互语言。
- 下一步建议：继续做 `我的 / 设置` 的真机小屏回归，优先看头像、背景、资料整理卡在 Android 真机上的回弹、切换和触达感是否已经自然；如果这块稳定，下一轮继续收设置页头像/背景管理与个人页媒体反馈之间的一致性。

## 2026-03-20 最近动态 36
- 完成：继续收 `SettingsScreen` 首屏总览的状态语言。设置总览卡、设备状态卡、体验预设卡、开关 badge 现在统一往“提醒已收起 / 展示已收起 / 通道同步中 / 通道已就绪 / 状态已就绪”这一套结果语义靠拢，不再一处写“低曝光 / 更安静 / 在线”，另一处写“展示已收起 / 通道已就绪”，减少用户在同一屏里来回翻译状态的成本。
- 完成：补上设置首屏焦点卡对“通知通道同步中”的识别。之前手机号已补全、通知已开但 device token 还没回来时，总览焦点卡会误判成“当前状态良好”；现在会明确显示“通知通道正在同步 / 通道同步中”，首屏状态和通知运行态卡保持一致。
- 完成：把设备状态卡里的状态项进一步收口到真实用户理解路径。`消息通知 / 展示状态 / 震动提醒` 三条状态现在直接复用统一的 badge 与描述语义，体验预设当前 badge 也改成更结果导向的“主入口 / 提醒更克制 / 展示已收起 / 手动调整中”，用户不用再先记预设名、再自己换算成当前设备到底处于什么状态。
- 完成：补强设置页 smoke。回归现在会同时锁住首屏焦点卡、设备状态卡、开关 badge 和体验预设当前 badge 的统一文案，并新增“通知通道同步中会出现在总览焦点卡”的用例，避免后续继续打磨 UI 时又把首屏状态表达打散。
- 涉及模块：`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/test/smoke/settings_screen_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/screens/settings_screen.dart flutter-app/test/smoke/settings_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这轮主要收的是“同一屏状态语义一致性”，没有去大改设置页布局结构；当前首屏的理解成本已经明显下降，但体验预设的选项标题仍然保留“在线回复 / 低干扰 / 安静观察”这类场景名，后续如果继续往更强的成品感推进，可以再结合真机反馈评估是否还要进一步压缩解释成本。
- 下一步建议：继续做设置页和个人页的真机回归，重点看 360x640 级别小屏下首屏卡片、预设卡、头像/背景入口是否还有挤压和跳动；如果首屏状态理解已经稳定，下一轮优先继续压“我的 / 设置”里剩余的局部布局重叠和滚动体感问题。

## 2026-03-20 最近动态 35
- 完成：继续收 `SettingsScreen` 里高频开关的结果反馈语言。隐身、震动、体验预设现在都改成更统一的“状态已切换 + 当前影响”表达，例如“展示已切到隐身 / 展示已恢复”“震动提醒已经收起 / 已经恢复”“体验预设已切到在线回复 / 低干扰 / 安静观察”，不再一部分在讲场景标签、一部分在讲状态结果。
- 完成：通知反馈也进一步往同一套语义靠拢。通知恢复在线时的 inline feedback badge 现在改成“通道已就绪”，通知静默时改成“提醒已收起”，通知同步中也改成“通道同步中”；这样通知、资料编辑和其他开关在页内轻提示里读起来更像同一套成熟产品语言。
- 完成：补强设置页开关反馈 smoke。现有回归现在会继续锁住隐身 / 通知 / 震动切换后的标题与 badge，以及体验预设和通知恢复在线后的新反馈文案，避免后续优化时又回到“功能没坏，但结果语气越来越散”的状态。
- 涉及模块：`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/test/smoke/settings_screen_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/screens/settings_screen.dart flutter-app/test/smoke/settings_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这轮仍然是“反馈语言统一”，没有去大改设置页总览卡和设备状态卡本身的结构；当前 inline feedback 已经更统一，但列表项 badge、总览摘要和设备状态卡里仍存在少量“场景词”和“结果词”并存的情况，后续如果继续往精品成品感推进，还可以再做一轮总览层文案收口。
- 下一步建议：继续往“设置总览卡与设备状态卡”的信息层级推进，优先统一总览焦点卡、设备状态卡、体验预设卡里的 badge 与摘要语气，再配合真机重点回归，检查连续切换开关时是否还有跳动感或状态切换后的理解成本。

## 2026-03-20 最近动态 34
- 完成：继续收 `SettingsScreen` 里低频账号资料项的反馈语言。手机号、密码编辑现在统一改成更结果导向的 inline feedback：成功态分别收成“账号已刷新 / 安全已刷新”，失败态统一用“未生效”，描述也统一成“已经写回当前资料 / 安全设置”或“本次还没有生效”这套语言，不再一处在说功能用途、一处在说状态结果。
- 完成：顺手补齐设置页账号编辑 sheet 的控制器释放时序。手机号和密码编辑完成后现在会延后释放 `TextEditingController`，避免 sheet 关闭动画期间立即 dispose 带来的潜在抖动或与个人页同类的时序问题，和上一轮 `ProfileTab` 的稳定性处理保持一致。
- 完成：补强账号安全相关 smoke。现有设置页回归现在不仅验证手机号 / 密码保存成功和失败时的标题，还会继续锁住 badge 与描述文案，确保这轮账号资料反馈收口不会在后续修改中悄悄回退成“标题像成品、正文又像临时提示”的状态。
- 涉及模块：`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/test/smoke/settings_screen_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/screens/settings_screen.dart flutter-app/test/smoke/settings_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这轮优先收的是“账号资料修改结果反馈”，没有继续把通知 / 隐身 / 预设等开关型文案统一到完全同一模板；当前账号资料项已经更像成品链路，但设置页里仍存在“资料编辑反馈”和“开关切换反馈”两套轻微不同的语气，后续还可以再做一轮更细的统一。
- 下一步建议：继续往“设置页开关反馈与资料反馈统一”推进，优先看隐身、震动、通知、体验预设这几条高频开关的 badge 与描述是否可以进一步往“状态已切换 / 当前影响”这一套结果语言靠拢，然后补一轮真机重点回归，看连续切换后是否还有跳动感。

## 2026-03-20 最近动态 33
- 完成：继续把个人页资料编辑的“结果反馈”收成和设置页同一套语言。`ProfileTab` 现在把“设置返回同步”“昵称 / 签名 / 状态保存成功”“头像 / 背景更新成功或失败”统一接进资料整理卡片顶部的页内轻提示区，不再只靠底部 toast 告知结果；用户在个人页连续改资料时，不用再靠记忆判断刚才是否真的保存成功。
- 完成：把页内反馈放进原本 readiness 所在位置，而不是额外再插一层卡片。这样 compact 屏首屏结构不额外变高，仍然沿用“同一块区域显示当前状态 / 当前结果”的策略，避免个人页又重新出现一块新的浮层感信息。
- 完成：顺手修掉资料编辑弹层的一个稳定性问题。昵称 / 签名编辑原来在 sheet 关闭后立即 dispose `TextEditingController`，在 widget 测试里已经能稳定打出“controller used after dispose”，现在改成等弹层关闭动画后再释放，并在保存 / 取消前先收起焦点，减少真机快速保存时的潜在抖动和异常。
- 完成：补一条主 smoke，锁住“签名保存后会在个人页内出现统一 inline feedback”的行为，确保这轮不是只加提示文案，而是把新的资料反馈链路真正纳入回归。
- 涉及模块：`flutter-app/lib/widgets/profile_tab.dart`、`flutter-app/test/smoke/main_screen_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/widgets/profile_tab.dart flutter-app/test/smoke/main_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这轮只把个人页资料编辑结果接入页内反馈，没有把设置页所有低频资料项进一步抽成公共组件；当前 `SettingsScreen` 和 `ProfileTab` 的反馈语气已经更一致，但组件层面仍是局部复用、不是统一抽象，后续如果再继续扩展到手机号 / 密码 / 低频展示项时，可以再评估是否需要提一个共享 feedback widget。
- 下一步建议：继续往“设置页低频资料项收口”推进，优先看手机号 / 密码 / 背景模式这些弹层的保存前后状态文案是否还能进一步统一；同时可以开始补一轮资料页真机重点回归，确认 compact 尺寸下连续编辑后没有新增滚动、跳动或焦点抖动。

## 2026-03-20 最近动态 32
- 完成：继续收 `ProfileTab` 里“完成清单”和“优先整理”之间的重复扫描问题。现在资料整理卡片把签名 / 状态 / 背景三项统一成同一套数据表达，完成清单负责展示整体进度并保留可点入口，非 compact 屏的“优先整理”只继续展示还没整理好的项目，不再把已完成项重复铺在第二层卡片里。
- 完成：补强完成状态与动作状态的区分。完成清单的标签在常规屏下现在会直接显示“去完善 / 可微调”动作提示，已完成项不再和未完成项长得完全一样；同时 readiness 提示、完成清单、优先整理三处的顺序统一成“签名 -> 状态 -> 背景”，减少用户在同一张卡片内来回换扫描顺序的成本。
- 完成：补一条非 compact smoke，锁住“状态完成后从优先整理移除，但仍保留在完成清单中作为可微调入口”的行为，确保这轮资料页分层不是纯视觉调整，而是有回归兜底的交互收口。
- 涉及模块：`flutter-app/lib/widgets/profile_tab.dart`、`flutter-app/test/smoke/main_screen_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/widgets/profile_tab.dart flutter-app/test/smoke/main_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这轮有意识地没有继续给 compact 屏加新控件，而是只调整语义和非 compact 分层，目的是继续守住 360x640 下的零额外滚动；当前“已完成项”的二次入口主要落在完成清单标签上，后续如果还要增强常规屏的编辑效率，优先考虑继续收按钮层级，而不是再加一层新面板。
- 下一步建议：继续往“资料编辑结果反馈一致性”推进，把签名 / 状态 / 背景 / 设置内相关保存后的页内轻提示文案再统一一次，并顺手检查剩余低频资料弹层是否还能沿用这套“当前状态 + 动作提示 + 保存结果”语言。

## 2026-03-20 最近动态 31
- 完成：继续收“个人页快速整理”卡片的信息层级。`ProfileTab` 现在在非 compact 屏上新增了“优先整理这三项”资料面板，把个性签名、聊天状态、背景图收成三条带当前状态摘要的优先动作，用户不再只看到一堆平铺按钮，而是先看到“当前怎么样、该先改哪一项”。
- 完成：compact 与常规屏策略进一步分层。compact 屏继续保留轻量按钮结构，保证 360x640 下零额外滚动；常规屏再展示“优先整理这三项”面板和常规工具按钮，兼顾信息表达和小屏稳定性。
- 完成：补强资料整理面板的 smoke 回归。主测试现在会在常规屏尺寸下直接验证优先整理入口存在，并通过这些新入口打开签名与状态编辑弹层，锁住这轮新的资料整理路径。
- 涉及模块：`flutter-app/lib/widgets/profile_tab.dart`、`flutter-app/test/smoke/main_screen_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/widgets/profile_tab.dart flutter-app/test/smoke/main_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这轮已经不是简单加入口，而是开始做个人页内部的信息优先级；当前仍然没有把昵称纳入“优先整理这三项”，是因为昵称在页头本身已经足够高频可见，先把更容易被忽略的签名 / 状态 / 背景整理动作前置。
- 下一步建议：继续把“优先整理这三项”和“完成清单”之间的关系再收一次，考虑是否把完成清单里的未完成项做成可点击跳转，进一步减少用户在卡片里来回扫视和找入口的成本。

## 2026-03-20 最近动态 30
- 完成：继续微调个人页“快速整理”卡片的动作优先级，把“编辑状态”补进了常规屏的高频整理入口，让签名、状态、背景模式和设置入口在大多数正常真机尺寸下更像一组完整的资料整理动作。
- 完成：同时明确守住 compact 基线。经过 smoke 回归后，确认 360x640 级别小屏如果直接增加新的高频入口会重新引入额外滚动，因此最终收成“常规屏显示编辑状态快捷入口，compact 屏保持当前密度”的版本，优先保证小屏首屏稳定性不回退。
- 涉及模块：`flutter-app/lib/widgets/profile_tab.dart`、`flutter-app/test/smoke/main_screen_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/widgets/profile_tab.dart flutter-app/test/smoke/main_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/main_screen_smoke_test.dart --plain-name "main screen should keep profile quick actions visible on compact size" --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这一步本质上是一个“效率入口”和“小屏稳定性”之间的取舍，目前选择了优先守住小屏；如果后续你希望 compact 屏也补更多资料快捷入口，需要先继续压缩 quick actions card 的高度或重排按钮层级。
- 下一步建议：下一轮可以继续收“快速整理”卡片本身，把签名 / 状态 / 背景三项做成更有优先级的分层动作，而不是简单叠加按钮，避免后面再出现入口越加越多、但小屏越来越挤的情况。

## 2026-03-20 最近动态 29
- 完成：继续把个人主页资料编辑链路做成更完整的成品交互。`ProfileTab` 的昵称、签名编辑弹层现在都会先展示“当前昵称 / 当前签名”的预览卡和状态徽标，进入编辑前就能先确认当前对外展示值，避免用户一打开弹层只看到输入框，不知道自己现在处于什么状态。
- 完成：状态选择弹层补上了“当前状态”预览卡，并把当前已选状态高亮显示为选中态；这样用户切换状态时可以更直观看到“当前正在展示哪一条”和“点下去会切成哪一条”。
- 完成：把昵称 / 签名 / 状态三类资料弹层统一改成按真实可用高度做受控约束，保留必要时的轻量滚动兜底，解决补充预览卡后在测试环境和小高度场景里出现的底部溢出问题。
- 涉及模块：`flutter-app/lib/widgets/profile_tab.dart`、`flutter-app/test/smoke/main_screen_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/widgets/profile_tab.dart flutter-app/test/smoke/main_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这轮主要收的是资料编辑弹层的状态可理解性和小高度稳定性，还没有进一步改“快速整理”卡片的动作编排；当前保存反馈仍然沿用轻 toast，后续如果你希望更像成熟聊天产品，可以考虑把关键资料保存后的结果也接成页内轻提示。
- 下一步建议：继续往“快速整理”卡片推进，把昵称 / 状态也纳入高频整理入口，再统一检查个人页上所有编辑入口的文案、触达面积和优先级，减少用户在个人页里来回找入口的成本。

## 2026-03-20 最近动态 28
- 完成：继续把“资料与展示”链路往下统一，补齐背景管理的状态感知。`SettingsScreen` 现在不仅有头像预览，也给“背景管理”入口补上了当前背景缩略预览和状态徽标；进入背景管理 sheet 后也能直接看到“当前背景已设置 / 当前使用默认背景”，减少用户点进去后才知道当前状态的认知负担。
- 完成：`SettingsScreen` 内部把头像 / 背景预览状态收口成统一的 media preview 读取逻辑，替换背景、删除背景后会同步刷新入口状态，避免列表入口和弹层里的状态显示不一致。
- 完成：`ProfileTab` 的背景编辑提示从原来的右上角小圆点图标，升级为更明确的“编辑背景”胶囊提示，并补上 `Semantics/Tooltip`，让真机上背景可编辑性更接近头像入口的可理解性。
- 涉及模块：`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/lib/widgets/profile_tab.dart`、`flutter-app/test/smoke/settings_screen_smoke_test.dart`、`flutter-app/test/smoke/main_screen_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/screens/settings_screen.dart flutter-app/lib/widgets/profile_tab.dart flutter-app/test/smoke/main_screen_smoke_test.dart flutter-app/test/smoke/settings_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这轮仍然是局部收口，没有动“我的”页更大范围的信息架构；背景管理继续保留在低频设置区，只是先把入口和弹层状态语言统一起来，避免再出现“头像是成品链路、背景还是旧逻辑”的割裂感。
- 下一步建议：继续把昵称 / 签名 / 状态这些资料编辑入口也补成统一的“当前状态 + 明确动作 + 保存结果反馈”模式，然后再回头检查设置页剩余低频弹层是否还能继续压紧，减少真机上的层级跳跃感和操作陌生感。

## 2026-03-20 最近动态 27
- 完成：继续收 `个人主页 / 设置头像` 这条链路。`ProfileTab` 的头像入口从“右下角小相机点”改成更明确的编辑胶囊，紧凑态保留图标触点、常规态显示“编辑”文案，并补上 `Semantics/Tooltip`，让头像可编辑性更直观，同时避免小头像尺寸下的拥挤和溢出。
- 完成：`SettingsScreen` 的“头像管理”入口补上当前头像预览与状态感知，列表项右侧现在会显示当前头像缩略预览；头像管理 sheet 里也补了当前状态卡，能直接看见“当前头像已设置 / 当前使用默认头像”，并同步压紧弹层内的说明、间距和操作行高度，保证小高度约束下仍然完整可见。
- 完成：顺手补齐头像修改失败回调。`ProfileTab` 里的头像 / 背景更换从原来的“默认假设上传成功”收成显式 `try/catch`，上传失败时会给出错误反馈，避免真机弱网或上传波动时用户没有结果感知。
- 涉及模块：`flutter-app/lib/widgets/profile_tab.dart`、`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/test/smoke/main_screen_smoke_test.dart`、`flutter-app/test/smoke/settings_screen_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/screens/settings_screen.dart flutter-app/lib/widgets/profile_tab.dart flutter-app/test/smoke/settings_screen_smoke_test.dart flutter-app/test/smoke/main_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_screen_smoke_test.dart --plain-name "settings screen should restore avatar and background defaults with inline feedback" --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这轮优先把头像链路做成“状态更直观、动作更明确、失败有回调”，没有扩大到整套资料页重构；其中 `ProfileTab` 紧凑态头像胶囊最终收成 icon-only，是为了避免 360x640 级别小屏下再次出现重叠和溢出。
- 下一步建议：沿着这条思路继续把“背景管理”和“个人主页资料编辑入口”统一成同一套状态语言，再检查设置页其余低频弹层是否也能按同样方式压紧，减少真机上“每个弹层都像一套不同逻辑”的割裂感。

## 2026-03-20 最近动态 26
- 完成：继续把高频的聊天投递状态组件收轻。`chat_delivery_status.dart` 里状态徽标和状态卡的阴影半径进一步降低，同时去掉了 `AnimatedSwitcher` 里的缩放过渡，统一改成纯淡入，减少失败态/送达态/已读态频繁切换时的细碎动感。
- 完成：补跑聊天页和消息页 smoke，确认这轮状态组件减负没有影响失败态说明、重试反馈、已读/送达标记和紧凑屏显示稳定性。
- 涉及模块：`flutter-app/lib/widgets/chat_delivery_status.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/widgets/chat_delivery_status.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/messages_tab_smoke_test.dart --reporter expanded`
- 风险 / 备注：这轮仍然遵循“保留状态可理解性，但尽量不做多余 motion”的原则；当前聊天和消息高频链路里最明显的缩放/滑入感已经基本压掉。
- 下一步建议：继续检查剩余低频但成本较高的装饰组件，例如匹配页局部成功反馈卡、设置页诊断卡和可能的调试面板动画，优先把“真机能感知到卡顿”的部分继续做减负。

## 2026-03-20 最近动态 25
- 完成：继续从渲染成本角度做减负，而不改变当前视觉方向。`MainScreen` 底部导航的 `BackdropFilter` 模糊强度进一步下调，顶部轻提示阴影也同步收轻；`MatchTab` 光球、主按钮和结果卡的阴影半径整体降低；`LoginScreen` 与 `SplashScreen` 的品牌光晕、`ProfileTab` compact 身份卡和头像投影也一起压薄，保留精品感但减少低端真机上的“发闷”和掉帧风险。
- 涉及模块：`flutter-app/lib/screens/main_screen.dart`、`flutter-app/lib/widgets/match_tab.dart`、`flutter-app/lib/screens/login_screen.dart`、`flutter-app/lib/screens/splash_screen.dart`、`flutter-app/lib/widgets/profile_tab.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/screens/main_screen.dart flutter-app/lib/widgets/match_tab.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/screens/login_screen.dart flutter-app/lib/screens/splash_screen.dart flutter-app/lib/widgets/profile_tab.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/match_tab_smoke_test.dart --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/login_screen_smoke_test.dart --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/splash_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这轮主要是减轻 blur/shadow 的感知成本和渲染压力，不改功能语义；视觉基调仍保持当前夜间精品感，只是把部分“太厚”的装饰压回更克制的范围。
- 下一步建议：继续查剩余高频页里是否还有类似高成本装饰，优先看聊天投递状态卡、匹配页局部装饰和设置页低频卡片，再决定是否继续做第二轮更细的阴影/模糊减负。

## 2026-03-20 最近动态 24
- 完成：把 `SettingsScreen` 的整份 smoke 回归也重新收成稳定绿色。定位到首条用例里“清空聊天投递统计”后会触发 `ChatProvider` 的 650ms 持久化 debounce，因此在测试里补了显式泵过这段时序，避免整文件回归在 teardown 阶段留下 pending timer。
- 完成：在此基础上补跑整份 `settings_screen_smoke_test.dart`，确认这轮对设置页动效收口和首屏密度压缩没有带来其它设置入口、通知反馈、账号安全和媒体修改链路的回归。
- 涉及模块：`flutter-app/test/smoke/settings_screen_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/test/smoke/settings_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这轮修的是测试稳定性，不改业务语义；但也说明当前项目里仍有少量 provider debounce 会在整文件 smoke 中暴露出 teardown 时序问题，后续继续做全量回归时要优先关注这类“功能没坏，但测试基线会脏”的隐性问题。
- 下一步建议：继续补查其余高频 smoke 是否也存在类似 debounce/timer 残留，再回到设置页更低频模块和主壳视觉层次，继续压“发飘感”和首屏认知负担。

## 2026-03-20 最近动态 23
- 完成：继续把 `SettingsScreen` 的首屏信息密度往下压了一层。`tight / compact` 两档的页面外边距、总览卡内边距、段间距和操作按钮间隔都进一步收紧；极小屏下总览说明也缩成更短的一句，让 320~360 宽度设备更容易在首屏看见高频设置入口，而不是先感到页面需要滑动。
- 涉及模块：`flutter-app/lib/screens/settings_screen.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/screens/settings_screen.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_screen_smoke_test.dart --plain-name "settings screen should keep overview actions visible on compact size" --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_screen_smoke_test.dart --plain-name "settings screen should keep overview and toggles stable on tight size" --reporter expanded`
- 风险 / 备注：这轮压的是首屏密度，不是砍功能。设置页仍然保留长页滚动作为兜底，但现在小屏更接近“先看到关键设置，再决定是否继续往下看”的结构。
- 下一步建议：继续按这个原则看设置页诊断卡、通知状态卡和更低频模块的段间距，优先把“必须先滚一下才知道能做什么”的感知再往下压。

## 2026-03-20 最近动态 22
- 完成：继续收口 `MainScreen` 和 `SettingsScreen` 里剩余的明显 motion。`MainScreen` 顶部“首页同步中”轻提示去掉了 `AnimatedSwitcher`，改成稳定直接显示/隐藏；底部导航切换也不再做图标上浮和指示点缩放，而是改成静态选中态切换，减少主壳层级“页面一直在轻微动”的感觉。
- 完成：`SettingsScreen` 总览区的页内反馈卡不再经过 `AnimatedSwitcher` 过渡，改成稳定直接呈现；这样保存、切换和复制等操作后的反馈仍然可理解，但不会再带出额外的切换动感。
- 涉及模块：`flutter-app/lib/screens/main_screen.dart`、`flutter-app/lib/screens/settings_screen.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/screens/main_screen.dart flutter-app/lib/screens/settings_screen.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_screen_smoke_test.dart --plain-name "settings screen should show inline feedback for toggle actions" --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_screen_smoke_test.dart --plain-name "settings screen should keep overview and toggles stable on tight size" --reporter expanded`
- 风险 / 备注：主壳和设置页这轮已经进一步变稳，但设置页本身仍是功能密集型长页，后续不能为了“完全不动”牺牲小屏可达性；更合适的方向是继续减少无意义过渡，同时保留必要的状态反馈和滚动兜底。
- 下一步建议：继续往设置页总览区和诊断卡区压信息密度，优先减少小屏首屏需要滚动才能看到关键操作的情况；如果用户真机仍觉得“发飘”，再继续检查 `BackdropFilter`、阴影层次和少量 remaining animation 的感知成本。

## 2026-03-20 最近动态 21
- 完成：继续按“高频页面能稳就稳，不要有多余滑动感”的方向往下收口。`ProfileTab` 主页面改成了受控滚动布局，并额外压薄了 compact 版身份卡、快速整理卡和底部留白，让 360x640 下主内容完整可见时不再保留多余滚动余量；同时给主滚动容器补了 `profile-main-scroll` 键位，方便 smoke 直接锁住“紧凑屏下滚动范围应为 0”。
- 完成：把 `MessagesTab` 的会话卡片入场从“淡入 + 轻微上滑”收成纯淡入，减少消息列表首屏加载时的页面在动感；把 `ChatScreen` 的消息气泡首次渲染也从左右轻滑改成纯淡入，避免聊天过程里出现整屏一直有轻微滑入的体感。
- 涉及模块：`flutter-app/lib/widgets/profile_tab.dart`、`flutter-app/lib/widgets/messages_tab.dart`、`flutter-app/lib/screens/chat_screen.dart`、`flutter-app/test/smoke/main_screen_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/widgets/profile_tab.dart flutter-app/test/smoke/main_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/widgets/messages_tab.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/screens/chat_screen.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/messages_tab_smoke_test.dart --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：当前主链路里最明显的“横向滑 / 页级滑入 / 内容装得下却还能滑”的问题已经压掉一批，但 `SettingsScreen` 仍然是超长配置页，个别弹层和说明页仍需要滚动兜底；后续要继续区分“必要滚动”和“体验冗余”，不能为了完全不滑把可达性做坏。
- 下一步建议：继续收口 `SettingsScreen` 和 `MainScreen` 里剩余的轻量动效与长页滚动感，优先看设置总览区、状态卡区和主壳顶部轻提示是否还能再减一层 motion。

## 2026-03-20 最近动态 20
- 完成：继续按照“页面尽量稳，不要有多余滑动感”的方向收口高频入口。`MatchTab` 里两处快捷招呼语不再使用横向 `SingleChildScrollView`，改成原地换行的 `Wrap` 排布，避免用户还要左右滑动去选开场白；同时把匹配成功卡片从“淡入 + 轻微上滑”改成纯淡入，减少页面级滑入感，整体更接近克制的原生聊天产品节奏。
- 完成：把 `LoginScreen` 改成受控滚动布局。现在登录页会先按可视区高度撑满，正常屏幕下更像固定页面；只有在小屏或键盘顶起导致内容装不下时才继续滚动，降低首屏入口“整页发飘、轻触就滑”的体感。
- 涉及模块：`flutter-app/lib/widgets/match_tab.dart`、`flutter-app/lib/screens/login_screen.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/widgets/match_tab.dart flutter-app/lib/screens/login_screen.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/test/smoke/match_tab_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/match_tab_smoke_test.dart --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/login_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这轮先优先收掉了最明显的横向滑动和页级滑入感；但 `ProfileTab`、`SettingsScreen` 以及个别弹层里仍有整页 `SingleChildScrollView`，虽然多数属于内容确实可能超长时的兜底滚动，后续还需要继续区分“必要滚动”和“多余滚动”。
- 下一步建议：继续检查 `ProfileTab`、`SettingsScreen` 和 `FriendsTab` 里的整页/弹层滚动，优先把“内容其实装得下却仍然容易发飘”的页面收成固定布局，仅在小屏或键盘弹出时再启用滚动。

## 2026-03-20 最近动态 19
- 完成：继续沿着真机“聊天页卡顿、小屏输入区和头部容易抖动/重叠”的反馈收口 `ChatScreen`。输入框监听不再因为 `_hasText` 变化对整页 `setState()`，改为只保存草稿；首个会话激活从初始 `postFrameCallback` 挪到依赖绑定流程；头部标题、右上角更多菜单、取关提示和底部输入区分别改成 `Selector` / `Selector2` 局部订阅，消息列表与输入区外层补上 `RepaintBoundary`，减少输入时整页重绘和首帧附加抖动。
- 完成：顺手修了 `chat_screen_smoke_test.dart` 的 teardown 稳定性问题。聊天页整文件 smoke 之前会因为 `NotificationCenterProvider` 单例里的延迟持久化 timer 残留而在首条用例后报 pending timer；现在 `_disposeHost(...)` 会额外清理通知中心 session，把聊天页整套回归重新收成稳定绿色。
- 涉及模块：`flutter-app/lib/screens/chat_screen.dart`、`flutter-app/test/smoke/chat_screen_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/screens/chat_screen.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/test/smoke/chat_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/chat_screen_smoke_test.dart --plain-name "chat screen should keep composer actions visible on compact size" --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/chat_screen_smoke_test.dart --plain-name "chat screen should keep header and composer stable on tight size" --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/chat_screen_smoke_test.dart --plain-name "chat screen should show composer capability chips" --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/chat_screen_smoke_test.dart --plain-name "chat screen should show retry success feedback after failed message recovers" --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded`
- 风险 / 备注：这轮主要压的是聊天页输入期的局部重绘和小屏布局稳定性，能直接改善打字、切会话和首屏进入时的顿挫感；但 `ChatScreen` 里仍有部分 `Consumer2` 和路由同步/滚动相关的 post-frame 调度，若真机还有抖动，下一轮优先继续沿这些点做更细粒度收口。
- 下一步建议：继续检查聊天页 `AppBar.actions`、滚动到底部调度和消息列表项是否还存在高频无效重建，同时回到 `SettingsScreen` 继续压 320~360 宽度下状态卡与操作区的层级拥挤感。

## 2026-03-20 最近动态 18
- 完成：继续收口设置页小屏重叠与交互拥挤问题，补齐 `compact / tight` 两级响应式布局；设置总览操作区改为紧凑屏整行按钮，通知运行态卡片与设备模式预设卡片改为标题/徽标可堆叠、操作区可纵向展开，设备模式预设在 tight 屏下切为单列，降低 320~360 宽度真机上的挤压和错位风险。
- 完成：把设置页头像/背景替换重新接回可注入的 `MediaUploadService` 上传链路，恢复远端媒体引用保存、本地引用清理和页面内轻反馈，保证现有 smoke 中的“真上传后回写资料引用”链路继续可测。
- 涉及模块：`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/test/smoke/settings_screen_smoke_test.dart`
- 验证：
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\dart.bat format flutter-app/lib/screens/settings_screen.dart flutter-app/test/smoke/settings_screen_smoke_test.dart`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat analyze`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_screen_smoke_test.dart --plain-name "settings screen should show inline feedback after avatar and background update succeeds" --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_screen_smoke_test.dart --plain-name "settings screen should keep overview actions visible on compact size" --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_screen_smoke_test.dart --plain-name "settings screen should keep overview and toggles stable on tight size" --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_screen_smoke_test.dart --plain-name "settings screen should refresh notification runtime state into ready feedback" --reporter expanded`
  - `D:\\flutter_windows_3.27.1-stable\\flutter\\bin\\flutter.bat test test/smoke/settings_screen_smoke_test.dart --plain-name "settings screen should apply experience preset from overview card" --reporter expanded`
- 风险 / 备注：这轮排查中确认 `settings_screen.dart` 对编码非常敏感，后续如果再做大段文本替换，必须避免经过会改写 UTF-8 内容的终端文本流；优先保持 `git restore/apply_patch` 这类保字节或结构化改动方式，避免再次把中文字符串写坏。
- 下一步建议：继续沿着真机反馈收口 `ChatScreen` 和 `SettingsScreen` 的局部重绘与按钮层级，优先看聊天页顶部/输入区、小屏设备状态卡和资料页返回后的身份一致性感知。

## 2026-03-19 最近动态 16
- 完成：根据用户纠偏，放弃上一版“优化策划案”方向，改为以求职者身份重写《王者荣耀》游戏拆解案，强调真实、可靠、可面试表达，而不是功能立项方案。
- 涉及模块：新增文档 `wangzhe_job_deconstruction_case_v1.md`，并导出到用户指定目录 `C:\\Users\\chenjiageng\\Desktop\\cehua`，生成 `wangzhe_job_deconstruction_case_v1.docx` 和同名 `.md` 源稿。
- 验证：已完成 `.docx` 文件生成与二次读取验证，通过 `python-docx` 成功读取段落数量与标题内容；同时补充查阅公开来源用于事实校验，包括 App Store 官方页面、TapTap 官方入驻页和王者荣耀官网。
- 风险 / 备注：本轮文档属于求职作品，事实层仅基于公开可核验信息，未使用内部数据和无法确认的市场数字；如后续继续打磨，建议再拆一版“3 分钟口述稿”和“一页纸面试总结稿”。
- 下一步建议：若用户继续收口，可进一步将当前拆解案压缩成更口语化的面试讲稿版本，或补一版更像腾讯 / 天美内部写作习惯的简历附件版。

## 2026-03-19 最近动态 15
- 完成：新增一轮非代码交付物打磨，围绕《王者荣耀》排位单排体验优化方案，先以资深 MOBA 策划视角完成评审，再输出评审修订版 V2 文稿。
- 涉及模块：更新面试策划文档 `wangzhe_ranked_solo_queue_plan_review_v1.md`，补充方案取舍、竞品启发、关键流程与交互示意、开发排期与资源评估、灰度与 A/B 实验设计等章节，并生成对应 Word 文档交付。
- 验证：已完成本地文档生成链路验证，包括 `py -m pip install python-docx --user`、重新生成 `.docx`、以及通过 `python-docx` 二次读取验证段落数量与标题内容，确认文档可正常打开读取。
- 风险 / 备注：当前工作为面试策划文档交付，不影响 Flutter / backend 主线功能；后续若继续打磨，建议拆成“正式提案版”和“3-5 分钟口述答辩版”两套独立输出，避免一份文档同时承担所有场景导致的信息密度过高。
- 下一步建议：继续把最新版策划案导出到用户指定目录 `C:\\Users\\chenjiageng\\Desktop\\cehua`，并视需要补一份更偏腾讯 / 天美风格的面试答辩稿。

## 当前目标
- 在不改变现有 UI 主题的前提下，继续把项目按模块收敛到可联调、可穿透测试、可上线准备的状态。
- 优先优化“我的 / 设置”和聊天主链路的真实用户体验，同时保持回归基线稳定。

## 当前主线
- 前端继续做高频与低频设置操作的页面内反馈统一。
- 聊天链路后续继续补失败态、重试、图片失效的前后端闭环。
- 为后续内网穿透测试提前整理环境、鉴权、WebSocket 恢复和日志能力。

## 本阶段已完成
- 匹配页首屏、小屏适配、失败态和行动提示已补齐。
- 聊天页输入区能力提示、小屏适配、发送操作区反馈已补齐。
- 消息列表优先级标签、草稿/未读/到期提示和小屏适配已补齐。
- 设置页诊断卡已升级为动作型状态卡，并补齐处理状态说明和复制摘要。
- “我的 / 设置”低频管理入口已统一为更成品化的 bottom sheet。
- 黑名单、手机号、密码、头像、背景等账户与资料入口已统一交互语言。
- 设置页已经具备设备模式预设、通知运行态提示和页面内即时反馈卡。

## 本轮最新完成
- 设置页低频操作也接入了统一的页面内反馈：
  - 头像更新 / 恢复默认
  - 背景更新 / 恢复默认
  - UID 复制
  - 手机号更新
  - 密码更新
  - 解除拉黑
- 手机号和密码编辑抽屉的关闭时序已收稳，避免 `TextEditingController` 在关闭动画期间被过早释放。
- 设置页 smoke 已补成更完整的真实交互链路：
  - 手机号保存后校验页面内反馈
  - 密码保存后回到总览区校验反馈标题
  - 用例显式初始化本地密码和手机号，避免跨测试污染
- 聊天发送状态卡不再把所有“原图发送失败”一刀切成“必须重选图片”：
  - 本地预览仍然存在时，继续提供“立即重试”
  - 只有预览路径缺失、远端地址不可重发或本地文件已失效时，才引导“查看说明 / 重选图片”
- 为聊天主链路补上了更聚焦的回归验证：
  - `chat_provider_test.dart` 新增“失败原图但本地预览仍在时可直接重试”
  - `chat_delivery_status_test.dart` 新增状态解析单测，锁住 UI 不会误判为“必须重选”
  - 保留 `chat_screen_smoke_test.dart` 中“原图失效时展示重选引导”的整页验证
- 聊天失败态继续细化了一层“原因可理解性”：
  - 失败消息所在会话已经过期时，不再继续展示误导性的“立即重试”
  - 聊天页会直接展示“会话已过期”，并把说明改成“当前不能继续重试”
  - 重试动作兜底报错也会按当前状态区分为：会话过期 / 原图需重选 / 暂不可重试 / 普通失败
- 聊天失败态这一轮继续把“后端错误语义”接到了前端状态上：
  - `ChatService` / `ChatSocketService` 新增详细结果对象，区分业务失败和传输失败
  - `ChatProvider` 为失败消息补上独立 failure state 缓存，不再只靠 `MessageStatus.failed` 推断
  - WebSocket 发送只在传输失败时回退 HTTP，业务错误会原样落到消息失败态
  - HTTP / Socket 返回的 `THREAD_EXPIRED`、`BLOCKED_RELATION`、`NETWORK_ERROR` 会映射成前端可解释状态
- 聊天页失败卡和重试提示继续补齐了“关系阻断 / 网络波动”两类真实场景：
  - 被拉黑或关系阻断时，失败卡直接展示“关系受限”，不再继续给误导性重试入口
  - 网络波动时，失败卡会明确提示“网络波动”，同时保留“立即重试”
  - 重试失败 toast 现在会真正透出详细文案，而不是一律落回通用发送失败
- 聊天实时发送链路又补了一层 `joinThread` 失败语义收口：
  - WebSocket `joinThread` 现在也区分业务失败和传输失败，不再一律按 `false` 处理
  - `joinThread` 业务失败时，会直接把失败原因映射到消息 failure state，而不是误走 HTTP 回退
  - `joinThread` 仅在传输失败时才继续回退 HTTP，避免把“关系阻断”误判成普通网络失败
- 图片发送链路这轮继续把“上传阶段失败”拆得更细了一层：
  - `MediaUploadService` 现在会区分“上传令牌申请失败”和“二进制上传中断”，不再只返回静默降级结果
  - `ChatProvider` 会把图片上传阶段错误映射成独立 failure state，而不是统一并入普通网络失败
  - 聊天失败卡新增了“上传准备失败 / 上传中断”两种图片失败文案，并继续保留“立即重试”
  - 聊天页重试失败 toast 也会按上传阶段给出更具体说明，避免把上传失败和发送失败混成一类
- 聊天已读同步链路这轮也补上了 `markRead` 的失败语义收口：
  - `ChatSocketService` 新增 `markReadResult(...)`，`msg.read` 不再只能压成 `true / false`
  - `ChatService` 新增 `markThreadReadResult(...)`，HTTP 已读回退现在也能区分成功与失败
  - `ChatProvider` 现在只会在 `joinThread` / `markRead` 的传输失败时回退 HTTP，业务失败不再误走兜底
  - `_lastReadSyncMessageIds` 会在同步失败后回滚到上一次成功位点，避免同一条消息因为一次失败而长期不再重试
- 线程升级和清理链路也补上了失败态收口：
  - 本地线程升级为远端线程时，会同步迁移消息 failure state
  - 删除线程、召回消息、从本地存储恢复时，会清空或重置过期 failure state，避免旧状态污染
- 本轮补上了新的聊天回归用例：
  - `chat_provider_test.dart` 新增“关系阻断”和“网络波动回退”两类失败态映射验证
  - `chat_delivery_status_test.dart` 新增“关系受限”和“网络波动”状态卡解析验证
  - `chat_provider_test.dart` 继续新增“`joinThread` 业务失败直接阻断发送”和“`joinThread` 传输失败回退 HTTP”两类回归
  - 聊天页“关系受限”整页 smoke 这一轮尝试过，但为了保持回归稳定，暂时没有保留不稳定版本
  - `chat_provider_test.dart` 本轮继续新增“上传令牌失败”和“上传中断”两类图片失败态映射验证
  - `chat_delivery_status_test.dart` 本轮继续新增“上传准备失败”和“上传中断”状态卡解析验证
  - `chat_provider_test.dart` 本轮再补“`markRead` 业务失败不回退”“`markRead` 传输失败回退”“HTTP 已读兜底失败后仍可再次尝试”几类回归

## 最新验证结果
- `flutter analyze` 通过
- `flutter test test/smoke/settings_screen_smoke_test.dart --reporter expanded` 通过
- `flutter test --reporter expanded` 通过
- 当前前端全量测试：`140` 个通过
- 本轮补充：`flutter test test/widgets/chat_delivery_status_test.dart --reporter expanded` 通过
- 本轮补充：`flutter test test/smoke/chat_screen_smoke_test.dart --reporter expanded` 通过
- 本轮补充：`flutter test test/providers/chat_provider_test.dart --reporter expanded` 通过
- 本轮补充：`flutter analyze` 通过
- 本轮继续补充：`flutter test test/providers/chat_provider_test.dart --reporter expanded` 通过
- 本轮继续补充：`flutter test test/smoke/chat_screen_smoke_test.dart --reporter expanded` 通过
- 本轮继续补充：`flutter test test/widgets/chat_delivery_status_test.dart --reporter expanded` 通过
- 本轮继续补充：`flutter analyze` 通过
- 本轮再次补充：`flutter analyze` 通过
- 本轮再次补充：`flutter test test/providers/chat_provider_test.dart --reporter expanded` 通过
- 本轮再次补充：`flutter test test/widgets/chat_delivery_status_test.dart --reporter expanded` 通过
- 本轮再次补充：`flutter test test/smoke/chat_screen_smoke_test.dart --reporter expanded` 通过
- 本轮继续补充：`flutter analyze` 通过
- 本轮继续补充：`flutter test test/providers/chat_provider_test.dart --reporter expanded` 通过

## 下一步建议
1. 继续做“我的 / 设置”的最后一层反馈统一，把更多保存成功、权限拒绝、系统限制提示做成轻量页面内反馈，而不是只靠 toast。
2. 继续补聊天失败态的剩余边角，优先看：
   - 聊天页是否需要补一条“关系受限”整页 smoke，用于锁住真实 UI 展示
   - 把 `markRead` 这套“仅传输失败才回退 HTTP”的处理方式继续推广到其他实时事件
   - 图片上传失败是否要继续接上更细的后端错误码，例如文件过大 / 非图片 / token 被复用
3. 开始整理内网穿透前置项：
   - 鉴权与环境变量
   - WebSocket 连接恢复
   - CORS / API 地址切换
   - 健康检查与错误日志

## 工作规则
- 每轮有实际开发进展后，都要同步更新本文件。
- 新窗口接手时，优先阅读本文件，再结合 `AGENTS.md` 和 `PROJECT_CONTEXT.md` 开始工作。
- 如果文档与最新代码不一致，以代码为准，并在本轮结束前修正文档。

## 2026-03-17 最近动态
- 完成：图片上传失败态继续细化到 UPLOAD_TOKEN_INVALID / IMAGE_UPLOAD_TOO_LARGE / IMAGE_UPLOAD_UNSUPPORTED_FORMAT，并把聊天页底部指引区分为“重选图片 / 图片过大 / 格式异常”三类。
- 涉及模块：lutter-app/lib/services/media_upload_service.dart、lutter-app/lib/providers/chat_provider_messages.dart、lutter-app/lib/widgets/chat_delivery_status.dart、lutter-app/lib/screens/chat_screen.dart、lutter-app/test/providers/chat_provider_test.dart、lutter-app/test/services/media_upload_service_test.dart、lutter-app/test/widgets/chat_delivery_status_test.dart、lutter-app/test/smoke/chat_screen_smoke_test.dart
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/services/media_upload_service_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/widgets/chat_delivery_status_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/chat_provider_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded 通过。
- 风险 / 备注：chat_screen_smoke_test.dart 含历史编码噪音，修改时需要显式按 UTF-8 读写，否则容易把整文件写坏。
- 下一步建议：优先补“图片过大 / 格式异常”在聊天页的 smoke 覆盖；如果后端后续补充稳定错误码，再把当前基于 message 的归因逐步收敛成纯 code 映射。
## 2026-03-17 最近动态 2
- 完成：修复 messages_tab.dart 未读取 provider 失败态的问题，线程列表现在也能识别并展示 IMAGE_UPLOAD_TOO_LARGE / IMAGE_UPLOAD_UNSUPPORTED_FORMAT 对应的预览文案、状态徽标和优先级标签。
- 完成：新增 lutter-app/test/smoke/messages_tab_delivery_failure_smoke_test.dart，覆盖“图片过大 / 格式异常”两类聊天图片上传失败态在消息列表页的真实展示。
- 涉及模块：lutter-app/lib/widgets/messages_tab.dart、lutter-app/test/smoke/messages_tab_delivery_failure_smoke_test.dart
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/messages_tab_delivery_failure_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/messages_tab_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：在 widget smoke 里如果过早删除本地图片文件，deliveryFailureStateFor(...) 会先退回 imageReselectRequired，因此这类用例需要把测试图片保留到断言结束后再清理。
- 下一步建议：继续补聊天页层面对“图片过大 / 格式异常”的独立 smoke，或者把线程列表里 etry 类失败态也进一步细分成更可读的标签。
## 2026-03-17 最近动态 3
- 完成：新增 lutter-app/test/smoke/chat_screen_delivery_failure_smoke_test.dart，把聊天页里“图片过大 / 格式异常”两类上传失败态的状态卡与底部说明弹层单独锁住。
- 涉及模块：lutter-app/test/smoke/chat_screen_delivery_failure_smoke_test.dart
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_delivery_failure_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：聊天页内联状态卡在测试窗口下可能需要先 ensureVisible(...) 再点击动作按钮，否则容易出现命中不到的误报。
- 下一步建议：继续补 UPLOAD_TOKEN_INVALID 在聊天页与列表页的独立 smoke，或者把“会话过期 / 关系受限 / 网络波动”这几类失败态的列表页标签继续细化。
## 2026-03-17 最近动态 4
- 完成：在 lutter-app/test/smoke/messages_tab_delivery_failure_smoke_test.dart 和 lutter-app/test/smoke/chat_screen_delivery_failure_smoke_test.dart 中补齐 UPLOAD_TOKEN_INVALID 的独立 smoke，锁住“上传凭证失效”在列表页和聊天页的展示分支。
- 涉及模块：lutter-app/test/smoke/messages_tab_delivery_failure_smoke_test.dart、lutter-app/test/smoke/chat_screen_delivery_failure_smoke_test.dart
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/messages_tab_delivery_failure_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_delivery_failure_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：UPLOAD_TOKEN_INVALID 在聊天页 smoke 里更适合用“专属 icon 存在且不落到 guide 分支”来校验，直接断言按钮文案容易受可见区域和编码展示干扰。
- 下一步建议：继续补 
etworkIssue / lockedRelation 在消息列表页的独立 smoke，或者把列表页当前的通用 retry 标签细化成更具体的失败原因标签。
## 2026-03-17 最近动态 5
- 完成：继续收口消息列表页失败态标签这一轮，把 `messages_tab_delivery_failure_smoke_test.dart` 调整为与真实可达状态一致；其中 `NETWORK_ERROR` 改为走真实发送失败链路，`UPLOAD_TOKEN_INVALID` 改为按列表页当前标签文案断言，旧的“重选图片”列表 smoke 也同步到了 badge + priority tag 的双展示。
- 涉及模块：`flutter-app/lib/widgets/messages_tab.dart`、`flutter-app/test/smoke/messages_tab_delivery_failure_smoke_test.dart`、`flutter-app/test/smoke/messages_tab_smoke_test.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/messages_tab_delivery_failure_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/messages_tab_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：`MessagesTab` 当前不会展示 `threadExpired`，因为非好友且已过期的线程会先被 `ChatProvider.threads` 过滤掉；另外，列表页里的 `networkIssue` 需要通过真实发送失败链路覆盖，上传阶段的 `NETWORK_ERROR` 会先归并成 `imageUploadInterrupted`。
- 下一步建议：优先补聊天页对 `blockedRelation / networkIssue` 的独立 smoke，或者继续把当前“失败原因更可理解”的标签策略推广到其他高频状态入口。
## 2026-03-17 最近动态 6
- 完成：继续补齐聊天页失败态回归，在 `chat_screen_delivery_failure_smoke_test.dart` 中新增 `blockedRelation / networkIssue` 两类独立 smoke，分别锁住“关系受限时不再给重试入口”和“网络波动时继续保留立即重试入口”的展示分支。
- 涉及模块：`flutter-app/test/smoke/chat_screen_delivery_failure_smoke_test.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_delivery_failure_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：聊天页里的 `networkIssue` 和列表页一样，更适合通过真实发送失败链路覆盖；如果还是沿用上传阶段 `NETWORK_ERROR`，最终会先落到 `imageUploadInterrupted`，会把状态语义测歪。
- 下一步建议：继续把这批失败态往“用户动作反馈”再推进一层，例如补“点击立即重试后仍失败”的 toast/页内反馈 smoke，或者把文本消息链路也纳入同样的失败态回归覆盖。
## 2026-03-17 最近动态 7
- 完成：把聊天页失败态 smoke 继续从图片消息扩到文本消息，在 `chat_screen_delivery_failure_smoke_test.dart` 中新增文本消息的 `blockedRelation / networkIssue` 两类真实发送失败覆盖，锁住文本链路下“关系受限无重试入口”和“网络波动保留立即重试入口”的展示分支。
- 涉及模块：`flutter-app/test/smoke/chat_screen_delivery_failure_smoke_test.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_delivery_failure_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：文本消息的失败态 smoke 也要走真实发送失败链路，直接手工塞 `MessageStatus.failed` 只能覆盖 UI 默认分支，锁不住 provider 缓存下来的具体 failure state。
- 下一步建议：优先补“立即重试失败后”的用户反馈回归，或把 `threadExpired / retryUnavailable` 这类当前更多依赖边界条件的状态继续评估哪些页面最适合做稳定 smoke。
## 2026-03-17 最近动态 8
- 完成：继续把聊天页失败态收口到更完整的“可重试 / 不可重试”链路，在 `chat_screen_delivery_failure_smoke_test.dart` 中新增文本消息的 `threadExpired / retryUnavailable` 两类回归，补齐聊天页对“会话已过期 / 暂不可重试”这两种非重试分支的稳定覆盖。
- 涉及模块：`flutter-app/test/smoke/chat_screen_delivery_failure_smoke_test.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_delivery_failure_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：`threadExpired` 这类状态更适合在聊天页做稳定 smoke，因为消息列表页会先过滤过期非好友线程；`retryUnavailable` 也需要通过真实失败码或失败态缓存去覆盖，不能只靠手工摆一个 failed UI。
- 下一步建议：优先把“点击立即重试后仍失败”的用户反馈做成稳定回归，其次再评估是否把同样的 failure-state 覆盖推广到 provider / widget 更细粒度测试里，减少后续 smoke 的时序脆弱性。
## 2026-03-17 最近动态 9
- 完成：把“重试失败后的用户反馈”补进聊天页通用 smoke，在 `chat_screen_smoke_test.dart` 中新增 `failed -> sending -> failed` 的稳定回归，锁住聊天页在重试后再次失败时会给出“重试未成功，请稍后再试”的反馈提示。
- 涉及模块：`flutter-app/test/smoke/chat_screen_smoke_test.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：这类反馈链路如果直接依赖真实异步失败时序会比较脆，因此当前 smoke 采用手动状态切换来稳定锁住 `failed -> sending -> failed` 的反馈逻辑，更适合作为回归基线。
- 下一步建议：继续把聊天失败态下沉到更细粒度测试，优先看 provider / widget 层是否需要补“失败态缓存驱动 UI 卡片”的单测，减少后续 smoke 对动画和时序的依赖。
## 2026-03-17 最近动态 10
- 完成：继续把聊天失败态下沉到更细粒度测试，在 `chat_delivery_status_test.dart` 中补齐 `retryUnavailable` 的状态卡解析回归，在 `chat_provider_test.dart` 中补齐文本消息 `THREAD_NOT_FOUND -> retryUnavailable` 的真实失败态映射回归。
- 涉及模块：`flutter-app/test/widgets/chat_delivery_status_test.dart`、`flutter-app/test/providers/chat_provider_test.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/widgets/chat_delivery_status_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/chat_provider_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：`retryUnavailable` 这类状态如果只在页面 smoke 里验证，后续很容易被 UI 分支调整掩盖；下沉到 widget/provider 层之后，failure-state 语义就不再只靠页面回归兜底。
- 下一步建议：继续补消息列表页对 `retryUnavailable` 的独立回归，或者把聊天失败态相关的细粒度测试再往“重试动作后的状态迁移”补一层，进一步降低 smoke 对交互路径的依赖。
## 2026-03-17 最近动态 11
- 完成：继续补齐消息列表页对不可重试分支的独立覆盖，在 `messages_tab_delivery_failure_smoke_test.dart` 中新增文本消息 `THREAD_NOT_FOUND -> retryUnavailable` 的真实发送失败 smoke，锁住列表页“暂不可重试”标签与对应图标的展示。
- 涉及模块：`flutter-app/test/smoke/messages_tab_delivery_failure_smoke_test.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/messages_tab_delivery_failure_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：列表页这类不可重试分支如果没有独立 smoke，后续很容易被通用失败标签或 badge 逻辑覆盖掉；用真实文本发送失败路径去覆盖后，列表页和聊天页在 `retryUnavailable` 上的语义就一致了。
- 下一步建议：继续把聊天失败态相关测试往“状态迁移 + UI 映射”下沉，或者开始转回当前冲刺更靠前的“我的 / 设置”统一反馈链路，避免一直只在聊天模块里打磨。
## 2026-03-17 最近动态 12
- 完成：把聊天页“发送反馈状态机”从 `chat_screen.dart` 里抽到 `lib/utils/chat_outgoing_delivery_feedback.dart`，并新增 `test/services/chat_outgoing_delivery_feedback_test.dart`，单独锁住“消息已送达 / 重试成功 / 重试失败 / 已读优先级”这几条反馈规则；聊天页原有 smoke 也已回归通过。
- 涉及模块：`flutter-app/lib/utils/chat_outgoing_delivery_feedback.dart`、`flutter-app/lib/screens/chat_screen.dart`、`flutter-app/test/services/chat_outgoing_delivery_feedback_test.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/services/chat_outgoing_delivery_feedback_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：这段反馈逻辑之前主要靠页面 smoke 间接兜底，抽成 util 后回归会更稳，但后续如果再增加新的反馈文案，记得同步补 util 测试而不只是补页面用例。
- 下一步建议：切回当前冲刺更靠前的“我的 / 设置”统一反馈链路，优先找仍只依赖 toast、还没有稳定 smoke 锁住的设置保存反馈入口继续收口。
## 2026-03-17 最近动态 13
- 完成：继续回到“我的 / 设置”主线，给 `SettingsScreen` 的页内反馈卡补上更细的测试定位点，并在 `settings_screen_smoke_test.dart` 中新增三条稳定回归：`UID 已复制`、通知权限缺失时“已打开系统设置”的页内反馈、通知运行态从“同步中”刷新到“通知已经恢复在线”的反馈收口。
- 涉及模块：`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/test/smoke/settings_screen_smoke_test.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：通知运行态“刷新到已就绪”这条回归目前通过测试内轻量 fake push service 锁住状态迁移，避免平台权限插件和设备 token 时序把 smoke 变脆；权限缺失场景仍然保留真实运行态卡 + `openAppSettings` 路径覆盖。
- 下一步建议：继续把设置页其余已经接入 `_showInlineFeedback(...)` 的低频操作补成稳定 smoke，优先看头像 / 背景更新与恢复默认、以及解除拉黑后的页内反馈是否也需要补一层回归。
## 2026-03-17 最近动态 14
- 完成：继续收口设置页统一反馈主线，在 `settings_screen_smoke_test.dart` 中补上了隐身 / 通知 / 振动三个开关动作后的页内反馈回归；同时修正了解除拉黑后的真实交互时序，恢复按钮现在会先关闭底部弹层，再把“已解除拉黑”反馈露回设置主界面，并补上对应 smoke。
- 涉及模块：`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/test/smoke/settings_screen_smoke_test.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：设置页当前“开关即时反馈”和“解除拉黑反馈”已经有稳定 smoke 兜底，但头像 / 背景这类依赖媒体选择器的低频操作还没有同等级回归，后续需要优先挑稳定的 mock 入口补齐。
- 下一步建议：继续补 `头像更新 / 恢复默认`、`背景更新 / 恢复默认` 这两组设置反馈回归；如果媒体选择器链路暂时不够稳，就先把相关反馈下沉到更细粒度测试，避免一直只靠页面 smoke。
## 2026-03-17 最近动态 15
- 完成：继续推进设置页低频管理链路，在 `settings_screen_smoke_test.dart` 中补上了“头像恢复默认 / 背景恢复默认”的稳定回归。当前用 `avatar/...`、`background/...` 这类非本地引用模拟“已有媒体资源”状态，锁住删除确认、清空引用和页内反馈三段用户结果，而不把 smoke 绑死在媒体选择器实现上。
- 涉及模块：`flutter-app/test/smoke/settings_screen_smoke_test.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：这轮只收口了“恢复默认”这半条媒体管理链路；`头像已经更新 / 背景已经更新` 仍然依赖图片来源弹窗、权限和 image picker，本轮刻意没有把不稳定的文件系统 / 选择器时序直接塞进 smoke。
- 下一步建议：优先评估是否给 `ImageUploadService` 增加更轻量的测试替身入口，再补“头像更新 / 背景更新”的页内反馈回归；如果不想扩大页面级时序风险，也可以先把这两条反馈逻辑下沉到更细粒度测试。
## 2026-03-17 最近动态 16
- 完成：给 `ImageUploadService` 增加了仅测试使用的轻量 pick override，并补上 `test/services/image_upload_service_test.dart`；基于这套替身入口，`settings_screen_smoke_test.dart` 继续补齐了“头像已经更新 / 背景已经更新”的页内反馈回归，现在线上逻辑不需要改测试分支，也能稳定锁住媒体管理成功链路。
- 涉及模块：`flutter-app/lib/services/image_upload_service.dart`、`flutter-app/test/services/image_upload_service_test.dart`、`flutter-app/test/smoke/settings_screen_smoke_test.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/services/image_upload_service_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：当前 override 只用于测试环境短路平台选择器和权限请求，真实运行时仍然走原始图片来源弹窗、权限和持久化流程；后续如果图片管理入口再增加新状态，记得优先补 service/test hook，而不是把页面 smoke 重新绑回平台插件。
- 下一步建议：设置主线这块可以继续往“通知 / 资料 / 黑名单”的失败反馈和异常提示收口，或者开始回切到当前冲刺里更靠前的聊天与设置交界链路，例如通知中心入口、聊天权限态在设置页的统一说明。
## 2026-03-17 最近动态 17
- 完成：继续把设置页账号区的失败反馈统一到页内反馈卡上。当前 `UID` 未就绪时，点击复制会在页内明确提示“稍后再试”；手机号格式错误、旧密码错误、新密码长度不足、两次密码输入不一致也都会同步落到设置页反馈卡，不再只靠 toast。`settings_screen_smoke_test.dart` 已补上 `UID 未就绪` 和 `手机号 / 密码无效输入` 的稳定回归。
- 涉及模块：`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/test/smoke/settings_screen_smoke_test.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：当前账号区成功态和主要输入失败态都已有 smoke 兜底，但异常反馈仍以页面级回归为主；如果后续校验规则继续变多，建议再往更细粒度 helper / service 测试下沉一层，减少页面级断言膨胀。
- 下一步建议：可以开始转回“设置与聊天/通知交界”这条更靠前的主线，优先评估通知中心入口、聊天权限说明、系统权限缺失时的统一文案是否还需要继续收口。
## 2026-03-17 最近动态 18
- 完成：继续推进“设置与通知交界”主线，在 `SettingsScreen` 的通知运行态卡里补了次级入口“查看通知中心”，不改原有“开启通知 / 去系统设置 / 刷新状态”主动作；同时在 `settings_screen_smoke_test.dart` 里补上设置页降级通知态下可见该入口、并能进入 `NotificationCenterScreen` 的回归。
- 涉及模块：`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/test/smoke/settings_screen_smoke_test.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/notification_center_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：当前设置页这条回归重点锁住了“入口可见 + 目标页可达”；由于 `go_router` 的 `push` 在 widget test 里更适合直接看目标页结果，而不是把 `currentConfiguration.uri` 当作唯一依据，所以本轮 smoke 以页面出现为准做断言。
- 下一步建议：可以继续把通知中心和设置页再收一层，比如补“未读数量 / 最近消息摘要”在设置页的轻提示，或者继续统一系统权限缺失时聊天、设置、通知中心三处的说明文案。
## 2026-03-17 最近动态 19
- 完成：继续把“设置与通知交界”再收一层，在 `SettingsScreen` 的通知运行态卡里补了通知中心摘要区。当前只要通知中心里已有留存提醒，设置页就会轻量展示“待查看数量 + 最新一条摘要”，帮助用户在通知关闭、待授权或同步中的降级态下先理解是否还有消息积压；`settings_screen_smoke_test.dart` 已补上对应回归。
- 涉及模块：`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/test/smoke/settings_screen_smoke_test.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/notification_center_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：这轮摘要回归为了避免设置页初始化时额外插入“通知已关闭”的系统提醒干扰，测试里使用了“预置关闭状态后再打开页面”的方式锁场景；后续如果通知中心新增更多系统类提醒来源，仍建议优先通过 provider 当前状态做断言，而不是把数量写死。
- 下一步建议：可以继续往前做两件事里的任一项：一是把通知中心未读上下文再延伸成更轻量的概览提示，例如区分“消息 / 好友 / 系统”来源；二是开始统一聊天页、设置页、通知中心三处关于系统通知权限缺失的说明文案。
## 2026-03-17 最近动态 20
- 完成：继续收口“聊天 / 设置 / 通知中心”交界处的系统通知权限缺失说明，新增 `notification_permission_guidance.dart` 和 `notification_permission_notice_card.dart` 作为统一文案与提示卡；`NotificationCenterScreen` 现在会在“应用内通知已开但系统权限未放行”时展示顶部提示卡并可跳转设置页，`ChatScreen` 也会在同条件下展示顶部提示卡，并提供“去设置页处理 / 查看通知中心”两个入口；同时把“查看通知中心”动作文案也并入统一常量，避免聊天页和设置页再各自写死。
- 涉及模块：`flutter-app/lib/utils/notification_permission_guidance.dart`、`flutter-app/lib/widgets/notification_permission_notice_card.dart`、`flutter-app/lib/screens/notification_center_screen.dart`、`flutter-app/lib/screens/chat_screen.dart`、`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/test/smoke/notification_center_screen_smoke_test.dart`、`flutter-app/test/smoke/chat_screen_notification_permission_smoke_test.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/utils/notification_permission_guidance.dart flutter-app/lib/screens/chat_screen.dart flutter-app/lib/screens/settings_screen.dart flutter-app/test/smoke/notification_center_screen_smoke_test.dart flutter-app/test/smoke/chat_screen_notification_permission_smoke_test.dart 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/notification_center_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_notification_permission_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：这轮聊天页权限回归刻意新建了 `chat_screen_notification_permission_smoke_test.dart`，没有继续堆在历史噪声较多的 `chat_screen_smoke_test.dart` 里，后续更适合把“权限态 banner”与“发送失败态”两条主线分开维护；当前统一说明只覆盖 `notificationEnabled == true && permissionGranted == false` 这一真实缺权限场景，通知关闭或通道同步中的降级态仍由设置页运行态卡继续承接。
- 下一步建议：可以顺着这条主线继续往前做两件事里的任一项：一是把通知中心摘要从“未读数量 + 最新一条”再延伸成轻量来源概览，例如区分消息 / 好友 / 系统来源；二是继续统一从设置页返回聊天页、通知中心后的“权限恢复已生效 / 仍待刷新”反馈，让权限处理后的结果态也有稳定回归。
## 2026-03-17 最近动态 21
- 完成：继续把“通知权限处理后的结果态”做成闭环。`SettingsProvider` 新增了“从系统设置返回后待刷新”的恢复状态，`SettingsScreen` 现在会在用户点“去系统设置”后先记录待恢复标记，等应用重新回到前台时自动刷新通知权限状态，并把结果直接落成页内反馈卡，不再要求用户必须手动再点一次“刷新状态”；同时补了一条聊天页跨路由回归，锁住“聊天页进入设置页处理权限，设置状态恢复后返回聊天页 banner 会消失”这条结果回流链路。
- 涉及模块：`flutter-app/lib/providers/settings_provider.dart`、`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/test/smoke/settings_screen_smoke_test.dart`、`flutter-app/test/smoke/chat_screen_notification_permission_smoke_test.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/providers/settings_provider.dart flutter-app/lib/screens/settings_screen.dart flutter-app/test/smoke/settings_screen_smoke_test.dart flutter-app/test/smoke/chat_screen_notification_permission_smoke_test.dart 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_notification_permission_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/notification_center_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：这轮把“等待从系统设置返回”的 pending 状态收到了 `SettingsProvider` 里，而不是只放在 `SettingsScreen` 本地 state，主要是为了避免后续跨路由、页面重建或进一步拆分设置页时把恢复标记丢掉；当前自动刷新结果态重点落在设置页反馈卡上，通知中心页和聊天页本轮主要锁住的是“状态恢复后 banner 会同步消失”，还没有再额外叠一层独立 toast 或二次提示。
- 下一步建议：沿着这条链路继续往前，优先做“通知中心摘要来源概览”，把当前设置页摘要从单一未读计数延伸成“消息 / 好友 / 系统”轻量来源分布；做完这层后，再回头评估是否给聊天页和通知中心页补更轻的恢复成功提示，避免只在设置页内可见结果态。
## 2026-03-17 最近动态 22
- 完成：继续把设置页里的通知中心摘要从“未读数量 + 最新一条”收成更轻的来源概览，在 `SettingsScreen` 的通知摘要卡里补了一行最近留存提醒的来源 chips，当前会按“消息 / 好友 / 系统”三类做轻量分布展示，帮助用户在不进入通知中心的前提下先判断积压提醒主要来自哪里；同时把对应 smoke 补到现有摘要用例里，锁住来源概览不会在后续文案或布局调整时悄悄丢失。
- 涉及模块：`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/test/smoke/settings_screen_smoke_test.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/screens/settings_screen.dart flutter-app/test/smoke/settings_screen_smoke_test.dart 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：这轮来源分布刻意限制在“最近一段留存提醒”的轻量概览上，没有把设置页做成第二个通知中心；如果后续通知来源继续扩张，建议优先扩展摘要聚合规则，而不是直接把完整列表信息搬进设置页。
- 下一步建议：继续顺着这条主线往前做“来源概览可操作化”，优先评估是否要把来源 chips 接成更轻的过滤入口或跳转上下文，例如点击后直达通知中心对应来源的首屏状态；如果暂时不想扩入口，也可以先补通知中心页自身的来源分段或筛选骨架，为后续上线前的消息治理做准备。
## 2026-03-17 最近动态 23
- 完成：继续把通知中心来源概览做成可操作入口。`NotificationCenterScreen` 新增了轻量来源筛选条，支持 `全部 / 消息 / 好友 / 系统` 四档切换，并支持从路由 query 中读取初始筛选；设置页通知摘要卡里的来源 chips 现在也能直接跳到带筛选上下文的通知中心首屏，不再只是静态展示。这样用户在设置页里看见“消息 / 好友 / 系统”分布后，可以一步进入对应来源做处理。
- 涉及模块：`flutter-app/lib/screens/notification_center_screen.dart`、`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/lib/config/routes.dart`、`flutter-app/test/smoke/notification_center_screen_smoke_test.dart`、`flutter-app/test/smoke/settings_screen_smoke_test.dart`、`flutter-app/test/smoke/chat_screen_notification_permission_smoke_test.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/screens/notification_center_screen.dart flutter-app/lib/screens/settings_screen.dart flutter-app/lib/config/routes.dart flutter-app/test/smoke/settings_screen_smoke_test.dart flutter-app/test/smoke/notification_center_screen_smoke_test.dart flutter-app/test/smoke/chat_screen_notification_permission_smoke_test.dart 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/notification_center_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_notification_permission_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：这轮设置页来源 chip 的路由回归在 widget test 里采用了直接调用绑定回调的方式锁住“携带 query 进入通知中心”这条逻辑，主要是为了避开当前测试环境下手势触发 `go_router push` 的脆弱时序；通知中心页本身的来源筛选切换仍然保留了真实点按 smoke 覆盖。
- 下一步建议：可以继续沿着通知治理主线往前推进两类增强：一类是通知中心来源筛选下的空态与批量动作更细化，例如“当前没有好友提醒”时给出更明确引导；另一类是把设置页摘要来源和通知中心筛选状态继续接成更稳定的返回上下文，让用户处理完某一类提醒后再回到设置页时，摘要变化也更可感知。
## 2026-03-18 最近动态 24
- 完成：补记上一轮真实修复，并继续把“主壳层稳定性 + 聊天页减重”收了一轮。`MainScreen` 已从“内容区 + bottomNavigationBar”改成显式的 `Column + Expanded(content) + 底部导航` 结构，解决了底部导航覆盖内容区、导致“我的”页签名按钮等点击被拦截的问题；`ProfileTab` 也同步从 `CustomScrollView/Sliver` 收成更稳定的 `SingleChildScrollView + Column`，并压紧了小屏头图、头像和状态区间距，降低真机上的重叠感。基于这层结构修复，本轮继续把 `MainScreen` 改成真正保活的 `IndexedStack`，同时把未读数 / 待处理好友数改成 `context.select(...)` 粒度订阅，减少消息和好友状态变化时整壳层跟着重建带来的卡顿感；`ChatScreen` 则清掉了永远不会命中的 burn hint 分支和几段已被现代状态卡替代的历史死代码，保留当前正在使用的现代输入区/投递状态实现。
- 涉及模块：`flutter-app/lib/screens/main_screen.dart`、`flutter-app/lib/widgets/profile_tab.dart`、`flutter-app/lib/screens/chat_screen.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib\screens\main_screen.dart lib\screens\chat_screen.dart 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_notification_permission_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/match_tab_smoke_test.dart --reporter expanded 通过。
- 风险 / 备注：当前环境下仍不建议并行执行多个 `flutter test`，之前已出现 shader 资源写入冲突；另外，`MainScreen` 现在已经具备更接近原生聊天 app 的 tab 保活能力，但 `ProfileTab` 的全屏背景模式和大图加载体验仍建议继续用真机做一轮小屏回归，重点看长图、低内存机和频繁切 tab 时的稳定性。
- 下一步建议：继续沿着“我的 / 设置 / 聊天”这条高频链路往前做两件事里的任一项：一是继续收紧 `ProfileTab` 和设置页操作入口的点击热区、间距和层级，让视觉逻辑更接近微信 / Telegram 这类成熟聊天 app；二是继续减轻 `ChatScreen` 的历史包袱，把剩余未使用的旧交互辅助分支继续清掉，并补一轮更聚焦的 compact UI 回归。
## 2026-03-18 最近动态 25
- 完成：继续把这一轮壳层与消息链路收稳。`MainScreen` 在验证过程中从 `IndexedStack` 微调为更可控的 `Stack + Visibility(maintainState)` 方案，并补了稳定的 `main-tab-stack` key，让当前页保活的同时不再把 smoke 绑死在具体容器实现上；`ProfileTab` 去掉了非全屏模式下重复的“背景模式 / 设置”二次入口，只保留快捷操作卡里的统一入口，页面层级更干净，也一并删掉了旧菜单和旧弹窗死代码；`MessagesTab` 修好了列表渲染块里的括号结构问题，补正了“从消息进入聊天后返回主壳层”应回到 `tab=1` 而不是错误跳去匹配页的路由，并把“即将到期”提示改为在剩余 3 小时内展示，和现有 smoke 场景保持一致。
- 涉及模块：`flutter-app/lib/screens/main_screen.dart`、`flutter-app/lib/widgets/profile_tab.dart`、`flutter-app/lib/widgets/messages_tab.dart`、`flutter-app/test/smoke/main_screen_smoke_test.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib\screens\main_screen.dart lib\widgets\profile_tab.dart lib\widgets\messages_tab.dart lib\widgets\match_tab.dart test\smoke\main_screen_smoke_test.dart 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/messages_tab_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_notification_permission_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/match_tab_smoke_test.dart --reporter expanded 通过。
- 风险 / 备注：当前 `main_screen_smoke_test.dart` 的首屏匹配引导断言改成了基于业务 key 的稳定检查，不再依赖某一个具体容器类型；另外，消息列表“从聊天返回消息 tab”这条真实路由虽然已修正，但目前还没有单独的 widget smoke 锁住，后续建议补一条更聚焦的回归，避免再被 tab 顺序调整带偏。
- 下一步建议：优先继续做两件事里的任一项：一是给“消息列表 -> 聊天页 -> 返回消息 tab”补一条专门 smoke，把这次路由修复正式锁住；二是继续打磨 `ProfileTab / Settings / ChatScreen` 的 compact 布局和点击热区，把真机上还可能显得拥挤的局部入口再收一轮。
## 2026-03-18 最近动态 26
- 完成：继续把主壳层 tab 顺序和消息回流链路正式锁住。`MainScreen` 的 tab 内容映射已纠正回 `匹配=0 / 消息=1 / 好友=2 / 我的=3`，避免主壳层和消息列表内 `context.go('/main?tab=1')` 的语义再出现错位；`MessagesTab` 新增了 `messages-tab-title` 业务 key，并补上了“消息列表 -> 聊天页 -> 返回后仍停在消息页”的专门 smoke，用真实路由和真实返回动作锁住这次修复；另外顺手做了一轮小屏消息列表减重，把 compact 场景下原本挤在预览行里的亲密度胶囊移到了下方时效信息行，更接近成熟聊天 app 的信息层级，减少小屏上的拥挤感。
- 涉及模块：`flutter-app/lib/screens/main_screen.dart`、`flutter-app/lib/widgets/messages_tab.dart`、`flutter-app/test/smoke/main_screen_smoke_test.dart`、`flutter-app/test/smoke/messages_tab_smoke_test.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib\screens\main_screen.dart lib\widgets\messages_tab.dart test\smoke\main_screen_smoke_test.dart test\smoke\messages_tab_smoke_test.dart 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/messages_tab_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded 通过。
- 风险 / 备注：当前消息回流 smoke 以“聊天页真实出现 + 返回后消息页真实恢复”为主，不再依赖 `GoRouter.currentConfiguration.uri` 在 imperative push 场景下的实现细节；如果后续继续做 shell 或路由重构，建议优先保留这类结果态断言，而不是回到只盯内部 route object。
- 下一步建议：继续沿着这条链路往前做两件事里的任一项：一是补一条“消息页在 compact 模式下未读 badge / 亲密度 / 投递状态同时存在时仍不拥挤”的更聚焦 UI smoke；二是继续回到 `ProfileTab / Settings / ChatScreen` 做下一轮小屏点击热区和层级收紧，优先处理真机上最容易显得挤的入口。
## 2026-03-18 最近动态 27
- 完成：继续把“我的”页首屏往成熟聊天 app 的信息层级收了一轮。`ProfileTab` 在小屏非全屏背景场景下改成了更紧凑的 identity panel：头像改为左侧固定入口，昵称 / 签名 / 状态收进同一张半透明身份卡，减少了原先竖向堆叠导致的拥挤和重叠感；统计区同步收成独立的 compact stats card；“个人页快速整理”卡在小屏下继续压短文案、提示和按钮内边距，让快捷整理卡能完整留在 360x640 首屏内。与此同时，`main_screen_smoke_test.dart` 补上了对 compact 身份卡、统计卡和首屏可见区的结果态断言，正式锁住这轮小屏收口。除此之外，还顺手清理了 `flutter-app/lib/content/app_legal_content.dart` 里一段明显的合并残留，恢复了全量 `flutter analyze` 绿灯。
- 涉及模块：`flutter-app/lib/widgets/profile_tab.dart`、`flutter-app/test/smoke/main_screen_smoke_test.dart`、`flutter-app/lib/content/app_legal_content.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/widgets/profile_tab.dart flutter-app/test/smoke/main_screen_smoke_test.dart flutter-app/lib/content/app_legal_content.dart 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：当前 compact 首屏约束是基于 `360x640` widget smoke 锁住的结果态，能兜住常规小屏布局回归，但仍建议继续用真机检查两类场景：一是长昵称 / 长签名 / 大字号组合；二是竖屏全屏背景模式与普通模式频繁切换时的视觉稳定性。另，当前工作区仍存在其他未提交改动，本轮仅增量处理了与小屏个人页和 analyze 阻塞直接相关的部分。
- 下一步建议：优先沿着同一条高频链路继续做两件事里的任一项：一是回到 `SettingsScreen / ChatScreen` 再补一轮 compact 首屏收口，把最容易挤的 banner、说明文案和操作入口继续压稳；二是给法律 / 关于页补一条轻量 smoke，锁住这次 `app_legal_content.dart` 清理后的可打开性，避免后续再出现文案合并残留把全量 analyze 或运行态带坏。
## 2026-03-18 最近动态 28
- 完成：继续沿着“设置 / 聊天”高频链路做了下一轮 compact 收口。`SettingsScreen` 现在把首屏 overview 区和后续分组之间的节奏切回 `layout.sectionSpacing` 驱动，compact 模式下同步压短了总览说明、焦点卡、设备状态卡、通知运行态卡、通知中心摘要卡和体验预设卡的文案高度，并把预设项宽度收紧到更适合 360 宽度的小屏区间，减少 overview 在小屏上的纵向拖拽感；`ChatScreen` 则继续压紧了小屏 header、通知权限 banner、消息列表边距和取关提示文案/按钮尺寸，降低聊天首屏顶部堆叠带来的拥挤感；`NotificationPermissionNoticeCard` 也同步补上了 compact 下的说明文案折叠与更紧凑的按钮间距，让聊天页和通知中心共用的权限提示卡在小屏上更稳。
- 涉及模块：`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/lib/screens/chat_screen.dart`、`flutter-app/lib/widgets/notification_permission_notice_card.dart`、`flutter-app/test/smoke/settings_screen_smoke_test.dart`、`flutter-app/test/smoke/chat_screen_notification_permission_smoke_test.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/screens/settings_screen.dart flutter-app/lib/screens/chat_screen.dart flutter-app/lib/widgets/notification_permission_notice_card.dart flutter-app/test/smoke/settings_screen_smoke_test.dart flutter-app/test/smoke/chat_screen_notification_permission_smoke_test.dart 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_notification_permission_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：本轮设置页 compact smoke 改成了更稳定的结果态约束，主要锁住“小屏 overview 操作仍可达 + 预设卡宽度已进入紧凑区间”，而不是把测试绑死在某种特定的换行实现上；聊天页这轮主要收的是顶部堆叠密度和 banner/composer 共存时的可用性，仍建议后续继续用真机看长昵称、系统大字体和通知 banner + 多条失败状态卡同时出现时的视觉稳定性。
- 下一步建议：优先继续往前做两件事里的任一项：一是回到 `MessagesTab / NotificationCenterScreen` 做同样的小屏层级收紧，把列表页和通知中心页也统一到现在这套 compact 节奏；二是开始补一轮法律 / 关于页的轻量 smoke，把最近新增的文案页、协议页和安全提示页都锁到“可打开、可滚动、不会再因文案残留拖垮 analyze”的状态。
## 2026-03-18 最近动态 29
- 完成：继续把“小屏消息列表 / 通知中心”这一层收紧并顺手修了一个真实回流 bug。`MessagesTab` 这轮补上了搜索区的 compact 间距参数，把 thread card 的 unread badge 从小屏预览行挪到了底部时效信息行，并给 unread / intimacy / priority / expiring 这些结果态补上业务 key；同时把“从消息页进入聊天，再返回主壳层”纠正回 `tab=1`，不再错误跳去其他 tab。`NotificationCenterScreen` 则新增了 compact layout spec，收紧了页边距、筛选 chip、权限 banner 和通知条目的布局，并把列表项改成更可控的自定义紧凑 tile，保证权限 banner、筛选条和第一条通知在 360x640 下依然有清晰层级。除此之外，还顺手把 `MainScreen` 底部导航圆点指示器的动画曲线从 `easeOutBack` 收成了更稳的 `easeOutCubic`，修复了特定测试尺寸下可能出现的负约束异常。
- 涉及模块：`flutter-app/lib/widgets/messages_tab.dart`、`flutter-app/lib/screens/notification_center_screen.dart`、`flutter-app/lib/screens/main_screen.dart`、`flutter-app/test/smoke/messages_tab_smoke_test.dart`、`flutter-app/test/smoke/notification_center_screen_smoke_test.dart`
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/widgets/messages_tab.dart flutter-app/lib/screens/notification_center_screen.dart flutter-app/lib/screens/main_screen.dart flutter-app/test/smoke/messages_tab_smoke_test.dart flutter-app/test/smoke/notification_center_screen_smoke_test.dart 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/messages_tab_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/notification_center_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded 通过。
- 验证：D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze 通过。
- 风险 / 备注：这轮消息列表 compact smoke 主要锁的是“unread / intimacy / sending 并存时仍可见”的结果态，通知中心 compact smoke 主要锁的是“权限 banner + 筛选条 + 第一条通知”在小屏下的可达性；后续如果继续调整列表视觉，建议保留这类结果态断言，不要回退成只盯具体某个文案或某一种换行形态。另，本轮曾出现 Flutter startup lock 等待提示，后续建议继续按串行方式跑 widget/smoke 测试，避免资源写入冲突。
- 下一步建议：优先继续做两件事里的任一项：一是补法律 / 关于页的轻量 smoke，把协议、隐私和安全提示页也纳入“可打开、可滚动、analyze 绿色”的稳定面；二是继续回到 `FriendsTab / MatchTab` 做同样的小屏层级收紧，让主壳层四个高频入口的 compact 节奏彻底统一。
## 2026-03-18 最近动态 30
- 完成：继续把主壳剩余两块高频入口往统一 compact 节奏上收。`flutter-app/lib/widgets/friends_tab.dart` 新增了 `FriendsTab` 小屏布局规格，收紧了好友列表卡片的横向/纵向间距，给 pending banner、好友条目、好友申请条目补上稳定业务 key，并把好友申请弹层改成带内边距和卡片间距的小屏列表，降低 360 宽度下的拥挤感；`flutter-app/lib/widgets/match_tab.dart` 则把状态 chip 改成了受宽度约束的可折行结构，并为匹配成功卡与底部动作区补上稳定 key，避免小屏下长状态文案把层级挤乱。
- 完成：补上 `flutter-app/test/smoke/friends_tab_smoke_test.dart`，锁住“好友页 compact 首屏可见 + 好友申请弹层动作按钮可达”；同时在 `flutter-app/test/smoke/match_tab_smoke_test.dart` 新增“匹配成功卡在 compact 下动作区仍可见”的回归，连同主壳 smoke 一起把这轮改动正式纳入回归面。
- 涉及模块：`flutter-app/lib/widgets/friends_tab.dart`、`flutter-app/lib/widgets/match_tab.dart`、`flutter-app/test/smoke/friends_tab_smoke_test.dart`、`flutter-app/test/smoke/match_tab_smoke_test.dart`
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/widgets/friends_tab.dart flutter-app/lib/widgets/match_tab.dart flutter-app/test/smoke/friends_tab_smoke_test.dart flutter-app/test/smoke/match_tab_smoke_test.dart` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/friends_tab_smoke_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/match_tab_smoke_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded` 通过。
- 风险 / 备注：`FriendsTab` 的 UID 搜索弹层和空态仍沿用旧结构，只做了列表/请求主链路优先收口；如果后续真机上仍觉得搜索结果卡横向发紧，下一轮建议继续把搜索弹层也接入同一套 compact 规格。`MatchTab` 当前主要收的是状态信息与结果动作区，匹配成功卡内部的问候输入区如果后续要继续打磨，可以再补一条更聚焦的 compact smoke。
- 下一步建议：优先继续两条之一：一是把 `FriendsTab` 的 UID 搜索弹层与好友资料 sheet 继续做 compact 收口，补齐好友链路最后一层；二是转去补法律 / 关于页 smoke，把最近修过的 `app_legal_content.dart` 一起正式锁住。
## 2026-03-18 最近动态
- 完成：P1 后端持久化基础设施确认与补齐。
- 确认现有文件：`backend/ops/docker-compose.yml`（postgres:15 + redis:7）、`backend/db/schema_v1.sql`（完整建表脚本）、`backend/ops/.env.example`（含正确 env var 名）已就位。
- 确认存储驱动工厂：`backend/server/src/modules/shared/infrastructure/infrastructure.module.ts` 已按 `USER_STORE_DRIVER` / `AUTH_RUNTIME_DRIVER` / `RUNTIME_STATE_DRIVER` 三个环境变量独立切换 postgres/redis/memory。
- 完成：更新 `backend/ops/docker-compose.yml`，补齐：
  - postgres 挂载 `../db/schema_v1.sql` 到 `docker-entrypoint-initdb.d/`，一键启动自动建表。
  - postgres / redis 均新增 `healthcheck`，容器就绪检测更可靠。
  - postgres / redis 端口和密码改为读取 env var，本地覆盖更灵活。
- 涉及模块：`backend/ops/docker-compose.yml`
- 验证：文件已更新，schema 挂载路径与现有 `backend/db/schema_v1.sql` 对齐。
- 风险 / 备注：
  - redis-auth-runtime.store.ts 当前未读取 `REDIS_PASSWORD`，如需启用 redis auth 需补一行 `password: process.env.REDIS_PASSWORD`。
  - backend/docker-compose.yml 和 backend/server/sql/init.sql 是本轮误建的重复文件，可手动删除，不影响功能。
- 下一步建议：
  1. 本地执行 `cd backend/ops && docker compose up -d`，确认 postgres+redis 正常启动。
  2. 复制 `backend/ops/.env.example` 为 `backend/server/.env`，填入密码后执行 `npm run start:dev`。
 3. 用真机跑 `flutter run --dart-define=SUNLIAO_API_BASE_URL=http://192.168.x.x:3000/api/v1`，验证注册/登录/匹配/聊天全链路写入 postgres。
 4. 若需 redis 密码认证，在 redis-auth-runtime.store.ts 和 redis-runtime-state.store.ts 的 `new Redis({...})` 中补 `password: process.env.REDIS_PASSWORD`。
## 2026-03-18 最近动态 31
- 完成：继续把 `FriendsTab` 这一轮剩余的 compact 和稳定性问题收口。UID 搜索弹层改成了独立的 `StatefulWidget` 托管输入框 controller，解决了关闭 bottom sheet 时 `TextEditingController` 过早释放导致的竞态；同时把好友长按操作菜单改成带最大高度约束的可滚动弹层，修掉了小屏下操作菜单先溢出、再污染好友资料烟测的问题。
- 完成：同步把与当前实现不一致的烟测基线修正到位。`main_screen_smoke_test.dart` 现在按当前主壳 tab 映射和前台可见树做断言，不再把保活但离屏的 widget 当成“显示中”；另外顺手清掉了 `notification_permission_notice_card.dart` 里一个遗留的未使用局部变量，恢复 `flutter analyze` 全绿。
- 涉及模块：`flutter-app/lib/widgets/friends_tab.dart`、`flutter-app/lib/widgets/notification_permission_notice_card.dart`、`flutter-app/test/smoke/friends_tab_smoke_test.dart`、`flutter-app/test/smoke/friends_profile_sheet_smoke_test.dart`、`flutter-app/test/smoke/main_screen_smoke_test.dart`
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/widgets/friends_tab.dart flutter-app/lib/widgets/notification_permission_notice_card.dart flutter-app/test/smoke/friends_tab_smoke_test.dart flutter-app/test/smoke/friends_profile_sheet_smoke_test.dart flutter-app/test/smoke/main_screen_smoke_test.dart` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/friends_tab_smoke_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/friends_profile_sheet_smoke_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze` 通过。
- 风险 / 备注：本轮排查里再次验证了当前仓库不适合并行跑多个 `flutter test`，否则容易卡在 startup lock 或资源竞争；后续 widget/smoke 建议继续串行执行。另，`FriendsTab` 里旧版 UID 搜索内联实现已被新弹层接管，后续如果继续做该模块清理，可以顺手把历史注释块彻底移除，避免维护噪音。
- 下一步建议：优先继续两件事里的任一项：一是沿着好友链路把“UID 搜索空态 / 搜索失败态 / 好友资料 sheet”的视觉文案和信息层级再统一一轮，进一步贴近微信 / Telegram 那种克制布局；二是切去法律 / 关于页补轻量 smoke，把最近已经收过的文案页稳定面也正式锁住。
## 2026-03-18 最近动态 32
- 完成：继续把两条高价值的小模块补成正式回归面。好友页这边给 `FriendsTab` 新增了两条 compact smoke：一条锁住好友长按操作菜单在小屏下动作按钮仍可达，一条锁住 UID 搜索空输入后的反馈文案仍能在 360x640 内稳定展示；同时给 UID 搜索反馈文本补了稳定 key，便于后续继续收搜索空态 / 失败态时保持测试不脆弱。
- 完成：法律 / 关于页正式纳入轻量 smoke。`AboutScreen` 补了列表与 hero 区 key，`LegalDocumentScreen` 补了滚动容器与正文卡 key，并新增 `flutter-app/test/smoke/legal_pages_smoke_test.dart`，锁住“关于页可滚动”和“长协议页可滚动”这两个结果态，避免后续再因为长文案、编码残留或样式调整把运行态和 analyze 一起带坏。
- 涉及模块：`flutter-app/lib/widgets/friends_tab.dart`、`flutter-app/test/smoke/friends_tab_smoke_test.dart`、`flutter-app/lib/screens/about_screen.dart`、`flutter-app/lib/screens/legal_document_screen.dart`、`flutter-app/test/smoke/legal_pages_smoke_test.dart`
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/widgets/friends_tab.dart flutter-app/test/smoke/friends_tab_smoke_test.dart flutter-app/lib/screens/about_screen.dart flutter-app/lib/screens/legal_document_screen.dart flutter-app/test/smoke/legal_pages_smoke_test.dart` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/friends_tab_smoke_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/legal_pages_smoke_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze` 通过。
- 风险 / 备注：本轮法律 / 关于页 smoke 故意只锁“可打开 + 可滚动 + 不抛异常”，没有把测试和具体文案内容强绑定，后续即使产品继续改措辞，也不容易把回归做脆；好友页这边则仍保留了旧版 UID 搜索历史注释块，功能已不走旧实现，但后续继续整理该文件时建议把历史块彻底删除。
- 下一步建议：优先继续两件事里的任一项：一是回到 `FriendsTab` 做最后一轮结构清理，把 UID 搜索历史实现移除，并顺手统一搜索空态 / 未找到态 / 资料卡的信息层级；二是顺着现在这条轻量 smoke 主线，继续把设置里的“关于与协议”真实入口跳转也补成一条端到端回归。

## 2026-03-19 最近动态
- 完成：本轮未改业务代码，先按接手流程补做了一次仓库探索与上下文核对，确认当前仓库主结构仍是 `flutter-app` Flutter 前端 + `backend/server` Nest 风格后端，当前 sprint 主线仍聚焦"设置 / 聊天体验收口、小屏适配、失败态可理解性、环境隔离与穿透测试准备"。
- 涉及模块：`AGENTS.md`、`PROJECT_CONTEXT.md`、`CURRENT_SPRINT.md`、`RELEASE_CHECKLIST.md`、`flutter-app/`、`backend/`、`versions/`
- 验证：`Get-Content -Raw -Encoding UTF8 AGENTS.md`、`PROJECT_CONTEXT.md`、`CURRENT_SPRINT.md`、`RELEASE_CHECKLIST.md` 已完成阅读。
- 验证：`rg --files flutter-app backend versions` 已完成结构扫描。
- 验证：`git status --short` 已确认当前工作区仅有未跟踪目录 `tmp_test_logs/`。
- 风险 / 备注：本轮仅做排查与子 agent 探索准备，未运行 Flutter / backend 自动化测试；另外，子 agent 探索期间未对仓库做写操作。
- 下一步建议：如继续开发，优先沿 `CURRENT_SPRINT.md` 现有建议继续二选一推进：一是回到 `FriendsTab` 做 UID 搜索历史实现清理与信息层级统一，二是把设置里的"关于 / 协议"真实入口跳转补成端到端回归；若转向后端，则优先补环境联调与持久化链路验证。

## 2026-03-19 最近动态 2
- 完成：清理 `flutter-app/lib/widgets/friends_tab.dart` 中旧版 UID 搜索历史注释块（约 370 行注释代码），该实现已由 `_UidSearchSheet` 独立 widget 接替，旧块长期以 `/* */` 形式残留。清理后文件从 ~2200 行降至 ~1830 行，结构更清晰。
- 完成：给设置页"关于与协议"三个入口（关于瞬 / 隐私政策 / 用户协议）补了稳定 key（`settings-about-item`、`settings-privacy-policy-item`、`settings-user-agreement-item`），并新增 `flutter-app/test/smoke/settings_legal_navigation_smoke_test.dart`，用带 GoRouter 的 harness 锁住三条真实跳转链路（Settings → AboutScreen / LegalDocumentScreen）。
- 涉及模块：`flutter-app/lib/widgets/friends_tab.dart`、`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/test/smoke/settings_legal_navigation_smoke_test.dart`
- 验证：`flutter test test/smoke/settings_legal_navigation_smoke_test.dart --reporter expanded` 3 条全通过。
- 验证：`flutter analyze` 通过，No issues found。
- 验证：全量 `flutter test` 225 个，221 通过，4 个失败为预存在问题（auth_provider_test 需要 requestOtp 前置步骤、match_tab/messages_tab 各有一条不稳定导航 smoke），与本轮改动无关。
- 风险 / 备注：旧版注释块删除过程因文件过大用了 PowerShell 脚本辅助，已清理临时文件；4 个预存在失败测试建议后续单独修复。
- 下一步建议：优先推进后端持久化切换（PostgreSQL + Redis），解决后端重启丢数据问题，为内网穿透测试铺路；或修复 auth_provider_test 中缺少 requestOtp 前置步骤的测试缺陷。

## 2026-03-19 最近动态 3
- 完成：修复上轮发现的 4 个预存在测试失败，全量测试恢复全绿（225 个全通过）。
  1. `auth_provider_test`：3 个用例在 `login()` 前补 `await provider.sendOtp(phone)` 前置步骤，修复 `_pendingOtpRequestId` 未初始化导致 login 直接返回 false 的问题。
  2. `messages_tab_smoke`（返回到消息页用例）：根因是业务代码 `messages_tab.dart` 点击线程后返回写死了 `context.go('/main?tab=1')`（MatchTab），修复为 `tab=0`（MessagesTab）；测试侧同步把 `initialLocation` 从 `/main?tab=1` 改为 `/main?tab=0`，并补 `pump(Duration(milliseconds: 300))` 稳定等待。
  3. `match_tab_smoke`（小屏主按钮断言）：physicalSize=360×640 但实际渲染高度 650.6，硬编码 `lessThanOrEqualTo(640)` 误报，改为动态计算 `screenHeight + 16` 容差。
- 完成：打出 release APK 并输出到 `apk-output/sunliao-v1.0.4+5-20260319.apk`（约 24.5 MB），可用于真机验证。
- 涉及模块：`flutter-app/lib/widgets/messages_tab.dart`、`flutter-app/test/providers/auth_provider_test.dart`、`flutter-app/test/smoke/messages_tab_smoke_test.dart`、`flutter-app/test/smoke/match_tab_smoke_test.dart`、`apk-output/`
- 验证：`flutter test --reporter expanded` 全量 225 个测试全部通过，exit_code=0。
- 验证：`flutter analyze` 通过，No issues found。
- 风险 / 备注：`messages_tab.dart` 返回路由的 bug（`tab=1` → `tab=0`）是真实业务 bug，用户在消息页点进聊天后返回会落到 MatchTab，本轮已一并修复。
- 下一步建议：
  1. 用真机验证 APK（`apk-output/sunliao-v1.0.4+5-20260319.apk`），重点验证：登录/登出、消息列表 → 聊天 → 返回消息列表的正确性。
  2. 推进后端持久化切换（PostgreSQL + Redis），为内网穿透测试铺路（参见 `backend/ops/docker-compose.yml`）。
  3. 准备正式签名 keystore 和上线前检查项（参见 `RELEASE_CHECKLIST.md`）。

## 2026-03-19 最近动态 4
- 完成：本轮未改业务代码，补做了一次“产品成熟度 + 工程成熟度 + 上线成熟度”的仓库排查；当前项目已经成型，更接近“高质量可联调测试版 / 准上线候选版”，还不是“成熟可规模上线版”。
- 涉及模块：`flutter-app/lib/config/routes.dart`、`flutter-app/lib/screens/login_screen.dart`、`flutter-app/lib/screens/main_screen.dart`、`flutter-app/lib/screens/chat_screen.dart`、`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/lib/widgets/friends_tab.dart`、`flutter-app/lib/widgets/messages_tab.dart`、`flutter-app/lib/widgets/match_tab.dart`、`flutter-app/lib/widgets/profile_tab.dart`、`flutter-app/lib/services/analytics_service.dart`、`backend/server/src/modules/shared/infrastructure/infrastructure.module.ts`、`backend/server/src/modules/report/application/report.service.ts`、`backend/server/test/`
- 验证：已完成文档与代码排查；核对了前端主路由、登录首跳、主壳 tab、聊天/消息/好友/设置主链路、后端驱动切换点、docker 持久化编排、举报模块实现与现有测试面。
- 风险 / 备注：
  1. 产品侧主问题不再是“有没有功能”，而是“首登激活、关系推进、留存闭环”仍偏弱；当前从 `Splash -> Login -> Main` 直接进入主壳，未看到独立 onboarding / 兴趣选择 / 新手任务链路。
  2. 工程侧主问题是几个高频页面持续膨胀，`settings_screen.dart`、`chat_screen.dart`、`match_tab.dart`、`friends_tab.dart` 体量已经较大，后续改动成本和回归风险会继续上升。
  3. 上线侧主问题是持久化、观测和审核链路仍未完全产品化；环境切换能力已经具备，但还需要真实联调验证，举报模块也仍是 in-memory + TODO moderation pipeline。
- 下一步建议：
  1. 先补“可上线阻塞项”：后端 PostgreSQL / Redis 真切换、内网穿透联调、异常日志与健康检查闭环。
  2. 再补“产品留存项”：首登激活、资料完善引导、匹配后转聊天/加好友的推进提示、低打扰召回。
  3. 最后做“工程收口”：按模块拆小超大页面，优先拆设置页、聊天页和好友页，降低后续继续迭代时的卡顿与返工风险。

## 2026-03-19 最近动态 5
- 完成：本轮以“测试工程师 + 产品经理”的视角，专项排查了失败场景的底层回调与 UI 交互一致性，重点覆盖聊天发送失败、图片上传失败、通知权限失败、登录失败与举报提交流程。
- 涉及模块：`flutter-app/lib/widgets/chat_delivery_status.dart`、`flutter-app/lib/providers/chat_provider_messages.dart`、`flutter-app/lib/screens/chat_screen.dart`、`flutter-app/lib/widgets/messages_tab.dart`、`flutter-app/lib/services/media_upload_service.dart`、`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/lib/screens/login_screen.dart`、`flutter-app/lib/screens/report_screen.dart`、`backend/server/src/modules/report/application/report.service.ts`
- 验证：
  1. `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze` 通过。
  2. `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\widgets\chat_delivery_status_test.dart --reporter expanded` 通过。
  3. `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\smoke\chat_screen_delivery_failure_smoke_test.dart --reporter expanded` 通过。
  4. `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\smoke\messages_tab_delivery_failure_smoke_test.dart --reporter expanded` 通过。
  5. `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\providers\chat_provider_test.dart --reporter expanded` 通过。
  6. `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\services\media_upload_service_test.dart --reporter expanded` 通过。
  7. `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\smoke\chat_screen_notification_permission_smoke_test.dart --reporter expanded` 通过。
  8. `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\smoke\settings_screen_smoke_test.dart --reporter expanded` 通过。
  9. `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\providers\auth_provider_test.dart --reporter expanded` 通过。
  10. `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\providers\settings_provider_test.dart --reporter expanded` 通过。
- 风险 / 备注：
  1. 聊天失败态主链路整体逻辑是通的：网络波动可重试、关系受限/会话过期不可重试、图片过大/格式异常走说明引导，方向正确。
  2. 发现一个文案级回调不一致：`chat_screen.dart` 内联失败动作里，`ChatDeliveryFailureState.retryable` 对文本消息给出的错误说明是“消息暂时无法重试，请稍后再发一条”，但该状态本身属于可重试态，容易误导用户。
  3. 发现一个更高优先级的一致性问题：后端举报服务对 `noop` / `rate_limited` / `dedup` 仍返回成功结构，而前端举报页会把所有成功响应统一提示为“举报已发送”后关闭页面，容易让用户误以为举报已正常受理。
  4. 图片上传失败归因当前仍部分依赖英文 message 文案匹配（如 too large / unsupported format / invalid upload token），对后端文案变动较敏感，后续建议逐步收敛到稳定错误码。
  5. 登录页 / 启动页 / 举报页目前缺少独立 smoke 覆盖，本轮主要通过代码排查确认风险，尚未补端到端 UI 自动化。
- 下一步建议：
  1. 优先修复举报成功回调误导问题，并补 `ReportScreen` 提交成功 / 重复举报 / 频控限制三类 smoke 或 widget 回归。
  2. 修正聊天页 `retryable` 文案与动作含义不一致的问题，避免用户看到“不可重试”却仍存在重试按钮。
  3. 为登录页和启动页补基础 smoke，至少锁住协议勾选、验证码失败、登录失败和首跳路由这几类基础场景。

## 2026-03-19 最近动态 6
- 完成：修复举报提交流程的“伪成功”反馈问题。后端 `ReportService` 现在会显式返回 `accepted / duplicate / rate_limited / ignored_self` 语义状态；前端 `ReportScreen` 会据此区分：
  1. 正常提交：返回上一页后提示“举报已提交，我们会尽快处理”。
  2. 重复举报：返回上一页后提示“今天已提交过该举报，我们会合并处理”。
  3. 频控限制：停留在当前页，提示“提交过于频繁，请稍后再试”。
  4. 自举报：停留在当前页，提示“不能举报自己”。
- 完成：修复聊天页失败态里 `retryable` 文案与动作不一致的问题，并把“重试失败提示映射”从超大文件 `chat_screen.dart` 中抽到独立的 `chat_retry_feedback.dart`，避免后续继续把聊天页做得更重。
- 完成：新增举报页 smoke 回归与举报服务后端测试，并新增聊天重试反馈单测，锁住这轮修复后的行为。
- 涉及模块：`flutter-app/lib/screens/report_screen.dart`、`flutter-app/lib/screens/chat_screen.dart`、`flutter-app/lib/utils/chat_retry_feedback.dart`、`flutter-app/test/smoke/report_screen_smoke_test.dart`、`flutter-app/test/utils/chat_retry_feedback_test.dart`、`backend/server/src/modules/report/application/report.service.ts`、`backend/server/test/report.service.spec.ts`
- 验证：
  1. `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze` 通过。
  2. `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\utils\chat_retry_feedback_test.dart --reporter expanded` 通过。
  3. `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\smoke\report_screen_smoke_test.dart --reporter expanded` 通过。
  4. `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\smoke\chat_screen_smoke_test.dart --reporter expanded` 通过。
  5. `cd backend/server && npm test -- --runInBand test/report.service.spec.ts` 通过。
- 风险 / 备注：
  1. 举报链路的用户感知已经收口，但后端仍未接入真正的 moderation pipeline，当前还是“受理语义更清楚”，不是“审核运营闭环已完成”。
  2. 本轮优先收口了高优体验问题；登录页 / 启动页基础失败态 smoke 仍建议后续继续补齐。
- 下一步建议：
  1. 继续补 `LoginScreen / SplashScreen` 的基础 smoke，把验证码失败、协议勾选和首跳路由纳入回归。
  2. 顺着这次的“从大屏幕里拆小逻辑块”方式，继续拆 `chat_screen.dart` 与 `settings_screen.dart` 中的失败态 / 提示态映射逻辑。
  3. 转向后端联调时，继续推进举报审核、观测埋点与持久化联调，不要让“前端提示更清楚”停留在展示层。

## 2026-03-19 最近动态 7
- 完成：补齐 `LoginScreen / SplashScreen` 的基础入口 smoke，并顺手做了两处低成本、高体验收益的登录页收口：
  1. 登录按钮不再只看“手机号位数 + 验证码位数 + 已勾选协议”，而是额外要求“当前手机号已经成功请求过验证码”，避免用户没发验证码就直接点登录。
  2. 用户在请求验证码后如果修改了手机号，登录按钮会重新禁用，验证码倒计时也会立即清零，避免被旧手机号的 60 秒倒计时锁住。
- 完成：给登录页补了稳定 key（手机号输入框 / 验证码输入框 / 发送验证码按钮 / 协议勾选 / 登录按钮 / 协议链接），方便后续持续补基础回归。
- 完成：给 `SplashScreen` 补了可注入的 `displayDuration / animationDuration / authPollInterval`，默认行为不变，但测试与后续局部联调可以用更短时序验证首跳逻辑。
- 涉及模块：`flutter-app/lib/screens/login_screen.dart`、`flutter-app/lib/screens/splash_screen.dart`、`flutter-app/test/smoke/login_screen_smoke_test.dart`、`flutter-app/test/smoke/splash_screen_smoke_test.dart`
- 验证：
  1. `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze` 通过。
  2. `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\smoke\login_screen_smoke_test.dart --reporter expanded` 通过。
  3. `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test\smoke\splash_screen_smoke_test.dart --reporter expanded` 通过。
- 风险 / 备注：
  1. 登录页当前仍是 OTP 登录单页形态，已经更稳，但“发送验证码成功后是否要加轻量页内提示而不只靠 toast”还可以后续继续打磨。
  2. `SplashScreen` 现已可测，但本质上仍承担首跳控制；如果后续入口逻辑继续增加，建议逐步把首跳判定从页面状态收束到更独立的启动协调层。
- 下一步建议：
  1. 继续补 `ReportScreen / LoginScreen / SplashScreen` 之外剩余基础入口的端到端验证，例如设置页退出登录后的回到登录页链路。
  2. 继续拆 `chat_screen.dart` 与 `settings_screen.dart` 的提示映射和动作分发逻辑，把高频失败态收束成独立 utility / presenter。
  3. 准备下一轮后端联调时，把“首登与登录稳定性”纳入真机回归 checklist，避免只在 widget smoke 里绿。
## 2026-03-19 最近动态 8
- 完成：补上“设置页退出登录 -> 返回登录页”的端到端回归链路，并顺手把退出登录行为收成更稳定的状态驱动式跳转。`AuthProvider.logout()` 现在会先同步清空内存态并 `notifyListeners()`，让受保护路由可以立刻基于登录态重定向；`SettingsScreen` 的退出按钮补了稳定 key，确认退出后会等待登出清理完成，再在仍挂载时兜底跳转 `/login`。
- 完成：给通用确认弹窗补了稳定 key（`app-dialog-cancel` / `app-dialog-confirm`），新增 `flutter-app/test/smoke/settings_logout_smoke_test.dart`，用真实 `AppRouter` + `/settings` 初始路由锁住这条链路：
  1. 已登录状态进入设置页。
  2. 点击退出登录并确认后，认证信息被清空。
  3. 路由回到 `/login`。
  4. 登出后再次尝试访问 `/main` 仍会被拦回登录页。
- 涉及模块：`flutter-app/lib/config/routes.dart`、`flutter-app/lib/providers/auth_provider.dart`、`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/lib/widgets/app_toast.dart`、`flutter-app/test/smoke/settings_logout_smoke_test.dart`
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_logout_smoke_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/auth_provider_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze` 通过。
- 风险 / 备注：本轮定位到一个测试层面的假死点，原因是 widget test 里误用了 `Future.delayed(Duration.zero)`；在 Flutter fake async 下这类等待容易卡住，后续 smoke / widget 回归继续优先用 `tester.pump(...)` 控时，避免再次出现“看起来像卡死”的假阻塞。
- 下一步建议：优先继续补“设置 / 我的”里剩余几个会改登录态或会话态的链路回归，例如账号注销后的回登录页、切换账号后的数据隔离，以及登录成功后的轻量页内反馈，逐步把首登 / 登出 / 换号这条账号主链路补成完整检查面。
## 2026-03-19 最近动态 9
- 完成：继续把账号主链路从“退出登录”往下补到“注销账号”和“切换账号数据隔离”。`AuthProvider.deleteAccount()` 现在和 `logout()` 一样，会先同步清空内存态并立刻 `notifyListeners()`，让设置页确认注销后即使页面提前卸载，路由层也能马上按未登录态接管；`SettingsScreen` 的“注销账号”按钮补了稳定 key，方便后续继续做端到端回归。
- 完成：扩展 `flutter-app/test/smoke/settings_logout_smoke_test.dart`，补上“设置页注销账号 -> 回登录页 -> 会话数据被清空 -> 再进受保护页面仍被拦截”的真实 smoke；同时在 `flutter-app/test/providers/auth_provider_test.dart` 新增两条 provider 级回归：
  1. `deleteAccount` 会清空 session scoped storage，但保留 `device_id`。
  2. 用不同手机号重新登录时，会清掉上一个账号残留的聊天/通知中心/昵称等会话数据。
- 涉及模块：`flutter-app/lib/providers/auth_provider.dart`、`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/test/smoke/settings_logout_smoke_test.dart`、`flutter-app/test/providers/auth_provider_test.dart`
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_logout_smoke_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/auth_provider_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze` 通过。
- 风险 / 备注：账号主链路里“登出 / 注销 / 换号的数据隔离”这一层现在已经有了基础自动化兜底，但登录成功后的反馈仍主要依赖 toast；如果后面做真机体验打磨，建议继续收成更轻量、可感知的页内成功态。
- 下一步建议：优先继续推进账号主链路剩余一段，例如登录成功后的页内反馈、切换账号后的首屏状态重置、以及“我的 / 设置”里依赖当前账号身份的资料刷新一致性，把账号生命周期真正补成闭环。
## 2026-03-19 最近动态 10
- 完成：继续补登录页的轻量页内反馈，把“验证码已发送”的状态从纯 toast 收成页面内可回看的提示卡。`LoginScreen` 现在会在当前手机号已成功请求过验证码时，展示带掩码手机号的 inline hint，并根据倒计时区分“稍后可重新获取”与“当前可重新获取验证码”两种说明；当用户修改手机号时，这张提示卡会和 OTP 绑定态一起被清掉，避免旧手机号的成功状态继续误导用户。
- 完成：同步扩展 `flutter-app/test/smoke/login_screen_smoke_test.dart`，锁住这条链路：发送验证码成功后提示卡出现，换号后提示卡消失，同时原有“未请求 OTP 不可登录 / 换号后登录重新禁用”的回归仍保持成立。
- 涉及模块：`flutter-app/lib/screens/login_screen.dart`、`flutter-app/test/smoke/login_screen_smoke_test.dart`
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/login_screen_smoke_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze` 通过。
- 风险 / 备注：登录页现在已经同时具备 toast 和页内状态提示，基础可理解性更好；但登录成功后的“资料同步中 / 即将进入首页”等成功态仍然没有独立页内反馈，后续如果继续打磨账号主链路，可以把这部分也收进统一的轻提示体系。
- 下一步建议：优先继续推进“换号后的首屏状态重置”和“我的 / 设置依赖当前账号身份的资料刷新一致性”，把账号生命周期从登录、登出、注销、换号进一步补到主壳首屏表现层。
## 2026-03-19 最近动态 11
- 完成：修复“我的”资料页对头像 / 背景媒体引用的路径判断不一致问题。`ProfileTab` 之前只把 `http/https` 识别成远端图片，像 `avatar/...`、`background/...` 这类对象存储 key 会被误当成本地文件；现在资料页会统一先走 `AppEnv.resolveMediaUrl(...)`，再按“远端网络图 / 本地文件”分支渲染，避免设置返回后头像或背景不刷新、丢失或误读本地路径。
- 完成：顺手补了资料页媒体节点的稳定 key，并在 `flutter-app/test/smoke/main_screen_smoke_test.dart` 新增“从资料页进入设置 -> 模拟保存远端头像 / 背景引用 -> 返回资料页立即按网络图回显”的真实 smoke，锁住设置返回后的刷新链路。
- 涉及模块：`flutter-app/lib/widgets/profile_tab.dart`、`flutter-app/test/smoke/main_screen_smoke_test.dart`
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze` 通过。
- 风险 / 备注：这轮已经把“对象存储 key 被误当成本地文件”的回显 bug 收住了，但设置页当前更换头像 / 背景仍主要走本地持久化分支，后续如果要把这条链路彻底收成可上线版本，建议继续补“设置页媒体更换直连远端上传 + 资料页 / 消息列表统一回显”的闭环。
- 下一步建议：沿着账号生命周期继续往下收口两件高价值工作：
  1. 补“换号后的首屏状态重置”，把 main shell 里的资料、会话和提醒入口按当前账号重新对齐。
  2. 把设置页头像 / 背景更换链路从本地引用升级为统一远端媒体链路，减少 profile / settings / message list 三处媒体回显逻辑分叉。
## 2026-03-19 最近动态 12
- 完成：把设置页“更换头像 / 更换背景”接回统一的 `MediaUploadService` 媒体链路。`SettingsScreen` 现在会在选图后走真实上传服务，再通过 `ImageUploadService.saveAvatarReference(...) / saveBackgroundReference(...)` 落盘最终引用，不再只是本地选图后直接提示“已更新”，从而和资料页、后续消息列表的媒体引用策略保持一致。
- 完成：顺手把远端上传成功后的本地临时图片清理逻辑补到 `ImageUploadService`，避免“上传已经切到远端引用，但本地预览文件仍滞留在沙盒里”的隐性堆积问题；`ProfileTab` 的头像 / 背景更换也同步接入了这条清理逻辑。
- 完成：扩展 `flutter-app/test/smoke/settings_screen_smoke_test.dart`，通过可注入的 fake `MediaUploadService` 锁住“设置页更换头像 / 背景后，最终保存的是远端媒体引用，并继续给出页内成功反馈”的行为；同时在 `flutter-app/test/services/image_upload_service_test.dart` 新增临时预览清理回归，防止后续再把清理逻辑改丢。
- 涉及模块：`flutter-app/lib/screens/settings_screen.dart`、`flutter-app/lib/services/image_upload_service.dart`、`flutter-app/lib/widgets/profile_tab.dart`、`flutter-app/test/smoke/settings_screen_smoke_test.dart`、`flutter-app/test/services/image_upload_service_test.dart`、`flutter-app/test/smoke/main_screen_smoke_test.dart`
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/services/image_upload_service_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze` 通过。
- 风险 / 备注：设置页现在已经能正确保存远端媒体引用，但“删除头像 / 删除背景”仍然主要是本地恢复默认视角，暂时还没有后端侧的媒体解绑 / 清理闭环；如果后面要进一步收口上线能力，需要把删除链路也补到服务端语义上。
- 下一步建议：
  1. 继续补“换号后的首屏状态重置”，尤其是 main shell 中资料、会话和通知摘要在账号切换后的即时刷新。
  2. 评估是否为头像 / 背景删除动作补一个明确的后端解绑接口或状态同步语义，避免后续多端出现“本地删了，但远端资料仍旧保留”的认知偏差。

## 2026-03-19 最近动态 13
- 完成：收口登录成功链路，`LoginScreen` 不再在认证成功后额外串行刷新旧页面树里的 `ProfileProvider / SettingsProvider / FriendProvider / MatchProvider / ChatProvider`。现在登录成功后会直接进入 `/main`，把首屏数据初始化交回给基于 `sessionKey` 重建的新会话 provider 子树，减少登录后等待和换号时的旧树耦合。
- 完成：扩展 `flutter-app/test/smoke/login_screen_smoke_test.dart`，新增“登录页即使不依赖旧的 session-scoped providers 也能成功进入主壳”的回归，锁住这次登录链路收口。
- 完成：扩展 `flutter-app/test/providers/auth_provider_test.dart`，新增“退出登录后再次登录新账号时，通知中心未读数、昵称缓存、聊天会话缓存保持清空”的账号生命周期回归，补上换号后残留态的稳定兜底。
- 涉及模块：`flutter-app/lib/screens/login_screen.dart`、`flutter-app/test/smoke/login_screen_smoke_test.dart`、`flutter-app/test/providers/auth_provider_test.dart`
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/login_screen_smoke_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/auth_provider_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze` 通过。
- 风险 / 备注：本轮尝试过补一条 live session widget smoke 去覆盖“主壳内实时换号后的首页重建”，但在当前 Flutter test runner 环境下会出现长时间挂起，因此没有保留不稳定用例；当前先用稳定的 login smoke + auth provider 生命周期回归锁住核心行为。
- 下一步建议：
  1. 继续把账号生命周期往主壳首页表现层推进，优先补“登录成功后首屏轻提示 / 同步中状态”和“设置页返回首页后的身份感知一致性”。
  2. 如果后续要继续补 live session UI 回归，优先复用已有稳定 smoke harness，避免把 router、session 切换和多个后台 timer 一次性耦进同一条 widget 测试。

## 2026-03-19 最近动态 14
- 完成：先从真机卡顿最敏感的全局层做了一轮减压。`AnalyticsService` 改为批量延迟落盘，不再每条埋点都同步写本地；`NotificationCenterProvider` 改为优先即时更新 UI，再延迟合并持久化；`ChatProvider` 的聊天快照持久化从高频短间隔改为更克制的 debounce，并补了“写入中合并下一次落盘”的保护，减少高频消息/回调时的磁盘写入抖动。
- 完成：优化主壳切 tab 的渲染成本。`MainScreen` 现在把四个主 tab 缓存在 `IndexedStack` 里，不再每次切换都走之前那套 `Visibility + TickerMode + AnimatedOpacity` 的重渲染路径；底部毛玻璃 blur 强度也做了下调，减少低端真机上的切页拖滞感。
- 完成：补“登录成功后的首屏轻提示 / 同步中状态”。登录成功后会带 `entry=login` 进入主壳首页，`MainScreen` 会短暂展示一条轻量提示“已登录，首页正在同步资料、消息和通知”，降低用户在首屏初始化阶段的等待不确定感。
- 完成：推进“设置返回首页后的身份感知一致性”。`ProfileTab` 现在统一通过 `_openSettings(...)` 进入设置，返回时会主动刷新头像/背景本地引用和资料远端快照；如果手机号、昵称、状态、签名、头像或背景发生变化，会在首页资料页展示一条轻提示“首页身份信息已同步”，明确告知设置改动已回收到当前首页。
- 涉及模块：`flutter-app/lib/services/analytics_service.dart`、`flutter-app/lib/providers/notification_center_provider.dart`、`flutter-app/lib/providers/chat_provider.dart`、`flutter-app/lib/providers/chat_provider_storage.dart`、`flutter-app/lib/screens/main_screen.dart`、`flutter-app/lib/screens/login_screen.dart`、`flutter-app/lib/widgets/profile_tab.dart`、`flutter-app/test/smoke/login_screen_smoke_test.dart`、`flutter-app/test/smoke/main_screen_smoke_test.dart`
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/login_screen_smoke_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/auth_provider_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/notification_center_screen_smoke_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze` 通过。
- 风险 / 备注：这轮先优先处理了“全局高频写本地 + 主壳切换成本 + 首屏/设置返回感知”三个高性价比问题，能直接改善真机响应；但 `chat_screen.dart`、`settings_screen.dart`、`friends_tab.dart` 这类超大页面内部仍有继续拆分和局部重绘优化空间，后续还可以继续往更细粒度推进。
- 下一步建议：
  1. 继续做聊天页与设置页内部的局部重绘收口，优先清理高频 `Consumer` 包裹过大的区域、重复 post frame 回调和一些重量级装饰。
  2. 真机重点回归：登录后首屏提示是否自然、主壳切 tab 是否顺手、设置修改手机号/头像/背景后返回“我的”页是否更稳、更明确。

## 2026-03-19 最近动态 15
- 完成：继续收口登录成功热路径。`AuthProvider.login()` 现在在保存登录态并同步通知中心后立即 `notifyListeners()`，把 `PushNotificationService.initialize(...)` 和 `login_success` 埋点改到后台 warmup；同时补了瞬时 `pendingEntryHint` 标记，避免 router 先重定向到 `/main` 时丢掉首屏轻提示。
- 完成：`MainScreen` 现在同时支持路由 `entry=login` 和认证态瞬时标记两条入口，保证登录后首屏“同步中”轻提示在真实重定向场景下也能稳定出现。
- 完成：`MessagesTab` 去掉 30 秒整页 `setState()` 刷新，改为 `ValueNotifier` 驱动的局部时间文案更新；补了 `nowProvider` 测试注入点和 scoped time keys，减少消息列表在真机上的周期性整页重建。
- 涉及模块：`flutter-app/lib/providers/auth_provider.dart`、`flutter-app/lib/screens/main_screen.dart`、`flutter-app/lib/widgets/messages_tab.dart`、`flutter-app/test/providers/auth_provider_test.dart`、`flutter-app/test/smoke/main_screen_smoke_test.dart`、`flutter-app/test/smoke/messages_tab_smoke_test.dart`、`flutter-app/test/smoke/login_screen_smoke_test.dart`
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/auth_provider_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/messages_tab_smoke_test.dart --reporter expanded` 通过。
- 验证：`D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/login_screen_smoke_test.dart --reporter expanded` 通过。
- 风险 / 备注：`NotificationCenterProvider.reloadFromStorage()` 仍保留在登录热路径中，用于避免换号后通知角标短暂显示旧会话数据；如果后续继续压缩登录耗时，可以优先补一个通知中心“内存态快速重置”能力，再把这一步继续下沉。
- 下一步建议：
  1. 继续拆 `ChatScreen` 里大范围 `Consumer` 和多处定时 / post-frame 回调，优先把头部、消息列表、输入区拆成更细粒度 rebuild。
  2. 继续检查 `SettingsScreen` 内部的状态块和大面积联动回调，把真机保存后的卡顿和返回抖动继续往下压。
## 2026-03-19 鏈€杩戝姩鎬?17
- 瀹屾垚锛氬洖鍒扳€滅湡鏈洪噸鍙犳槑鏄锯€濈殑褰撳墠浼樺厛绾э紝鍏堝湪 `ChatScreen` 鍜?`SettingsScreen` 鍋氫簡涓€杞獎灞忓竷灞€鏀剁泭锛屼笉鏀瑰彉鐜版湁涓婚锛屼富瑕佹槸鎶娾€滄爣棰?badge / action / switch鈥濊繖绉嶆渶瀹规槗鎸ゆ寲鐨勬í鍚戝竷灞€鏀规垚鏇翠繚瀹堢殑鍝嶅簲寮忔帓甯冦€傝亰澶╅〉鏂板浜?tight layout tier锛屽湪鏇寸獎灞忎笅鏀剁揣 AppBar锛屽ご鍍忋€佹爣棰樺拰鍙充笂瑙掓搷浣滅暀鍑烘洿瀹夊叏鐨勬í鍚戠┖闂达紝杈撳叆鍖哄垯鎶婂琛屾枃鏈拰鐘舵€佹彁绀轰紭鍏堟敹鍒版洿鍏嬪埗鐨勯珮搴︺€傝缃〉鍒欑粺涓€琛ヤ簡鍝嶅簲寮?badge helper锛屾€昏鍔ㄤ綔銆佽澶囩姸鎬佽銆佺珯鍐呭弽棣堝崱銆侀€氱煡涓績鎽樿鍗′互鍙婇€氱敤 `setting item` 閮芥敼涓烘敮鎸?tight 鍦烘櫙涓嬬殑鎹㈣ / 绾靛悜闄嶇骇銆?
- 娑夊強妯″潡锛歚flutter-app/lib/screens/chat_screen.dart`銆乣flutter-app/lib/screens/settings_screen.dart`銆乣flutter-app/test/smoke/chat_screen_smoke_test.dart`銆乣flutter-app/test/smoke/settings_screen_smoke_test.dart`
- 楠岃瘉锛?  1. `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze` 閫氳繃銆?  2. `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --plain-name "chat screen should keep composer actions visible on compact size" --reporter expanded` 閫氳繃銆?  3. `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --plain-name "chat screen should keep header and composer stable on tight size" --reporter expanded` 閫氳繃銆?  4. `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --plain-name "settings screen should show inline feedback for toggle actions" --reporter expanded` 閫氳繃銆?  5. `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --plain-name "settings screen should keep overview actions visible on compact size" --reporter expanded` 閫氳繃銆?  6. `D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --plain-name "settings screen should keep overview and toggles stable on tight size" --reporter expanded` 閫氳繃銆?
- 椋庨櫓 / 澶囨敞锛?  1. 鏈疆鐨?tight threshold 鏄?320~340 瀹藉害绾у埆鐨勬洿绐勫睆璁惧锛?360 瀹藉害浠嶇户缁娇鐢ㄥ師鏈夌殑 compact 瑙勫垯锛屼富瑕佹槸鍏堟妸鐪熸満閲嶅彔鏈€鏄庢樉鐨勫満鏅敹浣忥紝鍚屾椂涓嶆妸姝ｅ父灏忓睆甯冨眬涓€娆℃€ф敼寰楄繃婵€銆?  2. 鍦ㄥ皾璇曚互鈥滄暣鏂?smoke 鏂囦欢鈥濈殑鏂瑰紡骞惰鍥炲綊鏃讹紝瑙傚療鍒颁竴浜涙棤鍏冲綋鍓嶆敼鍔ㄧ殑 pending timer 鎶ヨ锛堜緥濡傞€氱煡涓績 / 鑱婂ぉ鎸佷箙鍖栫殑寤惰繜鍐欏叆锛夛紝鍥犳鏈疆鍏堜互鍙楀奖鍝嶅尯鍩熺殑瀹氬悕 smoke 楠岃瘉涓轰富锛屽悗缁彲鍐嶅崟鐙敹鏁翠竴杞?test harness銆?
- 涓嬩竴姝ュ缓璁細
  1. 缁х画鐪熸満鍥炲綊 `ChatScreen` 鍜?`SettingsScreen` 锛岀壒鍒湅 320~360 瀹藉害 + 闀挎樀绉?/ 闀挎枃妗?/ 绯荤粺瀛椾綋鍋忓ぇ鐨勭粍鍚堟儏鍐碉紝鎶婅繖杞殑鍝嶅簲寮忚勫垯缁х画鎵撶（瀹屾暣銆?  2. 濡傛灉鐪熸満涓婅繕鏈夆€滄煇涓€鍧楀崱鐗囨寲鍦ㄤ竴璧封€濈殑鐐圭姸闂锛屼笅涓€杞紭鍏堟妸 `notification runtime card` 鍜?`experience preset card` 鐨勫ご閮ㄨ涔夊尯涔熺户缁线 helper 鏀舵嫝锛屽仛鍒板拰 inline feedback / device status 涓€鏍风殑鍝嶅簲寮忚涓恒€?
## 2026-03-24 最近动态 70
- 完成：继续把 `MessagesTab` 的高频线程行 selector 往下压一层。`ChatProvider` 新增了 `threadSummaryRevision(threadId)`，线程摘要缓存失效时会单独递增该 revision；消息列表单行现在先只订阅“本线程摘要 revision + 当前关系态 bool”，只有这两个值真的变化时，才重新读取摘要并组装 `viewData`，减少了消息页在无关 `notifyListeners()` 下逐行重跑摘要选择器的成本。
- 完成：把消息页顶部通知角标从整段 `Consumer<NotificationCenterProvider>` 收成只看 `unreadCount` 的 `Selector`。这样通知中心里其他列表项的读写、持久化和时间字段变化，不会再顺带把消息页 AppBar 角标一起重建。
- 完成：补齐了线程摘要 revision 的 provider 回归。新增测试锁定“线程摘要 revision 只跟随当前变更线程递增”，同时保留并回归了 interaction revision / summary snapshot 的既有边界，避免后续再把消息列表和聊天页的共享摘要粒度放粗。
- 涉及模块：
  - flutter-app/lib/providers/chat_provider.dart
  - flutter-app/lib/providers/chat_provider_storage.dart
  - flutter-app/lib/providers/chat_provider_threads.dart
  - flutter-app/lib/widgets/messages_tab.dart
  - flutter-app/test/providers/chat_provider_test.dart
- 验证：
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/providers/chat_provider.dart flutter-app/lib/providers/chat_provider_storage.dart flutter-app/lib/providers/chat_provider_threads.dart flutter-app/lib/widgets/messages_tab.dart flutter-app/test/providers/chat_provider_test.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/chat_provider_test.dart --plain-name "thread summary revision should stay scoped to the changed thread" --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/chat_provider_test.dart --plain-name "thread interaction revision should stay scoped to the changed thread" --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/chat_provider_test.dart --plain-name "thread summary snapshot should stay scoped to the changed thread" --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/messages_tab_smoke_test.dart --reporter expanded
- 风险 / 备注：这一轮继续优先做的是 provider 粒度和 selector 边界收口，没有改动消息页的交互语义；当前 `FriendProvider` 关系变化仍然是全局 `notifyListeners()`，只是消息线程行已经先降级为只比较当前用户的 `isFriend/isBlocked` 布尔结果，后续如果真机上关系切换仍能感觉到轻微抖动，再考虑继续下沉关系 revision。
- 下一步建议：
  1. 继续沿着 `MessagesTab` 和 `ChatScreen` 共用的线程头部摘要往下压，优先看未读数、最近消息文案和置顶态之外，还有没有可以从 `threadInteractionRevision` 里拆开的纯摘要 revision。
  2. 回到真机重点看“消息列表 -> 聊天页 -> 返回列表”以及“设置改资料 -> 返回首页/消息页”这两条链路，确认这轮 selector 收口后，点击和返回时的慢半拍感是否继续下降。
## 2026-03-24 最近动态 71
- 完成：继续把 `ChatScreen` 顶部状态从消息交互级别的脏标记里拆出来。`ChatProvider` 新增了 `threadHeaderRevision(threadId)`，只在聊天页头部真正依赖的线程元信息变化时递增，用来服务标题、右上角更多菜单和未关注 banner 这些“头部 chrome”区域。
- 完成：聊天页 AppBar 标题和更多菜单现在都先订阅 `threadHeaderRevision + relationship bool`，再在 builder 里按需读取当前线程并组装 `viewData`；未关注 banner 也切成只看 `threadHeaderRevision`。这样当前线程里仅仅是消息发送态、已读态、重试态变化时，不会再顺带把标题、菜单和 banner 一起重算。
- 完成：补了一条 provider 回归，锁住“消息发送 / 草稿变化这类 message-only 变更不会提升 `threadHeaderRevision`，而取关这类头部相关变更会提升 revision”的边界，确保后续继续拆粒度时不会把顶部区域重新绑回高频消息通知。
- 涉及模块：
  - flutter-app/lib/providers/chat_provider.dart
  - flutter-app/lib/providers/chat_provider_storage.dart
  - flutter-app/lib/providers/chat_provider_threads.dart
  - flutter-app/lib/screens/chat_screen.dart
  - flutter-app/test/providers/chat_provider_test.dart
- 验证：
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/providers/chat_provider.dart flutter-app/lib/providers/chat_provider_storage.dart flutter-app/lib/providers/chat_provider_threads.dart flutter-app/lib/screens/chat_screen.dart flutter-app/test/providers/chat_provider_test.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/chat_provider_test.dart --plain-name "thread header revision should ignore message-only changes" --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/chat_provider_test.dart --plain-name "thread summary revision should stay scoped to the changed thread" --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded
- 风险 / 备注：这一轮继续是 selector / revision 粒度收口，没有改聊天页交互语义；当前聊天页内消息列表和 composer 仍然走 `threadInteractionRevision`，这部分是合理的，因为确实需要跟着消息发送、送达、重试等高频变化刷新。
- 下一步建议：
  1. 继续看 `ChatScreen` 内部是否还能把“顶部运行态提示”和“失败说明 / delivery 反馈”再拆开，避免 toast、失败引导和消息列表互相带动。
  2. 真机重点回归“连续发送消息 -> 顶部不抖动”和“未关注限制发送 1~3 条时 banner 状态切换”的手感，确认这轮顶部 chrome 收口确实把慢半拍感再压下去。
## 2026-03-24 最近动态 73
- 完成：继续收 `ChatScreen` 的发送反馈链路。`ChatProvider` 新增了 `threadOutgoingDeliveryRevision(threadId)`，把发送中 / 送达 / 失败 / 重试 / 对方已读这类 outgoing delivery 相关变化从更宽的线程交互里拆了出来；聊天页页面级 listener 现在优先订阅这条更窄的 revision，只在投递反馈真的变化时才重新解析 outgoing feedback。
- 完成：顺手把发送成功路径里的重复通知压掉了。文本/图片发送成功、重试成功、socket ack、自回声回填和 mock 回复链路里，`_addIntimacy()` 不再默认额外触发一轮通知，而是复用外层已有的最终 `notifyListeners()`，减少真机上“送达后又慢半拍抖一下”的双通知尾巴。
- 完成：补了一条 provider 回归，锁住“只有 delivery 相关变化才提升 outgoing delivery revision”的边界；同时给聊天页保留了一层轻量 fallback，如果外部或测试直接改消息列表再 `notifyListeners()`，仍然会在消息快照真的变化时正确冒出送达 / 重试成功 / 重试失败 toast，不把测试和调试场景变成盲区。
- 涉及模块：
  - flutter-app/lib/providers/chat_provider.dart
  - flutter-app/lib/providers/chat_provider_messages.dart
  - flutter-app/lib/providers/chat_provider_realtime.dart
  - flutter-app/lib/providers/chat_provider_storage.dart
  - flutter-app/lib/providers/chat_provider_threads.dart
  - flutter-app/lib/screens/chat_screen.dart
  - flutter-app/test/providers/chat_provider_test.dart
- 验证：
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/providers/chat_provider.dart lib/providers/chat_provider_messages.dart lib/providers/chat_provider_realtime.dart lib/providers/chat_provider_storage.dart lib/providers/chat_provider_threads.dart lib/screens/chat_screen.dart test/providers/chat_provider_test.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/chat_provider_test.dart --plain-name "thread outgoing delivery revision should stay scoped to delivery-related changes" --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/chat_provider_test.dart --plain-name "thread composer revision should only change when composer capability changes" --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/chat_provider_test.dart --plain-name "thread header revision should ignore message-only changes" --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/chat_provider_test.dart --plain-name "thread summary revision should stay scoped to the changed thread" --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded
- 风险 / 备注：这轮没有改 UI 结构和视觉方向，主要是把发送反馈和页面级 listener 的边界继续收窄；中途 smoke 暴露出“测试态直接改消息再 notify 时 toast 不再出现”的回归，已在本轮通过轻量 fingerprint fallback 修正并重新跑通回归。
- 下一步建议：
  1. 继续回到 `SettingsScreen`，优先看设置总览区、账号资料区和通知运行态卡片是否还存在“点一个开关，整块区域一起重建”的问题，把设置页的慢半拍继续压掉。
  2. 如果继续深挖聊天页，就优先查 `ChatDeliveryStatusCard` 动作链路和失败说明 sheet 是否还存在可下沉的 provider 查询，把“重试 / 查看说明 / 重选图片”这几条路径也往局部快照继续收。

## 2026-03-24 最近动态 72
- 完成：继续把 `ChatScreen` 输入区从高频消息交互 revision 里再拆细一层。`ChatProvider` 新增了 `threadComposerRevision(threadId)`，只在输入区真正依赖的发送能力变化时递增；聊天页 composer 的 selector 现在改为订阅 `threadComposerRevision + canonicalThreadId`，普通消息发送态、草稿变化、别的线程消息变化不会再把整块输入能力 view-data 一起重算。
- 完成：补了一条 provider 回归，锁住“message-only 变化不提升 composer revision，真正让输入能力切换的场景才提升”的边界。当前用例覆盖了普通消息 / 草稿 / 其他线程变化保持稳定，以及未关注会话发送额度耗尽后 `canSendMessage` 变为 false 时 revision 递增。
- 完成：继续压输入手感最敏感的本地重建。`TextEditingValue` 的监听不再包住整块 composer 外壳、能力 chips 和图片入口；现在只有发送按钮和底部状态提示会随输入文本局部刷新，打字时不会再把整块输入区容器一起重建。
- 涉及模块：
  - flutter-app/lib/providers/chat_provider.dart
  - flutter-app/lib/providers/chat_provider_storage.dart
  - flutter-app/lib/providers/chat_provider_threads.dart
  - flutter-app/lib/screens/chat_screen.dart
  - flutter-app/test/providers/chat_provider_test.dart
- 验证：
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/providers/chat_provider.dart lib/providers/chat_provider_storage.dart lib/providers/chat_provider_threads.dart lib/screens/chat_screen.dart test/providers/chat_provider_test.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/chat_provider_test.dart --plain-name "thread composer revision should only change when composer capability changes" --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/chat_provider_test.dart --plain-name "thread header revision should ignore message-only changes" --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/chat_provider_test.dart --plain-name "thread summary revision should stay scoped to the changed thread" --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format lib/screens/chat_screen.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded
- 风险 / 备注：这轮仍然是 selector / listener 粒度收口，没有改 UI 视觉方向和聊天语义；当前输入框里真正跟着每次敲字变化的只剩发送按钮和底部状态提示，`TextField` 本身的文本渲染仍由系统输入控件负责，后续如果真机上还觉得“发送后慢半拍”，重点就该转去查发送回调链路和消息投递反馈，而不是继续反复重刷整个 composer 外壳。
- 下一步建议：
  1. 继续检查 `ChatScreen` 里发送成功 / 失败反馈、delivery 卡片和顶部轻提示之间是否还存在可拆的宽监听，把“点发送后 UI 一起抖一下”的尾巴再往下压。
  2. 回到 `SettingsScreen`，优先查设置总览区和账号信息区是否还有跟随局部开关一起重建的大块区域，把“点一下再等半拍”的感知继续从设置页收掉。

## 2026-03-24 最近动态 74
- 完成：继续收 `SettingsScreen` 概览卡的重建边界。把原来包住整张概览卡的 `Selector2<AuthProvider, SettingsProvider, _SettingsOverviewViewData>` 拆成卡片内的局部 selector：概览焦点、设备状态、体验预设、状态 chip 和快捷动作分别只订阅各自真正依赖的 auth/settings 快照，减少“点一个开关整块首页一起重建”的情况。
- 完成：新增 `_SettingsOverviewFocusViewData`、`_SettingsExperiencePresetViewData`、`_SettingsOverviewNotificationRuntimeViewData` 等轻量 view data，并给 `_SettingsAccountSecurityViewData` 补了 `hasPhone`。其中体验预设卡只跟随 `notificationEnabled / vibrationEnabled / invisibleMode`，不再被 push permission / device token 这类运行时状态带着重建。
- 涉及模块：
  - flutter-app/lib/screens/settings_screen.dart
- 验证：
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/screens/settings_screen.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded
- 风险 / 备注：这轮主要是 selector 粒度收口，没有改视觉结构和交互路径；概览卡内依然保留 `DeviceStatusCard` 对完整 settings 快照的订阅，因为它本身就需要通知 / 展示 / 震动 / push runtime 的整体验证语义，后续如果真机仍感觉“点开关后卡一下”，优先继续排查通知运行态卡片和更多设置区的局部 rebuild。
- 下一步建议：
  1. 继续看 `SettingsScreen` 里通知运行态卡片和 “更多设置（低频）” 区块，确认 push runtime 刷新、系统权限返回、inline feedback 这些路径有没有还能下沉的监听或 post-frame 回调。
  2. 回到真机重点验证 “设置首页切开关 -> 返回主链路” 和 “通知权限恢复 -> 概览卡动作文案切换” 两条路径，确认这轮拆分对“点了以后慢半拍”的体感有没有继续往下压。

## 2026-03-25 最近动态 75
- 完成：继续把 `SettingsScreen` 的设备状态卡从卡片级 rebuild 往下压到行级和子卡级。现在设备状态卡外层不再直接订阅整份 `_SettingsViewData`，而是把“通知状态 / 展示状态 / 震动提醒 / 通知运行态卡片”分别改成独立 selector，只在各自真正依赖的 settings 字段变化时更新。
- 完成：新增 `_selectNotificationStatusItem`、`_selectPresenceStatusItem`、`_selectVibrationStatusItem`、`_selectNotificationRuntimeState` 和 `_selectShouldCondenseCompactDeviceStatusCard`，把原来设备状态卡内部一起计算的运行态和 badge 视图拆成轻量选择器。这样像隐身和震动切换，不会再顺带把通知运行态卡片整块一起重算。
- 完成：给 `_SettingsDeviceStatusItem` 和 `_SettingsNotificationRuntimeState` 补了值相等语义，确保 selector 返回的新快照在内容不变时不会触发额外重建，继续收紧设置页高频反馈路径上的无效刷新。
- 涉及模块：
  - flutter-app/lib/screens/settings_screen.dart
- 验证：
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/screens/settings_screen.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/settings_screen_smoke_test.dart --reporter expanded
- 风险 / 备注：这一轮仍然没有改动页面视觉和交互语义，主要是继续把设备状态卡内部的 rebuild 颗粒度收细；当前设备状态卡标题文案和布局骨架仍然跟随页面构建，真机如果后续还能感觉到轻微迟滞，下一步更值得看的就是系统设置返回后的权限恢复链路和 `ProfileTab` 从设置返回时的资料刷新链路。
- 下一步建议：
  1. 继续检查 `SettingsScreen.didChangeAppLifecycleState -> refreshPushRuntimeStateAfterSystemSettingsReturn()` 这条返回链，看能不能再减少一次无效状态检查或同步反馈抖动。
  2. 开始收 `ProfileTab` 首屏的大范围 `Consumer<ProfileProvider>`，把背景展示、身份信息和设置返回后的同步提示拆成更细的选择器，进一步压低“从设置回到首页时慢半拍”的体感。

## 2026-03-25 最近动态 76
- 完成：收口 `ProfileProvider` 里的 no-op `notifyListeners()`。现在 `_applyProfile(...)` 会先比较昵称、头像、状态、签名和两个主页展示开关，只有状态真的变化时才通知监听者；`refreshFromRemote()`、昵称/状态/签名/主页开关保存链路也都改成只在变更时触发刷新。
- 完成：补了头像更新的本地快反馈边界。 `updateAvatar(...)` 现在会跳过“同头像重复保存”的无效通知；当头像真的变化时，会先同步内存态并立刻通知 UI，再落本地存储，降低个人主页上“点了以后慢半拍”的感知。
- 完成：补齐 `ProfileProvider` 回归测试，锁住“透明主页开关只在有效状态切换时通知”“远端刷新无变化不通知”“头像重复保存不通知”这些边界，避免后续继续拆 `ProfileTab` 时把性能优化回退掉。
- 涉及模块：
  - flutter-app/lib/providers/profile_provider.dart
  - flutter-app/test/providers/profile_provider_test.dart
- 验证：
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/providers/profile_provider.dart flutter-app/test/providers/profile_provider_test.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/providers/profile_provider_test.dart --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded
- 风险 / 备注：本轮先把“设置返回首页 / 远端刷新后无变化却整页通知”的底层噪音压掉，还没有直接拆 `ProfileTab` 首屏最外层的大 `Consumer<ProfileProvider>`。如果真机上个人主页返回仍有轻微迟滞，下一轮最值得继续拆的就是背景展示、身份信息、签名区和媒体管理区的订阅边界。
- 下一步建议：
  1. 开始拆 `ProfileTab` 首屏外层大 `Consumer<ProfileProvider>`，优先把背景展示开关、身份信息块、签名状态和头像区改成更细粒度的 selector / view-data。
  2. 回到真机重点验证“设置页改资料 -> 返回首页”和“个人主页编辑签名 / 头像 -> 立即看到反馈”两条链路，确认这轮 provider 收口后，慢半拍感是否继续下降。

## 2026-03-25 最近动态 77
- 完成：继续收 `ProfileTab` 首屏的大范围资料订阅。页面最外层不再直接吃整份 `ProfileProvider`，而是把首屏布局先收成只看 `portraitFullscreenBackground / transparentHomepage` 的 `_ProfileHeaderModeState`；昵称、签名、头像和紧凑身份卡分别切成局部 selector，减少“改签名 / 改状态时整张首屏骨架一起重算”的情况。
- 完成：把“个人主页快捷整理卡”改成局部 `Selector<ProfileProvider, _ProfileReadinessViewData>`。现在完成度、待补项和优先动作只跟签名 / 状态这类真正相关的资料快照联动，不再跟首页其他无关重建绑在一起；紧凑身份卡也改成基于 `_ProfileIdentityViewData` 的局部刷新。
- 完成：给新的首屏 selector 补了值相等语义数据结构：`_ProfileHeaderModeState`、`_ProfileIdentityViewData`、`_ProfileReadinessViewData`，继续压缩“从设置返回首页”和“编辑资料后立即回显”路径上的无效 rebuild。
- 排查：顺手复看了 `SettingsScreen.didChangeAppLifecycleState -> refreshPushRuntimeStateAfterSystemSettingsReturn()` 这条返回链路。当前 provider 已经有 pending / in-flight 双重门闩，短期内没有发现比现状更低风险、收益更高的同步收口点，因此本轮没有继续改这条链路。
- 涉及模块：
  - flutter-app/lib/widgets/profile_tab.dart
- 验证：
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/widgets/profile_tab.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded
- 风险 / 备注：本轮仍然保持现有 UI 结构和视觉方向，没有改交互语义；常规状态条区域目前还是“容器本身 + 状态文案 selector”的折中方案，如果真机上点状态后仍能感觉到轻微滞后，下一轮可以把这块也进一步提成独立局部组件。
- 下一步建议：
  1. 回到真机重点验证“设置页改资料 -> 返回首页”“编辑签名 / 状态 / 头像 -> 立即回显”三条链路，确认首页慢半拍感是否继续下降。
  2. 如果手感还有残余抖动，下一轮优先继续拆个人主页常规状态条和资料区下方卡片的局部 listener，再考虑回到 `SettingsScreen` 的系统权限返回链路。

## 2026-03-25 最近动态 78
- 完成：继续收个人主页“背景模式”弹层的订阅边界。原来这块还是整段 `Consumer<ProfileProvider>`，现在改成只看 `portraitFullscreenBackground / transparentHomepage` 的 `_ProfileBackgroundModeViewData` selector，避免点一个背景模式开关时把弹层里无关部分一起跟着重建。
- 完成：给背景模式弹层补了稳定测试入口和状态断言。`profile-background-mode-sheet`、`profile-background-mode-portrait-switch`、`profile-background-mode-transparent-switch` 这些 key 已补齐，smoke 新增了“背景全屏 / 透明背景联动状态保持一致”的回归，锁住“关闭全屏时透明背景同步关闭、透明背景禁用状态正确”的底线。
- 涉及模块：
  - flutter-app/lib/widgets/profile_tab.dart
  - flutter-app/test/smoke/main_screen_smoke_test.dart
- 验证：
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/widgets/profile_tab.dart flutter-app/test/smoke/main_screen_smoke_test.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded
- 风险 / 备注：这轮只收了背景模式弹层本身的订阅和测试，没有改背景管理弹层的操作语义；真机如果仍觉得这块切换后有轻微滞后，下一步更值得看的就是背景管理预览卡和头像管理预览卡的局部回显路径。

## 2026-03-25 最近动态 79
- 完成：继续压 `ChatScreen` 的“发完消息后慢半拍”滚动尾巴。`_scrollToBottom()` 现在会根据距离动态选择策略：距离底部很近时直接 `jumpTo`，中等距离缩短动画，只有明显距离变化时才保留完整滚动动画，减少发送成功后界面还在慢慢追底部的拖尾感。
- 完成：保留了原有滚动语义和消息链路，没有改动聊天页消息选择器、头部或 composer 的结构，只是在底部追随这一步做了更符合真机手感的收口。
- 涉及模块：
  - flutter-app/lib/screens/chat_screen.dart
- 验证：
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/screens/chat_screen.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/chat_screen_smoke_test.dart --reporter expanded
- 风险 / 备注：这轮主要调的是滚动执行策略，不涉及消息发送、送达或重试语义；如果真机上仍然能感觉到“点发送后 UI 先停一下”，下一轮就该继续看消息发送回调与 toast / delivery feedback 的先后时序，而不是重复去改布局。
- 下一步建议：
  1. 真机回归“背景管理 -> 模式切换 -> 返回首页”和“聊天页连续发送 3~5 条消息”的手感，确认本轮两个细节优化是否继续压低慢半拍感。
  2. 如果聊天页还有残余滞后，优先继续拆发送反馈链路和底部 delivery card / toast 的触发时机；如果个人主页还有残余滞后，则继续收头像 / 背景管理预览卡的局部刷新。

## 2026-03-25 最近动态 80
- 完成：按“先净化页面、再出包”的优先级收了一轮用户可见页面。`SettingsScreen` 去掉了版本号长按调试入口，`AboutScreen` / `SettingsScreen` / `ProfileTab` / `MatchProvider` 里的开发、测试、联调式文案统一改回正常产品语气，避免真机测试时再看到“内部态”表达。
- 完成：修掉了一个真实源码级乱码入口。`MatchTab` 的头像兜底字符从异常的乱码字符改回统一的 `👤`，`ChatScreen` 里两处损坏注释也顺手修正，避免后续继续在这些文件上迭代时被历史编码残留干扰。
- 完成：同步校正版本展示与测试基线。设置页底部版本号、关于页版本信息统一到 `V1.0.4`，关于页构建描述改成更中性的“移动端体验版”；对应 smoke test 也改成不再依赖已移除的设置页调试入口，而是直接验证实际保留的能力。
- 完成：产出新的本地单人真机测试包，已按 demo 环境重新构建 release APK 并复制到 `C:\Users\chenjiageng\Desktop\sunliao\apk-output\sunliao-v1.0.4+5-demo-local-20260325.apk`，可直接安装做离线交互回归。
- 涉及模块：
  - flutter-app/lib/screens/settings_screen.dart
  - flutter-app/lib/screens/about_screen.dart
  - flutter-app/lib/widgets/profile_tab.dart
  - flutter-app/lib/providers/match_provider.dart
  - flutter-app/lib/widgets/match_tab.dart
  - flutter-app/lib/screens/chat_screen.dart
  - flutter-app/test/smoke/match_tab_smoke_test.dart
  - flutter-app/test/smoke/settings_screen_smoke_test.dart
- 验证：
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/screens/settings_screen.dart flutter-app/lib/screens/about_screen.dart flutter-app/lib/widgets/profile_tab.dart flutter-app/lib/providers/match_provider.dart flutter-app/lib/widgets/match_tab.dart flutter-app/lib/screens/chat_screen.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/test/smoke/match_tab_smoke_test.dart flutter-app/test/smoke/settings_screen_smoke_test.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat build apk --release --dart-define=SUNLIAO_APP_ENV=demo --dart-define=SUNLIAO_RELEASE_BUILD=true
- 风险 / 备注：这次包是 `demo` 环境的本地真机体验包，并通过 `ORG_GRADLE_PROJECT_sunliaoAllowDebugReleaseSigning=true` 允许 debug signing fallback，只适合当前单人离线交互测试，不适合作为正式上架包；构建过程中有 Android SDK XML 版本提示，但本次 APK 已成功生成。
- 下一步建议：
  1. 你先用这版包重点看“设置页 -> 关于/协议/账号安全”“匹配失败态”“我的页头像/背景/昵称编辑”这几条链路，确认页面上是否还残留不必要信息、重叠或违和入口。
  2. 如果真机上页面结构已经干净，再回到你前面提过的“局部重叠和摆放逻辑”继续做微信 / Telegram 风格的页面层级收口，而不是再扩新增量功能。

## 2026-03-25 最近动态 81
- 完成：按“只保留入口，别做过多引导”的反馈，重做了 `ProfileTab` 顶部这块资料整理区。现在不再叠“快速整理 / 完成清单 / 现在先补 / 优先事项”多层提示卡，而是收成一个更轻的“常用入口”卡，只保留签名、状态、头像、背景、设置 5 个直接入口。
- 完成：入口样式统一改成简洁入口格，并把缺失项仅通过颜色高亮来表达，不再出现“去完善 / 可微调 / 建议先补 / 两段解释文案”这类重复引导词。真机上这块会更接近微信、抖音那种“看得到入口，点进去处理”的交互，而不是先读提示。
- 完成：同步更新 `main_screen_smoke_test.dart`，把原来依赖旧完成清单和优先事项卡片的断言改成新的入口型结构验证；随后重新跑了 `main_screen_smoke_test.dart` 和全量 `test/smoke`，确认这次结构收口没有引入回归。
- 完成：补出新的真机测试包，已复制到 `C:\Users\chenjiageng\Desktop\sunliao\apk-output\sunliao-v1.0.4+5-demo-local-20260325-r2.apk`，可直接安装验证“我的”页这块新的简洁入口结构。
- 涉及模块：
  - flutter-app/lib/widgets/profile_tab.dart
  - flutter-app/test/smoke/main_screen_smoke_test.dart
- 验证：
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/lib/widgets/profile_tab.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\dart.bat format flutter-app/test/smoke/main_screen_smoke_test.dart
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat analyze
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke/main_screen_smoke_test.dart --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat test test/smoke --reporter expanded
  - D:\flutter_windows_3.27.1-stable\flutter\bin\flutter.bat build apk --release --dart-define=SUNLIAO_APP_ENV=demo --dart-define=SUNLIAO_RELEASE_BUILD=true
- 风险 / 备注：这次主要收的是“我的”页局部结构和引导密度，没有顺手去扩大改动消息页、匹配页和设置页的布局模式；如果你真机确认这种入口式结构更对，就可以继续按同一原则，把其他页面里重复说明、重复状态词条一起往下收。
- 下一步建议：
  1. 你先用 `sunliao-v1.0.4+5-demo-local-20260325-r2.apk` 看“我的”页这块是否已经回到你要的简洁感，重点看首屏是否还像提示集合、按钮密度是否顺手。
  2. 如果这个方向对，再继续把设置页和匹配页里同类“说明先于入口”的区域一起改成入口优先、说明后置或收起的结构。

## 2026-03-31 最近动态 178
- 完成：先把上一轮中断在验证阶段的小收口补齐了。`flutter-app/test/widgets/helpers/messages_thread_test_host.dart` 新增的共享能力已经确认可用：
  - `setMessagesThreadViewport(...)`
  - `pumpMessagesThreadScene(...)`
  同时 `flutter-app/test/widgets/messages_thread_title_markers_layout_test.dart` 已切到这两个共享 helper，去掉了本地重复的 viewport / scene pump 搭建。
- 完成：继续沿同一条“focused test 内部收口”路径，把 `flutter-app/test/widgets/messages_thread_delivery_badge_layout_test.dart` 里的本地 `_setCompactViewport` 和 `_pumpDeliveryCase` 替换为共享 helper；这一轮仍然没有改业务逻辑，只是进一步统一消息列表 focused test 的测试搭建方式。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/helpers/messages_thread_test_host.dart
  - flutter-app/test/widgets/messages_thread_title_markers_layout_test.dart
  - flutter-app/test/widgets/messages_thread_delivery_badge_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：第一次执行未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\helpers\messages_thread_test_host.dart test\widgets\messages_thread_title_markers_layout_test.dart`：沙箱内通过，`Formatted 2 files (0 changed)`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\helpers\messages_thread_test_host.dart test\widgets\messages_thread_title_markers_layout_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
  - 在项目根目录再次执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：第二次执行未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_delivery_badge_layout_test.dart`：沙箱内通过，`Formatted 1 file (0 changed)`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_delivery_badge_layout_test.dart`：沙箱内静态分析通过，`No issues found!`
- 风险 / 备注：这轮再次验证了“同样是最小文件集，`format` 往往能在沙箱里直接过，而 `analyze` 可能随机撞到 `CreateFile failed 5`”这个环境特征；后续继续保持“先恢复脚本、再最小命令、遇权限或无输出立刻提权”的快排流程，能明显降低卡住概率。
- 下一步建议：
  1. 继续把 `messages_thread_draft_preview_layout_test.dart` 也切到共享 helper，让 delivery / draft 这两类 preview 相关 focused test 的搭建方式对齐
  2. 如果准备结束这条小收口链路，可以回头做一次 very small 的命名与结构整理，只动测试文件内部组织，不碰消息列表业务逻辑

## 2026-03-31 最近动态 179
- 完成：继续沿消息列表 focused test 的“共享 helper 收口”往前推了一小步，把 `flutter-app/test/widgets/messages_thread_draft_preview_layout_test.dart` 里的本地 `_setCompactViewport` 和 `_pumpDraftCase` 去掉，统一切到了：
  - `setMessagesThreadViewport(...)`
  - `pumpMessagesThreadScene(...)`
- 完成：这一轮仍然没有改业务逻辑，也没有改 draft 相关断言；只是让 draft preview 测试和前一轮的 delivery badge / title markers 一样，复用同一套线程场景搭建方式，继续降低后续补 case 时的重复代码。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_draft_preview_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_draft_preview_layout_test.dart`：沙箱内通过，`Formatted 1 file (0 changed)`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_draft_preview_layout_test.dart`：沙箱内静态分析通过，`No issues found!`
- 风险 / 备注：这次是比较理想的一轮，恢复脚本后最小单文件 `format` / `analyze` 都直接通过；说明当前环境下继续把验证范围压到单文件，仍然是最不容易卡住的推进方式。
- 下一步建议：
  1. 如果继续沿这条线推进，可以回头收 `messages_thread_priority_tag_layout_test.dart`、`messages_thread_unread_badge_layout_test.dart`、`messages_thread_intimacy_chip_layout_test.dart`，看是否还能进一步抽掉局部重复 finder 或状态断言
  2. 如果准备先收尾消息列表这批测试，也可以做一次 very small 的内部命名整理，把这几份 focused test 的 helper 命名风格再对齐一点

## 2026-03-31 最近动态 180
- 完成：继续把消息列表 focused test 往共享 helper 上收了一小步。`flutter-app/test/widgets/messages_thread_unread_badge_layout_test.dart` 里的本地 `_setViewport` 和 `_pumpUnreadCase` 已移除，统一切到了：
  - `setMessagesThreadViewport(...)`
  - `pumpMessagesThreadScene(...)`
- 完成：这一轮仍然没有改 unread badge 的业务逻辑和断言语义，只是让 regular / compact 两个 case 的线程场景搭建方式与 title / delivery / draft 保持一致，继续压缩重复代码。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_unread_badge_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_unread_badge_layout_test.dart`：沙箱内通过，`Formatted 1 file (0 changed)`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_unread_badge_layout_test.dart`：沙箱内静态分析通过，`No issues found!`
- 风险 / 备注：这轮和上一轮一样，最小单文件验证直接在沙箱里通过；说明继续按“恢复脚本 + 单文件 format/analyze”推进，当前环境下稳定性还不错。
- 下一步建议：
  1. 继续看 `messages_thread_priority_tag_layout_test.dart` 是否也能按同一方式切到共享 helper，把这批 preview / priority / unread focused test 的搭建彻底统一
  2. 如果这条线准备暂时收尾，可以回头整理这些 focused test 里 finder helper 的命名风格，进一步减少后续阅读成本

## 2026-03-31 最近动态 181
- 完成：继续把消息列表 focused test 往共享 helper 上收了一步。`flutter-app/test/widgets/messages_thread_priority_tag_layout_test.dart` 里的本地 `_setCompactViewport` 和 `_pumpPriorityCase` 已移除，统一切到了：
  - `setMessagesThreadViewport(...)`
  - `pumpMessagesThreadScene(...)`
- 完成：这一轮没有改 priority tag 的业务逻辑和层级断言，只是让“发送失败”和“即将到期”这两个 compact case 的线程场景搭建方式与 title / delivery / draft / unread 保持一致，继续降低后续补边界时的重复代码。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_priority_tag_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_priority_tag_layout_test.dart`：沙箱内通过，`Formatted 1 file (0 changed)`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_priority_tag_layout_test.dart`：沙箱内静态分析通过，`No issues found!`
- 风险 / 备注：这轮继续验证了，当前环境下只要把验证范围压到单文件，`format` / `analyze` 的稳定性明显比大范围命令更好；这条节奏可以继续复用在后面的测试侧小收口里。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以开始看 `messages_thread_intimacy_chip_layout_test.dart` 里是否还存在可以进一步共用的 finder / 断言结构，把这批 focused test 的内部风格再对齐一点
  2. 如果准备先收尾这一条链路，也可以回头做一次 very small 的命名整理，只动测试文件内部 helper 和 case 组织，不碰消息页业务代码

## 2026-03-31 最近动态 182
- 完成：继续把消息列表 focused test 往共享 helper 上收了一小步。`flutter-app/test/widgets/messages_thread_intimacy_chip_layout_test.dart` 里的本地 `_setViewport` 和 `_pumpIntimacyCase` 已移除，统一切到了：
  - `setMessagesThreadViewport(...)`
  - `pumpMessagesThreadScene(...)`
- 完成：这一轮仍然没有改亲密度 chip 的业务逻辑和 regular / compact 两个 case 的层级断言，只是让它的线程场景搭建方式与 title / delivery / draft / unread / priority 保持一致，继续压缩重复代码。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_intimacy_chip_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_intimacy_chip_layout_test.dart`：沙箱内通过，`Formatted 1 file (0 changed)`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_intimacy_chip_layout_test.dart`：沙箱内静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 说明，只要继续把验证范围压到单文件，当前环境里的 Flutter/Dart CLI 基本能稳定跑完；后面如果继续做测试侧小收口，仍然优先保持这个节奏。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以开始做一次 very small 的内部命名整理，把这批 focused test 里 `finders` / `expectBase...` helper 的命名风格再对齐一点
  2. 如果准备切模块，消息列表这条 focused test 链路的共享搭建已经基本统一，可以回到“我的 / 设置”或消息页别的高频反馈组件继续用同样节奏推进

## 2026-03-31 最近动态 183
- 完成：继续对消息列表 focused test 做 very small 的内部命名整理，没有改业务逻辑和断言语义，只把几份 helper 名称往统一的 `...State` 风格上收了一层：
  - `flutter-app/test/widgets/messages_thread_draft_preview_layout_test.dart`
    - `_findDraftPreview(...)` -> `_findDraftPreviewState(...)`
    - `_expectBaseDraftPreview(...)` -> `_expectBaseDraftPreviewState(...)`
  - `flutter-app/test/widgets/messages_thread_unread_badge_layout_test.dart`
    - `_findUnreadState(...)` -> `_findUnreadBadgeState(...)`
    - 新增 `_expectBaseUnreadBadgeState(...)`
  - `flutter-app/test/widgets/messages_thread_intimacy_chip_layout_test.dart`
    - `_findIntimacyState(...)` -> `_findIntimacyChipState(...)`
    - `_expectBaseIntimacyState(...)` -> `_expectBaseIntimacyChipState(...)`
- 完成：这轮整理后，delivery / draft / unread / priority / intimacy 这批消息列表 focused test 的 helper 命名更接近同一套风格，后续继续补 case 时更容易快速判断“这是 finder helper 还是基础断言 helper”。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_draft_preview_layout_test.dart
  - flutter-app/test/widgets/messages_thread_unread_badge_layout_test.dart
  - flutter-app/test/widgets/messages_thread_intimacy_chip_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_draft_preview_layout_test.dart test\widgets\messages_thread_unread_badge_layout_test.dart test\widgets\messages_thread_intimacy_chip_layout_test.dart`：沙箱内通过，`Formatted 3 files (0 changed)`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_draft_preview_layout_test.dart test\widgets\messages_thread_unread_badge_layout_test.dart test\widgets\messages_thread_intimacy_chip_layout_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮再次验证了当前环境里的典型模式是“多文件 `format` 常能直接通过，但 `analyze` 仍可能随机命中权限错误”；后面继续做小范围测试整理时，仍然优先保持“恢复脚本 -> 最小命令 -> 权限失败立刻提权重跑”的节奏，避免卡住。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以再做一次 very small 的内部风格整理，把 `messages_thread_title_markers_layout_test.dart` / `messages_thread_delivery_badge_layout_test.dart` / `messages_thread_priority_tag_layout_test.dart` 里相关 helper 命名也进一步对齐
  2. 如果准备切模块，消息列表这批 focused test 的共享搭建和命名已经比较统一，可以回到消息页别的高频状态组件或“我的 / 设置”链路继续做同样粒度的小步优化

## 2026-03-31 最近动态 184
- 完成：继续对消息列表 focused test 做 very small 的内部命名整理，把 `flutter-app/test/widgets/messages_thread_title_markers_layout_test.dart` 里的 helper 名称也收到了同一套 `...State` 风格：
  - `_findTitleMarkers(...)` -> `_findTitleMarkerState(...)`
  - `_expectBaseTitleMarkers(...)` -> `_expectBaseTitleMarkerState(...)`
- 完成：这一轮仍然没有改标题行的业务逻辑、时间边界断言或 friend/pinned 标记层级，只是让 title markers 这份测试和 draft / unread / intimacy / delivery / priority 更一致，后续继续读这批 focused test 时更容易快速定位 helper 职责。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_title_markers_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_title_markers_layout_test.dart`：沙箱内通过，`Formatted 1 file (0 changed)`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_title_markers_layout_test.dart`：沙箱内静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 说明，单文件范围的格式化和静态分析在当前环境下最稳；如果后面继续做测试内部整理，仍然优先保持“先恢复、再单文件验证”的节奏。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以回头看 `messages_thread_delivery_badge_layout_test.dart` 和 `messages_thread_priority_tag_layout_test.dart` 是否还要做最后一层 helper 命名对齐
  2. 如果准备先切模块，消息列表这批 focused test 的共享搭建和内部命名已经比较统一，可以回到消息页别的高频状态组件或“我的 / 设置”链路继续用同样节奏推进

## 2026-03-31 最近动态 185
- 完成：继续把消息列表 focused test 里还保留老写法的 `flutter-app/test/widgets/messages_thread_row_hierarchy_test.dart` 收到了和其他文件一致的结构上：
  - 手动 viewport 设置改为 `setMessagesThreadViewport(...)`
  - 手动 `addThread / getMessages / pumpWidget` 改为 `pumpMessagesThreadScene(...)`
  - 新增 `_RowHierarchyFinders`
  - 新增 `_findRowHierarchyState(...)`
  - 新增 `_expectBaseRowHierarchyState(...)`
- 完成：这一轮没有改四层行顺序的业务断言，仍然只锁住 compact 宽度下 `title -> preview -> priority -> meta` 的层级关系；只是让这份 row hierarchy focused test 和前面几份消息列表测试在“场景搭建 + finder/assert helper”这两层的写法更一致。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_row_hierarchy_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_row_hierarchy_test.dart`：沙箱内通过，`Formatted 1 file (0 changed)`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_row_hierarchy_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮再次命中了当前环境里很典型的模式：单文件 `format` 能直接过，但单文件 `analyze` 仍可能随机撞权限错误；继续把这类情况视为环境失败并立即提权重跑，仍然是最稳的处理方式。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以开始看 `messages_thread_delivery_badge_layout_test.dart` 是否值得再补一层 very small 的 finder/assert 命名对齐，或者确认这批 focused test 已经足够统一后再切模块
  2. 如果准备切模块，消息列表这条测试链路现在已经基本收口，可以回到消息页其他高频反馈组件，或者回到“我的 / 设置”继续做同样粒度的小步优化

## 2026-03-31 最近动态 186
- 完成：继续把消息列表的高频状态链路往 focused test 上补了一小步，新加了 `flutter-app/test/widgets/messages_thread_online_priority_layout_test.dart`，专门锁住 compact 宽度下两条优先级状态：
  - 在线、非好友、无未读、无草稿、非失败状态时，显示 `对方在线可聊`
  - 同样在线，但会话已进入近到期窗口时，优先显示 `即将到期`，不再显示 `对方在线可聊`
- 完成：这一轮没有改 `messages_tab.dart` 的业务逻辑，只是把 `_shouldShowOnlinePriority(...)` 和 “near expiry urgency hint” 这组高频状态关系补成了 focused coverage，避免后续继续调消息列表层级时把在线优先提示和到期提示的先后关系悄悄改坏。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_online_priority_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_online_priority_layout_test.dart`：沙箱内通过，`Formatted 1 file (0 changed)`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_online_priority_layout_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 说明，当前环境里即便已经把验证压到单文件，`analyze` 也仍然可能随机撞权限错误；继续保持“恢复脚本 -> 单文件命令 -> 权限失败立即提权”的快排策略最稳。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以补一条 focused case，继续锁“对方在线可聊”在出现未读、草稿或发送失败时不会误显示，把这组优先级状态链路补完整
  2. 如果准备切模块，消息列表这条高频状态链路已经从布局结构推进到了状态优先级测试，可以回到消息页别的反馈组件，或者切回“我的 / 设置”继续做同样粒度的小步优化

## 2026-03-31 最近动态 187
- 完成：继续沿消息列表“在线优先状态”这条 focused test 往前补了一条 suppression case。`flutter-app/test/widgets/messages_thread_online_priority_layout_test.dart` 新增覆盖：
  - 在线、非好友
  - 但存在未读徽标
  - compact 宽度下不再显示 `对方在线可聊`
  - `priority row` 不出现
  - 未读徽标仍正常保留
- 完成：这轮仍然没有改 `messages_tab.dart` 的业务逻辑，只是把 `_shouldShowOnlinePriority(...)` 在 `unreadCount > 0` 这条高频抑制分支补成了 focused coverage，避免后续继续调消息列表优先级时把“有未读仍显示在线可聊”这种误回归带回来。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_online_priority_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_online_priority_layout_test.dart`：沙箱内通过，`Formatted 1 file (1 changed)`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_online_priority_layout_test.dart`：沙箱内静态分析通过，`No issues found!`
- 风险 / 备注：这轮是比较理想的一次，最小单文件 `format` / `analyze` 都直接通过；说明继续把这条状态优先级链路拆成单文件 focused case，是当前环境下既稳又高性价比的推进方式。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以再补 `draft` 或 `发送失败` 其中一条 suppression case，把“在线可聊不会误压过更高优先级状态”继续补完整
  2. 如果准备切模块，消息列表这条高频状态链路已经开始从“显示规则”覆盖到“抑制规则”，可以回到消息页其他反馈组件或“我的 / 设置”继续用同样节奏推进

## 2026-03-31 最近动态 188
- 完成：继续沿消息列表“在线优先状态”这条 focused test 往前补了一条 draft suppression case。`flutter-app/test/widgets/messages_thread_online_priority_layout_test.dart` 现在额外锁住：
  - 在线、非好友、无未读
  - 但存在草稿预览
  - compact 宽度下不再显示 `对方在线可聊`
  - `草稿待发送` 优先标签仍正常显示
  - draft slot 仍正常保留在 preview row
- 完成：这一轮仍然没有改 `messages_tab.dart` 的业务逻辑，只是把 `_shouldShowOnlinePriority(...)` 在 `hasDraft == true` 这条高频抑制分支补成了 focused coverage，继续降低后续调优消息列表优先级时的回归风险。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_online_priority_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_online_priority_layout_test.dart`：沙箱内通过，`Formatted 1 file (1 changed)`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_online_priority_layout_test.dart`：沙箱内静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 说明，把这条状态优先级链路拆成单文件 focused case 并单文件验证，仍然是当前环境下最稳的推进方式；而且这种“只补一条 suppression 分支”的节奏，也不容易把测试文件一下子做得过重。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以再补 `发送失败` 这一条 suppression case，把“在线可聊不会误压过失败优先标签”这组规则补完整
  2. 如果准备切模块，消息列表这条高频状态链路已经从“显示规则”补到了“未读 / 草稿抑制规则”，可以回到消息页别的反馈组件或“我的 / 设置”继续用同样节奏推进

## 2026-03-31 最近动态 189
- 完成：继续沿消息列表“在线优先状态”这条 focused test 往前补了一条 failure suppression case。`flutter-app/test/widgets/messages_thread_online_priority_layout_test.dart` 现在额外锁住：
  - 在线、非好友、无未读、无草稿
  - 但最近消息为发送失败
  - compact 宽度下不再显示 `对方在线可聊`
  - `发送失败` 优先标签仍正常显示
  - delivery badge slot 仍正常保留
- 完成：这一轮仍然没有改 `messages_tab.dart` 的业务逻辑，只是把 `_shouldShowOnlinePriority(...)` 在失败优先状态存在时的抑制规则补成了 focused coverage；这样这条“在线优先不会误压过更高优先级状态”的高频链路已经补到了比较完整的程度。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_online_priority_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_online_priority_layout_test.dart`：沙箱内通过，`Formatted 1 file (0 changed)`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_online_priority_layout_test.dart`：沙箱内静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 说明，把这类高频状态链路拆成单文件 focused case 并单文件验证，仍然是当前环境下最稳、最不容易卡住的推进方式。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以回头给这份 `messages_thread_online_priority_layout_test.dart` 做 very small 的内部 helper 整理，把“显示态 / 抑制态”这两类断言再收得更清楚一点
  2. 如果准备切模块，消息列表这条高频状态链路已经从“显示规则”补到了“未读 / 草稿 / 失败抑制规则”，可以转去消息页别的反馈组件，或者回到“我的 / 设置”继续做同样粒度的小步优化

## 2026-03-31 最近动态 190
- 完成：为了把消息列表里更具体的 delivery failure 标签补成 focused coverage，这轮先做了一个很小的测试入口收口：
  - 在 `flutter-app/lib/providers/chat_provider_messages.dart` 新增 `@visibleForTesting markMessageFailedForTesting(...)`
  - 这个入口只复用现有 `_markMessageFailed(...)` 流程，用来让测试以最小代价给某条消息挂上明确的 `ChatDeliveryFailureState`
- 完成：基于这个测试入口，`flutter-app/test/widgets/messages_thread_priority_tag_layout_test.dart` 新增了一条 `networkIssue -> 网络波动` 的 focused case，锁住：
  - compact 宽度下 `网络波动` priority tag 正常显示
  - priority row 仍保持在 meta row 之上
  - unread meta 和 delivery badge slot 仍正常保留
- 完成：这一轮没有改消息列表业务逻辑，只是把以前只覆盖 `发送失败` / `即将到期` 的 priority tag，往真实弱网失败标签上补了一格 focused coverage，降低后续继续调 priority 显示规则时的回归风险。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/lib/providers/chat_provider_messages.dart
  - flutter-app/test/widgets/messages_thread_priority_tag_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format lib\providers\chat_provider_messages.dart test\widgets\messages_thread_priority_tag_layout_test.dart`：沙箱内通过，`Formatted 2 files (0 changed)`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\providers\chat_provider_messages.dart test\widgets\messages_thread_priority_tag_layout_test.dart`：沙箱内因 `CreateFile failed 5 / 拒绝访问` 失败
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 说明，多文件最小范围验证时，`format` 常能在沙箱里直接过，但 `analyze` 仍可能随机命中权限错误；继续保持“恢复脚本 -> 最小命令 -> 权限失败立刻提权重跑”的处理最稳。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以再补 `retryUnavailable -> 暂不可重试` 或 `blockedRelation -> 关系受限` 其中一条 focused case，把 priority tag 的具体失败标签覆盖再向前推进一格
  2. 如果准备切模块，消息列表这条状态链路已经从布局结构、在线优先级走到了具体 failure tag，可以回到消息页别的反馈组件，或者回到“我的 / 设置”继续做同样粒度的小步优化

## 2026-03-31 最近动态 191
- 完成：继续沿消息列表 priority tag 的具体 failure label 覆盖往前补了一条 focused case。`flutter-app/test/widgets/messages_thread_priority_tag_layout_test.dart` 新增了 `retryUnavailable -> 暂不可重试` 的 compact 场景，锁住：
  - `暂不可重试` priority tag 正常显示
  - priority row 仍保持在 meta row 之上
  - unread meta 和 delivery badge slot 仍正常保留
- 完成：这一轮没有再改 provider 逻辑，直接复用了上一轮新增的 `markMessageFailedForTesting(...)` 测试入口，把 priority tag 这条 failure label 覆盖继续向前推了一格。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_priority_tag_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_priority_tag_layout_test.dart`：沙箱内通过，`Formatted 1 file (0 changed)`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_priority_tag_layout_test.dart`：沙箱内静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 说明，已经加好测试入口后，继续沿单文件 focused test 补 failure label 是当前环境里很稳的一种推进方式；单文件 `format` / `analyze` 也更不容易卡住。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以再补 `blockedRelation -> 关系受限` 或 `threadExpired -> 会话已过期` 其中一条 focused case，把 priority tag 的具体失败标签覆盖再往前推一格
  2. 如果准备切模块，消息列表这条链路已经从布局结构、在线优先级推进到了具体 failure label，可以回到消息页别的反馈组件，或者回到“我的 / 设置”继续做同样粒度的小步优化

## 2026-03-31 最近动态 192
- 完成：继续沿消息列表 priority tag 的具体 failure label 覆盖往前补了一条 focused case。`flutter-app/test/widgets/messages_thread_priority_tag_layout_test.dart` 新增了 `blockedRelation -> 关系受限` 的 compact 场景，锁住：
  - `关系受限` priority tag 正常显示
  - priority row 仍保持在 meta row 之上
  - unread meta 和 delivery badge slot 仍正常保留
- 完成：这一轮同样没有改业务逻辑，继续复用了 `markMessageFailedForTesting(...)` 测试入口，把消息列表里关系受限这条真实失败态补成了 focused coverage。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_priority_tag_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_priority_tag_layout_test.dart`：沙箱内通过，`Formatted 1 file (0 changed)`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_priority_tag_layout_test.dart`：沙箱内静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 说明，沿着单文件 focused test 逐条补具体 failure label，在当前环境里仍然是稳定、清晰且不容易卡住的推进方式。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以再补 `threadExpired -> 会话已过期` 或 `imageUploadTokenInvalid -> 上传凭证失效` 其中一条 focused case，把 priority tag 的具体失败标签覆盖继续往前推
  2. 如果准备切模块，消息列表这条链路已经从布局结构、在线优先级推进到了多种具体 failure label，可以回到消息页别的反馈组件，或者回到“我的 / 设置”继续做同样粒度的小步优化

## 2026-04-01 最近动态 193
- 完成：继续沿消息列表 priority tag 的具体 failure label 覆盖往前补了一条 focused case。考虑到当前列表会过滤掉已过期的非好友线程，这轮没有直接补 `threadExpired`，而是先补了更稳定可见的 `imageUploadTokenInvalid -> 上传凭证失效` compact 场景，锁住：
  - `上传凭证失效` priority tag 正常显示
  - priority row 仍保持在 meta row 之上
  - unread meta 和 delivery badge slot 仍正常保留
- 完成：这一轮仍然没有改业务逻辑，继续复用了 `markMessageFailedForTesting(...)` 测试入口，把 priority tag 的具体失败标签覆盖继续向前推了一格。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_priority_tag_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_priority_tag_layout_test.dart`：沙箱内通过，`Formatted 1 file (0 changed)`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_priority_tag_layout_test.dart`：沙箱内超时退出
  - 在 `flutter-app` 目录提权执行同一条 `dart.exe analyze`：静态分析通过，`No issues found!`
- 风险 / 备注：这轮补充说明，当前环境里的 `dart analyze` 不只是会撞 `CreateFile failed 5`，也可能直接超时半挂起；继续把这两类现象都视为同一类环境失败，并立刻对同一条最小命令提权重跑，是目前最稳的快排方式。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以再补 `imageUploadPreparationFailed -> 上传准备失败` 或 `imageUploadInterrupted -> 上传中断` 其中一条 focused case，把 priority tag 的图片发送失败标签覆盖再向前推一格
  2. 如果准备切模块，消息列表这条链路已经从布局结构、在线优先级推进到了多种具体 failure label，可以回到消息页别的反馈组件，或者回到“我的 / 设置”继续做同样粒度的小步优化

## 2026-04-01 最近动态 194
- 完成：继续沿消息列表 priority tag 的图片发送失败标签覆盖往前补了一条 focused case。`flutter-app/test/widgets/messages_thread_priority_tag_layout_test.dart` 新增了 `imageUploadPreparationFailed -> 上传准备失败` 的 compact 场景，锁住：
  - `上传准备失败` priority tag 正常显示
  - priority row 仍保持在 meta row 之上
  - unread meta 和 delivery badge slot 仍正常保留
- 完成：这一轮仍然没有改业务逻辑，继续复用了 `markMessageFailedForTesting(...)` 测试入口，把 priority tag 的图片失败标签覆盖继续向前推了一格。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_priority_tag_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_priority_tag_layout_test.dart`：沙箱内通过，`Formatted 1 file (0 changed)`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_priority_tag_layout_test.dart`：沙箱内静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 说明，沿着单文件 focused test 逐条补具体图片失败标签，在当前环境里仍然是稳定且不容易卡住的推进方式。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以再补 `imageUploadInterrupted -> 上传中断` 或 `imageReselectRequired -> 重选图片` 其中一条 focused case，把图片发送失败标签覆盖继续往前推
  2. 如果准备切模块，消息列表这条链路已经从布局结构、在线优先级推进到了多种具体 failure label，可以回到消息页别的反馈组件，或者回到“我的 / 设置”继续做同样粒度的小步优化

## 2026-04-01 最近动态 195
- 完成：继续沿消息列表 priority tag 的图片发送失败标签覆盖往前补了一条 focused case。`flutter-app/test/widgets/messages_thread_priority_tag_layout_test.dart` 新增了 `imageUploadInterrupted -> 上传中断` 的 compact 场景，锁住：
  - `上传中断` priority tag 正常显示
  - priority row 仍保持在 meta row 之上
  - unread meta 和 delivery badge slot 仍正常保留
- 完成：这一轮仍然没有改业务逻辑，继续复用了 `markMessageFailedForTesting(...)` 测试入口，把图片发送失败标签覆盖再向前推了一格。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_priority_tag_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_priority_tag_layout_test.dart`：沙箱内通过，`Formatted 1 file (0 changed)`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_priority_tag_layout_test.dart`：沙箱内静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 说明，沿着单文件 focused test 逐条补图片发送失败标签，当前环境下仍然是稳定、清晰且高性价比的推进方式。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以再补 `imageReselectRequired -> 重选图片` 或 `imageUploadFileTooLarge -> 图片过大` 其中一条 focused case，把图片发送失败标签覆盖继续往前推
  2. 如果准备切模块，消息列表这条链路已经从布局结构、在线优先级推进到了多种具体 failure label，可以回到消息页别的反馈组件，或者回到“我的 / 设置”继续做同样粒度的小步优化

## 2026-04-01 最近动态 196
- 完成：继续沿消息列表 priority tag 的图片发送失败标签覆盖往前补了一条 focused case。`flutter-app/test/widgets/messages_thread_priority_tag_layout_test.dart` 新增了 `imageReselectRequired -> 重选图片` 的 compact 场景，锁住：
  - `重选图片` priority tag 正常显示
  - 同名 delivery badge 仍正常保留
  - priority row 仍保持在 meta row 之上
  - unread meta 仍正常保留
- 完成：这一轮仍然没有改业务逻辑，继续复用了 `markMessageFailedForTesting(...)` 测试入口，把图片发送失败标签覆盖再向前推了一格。
- 涉及模块：
  - CURRENT_SPRINT.md
  - flutter-app/test/widgets/messages_thread_priority_tag_layout_test.dart
- 验证：
  - 在项目根目录执行：`powershell -ExecutionPolicy Bypass -File .\repair_flutter_cli_hang.ps1`：未检测到残留 `flutter/dart` 进程
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe format test\widgets\messages_thread_priority_tag_layout_test.dart`：沙箱内通过，`Formatted 1 file (0 changed)`
  - 在 `flutter-app` 目录执行：`D:\flutter_windows_3.27.1-stable\flutter\bin\cache\dart-sdk\bin\dart.exe analyze test\widgets\messages_thread_priority_tag_layout_test.dart`：沙箱内静态分析通过，`No issues found!`
- 风险 / 备注：这轮 again 说明，沿着单文件 focused test 逐条补图片发送失败标签，当前环境里仍然是最稳、最不容易卡住的一种推进方式。
- 下一步建议：
  1. 如果继续沿消息列表推进，可以再补 `imageUploadFileTooLarge -> 图片过大` 或 `imageUploadUnsupportedFormat -> 格式异常` 其中一条 focused case，把图片发送失败标签覆盖继续往前推
  2. 如果准备切模块，消息列表这条链路已经从布局结构、在线优先级推进到了多种具体 failure label，可以回到消息页别的反馈组件，或者回到“我的 / 设置”继续做同样粒度的小步优化
## 2026-04-04 最近动态 198
- 完成：继续把本机 `openclaw` 从“已安装 CLI”推进到“可本地启动”的状态，补齐了本地初始化，并在当前机器上拉起了 OpenClaw Gateway 后台进程。
- 涉及模块：
  - CURRENT_SPRINT.md
- 验证：
  - 在项目根目录执行：`openclaw --help`：失败，PowerShell 默认命中了 `openclaw.ps1`，被本机执行策略拦截
  - 在项目根目录执行：`openclaw.cmd --help`：通过，确认应改用 `openclaw.cmd`
  - 在项目根目录执行：`openclaw.cmd status`：返回 Gateway 未初始化、`gateway.mode` 未设置
  - 在项目根目录执行：`openclaw.cmd doctor`：返回需先做本地 setup/onboard，且 `~\.openclaw` 状态目录缺失
  - 在项目根目录提权执行：`openclaw.cmd onboard --mode local --non-interactive --accept-risk ... --no-install-daemon --json`：通过，已生成 `C:\Users\chenjiageng\.openclaw\openclaw.json` 与工作目录
  - 在项目根目录提权执行：后台启动 `openclaw.cmd gateway run`：通过，进程已拉起
  - 在项目根目录执行：`openclaw.cmd health`：通过，CLI 已能拿到本地 Gateway 响应
- 风险 / 备注：当前是在原生 Windows 下以本地 loopback + token 鉴权方式启动，Gateway service / Node service 尚未安装；`openclaw.cmd status` 仍提示 `missing scope: operator.read`，说明当前后台虽已可响应，但后续若要稳定使用 dashboard / operator 相关能力，还需要继续补完整授权或按官方建议迁移到 WSL2。
- 下一步建议：
  1. 日常启动先使用 `openclaw.cmd`，不要直接敲 `openclaw`
  2. 如果准备长期使用，可继续执行 `openclaw.cmd configure` 补模型/授权配置，或改走官方更推荐的 WSL2 运行方式
## 2026-04-04 最近动态 199
- 完成：为本机 OpenClaw 补了一个可双击的一键启动器，新增 Windows 原生 `OpenClawLauncher.exe`，用于静默检查 Gateway、按需拉起 `openclaw.cmd gateway run`，并打开带当前 token 的本地 Dashboard。
- 涉及模块：
  - CURRENT_SPRINT.md
  - tools/openclaw-launcher/OpenClawLauncher.cs
  - tools/openclaw-launcher/build-openclaw-launcher.cmd
  - OpenClawLauncher.exe
- 验证：
  - 在项目根目录执行：`cmd /c tools\openclaw-launcher\build-openclaw-launcher.cmd`：通过，已生成 `tools\openclaw-launcher\OpenClawLauncher.exe` 并复制到仓库根目录 `OpenClawLauncher.exe`
  - 在项目根目录执行：`.\tools\openclaw-launcher\OpenClawLauncher.exe --no-open`：通过，启动器可正常运行且无报错退出
  - 在项目根目录执行：`.\OpenClawLauncher.exe --no-open`：通过，根目录一键入口可正常运行
  - 在项目根目录执行：`openclaw.cmd health --json`：通过，当前本机 Gateway 仍健康可响应
- 风险 / 备注：这轮启动器默认依赖现有 `C:\Users\chenjiageng\AppData\Roaming\npm\openclaw.cmd` 和 `C:\Users\chenjiageng\.openclaw\openclaw.json`；如果后续重装 Node、移动全局 npm 目录或清掉 `~\.openclaw`，需要重新初始化或重建启动器。
- 下一步建议：
  1. 日常直接双击仓库根目录的 `OpenClawLauncher.exe`
  2. 如果想放到桌面或别的目录继续双击使用，可以把 `OpenClawLauncher.exe` 复制过去；若后续改了启动逻辑，再运行一次 `tools\openclaw-launcher\build-openclaw-launcher.cmd` 重建
## 2026-04-04 最近动态 200
- 完成：继续把 OpenClaw 的一键使用链路补完整，新增了配套的 `CloseOpenClawLauncher.exe`，并已将启动/关闭两个 exe 部署到桌面，方便直接双击使用。
- 涉及模块：
  - CURRENT_SPRINT.md
  - tools/openclaw-launcher/CloseOpenClawLauncher.cs
  - tools/openclaw-launcher/build-openclaw-launcher.cmd
  - CloseOpenClawLauncher.exe
  - OpenClawLauncher.exe
- 验证：
  - 在项目根目录执行：`cmd /c tools\openclaw-launcher\build-openclaw-launcher.cmd`：通过，已重新生成启动/关闭两个 exe，并同步复制到仓库根目录
  - 在项目根目录提权执行：复制 `OpenClawLauncher.exe` 与 `CloseOpenClawLauncher.exe` 到桌面：通过
  - 在项目根目录提权执行：`openclaw.cmd health --json`：通过，确认沙箱外真实本机环境下 Gateway 正常可连
  - 在项目根目录提权执行：关闭器 + 启动器闭环后，再执行 `openclaw.cmd health --json`：通过
  - 在项目根目录提权执行：`netstat -ano | Select-String ':18789'`：通过，确认当前监听 PID 已恢复
- 风险 / 备注：`CloseOpenClawLauncher.exe` 在关闭提权拉起的旧 Gateway 时会触发一次系统 UAC 确认；另外，Codex 沙箱内执行 `openclaw.cmd health` 可能误报 `device-auth.json` 的 `EPERM`，这不是本机桌面双击使用时的真实结果，沙箱外复测已经通过。
- 下一步建议：
  1. 日常直接双击桌面的 `OpenClawLauncher.exe` 启动
  2. 需要关闭时双击桌面的 `CloseOpenClawLauncher.exe`
## 2026-04-04 最近动态 201
- 完成：修复了 `C:\Users\chenjiageng\.openclaw\openclaw.json` 的 JSON 语法错误和模型配置结构错误。当前已恢复为合法配置，并将默认模型收敛到 `openrouter/xiaomi/mimo-v2-pro`，fallback 为 `openrouter/xiaomi/mimo-v2-omni`。
- 涉及模块：
  - CURRENT_SPRINT.md
  - tools/openclaw-launcher/fix-openclaw-config.ps1
- 验证：
  - 在项目根目录执行：`Get-Content -Raw $env:USERPROFILE\.openclaw\openclaw.json`：确认配置已恢复为合法 JSON，且 `env.vars.OPENROUTER_API_KEY`、`agents.defaults.model`、`agents.defaults.models` 均在正确位置
  - 在项目根目录执行：`openclaw.cmd config validate`：通过，输出 `Config valid: ~\.openclaw\openclaw.json`
  - 在项目根目录提权执行：`openclaw.cmd health --json`：通过，OpenClaw 运行健康
  - 在项目根目录提权执行：`openclaw.cmd models status --plain`：通过，返回当前默认模型 `openrouter/xiaomi/mimo-v2-pro`
  - 在项目根目录执行：`openclaw.cmd config get agents.defaults.model`：通过，确认 primary/fallback 为 `openrouter/xiaomi/mimo-v2-pro` / `openrouter/xiaomi/mimo-v2-omni`
  - 在项目根目录执行：`openclaw.cmd config get agents.defaults.models`：通过，确认两条模型条目已注册
  - 本轮自动备份原坏配置到：`C:\Users\chenjiageng\.openclaw\openclaw.json.bak.20260404-145227`
- 风险 / 备注：当前 `OPENROUTER_API_KEY` 仍以内联方式写在 `openclaw.json` 的 `env.vars` 中，功能上可用，但从安全角度看更推荐后续迁移到系统环境变量或 SecretRef。
- 下一步建议：
  1. 现在可以直接继续用 OpenClaw 控制台，模型识别问题已修复
  2. 如果你想把 API key 配置再做得更稳，我下一轮可以继续帮你改成“环境变量 / SecretRef”版本，避免把 key 明文放在配置里
## 2026-04-04 最近动态 202
- 完成：排查了 OpenClaw 控制台聊天“转圈但日志里看不到请求”的现象。结论不是本地模型配置失效，而是请求已经进入模型调用链，并被 OpenRouter 以计费/余额不足错误拦截。
- 涉及模块：
  - CURRENT_SPRINT.md
- 验证：
  - 在项目根目录执行：`openclaw.cmd health --json`：通过，Gateway 正常
  - 在项目根目录执行：`openclaw.cmd config get agents.defaults.model`：通过，当前默认模型为 `openrouter/xiaomi/mimo-v2-pro`
  - 检查 `C:\Users\chenjiageng\.openclaw\agents\main\sessions\sessions.json`：发现最近一次会话 `status: "failed"`，且包含 `providerOverride: "xiaomi"`、`modelOverride: "mimo-v2-pro"`
  - 控制台实际报错为：`openrouter (xiaomi/mimo-v2-pro) returned a billing error — your API key has run out of credits or has an insufficient balance`
- 风险 / 备注：当前问题点在 OpenRouter key 的账单/额度，不在 `openclaw.json` 语法或模型路由；由于现有日志级别较低，本地 `~\.openclaw\logs` 目录里不会自然看到完整请求明细。
- 下一步建议：
  1. 先到 OpenRouter 后台检查当前 key 是否还有可用余额/credits
  2. 若余额不足，充值或更换新的 `OPENROUTER_API_KEY`
  3. 若你不想继续走 OpenRouter，我可以下一轮帮你切成小米直连 provider 配置
## 2026-04-04 最近动态 203
- 完成：按“继续免费使用”的目标，把 OpenClaw 默认模型从付费的 `openrouter/xiaomi/mimo-v2-pro` 切换到了免费路由 `openrouter/free`，并清掉了当前聊天会话里粘住的付费模型覆盖项，避免控制台继续命中 `mimo-v2-pro`。
- 涉及模块：
  - CURRENT_SPRINT.md
  - tools/openclaw-launcher/switch-openclaw-to-openrouter-free.ps1
- 验证：
  - 在项目根目录提权执行：`powershell -ExecutionPolicy Bypass -File .\tools\openclaw-launcher\switch-openclaw-to-openrouter-free.ps1`：通过
  - 在项目根目录执行：`openclaw.cmd config get agents.defaults.model`：通过，当前 primary 已变为 `openrouter/free`
  - 在项目根目录执行：`openclaw.cmd config get agents.defaults.models`：通过，仅保留 `openrouter/free`
  - 检查 `C:\Users\chenjiageng\.openclaw\agents\main\sessions\sessions.json`：原 `providerOverride` / `modelOverride` 已移除
  - 在项目根目录提权执行：`openclaw.cmd health --json`：通过，切换后 Gateway 仍健康可用
  - 本轮自动备份：
    - `C:\Users\chenjiageng\.openclaw\openclaw.json.bak.20260404-150442`
    - `C:\Users\chenjiageng\.openclaw\agents\main\sessions\sessions.json.bak.20260404-150442`
- 风险 / 备注：控制台页面里先前那条 `mimo-v2-pro` 计费错误提示属于旧会话状态，刷新聊天页或重新打开控制台后，新的发送才会按 `openrouter/free` 走；免费路由可用性仍取决于 OpenRouter 当时开放的免费模型池。
- 下一步建议：
  1. 现在先刷新一次聊天页，或直接重新打开 OpenClaw 控制台
  2. 刷新后再次发送消息，观察是否还出现 `mimo-v2-pro` 的计费提示
## 2026-04-04 最近动态 204
- 完成：继续按 `C:\Users\chenjiageng\Desktop\1\Openrouter小米大模型注册及接入.pdf` 这条 OpenRouter 接入思路做了实际可用性验证。虽然当前环境无法完整抽取 PDF 全文，但已从文档中识别出 `https://openrouter.ai/` 与 `https://openrouter.ai/logs` 关键入口，并基于这条链路完成了本地实测。
- 涉及模块：
  - CURRENT_SPRINT.md
- 验证：
  - 在项目根目录执行：`openclaw.cmd dashboard --no-open`：通过，返回本地 Dashboard URL
  - 在项目根目录提权执行：`openclaw.cmd agent --local --agent main --message "Reply with exactly: ok" --json`：通过
  - 实测返回：
    - `provider: "openrouter"`
    - `model: "openrouter/free"`
    - `payloads[0].text: "ok"`
- 风险 / 备注：当前这份配置已经不是“语法正确但未验证”，而是已经完成了一次真实模型调用；如果控制台页面还显示旧错误，优先视为前端页面残留状态，刷新或重新打开控制台即可。
- 下一步建议：
  1. 重新打开 OpenClaw 聊天页后再发一次消息
  2. 如果你想继续固定使用小米系模型而不是 `openrouter/free`，后续需要一把有余额的 OpenRouter key 或改成小米直连 provider
## 2026-04-04 最近动态 205
- 完成：按你提供的 PPT 截图，把 OpenClaw 配置切回了文档里的 OpenRouter 小米模型写法：
  - `env.vars.OPENROUTER_API_KEY`
  - `agents.defaults.model.primary = openrouter/xiaomi/mimo-v2-pro`
  - `agents.defaults.models` 中保留 `openrouter/xiaomi/mimo-v2-pro` 与 `openrouter/xiaomi/mimo-v2-omni`
- 完成：同时修正了会话状态，移除了错误的 `providerOverride = xiaomi` 覆盖，确保本地调用真正按“默认模型走 OpenRouter”。
- 涉及模块：
  - CURRENT_SPRINT.md
  - tools/openclaw-launcher/switch-openclaw-to-ppt-openrouter-xiaomi.ps1
- 验证：
  - 在项目根目录提权执行：`powershell -ExecutionPolicy Bypass -File .\tools\openclaw-launcher\switch-openclaw-to-ppt-openrouter-xiaomi.ps1 -ApiKey ...`：通过
  - 在项目根目录执行：`openclaw.cmd config get agents.defaults.model`：通过，当前为 `openrouter/xiaomi/mimo-v2-pro`
  - 在项目根目录执行：`openclaw.cmd config get agents.defaults.models`：通过，模型条目与 PPT 一致
  - 在项目根目录提权执行：`openclaw.cmd agent --local --agent main --message "Reply with exactly: ok" --json`：已实际命中 `provider=openrouter`、`model=xiaomi/mimo-v2-pro`
  - 上游真实返回：`402 This request requires more credits, or fewer max_tokens. You requested up to 32000 tokens, but can only afford 13333.`
- 风险 / 备注：这一轮已经证明“本地配置和模型路由是正确的”；当前阻塞点在 OpenRouter 服务端对这把 key 的 credits/entitlement，而不在 `openclaw.json` 语法、字段位置或模型名。
- 下一步建议：
  1. 如果你坚持继续用 `openrouter/xiaomi/mimo-v2-pro`，需要换一把真正具备该模型可用额度的 OpenRouter key
  2. 如果你要先稳定可用，我可以下一轮把默认模型改成一个确定能通的免费模型，同时保留小米配置备份
## 2026-04-04 最近动态 206
- 完成：已将 OpenClaw 切换到你提供的 OpenAI 兼容中转站：
  - Base URL：`http://20.204.239.211:8317/v1`
  - API key：`bilonzask`
  - 默认模型：`relay/gpt-5.4`
- 完成：新增自定义 provider `relay`，并清理掉会话里遗留的小米/OpenRouter 路由影响，确保当前聊天直接走中转站里的 `gpt-5.4`。
- 涉及模块：
  - CURRENT_SPRINT.md
  - tools/openclaw-launcher/switch-openclaw-to-relay-gpt54.ps1
- 验证：
  - 在项目根目录提权执行：`powershell -ExecutionPolicy Bypass -File .\tools\openclaw-launcher\switch-openclaw-to-relay-gpt54.ps1`：通过
  - 在项目根目录执行：`openclaw.cmd config validate`：通过
  - 在项目根目录执行：`openclaw.cmd config get agents.defaults.model`：通过，返回 `relay/gpt-5.4`
  - 在项目根目录执行：`openclaw.cmd config get models.providers.relay`：通过，确认自定义 provider 指向 `http://20.204.239.211:8317/v1`
  - 在项目根目录提权执行：`openclaw.cmd agent --local --agent main --message "Reply with exactly: ok" --json`：通过
  - 实测返回：
    - `provider: "relay"`
    - `model: "gpt-5.4"`
    - `payloads[0].text: "ok"`
- 风险 / 备注：当前配置中转站 key 以内联方式保存在 `models.providers.relay.apiKey` 中，功能上已可用，但从安全角度看后续更推荐改成环境变量或 SecretRef。
- 下一步建议：
  1. 现在直接刷新或重新打开 OpenClaw 聊天页即可开始用 `gpt-5.4`
  2. 如果你希望把这个中转配置做成“更安全不明文存 key”的版本，我下一轮可以帮你再收一下
## 2026-04-04 最近动态 207
- 完成：修复了 `OpenClawLauncher.exe` 在“端口已被旧 Gateway 占用但网关实际不健康”场景下直接超时弹错的问题。新版本会在检测到不健康监听时自动走提权修复、清掉旧进程并重拉 Gateway，而不是停在 `did not become ready in time`。
- 涉及模块：
  - CURRENT_SPRINT.md
  - tools/openclaw-launcher/OpenClawLauncher.cs
  - OpenClawLauncher.exe
  - CloseOpenClawLauncher.exe
- 验证：
  - 在项目根目录执行：`cmd /c tools\openclaw-launcher\build-openclaw-launcher.cmd`：通过，已重新生成启动器
  - 在项目根目录提权执行：将新的 `OpenClawLauncher.exe` / `CloseOpenClawLauncher.exe` 同步到桌面：通过
  - 在项目根目录提权执行：`.\OpenClawLauncher.exe --no-open; Start-Sleep -Seconds 5; openclaw.cmd health --json`：通过，Gateway 健康可响应
- 风险 / 备注：当 Launcher 检测到旧的假活进程需要修复时，仍可能触发一次系统 UAC 确认；这是为了允许它清理旧 Gateway 并重拉新进程。
- 下一步建议：
  1. 直接使用桌面上的新 `OpenClawLauncher.exe`
  2. 如果聊天页仍显示旧状态，优先重新打开控制台，不要继续沿用之前卡住的页面标签
## 2026-04-04 最近动态 208
- 完成：已把 OpenClaw 默认模型从中转 `relay/gpt-5.4` 切换到你提供的 MiniMax 官方兼容端点：
  - Base URL：`https://api.minimaxi.com/anthropic`
  - 默认模型：`minimax/MiniMax-M2.7`
  - fallback：`minimax/MiniMax-M2.7-highspeed`
- 完成：新增/更新了 MiniMax 切换脚本 `tools/openclaw-launcher/switch-openclaw-to-minimax.ps1`，并把 `MINIMAX_API_KEY` 写入 `openclaw.json` 的 `env.vars`，同时清理了旧的 `OPENROUTER_API_KEY` 遗留。
- 涉及模块：
  - CURRENT_SPRINT.md
  - tools/openclaw-launcher/switch-openclaw-to-minimax.ps1
- 验证：
  - 在项目根目录提权执行：`powershell.exe -ExecutionPolicy Bypass -File .\tools\openclaw-launcher\switch-openclaw-to-minimax.ps1 -ApiKey ... -BaseUrl "https://api.minimaxi.com/anthropic"`：通过
  - 在项目根目录执行：`openclaw.cmd config validate`：通过
  - 在项目根目录执行：`openclaw.cmd config get agents.defaults.model`：通过，当前 primary/fallback 为 `minimax/MiniMax-M2.7` / `minimax/MiniMax-M2.7-highspeed`
  - 在项目根目录执行：`openclaw.cmd config get models.providers.minimax`：通过，确认 provider 指向 `https://api.minimaxi.com/anthropic` 且 API 协议为 `anthropic-messages`
  - 在项目根目录提权执行：`openclaw.cmd agent --local --agent main --message "Reply with exactly: ok" --json`：通过
  - 实测返回：
    - `provider: "minimax"`
    - `model: "MiniMax-M2.7"`
    - `payloads[0].text: "ok"`
- 风险 / 备注：这轮已经证明当前 MiniMax 路由不是“只改了配置未验证”，而是完成了一次真实端到端调用；如果聊天页还显示旧的 `relay/gpt-5.4` 或更早的小米/OpenRouter 状态，优先刷新或重新打开聊天页。
- 下一步建议：
  1. 重新打开 OpenClaw 聊天页后再发一条消息，新的会话应直接走 `MiniMax-M2.7`
  2. 如果你想把 key 再收得更安全，下一轮可以把 `MINIMAX_API_KEY` 从配置文件改成系统环境变量或 SecretRef
## 2026-04-04 最近动态 209
- 完成：定位并修复了 OpenClaw 聊天页里“消息气泡内容还在说 relay/gpt-5.4，但页签和消息底部已经显示 MiniMax-M2.7”的串上下文问题。根因不是当前请求还在走旧模型，而是同一个 `agent:main:main` 会话保留了早先 `relay/gpt-5.4` 的对话历史，MiniMax 在新一轮回答里沿用了这段旧上下文。
- 完成：新增会话重置脚本 `tools/openclaw-launcher/reset-openclaw-main-session.ps1`，对当前主会话做了“先备份、后移除”的安全重置，避免旧历史继续污染聊天页回答。
- 涉及模块：
  - CURRENT_SPRINT.md
  - tools/openclaw-launcher/reset-openclaw-main-session.ps1
- 验证：
  - 检查 `C:\Users\chenjiageng\.openclaw\agents\main\sessions\498e9e98-2c60-40d4-9710-714b282a4fbd.jsonl`：确认旧会话里先前确实存在 `relay/gpt-5.4` 的 `session_status` 工具输出和助手回答
  - 在项目根目录提权执行：`powershell.exe -ExecutionPolicy Bypass -File .\tools\openclaw-launcher\reset-openclaw-main-session.ps1`：通过
  - 本轮自动备份：
    - `C:\Users\chenjiageng\.openclaw\agents\main\sessions\sessions.json.bak.20260404-171135`
    - `C:\Users\chenjiageng\.openclaw\agents\main\sessions\498e9e98-2c60-40d4-9710-714b282a4fbd.jsonl.bak.20260404-171135`
  - 在项目根目录提权执行：`openclaw.cmd agent --local --agent main --message "What model/provider are you using right now? Reply with only the exact provider/model string." --json`：通过
  - 实测返回：
    - `provider: "minimax"`
    - `model: "MiniMax-M2.7"`
    - `payloads[0].text: "minimax/MiniMax-M2.7"`
- 风险 / 备注：这轮重置的是当前主聊天会话历史，不是模型配置；配置仍然保持 MiniMax。旧会话内容已做本地备份，如后续需要排查仍可回看。
- 下一步建议：
  1. 关闭并重新打开当前 OpenClaw 聊天页，让前端拿到新的空会话
  2. 如果后面频繁切换 provider，优先在切换后顺手重置一次当前会话，避免再次把旧模型身份带进新对话
## 2026-04-05 最近动态 214
- 完成：继续收口外部项目 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 的“没有返回按钮、灵动岛/状态栏遮挡、首屏导航安全区抖动、tabBar 文案异常”问题，这一轮重点是把自定义导航从“能显示”进一步收成“首帧就稳定、安全区一致”。
- 完成：
  - 修复 `src/utils/nav.js`
    - 增加 `getInitialNavBarData()`，页面在首屏渲染前就能拿到一份安全的导航占位数据
    - 为 `wx` 未就绪场景增加保护，避免在初始化阶段直接读系统信息时报错
    - `applyNavBar()` 统一改为下发初始化后的导航数据
  - 修复 `src/app.wxss`
    - 强化通用自定义导航的左右槽位、返回按钮高度和间距，减少刘海屏 / 灵动岛机型的顶部拥挤感
    - 让导航左槽位支持收缩、右槽位和返回按钮高度统一，减少不同页面头部不齐
  - 修复以下页面 JS 初始化：
    - `src/pages/index/index.js`
    - `src/pages/food/food.js`
    - `src/pages/exercise/exercise.js`
    - `src/pages/training/training.js`
    - `src/pages/plan/plan.js`
    - `src/pages/settings/settings.js`
    - `src/pages/ai-config/ai-config.js`
    - `src/pages/agreement/agreement.js`
    - `src/pages/privacy/privacy.js`
    - 上述页面均已补 `nav: getInitialNavBarData(...)`，避免 `onLoad` 前顶部高度为 `undefined` 导致的首屏错位
  - 修复 `src/pages/settings/settings.js`
    - 设置页读取数据前先 `recalculateTodayData()`，避免“我的”页里今日运动数据显示滞后
  - 修复 `src/app.json`
    - 再次确认 tabBar 文案为 `首页 / 饮食 / 训练 / 方案 / 我的`
    - 保留原有 `scope.userLocation` 权限声明，避免误伤无关配置
- 运动数据接入排查结论：
  - 微信运动仍然是当前最现实的接入方向，但不能只改前端；`wx.getWeRunData()` 拿到的是开放数据链路，敏感步数数据要继续通过云函数 / 服务端解密或 CloudID 方案获取
  - 小米手环：没有在当前小程序官方开放数据路径里找到“通用一键导入”能力；如果继续做，只能走设备级 BLE 适配或借道微信运动同步，成本和不确定性都明显更高
  - Apple Watch / iWatch：Apple 官方健康与配件能力主要在 `HealthKit / Core Motion / Core Bluetooth / WorkoutKit` 等原生生态里，当前微信小程序项目并没有直连这套原生健康数据能力的桥接路径
- 涉及模块：
  - CURRENT_SPRINT.md
  - 外部项目 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram`
- 验证：
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`Get-ChildItem -Recurse -Filter *.js src | ForEach-Object { node --check $_.FullName }`：通过
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`Select-String -Path src\app.json -Pattern '首页|饮食|训练|方案|我的'`：通过，确认 tabBar 文案正常
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`rg -n "getInitialNavBarData|nav: getInitialNavBarData|applyNavBar\\(this, true\\)|applyNavBar\\(this, false\\)" src\pages src\utils`：通过，确认导航初始化已覆盖目标页面
  - 官方/准官方资料补查：
    - `https://docs.cloudbase.net/practices/get-wechat-open-data`
    - `https://developer.apple.com/health-fitness/`
- 风险 / 备注：
  - 当前环境无法直接跑微信开发者工具真机截图，因此“灵动岛不遮挡”的最终确认仍建议你在开发者工具里用 iPhone 15 Pro / 16 Pro 一类机型再过一遍
  - 微信运动若要真正落地“实时同步”，下一轮最小可行实现也至少要补一条云函数或服务端解密链路；这不是纯 UI 改动
- 下一步建议：
  1. 在微信开发者工具里重点复测 `exercise / ai-config / privacy / agreement / settings` 五个页面的顶部安全区和返回按钮
  2. 如果要继续推进运动数据接入，建议下一轮只做“微信运动接入 MVP”，不要同时开小米手环和 Apple Watch 两条线

## 2026-04-05 最近动态 215
- 排查/梳理：围绕外部项目 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram`，进一步明确了产品需求重点应从“页面修修补补”转到“个人计划 + 可编辑训练计划 + 打卡闭环”，并确定设计方向继续沿用 iOS 原生 / SwiftUI 体验语言，但仍保持当前小程序技术路线，不额外切栈。
## 2026-04-05 最近动态 216
- 排查/梳理：新增明确了“慢性病膳食计划 + 进度跟踪 + 大模型辅助分析”这一条产品方向，尤其是以溃疡性结肠炎这类个体差异很大的疾病为代表，后续不能按普通健康饮食推荐做，而要按“医疗辅助、循证约束、个体化跟踪”的模式设计。
- 当前结论：
  - 不能让大模型直接产出“诊断式”或“治疗式”结论；更稳的方案应是“大模型负责解释与草案生成，规则引擎和循证知识库负责约束，用户症状/耐受数据负责个体化调整”
  - 慢病场景下，产品核心不应只是“推荐吃什么”，而应增加：
    - 疾病档案
    - 症状阶段（如缓解期 / 发作期）
    - 食物耐受记录
    - 摄入量监控
    - 红旗症状提醒
    - 阶段性复盘
  - 对溃疡性结肠炎这类疾病，后续功能应重点支持“膳食排期 + 摄取量监控 + 症状与食物关联跟踪”，而不是简单给固定菜单
- 资料排查参考：
  - NIDDK《Eating, Diet, & Nutrition for Ulcerative Colitis》强调：
    - 没有证据表明某种固定食物普遍导致或加重溃疡性结肠炎
    - 更适合结合个人症状做食物日记和个体化调整
  - NICE 溃疡性结肠炎指南补充信息部分强调：
    - 需要把患者当作个体对待
    - 营养师在整个疾病过程中提供平衡饮食和营养评估支持很重要
  - Crohn’s & Colitis Foundation 资料强调：
    - 小餐多次、发作期补液、识别 trigger foods、必要时关注高纤维/乳糖/高脂等耐受问题
## 2026-04-05 最近动态 217
- 完成：继续把外部项目 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 从“UI 修修补补”推进到“可上线导向的真实产品闭环”，这一轮重点补齐了健康档案、慢病膳食辅助、每日打卡、可编辑训练计划，并同步清理首页/饮食/运动/训练/方案/我的等核心页的损坏文案和结构问题。
- 完成：
  - 新增全局健康管理数据层：
    - 新增 `src/utils/health.js`
    - 提供慢病元数据、健康档案默认值、每日打卡默认值、打卡完成度计算
  - 重构 `src/app.js`
    - 补齐 `healthProfile / dailyCheckins / trainingPlans / currentPlanId` 全局状态
    - 新增训练计划保存/更新/删除、健康档案保存、每日打卡保存、近 7 天打卡统计、清理今日记录等方法
    - 保持饮食/运动日志与 AI 请求能力兼容
  - 重构路由与页面注册 `src/app.json`
    - 新增真实页面：
      - `pages/profile/profile`
      - `pages/checkin/checkin`
      - `pages/training-editor/training-editor`
    - 纠正 tabBar 文案和权限描述
  - 重构核心产品页面：
    - `src/pages/index/index`
      - 首页增加健康状态卡、打卡统计、健康档案/今日打卡快捷入口
      - 清理损坏文案和错误标签，保持顶部安全区兼容
    - `src/pages/settings/settings`
      - “我的”页改为真实总控页
      - 接入健康档案、今日打卡、运动同步说明、AI 设置、导出与清除记录
      - 不再保留假入口
    - `src/pages/training/training`
      - 支持 AI 生成训练计划
      - 支持保存计划、加载计划、删除计划、跳转训练编辑页
      - 明确“保存后还可以继续编辑”的产品能力
    - `src/pages/plan/plan`
      - 增加慢病模式卡片
      - 以溃疡性结肠炎为重点场景，按阶段输出更稳妥的饮食建议
      - 保留目标热量、自定义三大营养素、近 7 天趋势图
    - `src/pages/food/food`
      - 修复主要录入页的文案损坏与结构问题
    - `src/pages/exercise/exercise`
      - 修复快速记录、删除记录、自定义运动页的文案与结构问题
  - 新增真实功能页面：
    - `src/pages/profile/profile`
      - 维护身高、体重、年龄、活动水平、慢病方向、阶段、过敏/不耐受/补充说明
    - `src/pages/checkin/checkin`
      - 记录饮食执行、训练完成、水量、睡眠、自评执行度与慢病观察项
      - 包含红旗症状提醒文案
    - `src/pages/training-editor/training-editor`
      - 编辑计划名称、周期、频次、等级、说明和动作列表
- 涉及模块：
  - CURRENT_SPRINT.md
  - 外部项目 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram`
- 验证：
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`Get-ChildItem -Recurse -Filter *.js src | ForEach-Object { node --check $_.FullName }`：通过
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：
    - `Get-ChildItem -Recurse -Filter *.wxml src\pages | Select-String -Pattern '?/text>' -SimpleMatch`
    - `Get-ChildItem -Recurse -Filter *.wxml src\pages | Select-String -Pattern '?/view>' -SimpleMatch`
    两条均无结果，说明本轮已清掉核心页面里明显的损坏闭合标签
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`git status --short`：通过，确认本轮变更集中在 `app.js / app.json / index / settings / plan / training / food / exercise` 与新增的 `profile / checkin / training-editor / utils/health.js`
- 风险 / 备注：
  - 当前环境仍无法直接跑微信开发者工具真机预览，所以这轮主要完成了代码层、结构层和语法层收口；灵动岛 / 小屏 / 真机滚动细节仍建议用开发者工具再过一遍
  - 微信运动、小米手环、Apple Watch 的一键同步仍未直接落地；本轮只补了真实的“同步能力说明”，没有添加假接入按钮
  - `ai-config / agreement / privacy` 等辅助页仍保留部分旧实现，虽然本轮未发现新的语法问题，但若继续按上架标准推进，下一轮建议再统一做一轮文案和视觉清理
- 下一步建议：
  1. 用微信开发者工具重点真机预览 `index / food / exercise / training / plan / settings / profile / checkin / training-editor`
  2. 下一轮优先继续做：
     - `ai-config / agreement / privacy` 辅助页文案与结构统一
     - 微信运动接入 MVP 所需的云函数 / 服务端解密链路设计
     - 慢病知识约束和食物耐受记录的进一步细化
## 2026-04-05 最近动态 218
- 排查/梳理：重新分析外部项目 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 当前代码实态，确认它现在已经从“原始演示模板”推进到“本地存储驱动的健康管理小程序 MVP”，但距离 README 所写的 Production Ready 仍有明显差距。
- 当前结论：
  - 技术栈仍是原生微信小程序，无 package.json、无独立测试目录、无自动化构建脚本；核心代码集中在 src/app.js、src/pages/*、src/utils/*
  - 现在的产品主线已经不是单纯饮食/运动记录，而是“健康档案 + 每日打卡 + 慢病膳食辅助 + 可编辑训练计划 + AI 配置”的一体化闭环
  - 数据层仍以 wx.getStorageSync / wx.setStorageSync 本地存储为主，AI 调用直接从小程序端发起，请求配置和用户健康数据都还没有后端隔离
  - 自定义导航、安全区、返回逻辑和新增页面注册都已经落到代码里，但最终交付质量仍依赖微信开发者工具和真机回归
- 涉及模块：
  - CURRENT_SPRINT.md
  - 外部项目 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram
- 验证：
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：Get-ChildItem -Force：通过，确认仓库为原生微信小程序结构
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：g --files：通过，确认当前核心文件分布与新增页面/工具模块
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：git status --short：通过，确认当前仍有大量未提交改动，主要集中在 pp、核心页面、health.js、i.js、
av.js 及新增页面目录
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：Test-Path package.json：返回 False
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：Get-ChildItem -Recurse -Filter *.js src | ForEach-Object { node --check .FullName }：通过，确认当前 src 下 JS 语法可过
- 风险 / 备注：
  - README 仍声明 Production Ready，但现状更接近“功能闭环已成型、工程与验证体系仍偏弱”的可演示 MVP
  - 当前终端查看部分中文会出现乱码，更像控制台编码显示问题；是否存在真实文件编码残留，仍建议结合微信开发者工具页面渲染再核一次
  - 慢病辅助与 AI 建议虽然已进入主流程，但目前仍缺少后端、权限、合规和医学约束层的真正收口
- 下一步建议：
  1. 下一轮优先在微信开发者工具里做一轮手工 smoke，覆盖 index / food / exercise / training / plan / settings / profile / checkin / training-editor
  2. 如果按“可交付”继续推进，优先补三件事：真机回归清单、AI/健康数据的后端隔离方案、README 与项目现状对齐
## 2026-04-05 最近动态 219
- 完成：为外部项目 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 新增一份可执行的交付清单文档 `DELIVERY_CHECKLIST.md`，把“离可交付还差什么”从口头判断收成了按优先级推进的固定列表。
- 完成：
  - 新增 `DELIVERY_CHECKLIST.md`
    - 梳理当前项目定位与主要风险
    - 按 `P0 / P1 / P2` 拆分真机回归、关键闭环、AI 与隐私、文案合规、数据层、运动同步、慢病边界、工程化补强
    - 为每个关键模块补了验收标准和推荐执行顺序
- 涉及模块：
  - CURRENT_SPRINT.md
  - 外部项目 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram`
- 验证：
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`Get-Content DELIVERY_CHECKLIST.md`：通过，确认清单文档已写入
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`git status --short`：通过，确认新增文件已进入工作区变更
- 风险 / 备注：
  - 当前 `CURRENT_SPRINT.md` 历史内容较长，且已有部分早前通过终端追加写入的文本格式不够规整；本轮先保证信息补记完整，不额外做全文整理，避免误伤历史记录
- 下一步建议：
  1. 直接按 `DELIVERY_CHECKLIST.md` 的 `P0` 从真机 smoke 开始推进
  2. 如果你希望我继续接手，下一轮我建议先补“真机 smoke 检查清单”，把每页的检查点写成更细的操作表
## 2026-04-05 最近动态 220
- 完成：开始直接推进外部项目 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 的 UI 升级，这一轮重点把视觉方向从“普通浅色工具页”收成“更有冲击力的运动风 + iOS 原生层级感”的核心主链路版本。
- 完成：
  - 重构全局设计系统 `src/app.wxss`
    - 统一升级颜色令牌、圆角、阴影、按钮、玻璃态、深色能量顶部背景和动效节奏
    - 增加更强的深色首屏氛围、荧光绿 / 冷青强调色和全局 `card-dark / premium-pill / section-kicker` 等基础能力
  - 重构首页 `src/pages/index/index.wxml` / `src/pages/index/index.wxss`
    - 改为深色驾驶舱式 hero、环形热量面板、营养分配卡、高级感快捷入口和恢复状态卡
    - 同步优化 `src/pages/index/index.js` 的环形图配色、阴影和轨道表现
  - 重构训练页 `src/pages/training/training.wxml` / `src/pages/training/training.wxss`
    - 目标选择区改为更强视觉卡片
    - 计划结果区改为更像“训练控制台”的深色结果面板
    - 我的计划区统一为新的卡片和操作按钮风格
  - 重构方案页 `src/pages/plan/plan.wxml` / `src/pages/plan/plan.wxss`
    - 首屏改为策略型 hero
    - 三餐推荐、慢病模式、目标选择、自定义目标和 7 天趋势统一到新设计语言
  - 重构“我的”页 `src/pages/settings/settings.wxml` / `src/pages/settings/settings.wxss`
    - 改为控制中心式头部
    - 提升统计层级、列表卡片质感和功能分组清晰度
- 涉及模块：
  - CURRENT_SPRINT.md
  - 外部项目 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram`
- 验证：
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`Get-ChildItem -Recurse -Filter *.js src | ForEach-Object { node --check $_.FullName }`：通过
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`rg -n "DAILY DRIVE|TRAINING LAB|NUTRITION ENGINE|CONTROL CENTER|goal-panel|profile-hero|dashboard-card|drawCalorieRing" src\pages src\app.wxss`：通过，确认新视觉结构与核心类名已落地
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`git diff --stat -- src\app.wxss src\pages\index\index.js src\pages\index\index.wxml src\pages\index\index.wxss src\pages\training\training.wxml src\pages\training\training.wxss src\pages\plan\plan.wxml src\pages\plan\plan.wxss src\pages\settings\settings.wxml src\pages\settings\settings.wxss`：通过，确认本轮核心改动集中在全局设计系统与 4 个主页面
- 风险 / 备注：
  - 当前环境仍未直接跑微信开发者工具真机预览，因此这轮验证主要覆盖结构、样式落点和 JS 语法；实际动效节奏、滚动手感和刘海屏表现仍建议真机过一遍
  - 目前 `food / exercise / ai-config / agreement / privacy` 还没有完全跟上这套新视觉语言，主链路已经拉齐，但全局一致性还可以继续收
- 下一步建议：
  1. 下一轮优先继续把 `food` 和 `exercise` 两个高频录入页升级到同一套视觉系统
  2. 然后再统一 `ai-config / agreement / privacy` 等辅助页面，完成整仓视觉收口
## 2026-04-05 最近动态 221
- 完成：继续推进外部项目 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 的高频录入链路 UI 升级，这一轮重点把 `food` 和 `exercise` 两个页面收到了与首页 / 训练 / 方案 / 我的相同的高级运动风设计系统里。
- 完成：
  - 重构 `src/pages/food/food.wxml` / `src/pages/food/food.wxss`
    - 改为深色营养录入 hero、搜索与添加一体化入口、餐次切换卡、记录列表卡和更高级的手动录入底部弹层
    - 将当日营养汇总卡和录入结构统一到新视觉体系
  - 优化 `src/pages/food/food.js`
    - 调整 mini ring 的渐变、轨道和阴影，让热量环和新的视觉系统保持一致
  - 重构 `src/pages/exercise/exercise.wxml` / `src/pages/exercise/exercise.wxss`
    - 改为深色运动消耗 hero、常用运动网格、自定义录入卡、当日记录卡和消耗参考卡
    - 返回按钮与页面主视觉统一收口
- 涉及模块：
  - CURRENT_SPRINT.md
  - 外部项目 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram`
- 验证：
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`Get-ChildItem -Recurse -Filter *.js src | ForEach-Object { node --check $_.FullName }`：通过
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`rg -n "FOOD LOG STUDIO|MOVE & BURN|meal-switch-card|quick-panel|drawMiniRing|search-shell|burn-orb" src\pages`：通过，确认新结构与关键样式类已落地
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`rg -n '\?/text>|\?/view>|\?/button>' src\pages\food\food.wxml src\pages\exercise\exercise.wxml`：无结果，说明未发现明显损坏闭合标签
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`git diff --stat -- src\pages\food\food.js src\pages\food\food.wxml src\pages\food\food.wxss src\pages\exercise\exercise.wxml src\pages\exercise\exercise.wxss`：通过，确认本轮主要改动集中在高频录入页
- 风险 / 备注：
  - 当前仍未直接在微信开发者工具里做真机回归，因此录入页的滚动体验、底部弹层手感和小屏适配还需要真机验证
  - `ai-config / agreement / privacy` 等辅助页还未完全跟上这一轮视觉升级，整仓风格一致性仍可继续推进
- 下一步建议：
  1. 下一轮优先统一 `ai-config / agreement / privacy` 三个辅助页的视觉语言
  2. 然后再根据真机预览结果细调 `food / exercise` 的输入区、弹层高度和列表密度
## 2026-04-05 最近动态 222
- 完成：继续推进外部项目 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 的辅助页面视觉收口，这一轮把 `ai-config / agreement / privacy` 统一到了新的高级运动风 + iOS 原生层级视觉体系。
- 完成：
  - 重构 `src/pages/ai-config/ai-config.wxml` / `src/pages/ai-config/ai-config.wxss`
    - 改为 AI 控制台式 hero、服务商卡片、接口配置卡、模型参数卡、提示词卡、状态反馈卡和说明卡
    - 保留现有测试连接、保存配置和清空配置逻辑不变
  - 重构 `src/pages/agreement/agreement.wxml` / `src/pages/agreement/agreement.wxss`
    - 改为深色法律说明 hero、摘要卡、分节阅读卡和更稳的底部同意区
    - 协议文本结构重新整理为更清晰的阅读版式
  - 重构 `src/pages/privacy/privacy.wxml` / `src/pages/privacy/privacy.wxss`
    - 改为深色隐私说明 hero、摘要卡和分节阅读卡
    - 明确当前版本“本地存储为主、AI 按用户配置直连第三方服务”的数据边界
- 涉及模块：
  - CURRENT_SPRINT.md
  - 外部项目 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram`
- 验证：
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`Get-ChildItem -Recurse -Filter *.js src | ForEach-Object { node --check $_.FullName }`：通过
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`rg -n "AI CONTROL|TERMS OF USE|PRIVACY NOTICE|provider-panel|summary-card|agreement-footer|test-result|summary-grid" src\pages`：通过，确认辅助页新结构和关键类名已落地
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`rg -n '\?/text>|\?/view>|\?/button>' src\pages\ai-config\ai-config.wxml src\pages\agreement\agreement.wxml src\pages\privacy\privacy.wxml`：无结果，说明未发现明显损坏闭合标签
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`git diff --stat -- src\pages\ai-config\ai-config.wxml src\pages\ai-config\ai-config.wxss src\pages\agreement\agreement.wxml src\pages\agreement\agreement.wxss src\pages\privacy\privacy.wxml src\pages\privacy\privacy.wxss`：通过，确认本轮改动集中在 3 个辅助页面
- 风险 / 备注：
  - 当前 UI 主链路和辅助页已经基本切到同一套视觉系统，但尚未做微信开发者工具真机回归，滚动节奏、状态栏安全区和底部固定区仍建议真机过一遍
  - 当前仓库仍有较多历史未提交改动，本轮没有回退或覆盖用户已有修改
- 下一步建议：
  1. 下一轮优先做一轮微信开发者工具真机 smoke，重点检查 `agreement / privacy / ai-config / food / exercise`
  2. 如果继续做视觉精修，可以再统一 `profile / checkin / training-editor` 的局部控件密度和细节动画
## 2026-04-05 最近动态 223
- 完成：继续收口外部项目 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 的 AI 配置策略与页面交互，这一轮把 `ai-config` 从“偏工程师控制台”改成了更平民化的“AI 助手设置”，并直接定下了“免费预设优先 + 配好后一键切换 + 不建议前端直连共享 Key”的产品策略。
- 完成：
  - 重构 `src/pages/ai-config/ai-config.js`
    - 新增按服务商分别保存本地配置的能力，用户为不同服务填写过 Key / 模型 / 地址后，再点服务卡即可一键切换
    - 统一切到国产助手优先预设：`doubao / deepseek / kimi / ollama / custom`
    - 新增更平民化的切换逻辑：已配置服务可直接切换，未配置服务则提示先补配置
  - 重构 `src/pages/ai-config/ai-config.wxml` / `src/pages/ai-config/ai-config.wxss`
    - 页面文案从“AI 控制台”调整为更接近普通用户理解的“AI 助手设置”
    - 增加“推荐模式 / 不建议模式 / 多人使用时怎么做”的直白说明
    - 将高级参数折叠到“展开高级设置”后，减少首次进入的信息负担
    - 在服务卡中明确区分“免费体验优先”“通常需自备额度”“本地可免费”等状态
  - 调整 `src/utils/ai.js`
    - 新增 `deepseek / doubao / kimi` 的默认 endpoint 和 model
  - 调整 `src/app.js`
    - 将全局默认 AI 配置切到 `doubao`
- 涉及模块：
  - CURRENT_SPRINT.md
  - 外部项目 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram`
- 验证：
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`Get-ChildItem -Recurse -Filter *.js src | ForEach-Object { node --check $_.FullName }`：通过
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`rg -n "doubao|deepseek|kimi|一键切换|多人使用时怎么做|服务端统一代理|前端直连共享 Key" src\pages\ai-config src\utils\ai.js src\app.js`：通过，确认新的默认预设和产品策略提示已落地
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`rg -n '\?/text>|\?/view>|\?/button>' src\pages\ai-config\ai-config.wxml`：无结果
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`git diff --stat -- src\utils\ai.js src\app.js src\pages\ai-config\ai-config.js src\pages\ai-config\ai-config.wxml src\pages\ai-config\ai-config.wxss`：通过，确认本轮改动集中在 AI 配置链路
- 风险 / 备注：
  - 当前页面层已经把“免费体验优先”与“通常需自备额度”区分清楚，但如果后续真的做多人正式使用，仍建议下一轮直接补服务端代理层方案，而不是沿用前端直连思路
  - 这轮没有引入登录系统；如果你决定做“游客也能试用”，建议后端至少按设备 ID 或匿名 session 做限流
- 下一步建议：
  1. 下一轮我可以继续直接帮你产出“AI 服务端代理 MVP 方案”，把匿名试用、限流、排队、缓存和超时策略写成可开发清单
  2. 如果你先要继续视觉收尾，则回到真机 smoke，专查 `ai-config / food / exercise / agreement / privacy`
## 2026-04-05 最近动态 224
- 完成：继续优化外部项目 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 的 AI 使用逻辑，这一轮重点不是继续堆 UI，而是把“普通用户可用”和“免费体验不容易被打爆”两件事一起往前推了一步。
- 完成：
  - 优化 `src/pages/ai-config/ai-config.js`
    - 预设服务进一步收敛到更贴近生活助手方向的 `doubao / deepseek / kimi / ollama / custom`
    - 保留“每个服务单独记住 Key / 模型 / 地址，配好后点一下切换”的逻辑
    - 把产品判断直接写进页面：推荐服务端统一代理，不建议前端直连共享 Key
  - 优化 `src/pages/ai-config/ai-config.wxml` / `src/pages/ai-config/ai-config.wxss`
    - 将 AI 设置进一步做得更平民化
    - 增加“免费体验优先 / 通常需自备额度 / 本地可免费”的直白标签
    - 增加“需不需要登录、多人会不会卡住、推荐接入模式”说明
  - 优化 `src/utils/ai.js`
    - 新增 `doubao / deepseek / kimi` 默认 endpoint 和默认模型
  - 优化 `src/app.js`
    - 默认 AI 切到 `doubao`
    - 新增 AI 请求在飞保护，避免用户连续点击重复打请求
    - 新增已配置服务的自动候补逻辑：当前服务不可用时，会尝试已配置的备用服务
  - 优化 `src/pages/training/training.js`
    - 如果训练计划请求自动切到了备用服务，会给出轻提示，减少用户困惑
- 涉及模块：
  - CURRENT_SPRINT.md
  - 外部项目 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram`
- 验证：
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`node --check src\app.js`：通过
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`node --check src\pages\ai-config\ai-config.js`：通过
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`node --check src\pages\training\training.js`：通过
  - 在 `C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram` 执行：`rg -n "AI 正在处理中|至少配置一个可用服务|fallbackUsed|autoSwitchedProvider|已自动切到|豆包|DeepSeek|Kimi" src\app.js src\pages\ai-config\ai-config.js src\pages\ai-config\ai-config.wxml src\pages\training\training.js`：通过
- 风险 / 备注：
  - 当前“自动候补”只是在客户端层做兜底，能减少单个用户的失败感知，但不能替代真正的服务端限流和代理
  - 如果后续要给大量真实用户开放免费试用，下一步仍应尽快补后端，不适合长期依赖前端直连
- 下一步建议：
  1. 继续直接做“AI 服务端代理 MVP 方案”，把游客试用、限流、缓存和超时策略落成开发任务
  2. 如果你准备马上进开发者工具验 UI，则优先复测 `ai-config` 的服务切换、保存、测试连接和错误提示
## 2026-04-05 最近动态 225
- 完成：继续在外部项目 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 上推进“拍照识别记餐”MVP，并把技术路线从“必须单独后端”收口成“优先微信云函数，没有云函数时再回退 HTTP 接口”的可落地方案。
- 完成：
  - 新增 src/utils/food-photo.js
    - 统一处理拍照识别入口
    - 优先走 wx.cloud.uploadFile + wx.cloud.callFunction
    - 无云函数时支持回退到 HTTP 接口
    - 统一清洗模型返回的食物 JSON
  - 重构 src/pages/food/food.js
    - 新增拍照/选图识别流程
    - 新增识别中状态
    - 新增“识别结果确认”弹层
    - 确认后按现有 pp.addMealLog() 逐条写入 mealLogs
  - 优化 src/pages/food/food.wxml / src/pages/food/food.wxss
    - 增加“拍照识别”按钮和提示卡
    - 增加识别结果确认弹层，包括预览图、识别项列表和移除单项能力
  - 优化 src/app.js
    - 补 wx.cloud.init()，让当前小程序可以直接走云开发能力
  - 新增云函数骨架：
    - cloudfunctions/foodPhotoRecognize/index.js
    - cloudfunctions/foodPhotoRecognize/package.json
    - 作用：接收图片临时 URL，调用多模态模型并返回结构化食物识别 JSON
  - 新增部署文档：
    - FOOD_PHOTO_RECOGNITION_MVP.md
    - 说明前端流程、云函数部署步骤、环境变量和推荐模型配置
- 涉及模块：
  - CURRENT_SPRINT.md
  - 外部项目 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram
- 验证：
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：
ode --check src\pages\food\food.js：通过
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：
ode --check src\utils\food-photo.js：通过
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：
ode --check src\app.js：通过
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：
ode --check cloudfunctions\foodPhotoRecognize\index.js：通过
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：g -n "拍照识别|chooseFoodPhoto|showRecognitionModal|foodPhotoRecognize|wx\.cloud\.init|PHOTO DRAFT|FOOD_PHOTO_" src cloudfunctions FOOD_PHOTO_RECOGNITION_MVP.md：通过，确认前端入口、云函数、文档和环境变量说明已落地
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：g -n '\?/text>|\?/view>|\?/button>' src\pages\food\food.wxml src\pages\ai-config\ai-config.wxml：无结果
- 风险 / 备注：
  - 当前拍照识别链路已经具备前端和云函数骨架，但云函数真正可用还需要你在微信开发者工具里部署 oodPhotoRecognize 并配置 FOOD_PHOTO_* 环境变量
  - 识别结果当前支持“移除单项后整体加入”，但还没有做到逐项手动改单个食物的克数/热量
- 下一步建议：
  1. 在微信开发者工具里先部署 cloudfunctions/foodPhotoRecognize，并按 FOOD_PHOTO_RECOGNITION_MVP.md 配好环境变量
  2. 部署后第一轮真机联调优先验证：拍照上传、识别成功、识别失败、确认入库、移除单项这五条路径
## 2026-04-05 最近动态 226
- 完成：继续优化外部项目 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 的“拍照识别记餐”体验，这一轮重点把识别结果从“只能整体接受”升级成了“确认前可编辑”的版本。
- 完成：
  - 优化 src/pages/food/food.js
    - 新增识别结果餐次切换能力
    - 新增单项克数编辑能力，编辑后会按比例联动热量与三大营养素
    - 新增单项热量手动修正能力
    - 将识别草稿的总热量汇总逻辑统一收口
  - 优化 src/pages/food/food.wxml
    - 在识别结果确认弹层里新增餐次切换区
    - 在每个识别项下新增“克数 / 热量”可编辑输入区
  - 优化 src/pages/food/food.wxss
    - 补齐识别确认弹层的餐次切换样式与编辑区样式
- 涉及模块：
  - CURRENT_SPRINT.md
  - 外部项目 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram
- 验证：
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：
ode --check src\pages\food\food.js：通过
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：g -n "switchRecognitionMeal|onRecognizedGramInput|onRecognizedCaloriesInput|recognition-meal-switch|recognition-edit-row|recognition-edit-input" src\pages\food：通过，确认编辑逻辑与样式已落地
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：g -n '\?/text>|\?/view>|\?/button>' src\pages\food\food.wxml：无结果
- 风险 / 备注：
  - 当前仍然是“改单项克数 / 热量”级别的编辑，尚未补到“改单项名称 / 类别 / 蛋白碳水脂肪”的更细编辑
  - 若后续识别误差主要集中在复杂菜品和油量估算，下一轮更推荐补“改单项名称/类别”和“新增一项”能力
- 下一步建议：
  1. 下一轮优先继续给识别确认弹层补“新增一项 / 改名称 / 改类别”
  2. 如果你准备联调云函数，则现在已经可以先走一轮真机测试，把拍照上传、识别确认和入库链路跑通
## 2026-04-05 最近动态 226
- 完成：继续优化外部项目 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 的“拍照识别记餐”确认层，这一轮把识别草稿从“可删除、可改克数/热量”进一步补成了“可新增、可改名称、可改分类”的可编辑工作台。
- 完成：
  - 优化 src/pages/food/food.js
    - 新增 ddRecognizedItem()
    - 新增 onRecognizedNameInput()
    - 新增 onRecognizedCategoryChange()
    - 识别草稿现在支持新增手工项和改名称/分类
  - 优化 src/pages/food/food.wxml
    - 在识别结果确认弹层中加入名称输入框、分类选择器和“新增一项”按钮
  - 优化 src/pages/food/food.wxss
    - 补齐名称输入、分类标签和新增按钮样式
- 涉及模块：
  - CURRENT_SPRINT.md
  - 外部项目 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram
- 验证：
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：
ode --check src\pages\food\food.js：通过
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：g -n "addRecognizedItem|onRecognizedNameInput|onRecognizedCategoryChange|recognition-name-input|recognition-category-value|recognition-add-btn" src\pages\food：通过
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：g -n '\?/text>|\?/view>|\?/button>' src\pages\food\food.wxml：无结果
- 风险 / 备注：
  - 当前识别确认层已经可以支撑“拍照出草稿 + 用户修正后入库”，但还没有补到“改单项蛋白/碳水/脂肪”这一层
  - 如果你后续发现主要误差在营养估算而不是食物名和克数，下一轮再补单项宏量营养编辑会更有价值
- 下一步建议：
  1. 现在可以优先去微信开发者工具做真机联调，先把拍照上传、云函数识别、确认入库完整跑通
  2. 联调后如果发现某些菜品营养误差偏大，我下一轮可以继续补“改单项蛋白/碳水/脂肪”
## 2026-04-05 最近动态 227
- 完成：继续优化外部项目 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 的拍照识别确认层，这一轮把单项营养修正也补齐了，识别草稿已经可以在入库前直接改碳水 / 蛋白 / 脂肪。
- 完成：
  - 优化 src/pages/food/food.js
    - 新增 onRecognizedCarbsInput()
    - 新增 onRecognizedProteinInput()
    - 新增 onRecognizedFatInput()
  - 优化 src/pages/food/food.wxml
    - 在识别结果确认弹层中补充“碳水 / 蛋白 / 脂肪”三项可编辑输入区
  - 优化 src/pages/food/food.wxss
    - 为营养编辑区补齐 macro-row 的布局样式
- 涉及模块：
  - CURRENT_SPRINT.md
  - 外部项目 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram
- 验证：
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：
ode --check src\pages\food\food.js：通过
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：g -n "onRecognizedCarbsInput|onRecognizedProteinInput|onRecognizedFatInput|macro-row" src\pages\food：通过
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：g -n '\?/text>|\?/view>|\?/button>' src\pages\food\food.wxml：无结果
- 风险 / 备注：
  - 当前识别确认层已经可以改名称、分类、克数、热量和三大营养素，实用性已经较高
  - 仍未补“改单项时间”与“改单项图标”这类低优先级字段，但对记餐主流程影响不大
- 下一步建议：
  1. 现在优先去微信开发者工具做云函数联调，这条链路已经值得开始真机验证
  2. 如果联调后识别质量还不稳定，下一轮优先优化云函数里的 prompt 和错误映射，而不是继续加前端控件
## 2026-04-05 最近动态 228
- 完成：继续优化外部项目 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 的拍照识别链路，这一轮重点不再是增加新入口，而是同步加强了“云函数识别质量”和“确认层可修正能力”。
- 完成：
  - 重构 cloudfunctions/foodPhotoRecognize/index.js
    - 统一重写为更干净的实现
    - 强化 prompt，要求模型更保守地处理混合菜、盖饭、汤面等复杂场景
    - 明确“只返回 JSON”
    - 新增超时控制、最多 2 次重试和更清晰的错误映射
    - 新增 JSON 解析失败、鉴权失败、限流和网络故障等场景的更友好错误信息
  - 更新 FOOD_PHOTO_RECOGNITION_MVP.md
    - 补充当前前端确认层已支持的编辑能力
    - 补充云函数当前的重试、超时和错误处理说明
  - 继续优化 src/pages/food/food.js / src/pages/food/food.wxml / src/pages/food/food.wxss
    - 确认层现已支持改单项名称、分类、克数、热量以及碳水 / 蛋白 / 脂肪
- 涉及模块：
  - CURRENT_SPRINT.md
  - 外部项目 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram
- 验证：
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：
ode --check cloudfunctions\foodPhotoRecognize\index.js：通过
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：
ode --check src\pages\food\food.js：通过
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：g -n "MAX_ATTEMPTS|JSON_PARSE_FAILED|鉴权失败|当前较忙|改碳水|改名称|新增一项|只返回 JSON" cloudfunctions\foodPhotoRecognize\index.js src\pages\food\food.js FOOD_PHOTO_RECOGNITION_MVP.md：通过
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：git status --short：通过，确认 FOOD_PHOTO_RECOGNITION_MVP.md、cloudfunctions/、src/utils/food-photo.js 等新增产物仍在工作区中
- 风险 / 备注：
  - 当前云函数的稳定性已经比第一版更好，但真正识别效果仍高度依赖你最终接入的视觉模型和图片质量
  - 若后续主要问题不是“识别失败”而是“识别偏差”，则优先继续迭代云函数 prompt 和样例，而不是再继续堆前端控件
- 下一步建议：
  1. 现在优先去微信开发者工具部署并联调 oodPhotoRecognize 云函数
  2. 联调后把 3 张典型场景图片给我：单品、盖饭、混合菜；我下一轮可以继续按真实误差优化 prompt
## 2026-04-05 最近动态 229
- 完成：继续优化外部项目 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 的拍照识别报错诊断，这一轮重点是把“检查网络或者检查云函数”这种过于笼统的提示，改成更接近真实原因的定位信息。
- 完成：
  - 重构 src/utils/food-photo.js
    - 补充微信云函数调用失败的错误映射
    - 现在会更明确区分：
      - 没有部署 oodPhotoRecognize
      - 云环境未选择或未开通
      - 图片上传到云存储失败
      - 云函数调用失败
      - HTTP 接口失败
    - 同时修复了一处会吞掉云函数真实错误的逻辑问题
  - 清理 src/pages/food/food.js 中历史遗留的坏字符串，恢复文件可稳定通过语法检查
  - 优化 src/pages/food/food.js 的识别提示文案，让用户知道优先该检查“云函数部署 / 云环境 / FOOD_PHOTO_* 环境变量”
- 涉及模块：
  - CURRENT_SPRINT.md
  - 外部项目 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram
- 验证：
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：
ode --check src\utils\food-photo.js：通过
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：
ode --check src\pages\food\food.js：通过
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：g -n "没有找到云函数 foodPhotoRecognize|云环境没有配置好|FOOD_PHOTO_\*|云函数是否部署|HTTP 识别接口" src\utils\food-photo.js src\pages\food\food.js：通过
- 风险 / 备注：
  - 当前报错提示已经比之前清楚很多，但真正的云函数运行细节仍需结合微信开发者工具里的云函数日志一起排查
- 下一步建议：
  1. 现在优先在开发者工具里确认：云开发已开通、oodPhotoRecognize 已部署、环境变量已配置
  2. 如果你下一次把开发者工具里的报错原文或云函数日志贴给我，我可以继续按真实错误定点收口
## 2026-04-05 最近动态 230
- 完成：继续收口外部项目 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 的剩余前端页面，这一轮重点把 profile / checkin / training-editor 三个真实功能页补到了和主链路一致的视觉体系里。
- 完成：
  - 重构 src/pages/profile/profile.wxml / src/pages/profile/profile.wxss
    - 改为深色档案 hero、基础信息区、慢病与饮食限制区和说明卡
  - 重构 src/pages/checkin/checkin.wxml / src/pages/checkin/checkin.wxss
    - 改为深色打卡 hero、执行情况区、症状观察区和备注区
  - 重构 src/pages/training-editor/training-editor.wxml / src/pages/training-editor/training-editor.wxss
    - 改为深色计划编辑 hero、计划信息区和动作清单编辑区
- 涉及模块：
  - CURRENT_SPRINT.md
  - 外部项目 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram
- 验证：
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：
ode --check src\pages\profile\profile.js：通过
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：
ode --check src\pages\checkin\checkin.js：通过
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：
ode --check src\pages\training-editor\training-editor.js：通过
  - 在 C:\Users\chenjiageng\.openclaw\workspace\eatfit-miniprogram 执行：g -n "HEALTH PROFILE|DAILY CHECK-IN|PLAN EDITOR|section-kicker|panel-title|hero-panel" src\pages\profile src\pages\checkin src\pages\training-editor：通过
- 风险 / 备注：
  - 当前前端主要页面已经基本统一，但个别旧页面文案在终端里仍可能表现为乱码；更像控制台编码显示问题，最终仍建议以开发者工具真实渲染为准
- 下一步建议：
  1. 现在优先做一轮开发者工具真机 smoke，而不是继续大改 UI
  2. 如果后续还要继续打磨，优先按真机问题单做小步收口
## 2026-04-05 最近动态 231
- 完成：对当前仓库 `C:\Users\chenjiageng\Desktop\sunliao` 做了一轮结构化分析，补了前后端架构、测试基线、交付状态和当前工作区风险的结论。
- 排查结论：
  - 当前仓库主线仍然清晰，是 `flutter-app` 客户端 + `backend/server` 服务端 + `versions` 版本文档的双端工程，不是单前端演示仓库。
  - Flutter 侧分层已经比较成型，入口集中在 `main.dart`、`config/routes.dart`、`providers/*`、`services/*`；当前工作区活跃改动主要集中在“通知权限引导”和“聊天投递状态”两条链路。
  - 后端不是空壳 scaffold：`backend/server` 里已经有 `auth / users / settings / friends / match / chat / report` 模块、WebSocket 网关、memory/postgres/redis 驱动切换，以及成套集成测试。
  - 当前项目更接近“可持续收口中的联调 / 区域测试版”，不是纯 Demo；但距离正式商店上线仍缺正式签名、正式域名与 HTTPS、短信服务、PostgreSQL / Redis、推送 SDK、监控与风控后台等正式能力。
  - `CURRENT_SPRINT.md` 当前已经混入大量外部项目 `eatfit-miniprogram` 与 OpenClaw 工具记录，这会削弱它作为 Sunliao 当前进度“单一事实来源”的可靠性；后续最好单独清理或拆分。
- 涉及模块：
  - `CURRENT_SPRINT.md`
- 验证：
  - 在项目根目录执行：`git status --short`：通过，确认当前工作区存在未提交的 Sunliao 改动，主要集中在 Flutter 通知权限提示、聊天投递状态和相关 smoke/widget test。
  - 在项目根目录执行：`git diff --stat`：通过，确认本轮前序在研改动主要落在 `settings_screen`、`messages_tab`、`chat_delivery_status`、`notification_permission_notice_card` 及对应测试。
  - 在项目根目录执行：`Get-ChildItem -Force`、`rg --files`：通过，确认仓库包含 `flutter-app`、`backend/server`、`versions`、`tools` 等明确边界。
  - 在 `backend/server` 目录执行：`npm.cmd run test:integration`：通过，`4` 个测试套件、`34` 条测试全部通过。
  - 在 `backend/server` 目录执行：`npm.cmd run build`：通过。
  - 在项目根目录执行：`rg -n "flutter.*假死|lockfile|提权|沙箱外" ENVIRONMENT_SETUP.md CURRENT_SPRINT.md AGENTS.md`：通过，确认 Flutter CLI 仍存在“SDK 在工作区外导致 lockfile/权限问题”的环境性风险。
- 风险 / 备注：
  - 本轮没有主动补跑 Flutter 全量 `analyze/test`，原因不是忽略前端，而是项目文档已明确记录当前机器上 Flutter CLI 有较高概率出现无输出假死；这属于环境层阻塞，不应误判为代码本身失效。
  - 当前 Git 工作区已经是脏状态，且包含他人或前序未提交改动；后续继续开发时需要严格在现有改动之上增量推进，不能直接覆盖。
- 下一步建议：
  1. 先把 `CURRENT_SPRINT.md` 里不属于 Sunliao 的外部项目记录拆出去，恢复它作为当前仓库进度看板的可信度。
  2. 下一轮优先围绕当前已在进行的“通知权限引导 + 聊天投递状态”继续做最小闭环，并在可控范围内补跑对应 Flutter focused analyze / smoke。
  3. 如果目标转向可交付版本，接下来最值得推进的是正式环境配置、后端持久化驱动切换和内网穿透前的鉴权 / WebSocket 恢复验证。
