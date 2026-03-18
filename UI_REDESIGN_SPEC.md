# 瞬 (Sunliao) UI 重设计规范

> 版本：v1.0 · 2026-03-18
> 原则：在现有暗色主题基础上优化，参考微信、Telegram 成熟交互模式，不替换技术栈
> 执行 Agent：Flutter Agent
> 配合阅读：`MULTI_AGENT_DEV_GUIDE.md` → `flutter-app/lib/config/theme.dart`

---

## 一、设计原则

1. **保持现有暗色主题**：`AppColors` 颜色常量不变，所有改动在布局层面进行
2. **参考成熟 App 的空间布局**：微信（层级清晰）+ Telegram（信息密度适中）
3. **克制**：不增加动画复杂度，不引入新图标库，保持已有视觉语言
4. **一致性**：各 Tab 的 AppBar 高度、padding、字体规格统一

---

## 二、导航栏（BottomNavBar）优化

### 当前状态
- 4 个 Tab：匹配 / 消息 / 好友 / 我的
- 带小圆角卡片包裹的浮动导航
- 选中态：顶部蓝色横线 + 白色背景

### 目标调整

**Tab 顺序调整**（参考微信/Telegram 惯用顺序）：

```
旧顺序：匹配(0) → 消息(1) → 好友(2) → 我的(3)
新顺序：消息(0) → 匹配(1) → 好友(2) → 我的(3)
```

理由：
- 消息是高频操作，放最左符合拇指习惯（微信/Telegram 均以消息为首 Tab）
- 匹配是核心差异化功能，居中突出
- 好友与我的保持右侧，符合信息架构惯例

**匹配 Tab 图标强化**：
- 将匹配按钮图标改为略大（比其他 Tab 大 4px）
- 使用 `Icons.bolt` 替代 `Icons.whatshot_outlined`，更简洁
- 选中时图标下方显示 `brandBlue` 点，其他 Tab 保持横线

**文件修改位置**：[main_screen.dart](flutter-app/lib/screens/main_screen.dart)

```dart
// 修改 Tab 构建顺序（index 0→消息, 1→匹配, 2→好友, 3→我的）
Widget _buildCurrentTab() {
  return switch (_currentIndex) {
    0 => const MessagesTab(),   // 原 index 1
    1 => const MatchTab(),      // 原 index 0
    2 => const FriendsTab(),    // 不变
    _ => const ProfileTab(),    // 不变
  };
}
```

---

## 三、消息页（MessagesTab）优化

### 当前状态
- AppBar 居中「消息」标题 + 右侧通知铃铛
- 列表：头像 + 昵称 + 最后一条消息预览 + 时间
- 无搜索功能
- 空状态用 💵 emoji（与产品气质不符）

### 目标调整

#### 3.1 AppBar 改为左对齐大标题（参考 Telegram）

```
┌────────────────────────────────────────┐
│  消息                        🔔  ✏️    │  ← 标题左对齐，右侧：通知铃 + 新建对话
├────────────────────────────────────────┤
│  🔍  搜索消息...                        │  ← 搜索栏（固定在 AppBar 下方）
├────────────────────────────────────────┤
│  [消息列表]                             │
└────────────────────────────────────────┘
```

**搜索栏规格**：
- 背景：`AppColors.white05`
- 圆角：`BorderRadius.circular(10)`
- 高度：40px（compact）/ 44px（normal）
- 左侧图标：`Icons.search`，颜色 `AppColors.textTertiary`
- placeholder：「搜索」
- 搜索范围：昵称、消息内容前缀

#### 3.2 会话列表项优化

```
┌──────────────────────────────────────────────┐
│  [头像]  昵称           时间（右对齐）         │
│          最后消息预览   [未读气泡]             │
└──────────────────────────────────────────────┘
```

- 时间移至右上角（参考微信）
- 未读气泡移至右下角
- 删除当前「好友」tag 小标签，改为头像右下角显示绿色小圆点（在线）
- 「限时」倒计时仅在剩余 < 2小时时以橙色文字显示在昵称旁

#### 3.3 空状态修复

```dart
// 将 💵 emoji 替换为图标
Icon(Icons.chat_bubble_outline, size: 56, color: AppColors.textTertiary.withValues(alpha: 0.3))
// 文案：「还没有消息」
// 副文案：「去匹配一个人，开始聊聊吧」
```

**文件修改位置**：[messages_tab.dart](flutter-app/lib/widgets/messages_tab.dart)

---

## 四、匹配页（MatchTab）优化

### 当前状态
- 顶部：大标题「瞬」+ 副标题 + 剩余次数
- 中部：呼吸光球（核心交互元素）
- 底部：匹配按钮 + 快速问候选择

### 目标调整

#### 4.1 顶部 Header 精简

```
旧：
  瞬（大字）
  匿名随机 · 只存在24小时
  剩余 N 次
  [今日已开启/已完成 状态 chip]

新：
  瞬                     历史  ← 右上角新增历史入口
  今日剩余 N 次  ·  重置 HH:MM
```

