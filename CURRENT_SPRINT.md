# 当前迭代

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