- 副标题「匿名随机·只存在24小时」下沉到光球下方作为小字说明，节省竖向空间
- 右上角新增「历史」文字按钮，跳转到已过期匹配列表（路由：`/match-history`）

#### 4.2 光球区域不变

光球是品牌核心视觉，动画逻辑和大小规格保持现有 `_MatchLayoutSpec` 不变。

#### 4.3 快速问候区域优化

```
旧：6个问候语 chip，横向 Wrap 排列
新：横向可滚动 Row（SingleChildScrollView），每个 chip 稍加左右 padding
```

- 解决小屏上 Wrap 导致的换行拥挤问题
- 自定义输入框保持不变，放在 chip 列表下方

**文件修改位置**：[match_tab.dart](flutter-app/lib/widgets/match_tab.dart)

---

## 五、好友页（FriendsTab）优化

### 目标调整（轻量）

```
┌────────────────────────────────────────┐
│  好友                        ➕         │  ← 右上角加好友按钮（现有功能）
├────────────────────────────────────────┤
│  [待处理请求 Banner，有请求时才显示]     │
├────────────────────────────────────────┤
│  好友列表                              │
└────────────────────────────────────────┘
```

- 待处理好友请求改为顶部 Banner（橙色底，「N 条待处理请求 →」），点击展开
- 当前 `pendingCount` 在 BottomNav 已有 badge，Banner 作为补充引导
- 好友列表项：头像 + 昵称 + 在线状态（参考 Telegram 联系人列表密度）

---

## 六、个人页（ProfileTab）优化

### 当前状态
- 顶部背景图 + 头像 + 昵称 + 签名
- 下方：设置列表（通知、隐私、主题等）

### 目标调整

#### 6.1 个人信息区域新增数据统计行

```
┌────────────────────────────────────────┐
│  [背景图]                               │
│      [头像]  昵称  ✏️                   │
│             个性签名                   │
│  ────────────────────────────────────  │
│    匹配   好友   消息                  │  ← 新增统计行
│    128    36     204                   │
│  ────────────────────────────────────  │
└────────────────────────────────────────┘
```

统计数据来源：
- 匹配次数：`MatchProvider.totalMatchCount`（需新增字段）
- 好友数：`FriendProvider.friends.length`
- 消息数：`ChatProvider.threads.length`

#### 6.2 设置列表分组（参考微信「我」页面）

```
分组一：账号
  - 头像 / 背景图设置（现有）
  - 昵称 / 签名（现有）

分组二：隐私
  - 截图保护（现有）
  - 阻止列表（现有）

分组三：通知
  - 消息通知（现有）

分组四：关于
  - 版本号（只读）
  - 用户协议（现有）
  -
  - 反馈 / 联系我们

**文件修改位置**：[profile_tab.dart](flutter-app/lib/widgets/profile_tab.dart)

---

## 七、通用规范（所有 Tab 适用）

### AppBar 统一规范

| 属性 | 规格 |
|------|------|
| 背景色 | `AppColors.pureBlack`（保持现有） |
| 标题对齐 | **左对齐**（从居中改为左对齐，参考 Telegram） |
| 标题字号 | 20px，`FontWeight.w400`，`letterSpacing: 0` |
| 高度 | 系统默认 kToolbarHeight（56px） |
| 底部分割线 | `Border(bottom: BorderSide(color: AppColors.white05))` |

### 列表项间距规范

| 场景 | 规格 |
|------|------|
| 会话列表（消息页） | 水平 16px，垂直 12px |
| 好友列表 | 水平 16px，垂直 10px |
| 设置列表（个人页） | 水平 20px，垂直 14px |

### 分组标题规范

```dart
// 分组标题样式
TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w400,
  color: AppColors.textTertiary,
  letterSpacing: 1.2,
)
// 上方间距：24px，下方间距：8px
// 左侧 padding：与列表项一致（16px 或 20px）
```

---

## 八、实施顺序建议

按改动风险从低到高排序：

```
Step 1：修复空状态 emoji（messages_tab.dart）         ← 风险极低，5分钟
Step 2：AppBar 标题改为左对齐（4个 Tab）              ← 风险低，视觉调整
Step 3：消息列表项时间/未读气泡位置调整               ← 风险低，布局调整
Step 4：个人页新增统计数据行                          ← 风险中，需新增 Provider 字段
Step 5：消息页新增搜索栏                              ← 风险中，需新增搜索逻辑
Step 6：Tab 顺序调整（消息移至首位）                  ← 风险中，需同步更新路由和测试
Step 7：匹配页 Header 精简 + 历史入口                 ← 风险中，需新增路由
Step 8：快速问候改为横向滚动                          ← 风险低，布局调整
```

每个 Step 完成后运行：
```bash
cd flutter-app && flutter analyze && flutter test test/smoke/
```

---

## 九、不做的事（避免过度改动）

- 不修改 `AppColors` 任何颜色值
- 不引入新的动画库或图标库
- 不改变光球（Orb）的视觉和动画
- 不新增底部导航 Tab（保持 4 个）
- 不改变聊天页（chat_screen.dart）布局（该页面改动风险高，单独立项）
- 不实现日间主题（产品决策，当前版本跳过）
